#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "QUAST - Assembly quality assessment"
doc: |
  Quality assessment tool for genome assemblies. Computes basic
  assembly statistics (N50, total length, # contigs, etc.).

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 2048
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/quast:5.3.0--py313pl5321h5ca1c30_2"

baseCommand: [quast]

inputs:
  contigs:
    type: File
    inputBinding:
      position: 1
    doc: "Assembly contigs FASTA"

  min_contig:
    type: int?
    default: 500
    inputBinding:
      prefix: --min-contig
    doc: "Minimum contig length for analysis"

arguments:
  - prefix: -o
    valueFrom: quast_output
  - prefix: -t
    valueFrom: $(runtime.cores)

outputs:
  report_tsv:
    type: File
    outputBinding:
      glob: "quast_output/report.tsv"
    doc: "Assembly statistics in TSV format"

  report_html:
    type: File
    outputBinding:
      glob: "quast_output/report.html"
    doc: "QUAST HTML report"

  output_dir:
    type: Directory
    outputBinding:
      glob: "quast_output"
    doc: "Full QUAST output directory"
