#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Kraken2 host filtering subworkflow"
doc: |
  Filters host reads using Kraken2, keeping unclassified (viral) reads.
  Scatters over per-sample FASTQ files.

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  trimmed_fwd:
    type: File[]
  trimmed_rev:
    type:
      type: array
      items: ["null", "File"]
  sample_ids:
    type: string[]
  kraken2_host_db:
    type: Directory?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  kraken2_filter:
    run: ../../../tools/kraken2-filter.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: trimmed_fwd
      fastq_rev: trimmed_rev
      kraken2_host_db: kraken2_host_db
      sample_id: sample_ids
    out: [filtered_fwd, filtered_rev, kraken2_report]

outputs:
  filtered_fwd:
    type: File[]
    outputSource: kraken2_filter/filtered_fwd
  filtered_rev:
    type:
      type: array
      items: ["null", "File"]
    outputSource: kraken2_filter/filtered_rev
  kraken2_reports:
    type: File[]
    outputSource: kraken2_filter/kraken2_report
