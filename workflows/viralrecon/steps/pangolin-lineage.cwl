#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Pangolin lineage assignment subworkflow"
doc: "Assigns SARS-CoV-2 Pango lineages to consensus sequences."

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  consensus_fastas:
    type: File[]
  sample_ids:
    type: string[]
  run_pangolin:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  pangolin:
    run: ../../../tools/pangolin.cwl
    scatter: [consensus_fasta, sample_id]
    scatterMethod: dotproduct
    in:
      consensus_fasta: consensus_fastas
      sample_id: sample_ids
    out: [lineage_report]

outputs:
  lineage_reports:
    type: File[]
    outputSource: pangolin/lineage_report
