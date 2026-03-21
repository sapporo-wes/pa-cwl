#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "ampliseq - 16S/ITS amplicon sequencing analysis pipeline"
doc: |
  Amplicon sequencing analysis pipeline using Cutadapt and DADA2.
  Performs QC, primer trimming, ASV inference, and taxonomy assignment.

  Supports paired-end and single-end 16S, ITS, and 18S amplicon data.

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

  # === Primer sequences ===
  primer_fwd:
    type: string
    doc: "Forward primer sequence (e.g., 515F: GTGYCAGCMGCCGCGGTAA)"

  primer_rev:
    type: string?
    doc: "Reverse primer sequence (e.g., 806R: GGACTACNVGGGTWTCTAAT, omit for single-end)"

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
  # Prepare reverse reads for scatter (null -> array of nulls for SE)
  # =====================
  prepare_rev:
    run:
      class: ExpressionTool
      requirements:
        InlineJavascriptRequirement: {}
      inputs:
        fastq_fwd:
          type: File[]
        fastq_rev:
          type: File[]?
      outputs:
        rev_files:
          type:
            type: array
            items: ["null", File]
      expression: |
        ${
          if (inputs.fastq_rev !== null) {
            return {rev_files: inputs.fastq_rev};
          }
          var nulls = [];
          for (var i = 0; i < inputs.fastq_fwd.length; i++) {
            nulls.push(null);
          }
          return {rev_files: nulls};
        }
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
    out: [rev_files]

  # =====================
  # Primer trimming with Cutadapt (per sample)
  # =====================
  cutadapt:
    run: ../../tools/cutadapt.cwl
    scatter: [fastq_fwd, fastq_rev, prefix]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: prepare_rev/rev_files
      adapter_fwd:
        source: primer_fwd
        valueFrom: "^$(self)"
      adapter_rev:
        source: primer_rev
        valueFrom: |
          ${
            if (self) return "^" + self;
            return null;
          }
      prefix: sample_ids
    out: [trimmed_fwd, trimmed_rev, stdout_log]

  # =====================
  # Collect non-null trimmed reverse reads for DADA2
  # =====================
  collect_rev:
    run:
      class: ExpressionTool
      requirements:
        InlineJavascriptRequirement: {}
      inputs:
        rev_files:
          type:
            type: array
            items: ["null", File]
      outputs:
        fastq_rev:
          type: File[]?
      expression: |
        ${
          var files = [];
          for (var i = 0; i < inputs.rev_files.length; i++) {
            if (inputs.rev_files[i] !== null) {
              files.push(inputs.rev_files[i]);
            }
          }
          if (files.length === 0) return {fastq_rev: null};
          return {fastq_rev: files};
        }
    in:
      rev_files: cutadapt/trimmed_rev
    out: [fastq_rev]

  # =====================
  # DADA2 denoising (all samples together)
  # =====================
  dada2_denoise:
    run: ../../tools/dada2-denoise.cwl
    in:
      fastq_fwd: cutadapt/trimmed_fwd
      fastq_rev: collect_rev/fastq_rev
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
