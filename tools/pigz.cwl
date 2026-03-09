#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "pigz - Parallel gzip compression"
doc: "Compress files with gzip in parallel"

requirements:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/pigz:2.8--h2797004_0"
  ResourceRequirement:
    coresMin: 4
    ramMin: 1024
  InitialWorkDirRequirement:
    listing:
      - $(inputs.input_file)

baseCommand: [pigz]

inputs:
  input_file:
    type: File
    inputBinding:
      position: 1
      valueFrom: $(self.basename)
    doc: "File to compress"

arguments:
  - prefix: -p
    valueFrom: $(runtime.cores)

outputs:
  compressed_file:
    type: File
    outputBinding:
      glob: "*.gz"
