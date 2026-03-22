#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "StringTie2 transcript assembly subworkflow"
doc: |
  Transcript assembly from long-read alignments using StringTie2.
  Takes sorted BAM files and optional GTF annotation, outputs
  assembled transcripts per sample.

requirements:
  ScatterFeatureRequirement: {}

inputs:
  bams:
    type: File[]
    doc: "Sorted, indexed BAM files (one per sample)"
  sample_ids:
    type: string[]
    doc: "Sample identifiers"
  annotation:
    type: File?
    doc: "Reference annotation GTF to guide assembly"
  run_stringtie:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  stringtie:
    run: ../../../tools/stringtie.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: bams
      sample_id: sample_ids
      annotation: annotation
    out: [transcript_gtf]

outputs:
  transcript_gtfs:
    type: File[]
    outputSource: stringtie/transcript_gtf
