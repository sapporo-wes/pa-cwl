#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "bcftools variant calling subworkflow"
doc: "Variant calling with bcftools mpileup+call, plus VCF stats."

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  bams:
    type: File[]
  reference:
    type: File
    secondaryFiles:
      - .fai
  sample_ids:
    type: string[]
  run_bcftools:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  bcftools_call:
    run: ../../../tools/bcftools-call.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: bams
      reference: reference
      sample_id: sample_ids
      ploidy:
        default: "1"
    out: [vcf]

  bcftools_stats:
    run: ../../../tools/bcftools-stats.cwl
    scatter: [vcf, sample_id]
    scatterMethod: dotproduct
    in:
      vcf: bcftools_call/vcf
      sample_id: sample_ids
    out: [stats]

outputs:
  vcfs:
    type: File[]
    outputSource: bcftools_call/vcf
  stats:
    type: File[]
    outputSource: bcftools_stats/stats
