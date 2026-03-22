#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Arriba visualization - draw_fusions.R"
doc: |
  Generate publication-quality PDF visualizations of gene fusions
  detected by Arriba. Uses the draw_fusions.R script bundled with Arriba.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/arriba:2.5.1--h87b9561_0"

baseCommand: [draw_fusions.R]

inputs:
  fusions_tsv:
    type: File
    inputBinding:
      prefix: --fusions=
      separate: false
    doc: "Arriba fusions TSV output"

  bam:
    type: File
    secondaryFiles:
      - .bai
    inputBinding:
      prefix: --alignments=
      separate: false
    doc: "STAR-aligned BAM with index (.bai)"

  gtf:
    type: File
    inputBinding:
      prefix: --annotation=
      separate: false
    doc: "Gene annotation GTF file"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

  cytobands:
    type: File?
    inputBinding:
      prefix: --cytobands=
      separate: false
    doc: "Cytoband annotation TSV (optional)"

arguments:
  - prefix: --output=
    separate: false
    valueFrom: $(inputs.sample_id)_fusions.pdf

outputs:
  fusions_pdf:
    type: File
    outputBinding:
      glob: "*_fusions.pdf"
    doc: "PDF visualization of detected gene fusions"
