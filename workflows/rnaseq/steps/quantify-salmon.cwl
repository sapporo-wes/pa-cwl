#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Salmon quantification subworkflow"
doc: |
  Quantify transcript abundance using Salmon. Supports both
  alignment-based mode (from STAR transcriptome BAM) and
  mapping-based mode (direct from FASTQ).

requirements:
  InlineJavascriptRequirement: {}

inputs:
  index_dir:
    type: Directory?
    doc: "Salmon index directory"
  transcriptome_fasta:
    type: File?
    doc: "Transcriptome FASTA (for alignment-based mode targets)"
  transcriptome_bam:
    type: File?
    doc: "Transcriptome-aligned BAM from STAR (alignment-based mode)"
  fastq_fwd:
    type: File?
    doc: "Forward read FASTQ (mapping-based mode)"
  fastq_rev:
    type: File?
    doc: "Reverse read FASTQ (mapping-based mode)"
  sample_id:
    type: string
  mode:
    type:
      type: enum
      symbols: [mapping, alignment]
    default: alignment

steps:
  salmon_quant:
    run: ../../../tools/salmon-quant.cwl
    in:
      index_dir: index_dir
      transcriptome_fasta: transcriptome_fasta
      aligned_bam: transcriptome_bam
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_id
      mode: mode
    out: [quant_dir, quant_sf]

outputs:
  quant_dir:
    type: Directory
    outputSource: salmon_quant/quant_dir

  quant_sf:
    type: File
    outputSource: salmon_quant/quant_sf
