#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "cutandrun - CUT&RUN/CUT&TAG peak calling pipeline"
doc: |
  CUT&RUN and CUT&TAG analysis pipeline. Uses Bowtie2 alignment,
  MACS2 peak calling (--nomodel), and bigWig coverage track generation.
  Supports optional IgG control for background subtraction.
  Optional SEACR peak calling for CUT&RUN-optimized analysis.

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
    doc: "Forward read FASTQ files (one per sample)"

  fastq_rev:
    type: File[]
    doc: "Reverse read FASTQ files (one per sample)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  # === IgG control (optional) ===
  control_fastq_fwd:
    type: File?
    doc: "IgG control forward read FASTQ"

  control_fastq_rev:
    type: File?
    doc: "IgG control reverse read FASTQ"

  control_id:
    type: string?
    default: "IgG_control"
    doc: "Control sample identifier"

  # === Reference genome ===
  genome_fasta:
    type: File
    doc: "Reference genome FASTA"

  # === Bowtie2 index ===
  bowtie2_index_files:
    type: File[]
    doc: "Bowtie2 index files (.1.bt2, .2.bt2, .3.bt2, .4.bt2, .rev.1.bt2, .rev.2.bt2)"

  bowtie2_index_base:
    type: string
    doc: "Bowtie2 index base name"

  # === Peak calling ===
  genome_size:
    type: string
    doc: "Effective genome size for MACS2 (hs, mm, ce, dm, or number)"

  peak_type:
    type:
      type: enum
      symbols: [narrow, broad]
    default: narrow
    doc: "Peak type: narrow (TFs, CUT&RUN) or broad (histone marks)"

  # === SEACR options ===
  run_seacr:
    type: boolean?
    default: false
    doc: "Also run SEACR peak calling (CUT&RUN-optimized peak caller)"

  seacr_mode:
    type: string?
    default: "stringent"
    doc: "SEACR peak calling stringency: stringent or relaxed"

  seacr_threshold:
    type: float?
    default: 0.01
    doc: "SEACR numeric threshold (0-1) when no IgG control is used"

  seacr_control_bedgraph:
    type: File?
    doc: "Pre-generated IgG control bedGraph for SEACR (optional, uses threshold if omitted)"

steps:
  # =====================
  # FastQC on raw reads
  # =====================
  fastqc:
    run: ../../tools/fastqc.cwl
    scatter: fastq
    in:
      fastq: fastq_fwd
    out: [html_report, zip_report]

  # =====================
  # fastp trimming (per sample)
  # =====================
  fastp:
    run: ../../tools/fastp.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_ids
    out: [trimmed_fwd, trimmed_rev, json_report]

  # =====================
  # Bowtie2 alignment (per treatment sample)
  # =====================
  bowtie2_align:
    run: ../../tools/bowtie2-align.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastp/trimmed_fwd
      fastq_rev: fastp/trimmed_rev
      sample_id: sample_ids
      index_files: bowtie2_index_files
      index_base: bowtie2_index_base
    out: [sorted_bam, log]

  # =====================
  # Picard MarkDuplicates (per treatment sample)
  # =====================
  markdup:
    run: ../../tools/picard-markduplicates.cwl
    scatter: [sorted_bam, sample_id]
    scatterMethod: dotproduct
    in:
      sorted_bam: bowtie2_align/sorted_bam
      sample_id: sample_ids
    out: [markdup_bam, metrics]

  # =====================
  # BAM filtering (per treatment sample)
  # =====================
  filter:
    run: ../../tools/samtools-filter.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: markdup/markdup_bam
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
  # MACS2 peak calling (--nomodel for CUT&RUN)
  # =====================
  macs2:
    run: ../../tools/macs2-callpeak.cwl
    scatter: [treatment_bam, sample_id]
    scatterMethod: dotproduct
    in:
      treatment_bam: index_filtered/indexed_bam
      sample_id: sample_ids
      genome_size: genome_size
      broad:
        source: peak_type
        valueFrom: $(self == "broad")
      nomodel:
        default: true
    out: [narrow_peaks, broad_peaks, summits, xls, treat_pileup, control_lambda]

  # =====================
  # SEACR peak calling (conditional)
  # =====================
  seacr_peaks:
    run: steps/seacr-peaks.cwl
    when: $(inputs.run_seacr == true)
    in:
      bams: index_filtered/indexed_bam
      sample_ids: sample_ids
      control_bedgraph: seacr_control_bedgraph
      seacr_mode: seacr_mode
      seacr_threshold: seacr_threshold
      run_seacr: run_seacr
    out: [peaks, bedgraphs]

  # =====================
  # BigWig generation (per treatment sample)
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
          - fastqc/zip_report
          - fastp/json_report
          - bowtie2_align/log
          - markdup/metrics
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl cutandrun"
    out: [html_report, data_dir]

outputs:
  peaks:
    type: File[]
    outputSource:
      - macs2/narrow_peaks
      - macs2/broad_peaks
    linkMerge: merge_flattened
    pickValue: all_non_null
    doc: "Peak files (narrowPeak or broadPeak)"

  bigwigs:
    type: File[]
    outputSource: bamcoverage/bigwig
    doc: "Normalized bigWig coverage tracks"

  filtered_bams:
    type: File[]
    outputSource: index_filtered/indexed_bam
    doc: "Filtered, deduplicated BAM files"

  seacr_peak_files:
    type: File[]?
    outputSource: seacr_peaks/peaks
    doc: "SEACR peak calls in BED format (when run_seacr=true)"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
