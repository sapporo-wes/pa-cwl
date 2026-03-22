#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "NanoFilt quality filtering subworkflow"
doc: |
  Quality filtering of Nanopore reads using NanoFilt.
  Filters by minimum quality score and minimum read length.

requirements:
  ScatterFeatureRequirement: {}

inputs:
  fastqs:
    type: File[]
    doc: "Input FASTQ files (one per sample)"
  sample_ids:
    type: string[]
    doc: "Sample identifiers"
  quality:
    type: int?
    default: 7
    doc: "Minimum average read quality score"
  min_length:
    type: int?
    default: 200
    doc: "Minimum read length"
  run_nanofilt:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  nanofilt:
    run: ../../../tools/nanofilt.cwl
    scatter: [fastq, sample_id]
    scatterMethod: dotproduct
    in:
      fastq: fastqs
      sample_id: sample_ids
      quality: quality
      min_length: min_length
    out: [filtered_fastq]

outputs:
  filtered_fastqs:
    type: File[]
    outputSource: nanofilt/filtered_fastq
