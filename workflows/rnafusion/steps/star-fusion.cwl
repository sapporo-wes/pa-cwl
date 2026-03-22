#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "STAR-Fusion subworkflow"
doc: |
  Subworkflow for STAR-Fusion gene fusion detection. Scatters
  over samples using chimeric junction files from STAR alignment.

requirements:
  ScatterFeatureRequirement: {}

inputs:
  chimeric_junctions:
    type: File[]
    doc: "STAR Chimeric.out.junction files (one per sample)"
  ctat_lib:
    type: Directory
    doc: "CTAT genome library directory"
  sample_ids:
    type: string[]
    doc: "Sample identifiers"
  run_star_fusion:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  star_fusion:
    run: ../../../tools/star-fusion.cwl
    scatter: [chimeric_junction, sample_id]
    scatterMethod: dotproduct
    in:
      chimeric_junction: chimeric_junctions
      ctat_lib: ctat_lib
      sample_id: sample_ids
    out: [fusion_predictions, fusion_predictions_abridged]

outputs:
  fusion_predictions:
    type: File[]
    outputSource: star_fusion/fusion_predictions
  fusion_predictions_abridged:
    type: File[]
    outputSource: star_fusion/fusion_predictions_abridged
