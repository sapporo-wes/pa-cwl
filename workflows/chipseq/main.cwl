#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "chipseq - ChIP-seq peak calling pipeline"
doc: |
  ChIP-seq analysis pipeline. Performs QC, trimming, BWA-MEM2 alignment,
  duplicate marking, BAM filtering, MACS2 peak calling, and bigWig
  generation. Supports optional control/input samples for background
  subtraction during peak calling.

  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  # === Treatment samples ===
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files (one per treatment sample)"

  fastq_rev:
    type: File[]?
    doc: "Reverse read FASTQ files (one per treatment sample, omit for single-end)"

  sample_ids:
    type: string[]
    doc: "Treatment sample identifiers (same order as FASTQ files)"

  # === Control/input sample (optional) ===
  control_fastq_fwd:
    type: File?
    doc: "Control/input forward read FASTQ"

  control_fastq_rev:
    type: File?
    doc: "Control/input reverse read FASTQ"

  control_id:
    type: string?
    default: "control"
    doc: "Control sample identifier"

  # === Reference genome ===
  genome_fasta:
    type: File
    doc: "Reference genome FASTA"

  gtf:
    type: File?
    doc: "Gene annotation GTF (for featureCounts on peaks)"

  # === Pre-built index (optional) ===
  bwa_index:
    type: File?
    secondaryFiles:
      - pattern: ".0123"
      - pattern: .amb
      - pattern: .ann
      - pattern: .bwt.2bit.64
      - pattern: .pac
    doc: "Pre-built BWA-MEM2 indexed genome FASTA (with .0123 .amb .ann .bwt.2bit.64 .pac)"

  # === Tool options ===
  trimmer:
    type:
      type: enum
      symbols: [fastp, trim_galore, skip]
    default: fastp
    doc: "Read trimming tool"

  peak_type:
    type:
      type: enum
      symbols: [narrow, broad]
    default: narrow
    doc: "Peak calling mode (narrow for TFs, broad for histone marks)"

  genome_size:
    type: string
    doc: "Effective genome size for MACS2 (hs, mm, ce, dm, or number like 1.2e7)"

steps:
  # =====================
  # BWA-MEM2 index building (conditional)
  # =====================
  build_bwa_index:
    run: ../../tools/bwa-mem2-index.cwl
    when: $(inputs.bwa_index == null)
    in:
      genome_fasta: genome_fasta
      bwa_index: bwa_index
    out: [genome_with_index]

  # =====================
  # QC + Trimming (treatment samples)
  # =====================
  qc_trim:
    run: steps/qc-trim.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_ids
      trimmer: trimmer
    out: [trimmed_fwd, trimmed_rev, fastqc_raw_zip, fastp_json]

  # =====================
  # QC + Trimming (control sample, conditional)
  # =====================
  qc_trim_control:
    run: steps/qc-trim.cwl
    when: $(inputs.fastq_fwd != null)
    in:
      fastq_fwd: control_fastq_fwd
      fastq_rev: control_fastq_rev
      sample_id: control_id
      trimmer: trimmer
    out: [trimmed_fwd, trimmed_rev, fastqc_raw_zip, fastp_json]

  # =====================
  # Alignment: treatment samples
  # =====================
  align_treatment:
    run: steps/align-bwa.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: qc_trim/trimmed_fwd
      fastq_rev: qc_trim/trimmed_rev
      sample_id: sample_ids
      genome_fasta:
        source:
          - bwa_index
          - build_bwa_index/genome_with_index
        pickValue: first_non_null
    out: [aligned_bam, markdup_metrics]

  # =====================
  # Alignment: control sample (conditional)
  # =====================
  align_control:
    run: steps/align-bwa.cwl
    when: $(inputs.fastq_fwd != null)
    in:
      fastq_fwd: qc_trim_control/trimmed_fwd
      fastq_rev: qc_trim_control/trimmed_rev
      sample_id: control_id
      genome_fasta:
        source:
          - bwa_index
          - build_bwa_index/genome_with_index
        pickValue: first_non_null
    out: [aligned_bam, markdup_metrics]

  # =====================
  # BAM filtering: treatment samples
  # =====================
  filter_treatment:
    run: ../../tools/samtools-filter.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: align_treatment/aligned_bam
      sample_id: sample_ids
    out: [filtered_bam]

  # =====================
  # BAM filtering: control sample (conditional)
  # =====================
  filter_control:
    run: ../../tools/samtools-filter.cwl
    when: $(inputs.bam != null)
    in:
      bam: align_control/aligned_bam
      sample_id: control_id
    out: [filtered_bam]

  # =====================
  # Index filtered BAMs (treatment)
  # =====================
  index_filtered_treatment:
    run: ../../tools/samtools-index.cwl
    scatter: sorted_bam
    in:
      sorted_bam: filter_treatment/filtered_bam
    out: [indexed_bam]

  # =====================
  # Index filtered BAM (control, conditional)
  # =====================
  index_filtered_control:
    run: ../../tools/samtools-index.cwl
    when: $(inputs.sorted_bam != null)
    in:
      sorted_bam: filter_control/filtered_bam
    out: [indexed_bam]

  # =====================
  # MACS2 peak calling (per treatment sample)
  # =====================
  macs2_callpeak:
    run: ../../tools/macs2-callpeak.cwl
    scatter: [treatment_bam, sample_id]
    scatterMethod: dotproduct
    in:
      treatment_bam: index_filtered_treatment/indexed_bam
      control_bam: index_filtered_control/indexed_bam
      sample_id: sample_ids
      genome_size: genome_size
      broad:
        source: peak_type
        valueFrom: $(self == "broad")
    out: [narrow_peaks, broad_peaks, summits, xls, treat_pileup, control_lambda]

  # =====================
  # BigWig generation (per treatment sample)
  # =====================
  bamcoverage:
    run: ../../tools/deeptools-bamcoverage.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: index_filtered_treatment/indexed_bam
      sample_id: sample_ids
    out: [bigwig]

  # =====================
  # MultiQC reporting
  # =====================
  multiqc:
    run: ../../tools/multiqc.cwl
    in:
      report_files:
        source:
          - qc_trim/fastqc_raw_zip
          - qc_trim/fastp_json
          - align_treatment/markdup_metrics
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl chipseq"
    out: [html_report, data_dir]

outputs:
  peaks:
    type: File[]
    outputSource:
      - macs2_callpeak/narrow_peaks
      - macs2_callpeak/broad_peaks
    linkMerge: merge_flattened
    pickValue: all_non_null
    doc: "Peak files (narrowPeak or broadPeak)"

  peak_summits:
    type: File[]?
    outputSource: macs2_callpeak/summits
    pickValue: all_non_null
    doc: "Peak summit BED files (narrow peaks only)"

  peak_xls:
    type: File[]
    outputSource: macs2_callpeak/xls
    doc: "MACS2 peak statistics"

  bigwigs:
    type: File[]
    outputSource: bamcoverage/bigwig
    doc: "Normalized bigWig coverage tracks"

  filtered_bams:
    type: File[]
    outputSource: index_filtered_treatment/indexed_bam
    doc: "Filtered, deduplicated BAM files"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
