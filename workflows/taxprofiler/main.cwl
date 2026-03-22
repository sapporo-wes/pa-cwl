#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "taxprofiler - Taxonomic profiling pipeline"
doc: |
  Taxonomic classification and abundance estimation pipeline.
  Uses Kraken2 for classification and Bracken for abundance re-estimation,
  with optional MetaPhlAn marker-gene profiling, Centrifuge classification,
  Krona visualization, and taxpasta profile standardization.

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

  # === MetaPhlAn (optional) ===
  metaphlan_db:
    type: Directory?
    doc: "MetaPhlAn database directory. MetaPhlAn is skipped if not provided."

  metaphlan_index:
    type: string?
    doc: "MetaPhlAn database index name (default: latest in db dir)"

  # === Centrifuge (optional) ===
  centrifuge_db:
    type: File[]?
    doc: "Centrifuge index files (.cf files). Centrifuge is skipped if not provided."

  centrifuge_index_base:
    type: string?
    doc: "Base name of the Centrifuge index"

  # === Krona (optional) ===
  run_krona:
    type: boolean?
    default: false
    doc: "Generate interactive Krona HTML visualization from Kraken2 reports"

  # === taxpasta (optional) ===
  run_taxpasta:
    type: boolean?
    default: false
    doc: "Merge and standardize Kraken2/Bracken profiles with taxpasta"

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
  # MetaPhlAn profiling (conditional — runs when metaphlan_db provided)
  # =====================
  metaphlan:
    run: ../../tools/metaphlan.cwl
    when: $(inputs.database != null)
    scatter: [fastq_fwd, fastq_rev, prefix]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastp/trimmed_fwd
      fastq_rev: fastp/trimmed_rev
      database: metaphlan_db
      database_index: metaphlan_index
      prefix: sample_ids
    out: [profile, sam]

  # =====================
  # Centrifuge classification (conditional — runs when centrifuge_db provided)
  # =====================
  centrifuge:
    run: steps/centrifuge-classify.cwl
    when: $(inputs.centrifuge_db != null)
    in:
      fastq_fwd: fastp/trimmed_fwd
      fastq_rev: fastp/trimmed_rev
      sample_ids: sample_ids
      index_base: centrifuge_index_base
      index_files: centrifuge_db
      centrifuge_db: centrifuge_db
    out: [classifications, reports, kreports]

  # =====================
  # Krona visualization (conditional — runs when run_krona is true)
  # =====================
  krona:
    run: ../../tools/krona.cwl
    when: $(inputs.run_krona == true)
    in:
      reports: kraken2/report
      sample_ids: sample_ids
      run_krona: run_krona
    out: [html]

  # =====================
  # taxpasta standardization (conditional — runs when run_taxpasta is true)
  # =====================
  taxpasta:
    run: ../../tools/taxpasta.cwl
    when: $(inputs.run_taxpasta == true)
    in:
      reports: kraken2/report
      profiler:
        default: "kraken2"
      run_taxpasta: run_taxpasta
    out: [merged_profile]

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
          - metaphlan/profile
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

  metaphlan_profiles:
    type: File[]?
    outputSource: metaphlan/profile
    doc: "MetaPhlAn taxonomic profiles (when metaphlan_db provided)"

  centrifuge_classifications:
    type: File[]?
    outputSource: centrifuge/classifications
    doc: "Centrifuge per-read classifications (when centrifuge_db provided)"

  centrifuge_reports:
    type: File[]?
    outputSource: centrifuge/reports
    doc: "Centrifuge summary reports (when centrifuge_db provided)"

  centrifuge_kreports:
    type: File[]?
    outputSource: centrifuge/kreports
    doc: "Kraken-style reports from Centrifuge (when centrifuge_db provided)"

  krona_html:
    type: File?
    outputSource: krona/html
    doc: "Interactive Krona HTML visualization (when run_krona=true)"

  taxpasta_merged:
    type: File?
    outputSource: taxpasta/merged_profile
    doc: "Standardized merged taxonomic profile (when run_taxpasta=true)"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
