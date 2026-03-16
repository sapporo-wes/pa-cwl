#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "bcftools stats - VCF statistics"
doc: "Generate statistics from VCF/BCF files for MultiQC"

requirements:
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bcftools:1.19--h8b25389_1"

baseCommand: [bcftools, stats]

stdout: $(inputs.sample_id).bcftools_stats.txt

inputs:
  vcf:
    type: File
    inputBinding:
      position: 100
    doc: "Input VCF/BCF file"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

outputs:
  stats:
    type: File
    outputBinding:
      glob: "*.bcftools_stats.txt"
