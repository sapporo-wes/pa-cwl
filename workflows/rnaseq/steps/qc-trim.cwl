#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "QC and trimming subworkflow"
doc: |
  Run FastQC on raw reads, trim with fastp or Trim Galore,
  then run FastQC on trimmed reads.

requirements:
  InlineJavascriptRequirement: {}
  SubworkflowFeatureRequirement: {}

inputs:
  fastq_fwd:
    type: File
    doc: "Forward read FASTQ"
  fastq_rev:
    type: File?
    doc: "Reverse read FASTQ"
  sample_id:
    type: string
    doc: "Sample identifier"
  trimmer:
    type:
      type: enum
      symbols: [fastp, trim_galore, skip]
    doc: "Trimming tool to use"

steps:
  fastqc_raw:
    run: ../../../tools/fastqc.cwl
    in:
      fastq: fastq_fwd
    out: [html_report, zip_report]

  fastqc_raw_rev:
    run: ../../../tools/fastqc.cwl
    when: $(inputs.fastq != null)
    in:
      fastq: fastq_rev
    out: [html_report, zip_report]

  fastp_trim:
    run: ../../../tools/fastp.cwl
    when: $(inputs.trimmer == "fastp")
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_id
      trimmer: trimmer
    out: [trimmed_fwd, trimmed_rev, json_report, html_report]

  trim_galore_trim:
    run: ../../../tools/trim-galore.cwl
    when: $(inputs.trimmer == "trim_galore")
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      trimmer: trimmer
    out: [trimmed_fwd, trimmed_rev, trimming_report_fwd, trimming_report_rev]

  fastqc_trimmed:
    run: ../../../tools/fastqc.cwl
    when: $(inputs.trimmer != "skip")
    in:
      fastq:
        source:
          - fastp_trim/trimmed_fwd
          - trim_galore_trim/trimmed_fwd
        pickValue: first_non_null
      trimmer: trimmer
    out: [html_report, zip_report]

outputs:
  trimmed_fwd:
    type: File
    outputSource:
      - fastp_trim/trimmed_fwd
      - trim_galore_trim/trimmed_fwd
      - fastq_fwd
    pickValue: first_non_null

  trimmed_rev:
    type: File?
    outputSource:
      - fastp_trim/trimmed_rev
      - trim_galore_trim/trimmed_rev
      - fastq_rev
    pickValue: first_non_null

  fastqc_raw_html:
    type: File
    outputSource: fastqc_raw/html_report

  fastqc_raw_zip:
    type: File
    outputSource: fastqc_raw/zip_report

  fastp_json:
    type: File?
    outputSource: fastp_trim/json_report

  trim_report:
    type: File?
    outputSource: trim_galore_trim/trimming_report_fwd
