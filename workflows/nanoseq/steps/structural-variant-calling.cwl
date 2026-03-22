#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Sniffles2 structural variant calling subworkflow"
doc: |
  Structural variant calling from long-read alignments using Sniffles2.
  Detects insertions, deletions, inversions, duplications, and translocations.

requirements:
  ScatterFeatureRequirement: {}

inputs:
  bams:
    type: File[]
    doc: "Sorted, indexed BAM files (one per sample)"
  sample_ids:
    type: string[]
    doc: "Sample identifiers"
  reference:
    type: File?
    doc: "Reference genome FASTA (recommended for accurate SV calling)"
  call_structural_variants:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  sniffles:
    run: ../../../tools/sniffles.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: bams
      sample_id: sample_ids
      reference: reference
    out: [vcf]

outputs:
  sv_vcfs:
    type: File[]
    outputSource: sniffles/vcf
