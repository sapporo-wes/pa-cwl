#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Bismark deduplicate"
doc: "Remove PCR duplicates from Bismark-aligned BAM"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bismark:0.24.2--hdfd78af_0"

baseCommand: [deduplicate_bismark]

inputs:
  bam:
    type: File
    inputBinding:
      position: 100
    doc: "Bismark-aligned BAM file"

  paired:
    type: boolean?
    default: true
    inputBinding:
      prefix: --paired
    doc: "Paired-end data"

arguments:
  - --bam

outputs:
  deduplicated_bam:
    type: File
    outputBinding:
      glob: "*.deduplicated.bam"

  dedup_report:
    type: File
    outputBinding:
      glob: "*.deduplication_report.txt"
