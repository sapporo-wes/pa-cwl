#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "samtools index - Index BAM file"
doc: "Create BAI index for a sorted BAM file"

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 1024
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1"

baseCommand: []

inputs:
  sorted_bam:
    type: File
    doc: "Coordinate-sorted BAM file"

arguments:
  - shellQuote: false
    valueFrom: |
      cp $(inputs.sorted_bam.path) $(inputs.sorted_bam.basename) &&
      samtools index -@ $(runtime.cores) $(inputs.sorted_bam.basename)

outputs:
  indexed_bam:
    type: File
    secondaryFiles:
      - .bai
    outputBinding:
      glob: $(inputs.sorted_bam.basename)
