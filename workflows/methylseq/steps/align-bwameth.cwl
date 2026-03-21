#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "bwa-meth alignment subworkflow"
doc: |
  Bisulfite-aware alignment via bwa-meth: builds index, aligns reads,
  sorts, marks duplicates (Picard), then extracts methylation with
  MethylDackel.

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  genome_fasta:
    type: File
  fastq_fwd:
    type: File[]
  fastq_rev:
    type: File[]?
  sample_ids:
    type: string[]
  aligner:
    type: string?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  faidx:
    run: ../../../tools/samtools-faidx.cwl
    in:
      fasta: genome_fasta
    out: [indexed_fasta]

  bwameth_index:
    run: ../../../tools/bwameth-index.cwl
    in:
      genome_fasta: genome_fasta
    out: [indexed_fasta]

  bwameth_align:
    run: ../../../tools/bwameth-align.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      genome_fasta: bwameth_index/indexed_fasta
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_ids
    out: [sam]

  samtools_sort:
    run: ../../../tools/samtools-sort-index.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: bwameth_align/sam
      sample_id: sample_ids
    out: [sorted_bam]

  markduplicates:
    run: ../../../tools/picard-markduplicates.cwl
    scatter: [sorted_bam, sample_id]
    scatterMethod: dotproduct
    in:
      sorted_bam: samtools_sort/sorted_bam
      sample_id: sample_ids
    out: [markdup_bam, metrics]

  methyldackel:
    run: ../../../tools/methyldackel-extract.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: markduplicates/markdup_bam
      reference: faidx/indexed_fasta
      sample_id: sample_ids
    out: [bedgraph]

outputs:
  sorted_bams:
    type: File[]
    outputSource: markduplicates/markdup_bam
  bedgraphs:
    type: File[]
    outputSource: methyldackel/bedgraph
  markdup_metrics:
    type: File[]
    outputSource: markduplicates/metrics
