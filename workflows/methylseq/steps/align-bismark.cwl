#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Bismark alignment subworkflow"
doc: |
  Bismark bisulfite alignment path: builds Bismark index (if needed),
  aligns reads, deduplicates, sorts, and extracts methylation.

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}

inputs:
  genome_fasta:
    type: File
  bismark_index:
    type: Directory?
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
  build_bismark_index:
    run: ../../../tools/bismark-genome-preparation.cwl
    when: $(inputs.bismark_index == null)
    in:
      genome_fasta: genome_fasta
      bismark_index: bismark_index
    out: [bismark_index_dir]

  bismark_align:
    run: ../../../tools/bismark-align.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      genome_dir:
        source:
          - bismark_index
          - build_bismark_index/bismark_index_dir
        pickValue: first_non_null
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_ids
    out: [aligned_bam, report]

  bismark_dedup:
    run: ../../../tools/bismark-deduplicate.cwl
    scatter: bam
    in:
      bam: bismark_align/aligned_bam
    out: [deduplicated_bam, dedup_report]

  samtools_sort:
    run: ../../../tools/samtools-sort-index.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: bismark_dedup/deduplicated_bam
      sample_id: sample_ids
    out: [sorted_bam]

  methylation_extractor:
    run: ../../../tools/bismark-methylation-extractor.cwl
    scatter: bam
    in:
      bam: bismark_dedup/deduplicated_bam
      genome_dir:
        source:
          - bismark_index
          - build_bismark_index/bismark_index_dir
        pickValue: first_non_null
    out: [bedgraph, coverage, cytosine_report, mbias, splitting_report]

outputs:
  sorted_bams:
    type: File[]
    outputSource: samtools_sort/sorted_bam
  bedgraphs:
    type: File[]
    outputSource: methylation_extractor/bedgraph
  alignment_reports:
    type: File[]
    outputSource: bismark_align/report
  dedup_reports:
    type: File[]
    outputSource: bismark_dedup/dedup_report
  mbias_reports:
    type: File[]
    outputSource: methylation_extractor/mbias
  splitting_reports:
    type: File[]
    outputSource: methylation_extractor/splitting_report
  coverage_files:
    type: File[]
    outputSource: methylation_extractor/coverage
  cytosine_reports:
    type: File[]?
    outputSource: methylation_extractor/cytosine_report
