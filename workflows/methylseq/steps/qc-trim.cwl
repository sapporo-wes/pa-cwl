#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "QC and trimming subworkflow for methylseq"
doc: "Run FastQC on raw reads and trim with Trim Galore or fastp."

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
      symbols: [trim_galore, fastp, skip]
    default: trim_galore

steps:
  fastqc_raw:
    run: ../../../tools/fastqc.cwl
    in:
      fastq: fastq_fwd
    out: [html_report, zip_report]

  trim_galore:
    run: ../../../tools/trim-galore.cwl
    when: $(inputs.trimmer == "trim_galore")
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      trimmer: trimmer
    out: [trimmed_fwd, trimmed_rev, trimming_report_fwd]

  fastp:
    run: ../../../tools/fastp.cwl
    when: $(inputs.trimmer == "fastp")
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_id
      trimmer: trimmer
    out: [trimmed_fwd, trimmed_rev, json_report]

outputs:
  trimmed_fwd:
    type: File
    outputSource:
      - trim_galore/trimmed_fwd
      - fastp/trimmed_fwd
      - fastq_fwd
    pickValue: first_non_null

  trimmed_rev:
    type: File?
    outputSource:
      - trim_galore/trimmed_rev
      - fastp/trimmed_rev
      - fastq_rev
    pickValue: first_non_null

  fastqc_raw_zip:
    type: File
    outputSource: fastqc_raw/zip_report

  fastp_json:
    type: File?
    outputSource: fastp/json_report
    pickValue: first_non_null
