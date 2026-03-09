#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "kallisto quantification subworkflow"
doc: "Pseudoalignment-based quantification using kallisto"

requirements:
  InlineJavascriptRequirement: {}

inputs:
  index_file:
    type: File
    doc: "kallisto index file"
  fastq_fwd:
    type: File
  fastq_rev:
    type: File?
  sample_id:
    type: string
  single_end:
    type: boolean?
    default: false

steps:
  kallisto_quant:
    run: ../../../tools/kallisto-quant.cwl
    in:
      index_file: index_file
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_id
      single_end: single_end
    out: [quant_dir, abundance_tsv, abundance_h5]

outputs:
  quant_dir:
    type: Directory
    outputSource: kallisto_quant/quant_dir

  abundance_tsv:
    type: File
    outputSource: kallisto_quant/abundance_tsv
