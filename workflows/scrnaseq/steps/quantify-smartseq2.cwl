#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Smart-seq2 quantification subworkflow"
doc: |
  Plate-based Smart-seq2 quantification: STAR alignment followed by
  featureCounts per sample. Each well/sample is processed individually
  (no barcode demultiplexing needed).

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
  fastq_fwd:
    type: File[]
    doc: "Forward reads, one per sample/well"
  fastq_rev:
    type: File[]?
    doc: "Reverse reads, one per sample/well (optional for SE)"
  sample_ids:
    type: string[]
  strandedness:
    type: int?
    default: 0
    doc: "Strand-specificity for featureCounts (0=unstranded, 1=forward, 2=reverse)"
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

  star_align:
    run: ../../../tools/star-align.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      index_dir:
        source:
          - star_index
          - build_star_index/index_dir
        pickValue: first_non_null
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_ids
      quantmode:
        default: "GeneCounts"
    out: [aligned_bam, log_final]

  featurecounts:
    run: ../../../tools/featurecounts.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: star_align/aligned_bam
      gtf: gtf
      sample_id: sample_ids
      paired:
        default: true
      strandedness: strandedness
    out: [counts, summary]

outputs:
  aligned_bams:
    type: File[]
    outputSource: star_align/aligned_bam
  star_logs:
    type: File[]
    outputSource: star_align/log_final
  count_matrices:
    type: File[]
    outputSource: featurecounts/counts
  count_summaries:
    type: File[]
    outputSource: featurecounts/summary
