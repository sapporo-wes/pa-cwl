#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "kallisto index - Build kallisto index"
doc: "Build a kallisto index from a FASTA file of target sequences"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 8192

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/kallisto:0.50.1--h6de1650_2"

baseCommand: [kallisto, index]

inputs:
  transcriptome_fasta:
    type: File
    inputBinding:
      position: 1
    doc: "Transcriptome FASTA file"

arguments:
  - prefix: -i
    valueFrom: kallisto_index.idx

outputs:
  index_file:
    type: File
    outputBinding:
      glob: kallisto_index.idx
