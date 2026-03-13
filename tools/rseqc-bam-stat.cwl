#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "RSeQC bam_stat - BAM alignment statistics"
doc: "Generate alignment statistics from a BAM file"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 2048

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/rseqc:5.0.4--pyhdfd78af_1"

baseCommand: [bam_stat.py]

inputs:
  bam:
    type: File
    inputBinding:
      prefix: -i
    doc: "BAM file"

  sample_id:
    type: string
    doc: "Sample identifier"

stdout: $(inputs.sample_id).bam_stat.txt

outputs:
  report:
    type: File
    outputBinding:
      glob: "*.bam_stat.txt"
