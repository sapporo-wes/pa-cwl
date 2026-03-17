#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "ampliseq - 16S/ITS amplicon sequencing analysis pipeline"
doc: |
  Amplicon sequencing analysis pipeline using Cutadapt and DADA2.
  Performs QC, primer trimming, ASV inference, and taxonomy assignment.

  Supports paired-end 16S, ITS, and 18S amplicon data.

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
    type: File[]
    doc: "Reverse read FASTQ files (one per sample)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  # === Primer sequences ===
  primer_fwd:
    type: string
    doc: "Forward primer sequence (e.g., 515F: GTGYCAGCMGCCGCGGTAA)"

  primer_rev:
    type: string
    doc: "Reverse primer sequence (e.g., 806R: GGACTACNVGGGTWTCTAAT)"

  # === Reference database ===
  taxonomy_db:
    type: File
    doc: "Taxonomy reference FASTA (e.g., SILVA, UNITE)"

  # === DADA2 parameters ===
  trunc_len_fwd:
    type: int?
    default: 0
    doc: "Truncation length for forward reads (0 = no truncation)"

  trunc_len_rev:
    type: int?
    default: 0
    doc: "Truncation length for reverse reads (0 = no truncation)"

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
  # Primer trimming with Cutadapt (per sample)
  # =====================
  cutadapt:
    run: ../../tools/cutadapt.cwl
    scatter: [fastq_fwd, fastq_rev, prefix]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      adapter_fwd:
        source: primer_fwd
        valueFrom: "^$(self)"
      adapter_rev:
        source: primer_rev
        valueFrom: "^$(self)"
      prefix: sample_ids
    out: [trimmed_fwd, trimmed_rev, stdout_log]

  # =====================
  # DADA2 denoising (all samples together)
  # =====================
  dada2_denoise:
    run: ../../tools/dada2-denoise.cwl
    in:
      fastq_fwd: cutadapt/trimmed_fwd
      fastq_rev: cutadapt/trimmed_rev
      sample_ids: sample_ids
      trunc_len_fwd: trunc_len_fwd
      trunc_len_rev: trunc_len_rev
    out: [asv_counts, asv_seqs, seqtab_rds, tracking]

  # =====================
  # Taxonomy assignment
  # =====================
  assign_taxonomy:
    run: ../../tools/dada2-assign-taxonomy.cwl
    in:
      seqtab_rds: dada2_denoise/seqtab_rds
      reference_db: taxonomy_db
    out: [taxonomy_csv, taxonomy_rds]

  # =====================
  # MultiQC reporting
  # =====================
  multiqc:
    run: ../../tools/multiqc.cwl
    in:
      report_files:
        source:
          - fastqc/zip_report
          - cutadapt/stdout_log
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl ampliseq"
    out: [html_report, data_dir]

outputs:
  asv_counts:
    type: File
    outputSource: dada2_denoise/asv_counts
    doc: "ASV count table (samples x ASVs)"

  asv_seqs:
    type: File
    outputSource: dada2_denoise/asv_seqs
    doc: "Representative ASV sequences FASTA"

  taxonomy:
    type: File
    outputSource: assign_taxonomy/taxonomy_csv
    doc: "Taxonomy assignments CSV"

  tracking:
    type: File
    outputSource: dada2_denoise/tracking
    doc: "Read tracking through pipeline"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
