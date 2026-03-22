#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Arriba visualization subworkflow"
doc: |
  Subworkflow for generating Arriba fusion visualization PDFs.
  Scatters over samples using fusion TSV and indexed BAM files.

requirements:
  ScatterFeatureRequirement: {}

inputs:
  fusions_tsvs:
    type: File[]
    doc: "Arriba fusion TSV files (one per sample)"
  bams:
    type: File[]
    doc: "Indexed BAM files (one per sample, with .bai)"
  gtf:
    type: File
    doc: "Gene annotation GTF file"
  sample_ids:
    type: string[]
    doc: "Sample identifiers"
  cytobands:
    type: File?
    doc: "Cytoband annotation TSV (optional)"
  run_arriba_viz:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  arriba_viz:
    run: ../../../tools/arriba-visualization.cwl
    scatter: [fusions_tsv, bam, sample_id]
    scatterMethod: dotproduct
    in:
      fusions_tsv: fusions_tsvs
      bam: bams
      gtf: gtf
      sample_id: sample_ids
      cytobands: cytobands
    out: [fusions_pdf]

outputs:
  fusions_pdfs:
    type: File[]
    outputSource: arriba_viz/fusions_pdf
