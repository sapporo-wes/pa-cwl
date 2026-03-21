#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "STARsolo quantification subworkflow"
doc: |
  Builds STAR index (if not pre-built) and runs STARsolo for
  barcode-aware alignment and gene-barcode count matrix generation.

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}

inputs:
  genome_fasta:
    type: File
  gtf:
    type: File
  star_index:
    type: Directory?
  genome_sa_index_nbases:
    type: int?
  fastq_barcode:
    type: File[]
  fastq_cdna:
    type: File[]
  sample_ids:
    type: string[]
  barcode_whitelist:
    type: File
  cb_len:
    type: int
  umi_len:
    type: int
  solo_strand:
    type: string?
  solo_cell_filter:
    type: string?
  quantifier:
    type: string?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  build_star_index:
    run: ../../../tools/star-genome-generate.cwl
    when: $(inputs.star_index == null)
    in:
      genome_fasta: genome_fasta
      gtf: gtf
      genome_sa_index_nbases: genome_sa_index_nbases
      star_index: star_index
    out: [index_dir]

  starsolo:
    run: ../../../tools/starsolo.cwl
    scatter: [fastq_cdna, fastq_barcode, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_cdna: fastq_cdna
      fastq_barcode: fastq_barcode
      barcode_whitelist: barcode_whitelist
      sample_id: sample_ids
      index_dir:
        source:
          - star_index
          - build_star_index/index_dir
        pickValue: first_non_null
      cb_len: cb_len
      umi_len: umi_len
      solo_strand: solo_strand
      solo_cell_filter: solo_cell_filter
    out: [aligned_bam, solo_out_dir, log_final, log, barcodes_stats]

outputs:
  aligned_bams:
    type: File[]
    outputSource: starsolo/aligned_bam
  solo_out_dirs:
    type: Directory[]
    outputSource: starsolo/solo_out_dir
  star_logs:
    type: File[]
    outputSource: starsolo/log_final
