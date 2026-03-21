#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "BQSR subworkflow"
doc: |
  Base Quality Score Recalibration: runs GATK4 BaseRecalibrator to build
  a recalibration table, then ApplyBQSR to produce a recalibrated BAM.

requirements:
  InlineJavascriptRequirement: {}

inputs:
  bam:
    type: File
    secondaryFiles:
      - ^.bai
  reference:
    type: File
    secondaryFiles:
      - .fai
      - ^.dict
  known_sites:
    type: File[]
    secondaryFiles:
      - .tbi
  intervals:
    type: File?
  sample_id:
    type: string

steps:
  baserecalibrator:
    run: ../../../tools/gatk4-baserecalibrator.cwl
    in:
      bam: bam
      reference: reference
      known_sites: known_sites
      intervals: intervals
      sample_id: sample_id
    out: [recalibration_table]

  applybqsr:
    run: ../../../tools/gatk4-applybqsr.cwl
    in:
      bam: bam
      reference: reference
      recalibration_table: baserecalibrator/recalibration_table
      intervals: intervals
      sample_id: sample_id
    out: [recalibrated_bam]

outputs:
  recalibrated_bam:
    type: File
    secondaryFiles:
      - ^.bai
    outputSource: applybqsr/recalibrated_bam

  recalibration_table:
    type: File
    outputSource: baserecalibrator/recalibration_table
