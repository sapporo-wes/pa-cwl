#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "NanoPlot - Nanopore sequencing QC"
doc: |
  Quality control and visualization for Nanopore sequencing data.
  Generates read length distributions, quality scores, and throughput plots.

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/nanoplot:1.46.2--pyhdfd78af_1"

baseCommand: [NanoPlot]

arguments:
  - prefix: -t
    valueFrom: $(runtime.cores)
  - prefix: -o
    valueFrom: "."
  - prefix: -p
    valueFrom: $(inputs.sample_id)_
  - prefix: --plots
    valueFrom: dot

inputs:
  fastq:
    type: File
    inputBinding:
      prefix: --fastq
    doc: "Input FASTQ file (gzipped supported)"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

outputs:
  stats_txt:
    type: File
    outputBinding:
      glob: "*NanoStats.txt"
    doc: "Summary statistics text file"

  html_report:
    type: File
    outputBinding:
      glob: "*NanoPlot-report.html"
    doc: "NanoPlot HTML report"

  read_length_plot:
    type: File?
    outputBinding:
      glob: "*Non_weightedHistogramReadlength.html"
    doc: "Read length histogram (HTML)"

  quality_plot:
    type: File?
    outputBinding:
      glob: "*LengthvsQualityScatterPlot_dot.html"
    doc: "Length vs quality scatter plot (HTML)"
