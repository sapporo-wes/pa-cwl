#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Pangolin - SARS-CoV-2 lineage assignment"
doc: |
  Assign SARS-CoV-2 Pango lineages to consensus genome sequences.

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/pangolin:4.3.1--pyhdfd78af_3"

baseCommand: [pangolin]

inputs:
  consensus_fasta:
    type: File
    inputBinding:
      position: 1
    doc: "Consensus genome FASTA (one or more sequences)"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - prefix: --outfile
    valueFrom: $(inputs.sample_id)_pangolin.csv
  - prefix: --threads
    valueFrom: $(runtime.cores)

outputs:
  lineage_report:
    type: File
    outputBinding:
      glob: "*_pangolin.csv"
    doc: "Pangolin lineage assignment CSV"
