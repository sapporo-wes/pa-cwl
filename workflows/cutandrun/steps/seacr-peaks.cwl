#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "SEACR peak calling subworkflow"
doc: "Generate bedGraph coverage and call peaks with SEACR for CUT&RUN data."

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  bams:
    type: File[]
  sample_ids:
    type: string[]
  control_bedgraph:
    type: File?
    doc: "IgG control bedGraph (optional)"
  seacr_mode:
    type: string?
    default: "stringent"
  seacr_threshold:
    type: float?
    default: 0.01
  run_seacr:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  genomecov:
    run: ../../../tools/bedtools-genomecov.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: bams
      sample_id: sample_ids
    out: [bedgraph]

  seacr:
    run: ../../../tools/seacr.cwl
    scatter: [target_bedgraph, sample_id]
    scatterMethod: dotproduct
    in:
      target_bedgraph: genomecov/bedgraph
      control_bedgraph: control_bedgraph
      threshold: seacr_threshold
      mode: seacr_mode
      sample_id: sample_ids
    out: [peaks]

outputs:
  peaks:
    type: File[]
    outputSource: seacr/peaks
  bedgraphs:
    type: File[]
    outputSource: genomecov/bedgraph
