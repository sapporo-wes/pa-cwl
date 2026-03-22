#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Kallisto+BUStools quantification subworkflow"
doc: |
  Single-cell quantification via kallisto-BUStools (kb-python):
  builds a kallisto index from genome + GTF, then runs kb count
  for barcode-aware pseudoalignment and gene-barcode count matrix generation.

requirements:
  InlineJavascriptRequirement: {}

inputs:
  genome_fasta:
    type: File
  gtf:
    type: File
  fastq_barcode:
    type: File[]
  fastq_cdna:
    type: File[]
  chemistry:
    type: string
  quantifier:
    type: string?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  build_index:
    run: ../../../tools/kb-ref.cwl
    in:
      genome_fasta: genome_fasta
      gtf: gtf
    out: [index, t2g]

  count:
    run: ../../../tools/kb-count.cwl
    in:
      index: build_index/index
      t2g: build_index/t2g
      chemistry: chemistry
      fastq_barcode: fastq_barcode
      fastq_cdna: fastq_cdna
    out: [count_dir, bus_file]

outputs:
  count_dir:
    type: Directory
    outputSource: count/count_dir
  bus_file:
    type: File
    outputSource: count/bus_file
