#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "deepTools bamPEFragmentSize - Fragment size distribution QC"
doc: |
  Compute fragment size distribution for paired-end BAM files.
  Generates a histogram plot (PNG) and summary table (TSV).
  Essential QC for CUT&RUN where sub-nucleosomal and mono-nucleosomal
  fragment sizes indicate successful antibody targeting.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/deeptools:3.5.6--pyhdfd78af_0"

baseCommand: [bamPEFragmentSize]

inputs:
  bams:
    type: File[]
    secondaryFiles:
      - .bai
    inputBinding:
      prefix: --bamfiles
    doc: "Input BAM files (sorted, indexed)"

  sample_ids:
    type: string[]
    inputBinding:
      prefix: --samplesLabel
    doc: "Sample labels for the plot"

arguments:
  - prefix: --histogram
    valueFrom: fragment_sizes.png
  - prefix: --table
    valueFrom: fragment_sizes.tsv
  - prefix: -p
    valueFrom: $(runtime.cores)

outputs:
  histogram:
    type: File
    outputBinding:
      glob: fragment_sizes.png
    doc: "Fragment size distribution histogram (PNG)"

  table:
    type: File
    outputBinding:
      glob: fragment_sizes.tsv
    doc: "Fragment size distribution summary table (TSV)"
