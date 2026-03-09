#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "kallisto quant - Pseudoalignment-based quantification"
doc: "Quantify transcript abundance using kallisto pseudoalignment"

requirements:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/kallisto:0.50.1--h6de1650_2"
  ResourceRequirement:
    coresMin: 4
    ramMin: 4096

baseCommand: [kallisto, quant]

inputs:
  index_file:
    type: File
    inputBinding:
      prefix: -i
    doc: "kallisto index file"

  fastq_fwd:
    type: File
    inputBinding:
      position: 100
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File?
    inputBinding:
      position: 101
    doc: "Reverse read FASTQ"

  sample_id:
    type: string
    doc: "Sample identifier"

  single_end:
    type: boolean?
    default: false
    inputBinding:
      prefix: --single
    doc: "Single-end mode"

  fragment_length:
    type: int?
    default: 200
    inputBinding:
      prefix: -l
    doc: "Estimated fragment length (required for single-end)"

  fragment_length_sd:
    type: int?
    default: 20
    inputBinding:
      prefix: -s
    doc: "Estimated SD of fragment length (required for single-end)"

arguments:
  - prefix: -o
    valueFrom: $(inputs.sample_id)_kallisto
  - prefix: -t
    valueFrom: $(runtime.cores)

outputs:
  quant_dir:
    type: Directory
    outputBinding:
      glob: "*_kallisto"

  abundance_tsv:
    type: File
    outputBinding:
      glob: "*_kallisto/abundance.tsv"

  abundance_h5:
    type: File
    outputBinding:
      glob: "*_kallisto/abundance.h5"
