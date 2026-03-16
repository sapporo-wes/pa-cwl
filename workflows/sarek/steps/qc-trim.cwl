#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "QC and trimming subworkflow for sarek"
doc: "Run FastQC on raw reads and trim with fastp or Trim Galore."

requirements:
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  fastq_fwd:
    type: File
  fastq_rev:
    type: File?
  sample_id:
    type: string
  trimmer:
    type:
      type: enum
      symbols: [fastp, trim_galore, skip]
    default: fastp

steps:
  fastqc_raw:
    run: ../../../tools/fastqc.cwl
    in:
      fastq: fastq_fwd
    out: [html_report, zip_report]

  fastp:
    run: ../../../tools/fastp.cwl
    when: $(inputs.trimmer == "fastp")
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_id
      trimmer: trimmer
    out: [trimmed_fwd, trimmed_rev, json_report]

  trim_galore:
    run: ../../../tools/trim-galore.cwl
    when: $(inputs.trimmer == "trim_galore")
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_id
      trimmer: trimmer
    out: [trimmed_fwd, trimmed_rev, trimming_report_fwd]

outputs:
  trimmed_fwd:
    type: File
    outputSource:
      - fastp/trimmed_fwd
      - trim_galore/trimmed_fwd
      - fastq_fwd
    pickValue: first_non_null

  trimmed_rev:
    type: File?
    outputSource:
      - fastp/trimmed_rev
      - trim_galore/trimmed_rev
      - fastq_rev
    pickValue: first_non_null

  fastqc_raw_zip:
    type: File
    outputSource: fastqc_raw/zip_report

  fastp_json:
    type: File?
    outputSource: fastp/json_report
    pickValue: first_non_null
