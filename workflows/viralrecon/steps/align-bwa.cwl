#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "BWA-MEM2 alignment subworkflow for viralrecon"
doc: "Align reads with BWA-MEM2, sort, index, and mark duplicates."

requirements:
  InlineJavascriptRequirement: {}

inputs:
  fastq_fwd:
    type: File
  fastq_rev:
    type: File?
  sample_id:
    type: string
  genome_fasta:
    type: File
    secondaryFiles:
      - pattern: ".0123"
      - pattern: .amb
      - pattern: .ann
      - pattern: .bwt.2bit.64
      - pattern: .pac
    doc: "Reference genome with BWA-MEM2 index"

steps:
  bwa_align:
    run: ../../../tools/bwa-mem2-align.cwl
    in:
      genome_fasta: genome_fasta
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_id
    out: [aligned_sam]

  samtools_sort_index:
    run: ../../../tools/samtools-sort-index.cwl
    in:
      bam: bwa_align/aligned_sam
      sample_id: sample_id
    out: [sorted_bam]

  markduplicates:
    run: ../../../tools/picard-markduplicates.cwl
    in:
      sorted_bam: samtools_sort_index/sorted_bam
      sample_id: sample_id
    out: [markdup_bam, metrics]

outputs:
  aligned_bam:
    type: File
    outputSource: markduplicates/markdup_bam

  markdup_metrics:
    type: File
    outputSource: markduplicates/metrics
