#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "taxprofiler - Taxonomic profiling pipeline"
doc: |
  Taxonomic classification and abundance estimation pipeline.
  Uses Kraken2 for classification and Bracken for abundance re-estimation.

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

  # === Database ===
  kraken2_db:
    type: Directory
    doc: "Kraken2/Bracken database directory"

  # === Bracken parameters ===
  bracken_read_length:
    type: int?
    default: 150
    doc: "Read length for Bracken database (must match DB build)"

  bracken_level:
    type: string?
    default: S
    doc: "Taxonomic level for Bracken (S=species, G=genus, etc.)"

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
  # Quality trimming with fastp (per sample)
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
  # Kraken2 classification (per sample)
  # =====================
  kraken2:
    run: ../../tools/kraken2.cwl
    scatter: [fastq_fwd, fastq_rev, prefix]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastp/trimmed_fwd
      fastq_rev: fastp/trimmed_rev
      database: kraken2_db
      prefix: sample_ids
    out: [report, output]

  # =====================
  # Bracken abundance (per sample)
  # =====================
  bracken:
    run: ../../tools/bracken.cwl
    scatter: [kraken2_report, prefix]
    scatterMethod: dotproduct
    in:
      kraken2_report: kraken2/report
      database: kraken2_db
      prefix: sample_ids
      read_length: bracken_read_length
      level: bracken_level
    out: [abundance, adjusted_report]

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
          - kraken2/report
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl taxprofiler"
    out: [html_report, data_dir]

outputs:
  kraken2_reports:
    type: File[]
    outputSource: kraken2/report
    doc: "Kraken2 classification reports"

  bracken_abundances:
    type: File[]
    outputSource: bracken/abundance
    doc: "Bracken abundance estimates"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
