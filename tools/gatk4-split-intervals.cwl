#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 SplitIntervals"
doc: "Split genomic intervals into N sub-intervals for scatter-gather parallelism"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing: []

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, SplitIntervals]

inputs:
  reference:
    type: File
    secondaryFiles:
      - .fai
      - ^.dict
    inputBinding:
      prefix: -R
    doc: "Reference genome FASTA with .fai and .dict"

  intervals:
    type: File?
    inputBinding:
      prefix: -L
    doc: "Input intervals BED file (if not provided, splits the whole genome)"

  scatter_count:
    type: int
    default: 6
    inputBinding:
      prefix: --scatter-count
    doc: "Number of interval sub-lists to generate"

  subdivision_mode:
    type: string?
    default: "BALANCING_WITHOUT_INTERVAL_SUBDIVISION"
    inputBinding:
      prefix: --subdivision-mode
    doc: "How to subdivide intervals (BALANCING_WITHOUT_INTERVAL_SUBDIVISION or INTERVAL_SUBDIVISION)"

arguments:
  - prefix: -O
    valueFrom: interval_files

outputs:
  interval_files:
    type: File[]
    outputBinding:
      glob: "interval_files/*.interval_list"
