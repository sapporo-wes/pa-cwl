#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "methylseq - Bisulfite sequencing methylation pipeline"
doc: |
  Bisulfite sequencing (BS-seq) pipeline using Bismark. Performs QC,
  trimming, bisulfite-aware alignment, deduplication, and per-base
  methylation extraction (CpG bedGraph + coverage + cytosine report).

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
    doc: "Reverse read FASTQ files (one per sample)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  # === Reference genome ===
  genome_fasta:
    type: File
    doc: "Reference genome FASTA"

  # === Pre-built index (optional) ===
  bismark_index:
    type: Directory?
    doc: "Pre-built Bismark genome index directory"

  # === Tool options ===
  trimmer:
    type:
      type: enum
      symbols: [trim_galore, fastp, skip]
    default: trim_galore
    doc: "Read trimming tool (trim_galore is standard for bisulfite)"

steps:
  # =====================
  # Bismark genome preparation (conditional)
  # =====================
  build_bismark_index:
    run: ../../tools/bismark-genome-preparation.cwl
    when: $(inputs.bismark_index == null)
    in:
      genome_fasta: genome_fasta
      bismark_index: bismark_index
    out: [bismark_index_dir]

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
  # Bismark alignment
  # =====================
  bismark_align:
    run: ../../tools/bismark-align.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      genome_dir:
        source:
          - bismark_index
          - build_bismark_index/bismark_index_dir
        pickValue: first_non_null
      fastq_fwd: qc_trim/trimmed_fwd
      fastq_rev: qc_trim/trimmed_rev
      sample_id: sample_ids
    out: [aligned_bam, report]

  # =====================
  # Bismark deduplication
  # =====================
  bismark_dedup:
    run: ../../tools/bismark-deduplicate.cwl
    scatter: bam
    in:
      bam: bismark_align/aligned_bam
    out: [deduplicated_bam, dedup_report]

  # =====================
  # Sort + Index
  # =====================
  samtools_sort:
    run: ../../tools/samtools-sort-index.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: bismark_dedup/deduplicated_bam
      sample_id: sample_ids
    out: [sorted_bam]

  # =====================
  # Methylation extraction
  # =====================
  methylation_extractor:
    run: ../../tools/bismark-methylation-extractor.cwl
    scatter: bam
    in:
      bam: bismark_dedup/deduplicated_bam
      genome_dir:
        source:
          - bismark_index
          - build_bismark_index/bismark_index_dir
        pickValue: first_non_null
    out: [bedgraph, coverage, cytosine_report, mbias, splitting_report]

  # =====================
  # MultiQC reporting
  # =====================
  multiqc:
    run: ../../tools/multiqc.cwl
    in:
      report_files:
        source:
          - qc_trim/fastqc_raw_zip
          - bismark_align/report
          - bismark_dedup/dedup_report
          - methylation_extractor/mbias
          - methylation_extractor/splitting_report
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl methylseq"
    out: [html_report, data_dir]

outputs:
  sorted_bams:
    type: File[]
    outputSource: samtools_sort/sorted_bam
    doc: "Sorted, deduplicated BAM files"

  bedgraphs:
    type: File[]
    outputSource: methylation_extractor/bedgraph
    doc: "Methylation bedGraph files per sample"

  coverage_files:
    type: File[]
    outputSource: methylation_extractor/coverage
    doc: "Bismark coverage files per sample"

  cytosine_reports:
    type: File[]?
    outputSource: methylation_extractor/cytosine_report
    pickValue: all_non_null
    doc: "Genome-wide cytosine reports"

  mbias_reports:
    type: File[]
    outputSource: methylation_extractor/mbias
    doc: "M-bias reports per sample"

  bismark_alignment_reports:
    type: File[]
    outputSource: bismark_align/report
    doc: "Bismark alignment reports"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
