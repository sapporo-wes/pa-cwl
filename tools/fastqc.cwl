#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "FastQC - Quality control for sequencing reads"
doc: "Generates quality control reports for FASTQ files"

requirements:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0"
  ResourceRequirement:
    coresMin: 1
    ramMin: 1024

baseCommand: [fastqc]

arguments:
  - prefix: --outdir
    valueFrom: "."
  - prefix: --threads
    valueFrom: $(runtime.cores)
  - "--noextract"

inputs:
  fastq:
    type: File
    inputBinding:
      position: 100
    doc: "Input FASTQ file"

outputs:
  html_report:
    type: File
    outputBinding:
      glob: "*.html"
  zip_report:
    type: File
    outputBinding:
      glob: "*.zip"
