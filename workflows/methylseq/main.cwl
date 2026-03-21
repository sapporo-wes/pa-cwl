#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "methylseq - Bisulfite sequencing methylation pipeline"
doc: |
  Bisulfite sequencing (BS-seq) pipeline with Bismark or bwa-meth aligner.
  Performs QC, trimming, bisulfite-aware alignment, deduplication, and
  per-base methylation extraction.

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

  # === Aligner ===
  aligner:
    type: string
    default: bismark
    doc: "Alignment method: bismark (default) or bwameth (bwa-meth + MethylDackel)"

steps:
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
  # Bismark path (conditional)
  # =====================
  bismark_path:
    run: steps/align-bismark.cwl
    when: $(inputs.aligner == "bismark")
    in:
      genome_fasta: genome_fasta
      bismark_index: bismark_index
      fastq_fwd: qc_trim/trimmed_fwd
      fastq_rev: qc_trim/trimmed_rev
      sample_ids: sample_ids
      aligner: aligner
    out: [sorted_bams, bedgraphs, alignment_reports, dedup_reports,
          mbias_reports, splitting_reports, coverage_files, cytosine_reports]

  # =====================
  # bwa-meth path (conditional)
  # =====================
  bwameth_path:
    run: steps/align-bwameth.cwl
    when: $(inputs.aligner == "bwameth")
    in:
      genome_fasta: genome_fasta
      fastq_fwd: qc_trim/trimmed_fwd
      fastq_rev: qc_trim/trimmed_rev
      sample_ids: sample_ids
      aligner: aligner
    out: [sorted_bams, bedgraphs, markdup_metrics]

  # =====================
  # Select outputs (bismark or bwa-meth)
  # =====================
  select_outputs:
    run:
      class: ExpressionTool
      requirements:
        InlineJavascriptRequirement: {}
      inputs:
        bismark_bams:
          type:
            - "null"
            - type: array
              items: File
        bwameth_bams:
          type:
            - "null"
            - type: array
              items: File
        bismark_bedgraphs:
          type:
            - "null"
            - type: array
              items: File
        bwameth_bedgraphs:
          type:
            - "null"
            - type: array
              items: File
      outputs:
        bams:
          type: File[]
        bedgraphs:
          type: File[]
      expression: |
        ${
          var bams = inputs.bismark_bams;
          var bedgraphs = inputs.bismark_bedgraphs;
          if (bams === null || (Array.isArray(bams) && bams.length > 0 && bams[0] === null)) {
            bams = inputs.bwameth_bams;
            bedgraphs = inputs.bwameth_bedgraphs;
          }
          return {bams: bams, bedgraphs: bedgraphs};
        }
    in:
      bismark_bams: bismark_path/sorted_bams
      bwameth_bams: bwameth_path/sorted_bams
      bismark_bedgraphs: bismark_path/bedgraphs
      bwameth_bedgraphs: bwameth_path/bedgraphs
    out: [bams, bedgraphs]

  # =====================
  # MultiQC reporting
  # =====================
  multiqc:
    run: ../../tools/multiqc.cwl
    in:
      report_files:
        source:
          - qc_trim/fastqc_raw_zip
          - bismark_path/alignment_reports
          - bismark_path/dedup_reports
          - bismark_path/mbias_reports
          - bismark_path/splitting_reports
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl methylseq"
    out: [html_report, data_dir]

outputs:
  sorted_bams:
    type: File[]
    outputSource: select_outputs/bams
    doc: "Sorted, deduplicated BAM files"

  bedgraphs:
    type: File[]
    outputSource: select_outputs/bedgraphs
    doc: "Methylation bedGraph files per sample"

  coverage_files:
    type: File[]?
    outputSource: bismark_path/coverage_files
    doc: "Bismark coverage files per sample (Bismark path only)"

  cytosine_reports:
    type: File[]?
    outputSource: bismark_path/cytosine_reports
    doc: "Genome-wide cytosine reports (Bismark path only)"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
