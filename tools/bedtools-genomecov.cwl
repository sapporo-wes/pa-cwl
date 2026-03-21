#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "bedtools genomecov - Generate bedGraph coverage"
doc: "Generate bedGraph coverage from a BAM file using bedtools genomecov."

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bedtools:2.31.1--hf5e1c6e_2"

baseCommand: [bedtools, genomecov]

inputs:
  bam:
    type: File
    inputBinding:
      prefix: -ibam
    doc: "Input BAM file (sorted)"

  sample_id:
    type: string
    doc: "Sample identifier"

  bg:
    type: boolean?
    default: true
    inputBinding:
      prefix: -bg
    doc: "Report depth in bedGraph format"

stdout: $(inputs.sample_id).bedgraph

outputs:
  bedgraph:
    type: File
    outputBinding:
      glob: "*.bedgraph"
    doc: "Coverage in bedGraph format"
