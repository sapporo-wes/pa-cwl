#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "StringTie2 - Transcript assembly"
doc: |
  Assemble RNA-Seq alignments into potential transcripts using StringTie2.
  Takes a sorted BAM file and optional GTF annotation to guide assembly.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/stringtie:3.0.3--h29c0135_0"

baseCommand: [stringtie]

arguments:
  - prefix: -p
    valueFrom: $(runtime.cores)
  - prefix: -o
    valueFrom: $(inputs.sample_id).stringtie.gtf

inputs:
  bam:
    type: File
    secondaryFiles:
      - .bai
    inputBinding:
      position: 100
    doc: "Sorted, indexed BAM file from alignment"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

  annotation:
    type: File?
    inputBinding:
      prefix: -G
    doc: "Reference annotation GTF to guide assembly"

  long_reads:
    type: boolean?
    default: true
    inputBinding:
      prefix: -L
    doc: "Long-read mode for Nanopore/PacBio data (default: true)"

  min_coverage:
    type: float?
    inputBinding:
      prefix: -c
    doc: "Minimum read coverage for a transcript (default: 1)"

  min_transcript_length:
    type: int?
    inputBinding:
      prefix: -m
    doc: "Minimum assembled transcript length (default: 200)"

  gene_abundances:
    type: string?
    inputBinding:
      prefix: -A
    default: null
    doc: "Output gene abundance estimates to this filename (e.g., sample.gene_abund.tab)"

outputs:
  transcript_gtf:
    type: File
    outputBinding:
      glob: "*.stringtie.gtf"
    doc: "Assembled transcripts in GTF format"

  gene_abundance:
    type: File?
    outputBinding:
      glob: "*.gene_abund.tab"
    doc: "Gene abundance estimates (when gene_abundances=true)"
