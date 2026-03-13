#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "HISAT2 alignment subworkflow"
doc: |
  Align reads with HISAT2, sort, index, and mark duplicates.

requirements:
  InlineJavascriptRequirement: {}

inputs:
  fastq_fwd:
    type: File
  fastq_rev:
    type: File?
  sample_id:
    type: string
  index_files:
    type: File[]?
    doc: "Pre-built HISAT2 index files"
  index_basename:
    type: string?
    default: "hisat2_index"
  strandedness:
    type:
      type: enum
      symbols: [unstranded, forward, reverse]
    default: unstranded

steps:
  hisat2_align:
    run: ../../../tools/hisat2-align.cwl
    in:
      index_files: index_files
      index_basename: index_basename
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_id
      strandedness: strandedness
    out: [aligned_sam, summary_log]

  samtools_sort:
    run: ../../../tools/samtools-sort.cwl
    in:
      bam: hisat2_align/aligned_sam
      sample_id: sample_id
    out: [sorted_bam]

  samtools_index:
    run: ../../../tools/samtools-index.cwl
    in:
      sorted_bam: samtools_sort/sorted_bam
    out: [indexed_bam]

  markduplicates:
    run: ../../../tools/picard-markduplicates.cwl
    in:
      sorted_bam: samtools_index/indexed_bam
      sample_id: sample_id
    out: [markdup_bam, metrics]

outputs:
  aligned_bam:
    type: File
    outputSource: markduplicates/markdup_bam

  hisat2_log:
    type: File
    outputSource: hisat2_align/summary_log

  markdup_metrics:
    type: File
    outputSource: markduplicates/metrics
