#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "atacseq - ATAC-seq chromatin accessibility pipeline"
doc: |
  ATAC-seq analysis pipeline. Performs QC, trimming, BWA-MEM2 alignment,
  duplicate marking, BAM filtering, MACS2 peak calling (with --nomodel),
  and bigWig coverage track generation.

  Key differences from ChIP-seq:
  - MACS2 uses --nomodel (no fragment size estimation, uses actual fragment coords)
  - --keep-dup all (duplicates already filtered upstream)
  - No control/input sample expected (open chromatin assay)

  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  # === Samples ===
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files (one per sample)"

  fastq_rev:
    type: File[]?
    doc: "Reverse read FASTQ files (one per sample, omit for single-end)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  # === Reference genome ===
  genome_fasta:
    type: File
    doc: "Reference genome FASTA"

  # === Pre-built index (optional) ===
  bwa_index:
    type: File?
    secondaryFiles:
      - pattern: ".0123"
      - pattern: .amb
      - pattern: .ann
      - pattern: .bwt.2bit.64
      - pattern: .pac
    doc: "Pre-built BWA-MEM2 indexed genome FASTA"

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
    doc: "Peak calling mode (narrow is standard for ATAC-seq open chromatin)"

  genome_size:
    type: string
    doc: "Effective genome size for MACS2 (hs, mm, ce, dm, or number like 1.2e7)"

  macs2_qvalue:
    type: float?
    default: 0.05
    doc: "MACS2 q-value cutoff"

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
  # QC + Trimming
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
  # Alignment
  # =====================
  align:
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
  # BAM filtering
  # =====================
  filter:
    run: ../../tools/samtools-filter.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: align/aligned_bam
      sample_id: sample_ids
    out: [filtered_bam]

  # =====================
  # Index filtered BAMs
  # =====================
  index_filtered:
    run: ../../tools/samtools-index.cwl
    scatter: sorted_bam
    in:
      sorted_bam: filter/filtered_bam
    out: [indexed_bam]

  # =====================
  # MACS2 peak calling (ATAC-seq mode: --nomodel --keep-dup all)
  # =====================
  macs2_callpeak:
    run: ../../tools/macs2-callpeak.cwl
    scatter: [treatment_bam, sample_id]
    scatterMethod: dotproduct
    in:
      treatment_bam: index_filtered/indexed_bam
      sample_id: sample_ids
      genome_size: genome_size
      nomodel:
        default: true
      keep_dup:
        default: "all"
      broad:
        source: peak_type
        valueFrom: $(self == "broad")
      qvalue: macs2_qvalue
    out: [narrow_peaks, broad_peaks, summits, xls, treat_pileup, control_lambda]

  # =====================
  # BigWig generation
  # =====================
  bamcoverage:
    run: ../../tools/deeptools-bamcoverage.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: index_filtered/indexed_bam
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
          - align/markdup_metrics
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl atacseq"
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
    outputSource: index_filtered/indexed_bam
    doc: "Filtered, deduplicated BAM files"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
