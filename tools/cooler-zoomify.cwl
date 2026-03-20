#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "cooler zoomify - Generate multi-resolution contact matrix"
doc: |
  Generate a multi-resolution .mcool file from a single-resolution .cool
  file. Applies balanced normalization at each resolution level.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/cooler:0.10.3--pyhdfd78af_0"

baseCommand: [cooler, zoomify]

inputs:
  cool:
    type: File
    inputBinding:
      position: 100
    doc: "Input .cool file (single resolution)"

  sample_id:
    type: string
    doc: "Sample identifier"

  balance:
    type: boolean?
    default: true
    inputBinding:
      prefix: --balance
    doc: "Apply balancing at each zoom level"

  resolutions:
    type: string?
    default: "5000,10000,25000,50000,100000,250000,500000,1000000"
    inputBinding:
      prefix: --resolutions
    doc: "Comma-separated list of resolutions"

arguments:
  - prefix: -o
    valueFrom: $(inputs.sample_id).mcool

outputs:
  mcool:
    type: File
    outputBinding:
      glob: "*.mcool"
    doc: "Multi-resolution contact matrix"
