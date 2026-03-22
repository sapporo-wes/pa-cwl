#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Nextclade annotation subworkflow"
doc: "Assigns viral clades and calls mutations on consensus sequences."

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  consensus_fastas:
    type: File[]
  sample_ids:
    type: string[]
  dataset_name:
    type: string
    default: "sars-cov-2"
  run_nextclade:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  nextclade:
    run: ../../../tools/nextclade.cwl
    scatter: [sequences, output_prefix]
    scatterMethod: dotproduct
    in:
      sequences: consensus_fastas
      dataset_name: dataset_name
      output_prefix: sample_ids
    out: [tsv, aligned_fasta, json_results]

outputs:
  clade_tsvs:
    type: File[]
    outputSource: nextclade/tsv
  aligned_fastas:
    type: File[]
    outputSource: nextclade/aligned_fasta
  json_results:
    type: File[]
    outputSource: nextclade/json_results
