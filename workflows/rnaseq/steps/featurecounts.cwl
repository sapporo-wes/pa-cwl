#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "featureCounts subworkflow"
doc: |
  Count reads per gene using featureCounts, scattered over samples.

requirements:
  ScatterFeatureRequirement: {}

inputs:
  bams:
    type: File[]
    doc: "Aligned BAM files"
  gtf:
    type: File
  sample_ids:
    type: string[]

steps:
  featurecounts:
    run: ../../../tools/featurecounts.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: bams
      gtf: gtf
      sample_id: sample_ids
    out: [counts, summary]

outputs:
  counts:
    type: File[]
    outputSource: featurecounts/counts
  summaries:
    type: File[]
    outputSource: featurecounts/summary
