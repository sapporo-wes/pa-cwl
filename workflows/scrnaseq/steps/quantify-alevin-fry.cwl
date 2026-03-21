#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Alevin-Fry quantification subworkflow"
doc: |
  Single-cell quantification via simpleaf: builds a splici index from
  genome + GTF, then runs salmon alevin + alevin-fry per sample.

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  genome_fasta:
    type: File
  gtf:
    type: File
  fastq_barcode:
    type: File[]
  fastq_cdna:
    type: File[]
  sample_ids:
    type: string[]
  chemistry:
    type: string
  resolution:
    type: string
  barcode_whitelist:
    type: File?
  expect_cells:
    type: int?
  rlen:
    type: int
  quantifier:
    type: string?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  build_index:
    run: ../../../tools/simpleaf-index.cwl
    in:
      genome_fasta: genome_fasta
      gtf: gtf
      rlen: rlen
    out: [index_dir, t2g_map]

  quant:
    run: ../../../tools/simpleaf-quant.cwl
    scatter: [reads1, reads2, sample_id]
    scatterMethod: dotproduct
    in:
      index_dir: build_index/index_dir
      reads1: fastq_barcode
      reads2: fastq_cdna
      chemistry: chemistry
      t2g_map: build_index/t2g_map
      resolution: resolution
      barcode_whitelist: barcode_whitelist
      expect_cells: expect_cells
      sample_id: sample_ids
    out: [quant_dir]

outputs:
  quant_dirs:
    type: Directory[]
    outputSource: quant/quant_dir
