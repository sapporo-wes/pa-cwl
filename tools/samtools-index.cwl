#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "samtools index - Index BAM file"
doc: "Create BAI index for a sorted BAM file"

requirements:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1"
  ResourceRequirement:
    coresMin: 2
    ramMin: 1024
  InitialWorkDirRequirement:
    listing:
      - $(inputs.sorted_bam)

baseCommand: [samtools, index]

inputs:
  sorted_bam:
    type: File
    inputBinding:
      position: 1
      valueFrom: $(self.basename)
    doc: "Coordinate-sorted BAM file"

arguments:
  - prefix: -@
    valueFrom: $(runtime.cores)

outputs:
  indexed_bam:
    type: File
    secondaryFiles:
      - .bai
    outputBinding:
      glob: $(inputs.sorted_bam.basename)
