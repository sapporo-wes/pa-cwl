#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "samtools stats - Alignment statistics"
doc: "Generate alignment statistics from BAM for MultiQC"

requirements:
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1"

baseCommand: [samtools, stats]

stdout: $(inputs.sample_id).samtools_stats.txt

inputs:
  bam:
    type: File
    inputBinding:
      position: 100
    doc: "Input BAM file"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

outputs:
  stats:
    type: File
    outputBinding:
      glob: "*.samtools_stats.txt"
