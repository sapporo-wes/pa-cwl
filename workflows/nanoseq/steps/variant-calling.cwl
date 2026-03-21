#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Medaka variant calling subworkflow"
doc: |
  Variant calling from Nanopore reads: samtools faidx for reference
  indexing, medaka for haploid variant calling, bcftools stats for QC.

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  bams:
    type: File[]
    doc: "Sorted, indexed BAM files (one per sample)"
  reference:
    type: File
    doc: "Reference genome FASTA"
  sample_ids:
    type: string[]
    doc: "Sample identifiers"
  model:
    type: string
    doc: "Medaka model name"
  call_variants:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  faidx:
    run: ../../../tools/samtools-faidx.cwl
    in:
      fasta: reference
    out: [indexed_fasta]

  medaka:
    run: ../../../tools/medaka-variant.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: bams
      reference: faidx/indexed_fasta
      sample_id: sample_ids
      model: model
    out: [vcf]

  bcftools_stats:
    run: ../../../tools/bcftools-stats.cwl
    scatter: [vcf, sample_id]
    scatterMethod: dotproduct
    in:
      vcf: medaka/vcf
      sample_id: sample_ids
    out: [stats]

outputs:
  vcfs:
    type: File[]
    outputSource: medaka/vcf
  stats:
    type: File[]
    outputSource: bcftools_stats/stats
