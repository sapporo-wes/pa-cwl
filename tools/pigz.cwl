#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "pigz - Parallel gzip compression"
doc: "Compress files with gzip in parallel"

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 1024
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/pigz:2.8--h2797004_0"

baseCommand: []

inputs:
  input_file:
    type: File
    doc: "File to compress"

arguments:
  - shellQuote: false
    valueFrom: |
      cp $(inputs.input_file.path) $(inputs.input_file.basename) &&
      pigz -p $(runtime.cores) $(inputs.input_file.basename)

outputs:
  compressed_file:
    type: File
    outputBinding:
      glob: "*.gz"
