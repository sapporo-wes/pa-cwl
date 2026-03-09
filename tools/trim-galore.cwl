#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Trim Galore - Adapter and quality trimming"
doc: "Wrapper around Cutadapt and FastQC for adapter/quality trimming"

requirements:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/trim-galore:0.6.10--hdfd78af_0"
  ResourceRequirement:
    coresMin: 4
    ramMin: 4096

baseCommand: [trim_galore]

arguments:
  - "--gzip"
  - prefix: --cores
    valueFrom: $(runtime.cores)
  - prefix: -o
    valueFrom: "."

inputs:
  fastq_fwd:
    type: File
    inputBinding:
      position: 100
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File?
    inputBinding:
      position: 101
    doc: "Reverse read FASTQ (omit for single-end)"

  paired:
    type: boolean?
    default: true
    inputBinding:
      prefix: --paired
    doc: "Enable paired-end mode"

outputs:
  trimmed_fwd:
    type: File
    outputBinding:
      glob: "*_val_1.fq.gz"

  trimmed_rev:
    type: File?
    outputBinding:
      glob: "*_val_2.fq.gz"

  trimming_report_fwd:
    type: File
    outputBinding:
      glob: "*_trimming_report.txt"

  trimming_report_rev:
    type: File?
    outputBinding:
      glob: "*_val_2_trimming_report.txt"
