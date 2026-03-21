#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 BaseRecalibrator"
doc: "Generate Base Quality Score Recalibration (BQSR) table"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, BaseRecalibrator]

inputs:
  bam:
    type: File
    secondaryFiles:
      - ^.bai
    inputBinding:
      prefix: -I
    doc: "Input BAM file (sorted, indexed, with duplicates marked)"

  reference:
    type: File
    secondaryFiles:
      - .fai
      - ^.dict
    inputBinding:
      prefix: -R
    doc: "Reference genome FASTA with .fai and .dict"

  known_sites:
    type: File[]
    secondaryFiles:
      - .tbi
    doc: "Known variant sites VCFs (dbSNP, known indels, etc.)"
    inputBinding:
      prefix: --known-sites
      itemSeparator: " --known-sites "

  intervals:
    type: File?
    inputBinding:
      prefix: -L
    doc: "Intervals BED file (for WES/targeted)"

  sample_id:
    type: string
    doc: "Sample identifier"

arguments:
  - prefix: -O
    valueFrom: $(inputs.sample_id).recal_data.table

outputs:
  recalibration_table:
    type: File
    outputBinding:
      glob: "*.recal_data.table"
