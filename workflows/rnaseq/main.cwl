#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "rnaseq - RNA-seq quantification pipeline"
doc: |
  RNA-seq analysis pipeline supporting multiple aligners (STAR, HISAT2)
  and quantifiers (Salmon, RSEM, kallisto). Includes QC, trimming,
  alignment, quantification, and reporting.
  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}

inputs:
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files (one per sample)"

  fastq_rev:
    type: File[]?
    doc: "Reverse read FASTQ files (one per sample, omit for single-end)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  genome_fasta:
    type: File
    doc: "Reference genome FASTA"
    secondaryFiles:
      - .fai

  gtf:
    type: File
    doc: "Gene annotation GTF"

  aligner:
    type:
      type: enum
      symbols: [star, hisat2]
    default: star
    doc: "Alignment tool"

  quantifier:
    type:
      type: enum
      symbols: [salmon, rsem, kallisto]
    default: salmon
    doc: "Quantification tool"

  trimmer:
    type:
      type: enum
      symbols: [fastp, trim_galore, skip]
    default: fastp
    doc: "Read trimming tool"

  strandedness:
    type:
      type: enum
      symbols: [unstranded, forward, reverse]
    default: unstranded
    doc: "Library strandedness"

steps:
  # TODO: Implement steps
  # - qc_raw: FastQC on raw reads
  # - trim: fastp / Trim Galore
  # - qc_trimmed: FastQC on trimmed reads
  # - align: STAR / HISAT2
  # - sort_index: samtools sort + index
  # - quantify: Salmon / RSEM / kallisto
  # - multiqc: aggregate QC
  []

outputs:
  gene_counts:
    type: File
    doc: "Gene-level count matrix"
    outputSource: []  # TODO

  transcript_counts:
    type: File
    doc: "Transcript-level count matrix"
    outputSource: []  # TODO

  multiqc_report:
    type: File
    doc: "MultiQC HTML report"
    outputSource: []  # TODO

  aligned_bams:
    type: File[]
    doc: "Sorted BAM files per sample"
    outputSource: []  # TODO
