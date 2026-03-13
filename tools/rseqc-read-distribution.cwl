#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "RSeQC read_distribution - Read distribution over genome features"
doc: "Calculate read distribution over exons, introns, intergenic regions"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/rseqc:5.0.4--pyhdfd78af_1"

baseCommand: [read_distribution.py]

inputs:
  bam:
    type: File
    secondaryFiles:
      - ^.bai
    inputBinding:
      prefix: -i
    doc: "Indexed BAM file"

  bed:
    type: File
    inputBinding:
      prefix: -r
    doc: "Gene model in BED12 format"

  sample_id:
    type: string
    doc: "Sample identifier"

stdout: $(inputs.sample_id).read_distribution.txt

outputs:
  report:
    type: File
    outputBinding:
      glob: "*.read_distribution.txt"
