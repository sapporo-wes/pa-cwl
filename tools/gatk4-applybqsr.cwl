#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 ApplyBQSR"
doc: "Apply Base Quality Score Recalibration to BAM"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, ApplyBQSR]

inputs:
  bam:
    type: File
    secondaryFiles:
      - ^.bai
    inputBinding:
      prefix: -I
    doc: "Input BAM file"

  reference:
    type: File
    secondaryFiles:
      - .fai
      - ^.dict
    inputBinding:
      prefix: -R
    doc: "Reference genome FASTA with .fai and .dict"

  recalibration_table:
    type: File
    inputBinding:
      prefix: --bqsr-recal-file
    doc: "BQSR recalibration table from BaseRecalibrator"

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
    valueFrom: $(inputs.sample_id).recal.bam

outputs:
  recalibrated_bam:
    type: File
    secondaryFiles:
      - ^.bai
    outputBinding:
      glob: "*.recal.bam"
