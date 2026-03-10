#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "samtools sort - Sort BAM file"
doc: "Sort BAM file by coordinate"

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 4096

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1"

baseCommand: [samtools, sort]

inputs:
  bam:
    type: File
    inputBinding:
      position: 100
    doc: "Input BAM file"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - prefix: -@
    valueFrom: $(runtime.cores)
  - prefix: -o
    valueFrom: $(inputs.sample_id).sorted.bam
  - prefix: -m
    valueFrom: "1G"

outputs:
  sorted_bam:
    type: File
    outputBinding:
      glob: "*.sorted.bam"
