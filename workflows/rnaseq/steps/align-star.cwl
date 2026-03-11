#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "STAR alignment subworkflow"
doc: |
  Align reads with STAR, sort and index BAM, mark duplicates.
  Optionally produces transcriptome BAM for Salmon/RSEM quantification.

requirements:
  InlineJavascriptRequirement: {}

inputs:
  fastq_fwd:
    type: File
  fastq_rev:
    type: File?
  sample_id:
    type: string
  index_dir:
    type: Directory?
    doc: "Pre-built STAR index directory"

steps:
  star_align:
    run: ../../../tools/star-align.cwl
    in:
      index_dir: index_dir
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_id
    out: [aligned_bam, transcriptome_bam, log_final, log, splice_junctions]

  samtools_index:
    run: ../../../tools/samtools-index.cwl
    in:
      sorted_bam: star_align/aligned_bam
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

  transcriptome_bam:
    type: File?
    outputSource: star_align/transcriptome_bam

  star_log:
    type: File
    outputSource: star_align/log_final

  markdup_metrics:
    type: File
    outputSource: markduplicates/metrics
