#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "FusionCatcher subworkflow"
doc: |
  Subworkflow for FusionCatcher gene fusion detection. Scatters
  over samples using trimmed FASTQ files.

requirements:
  ScatterFeatureRequirement: {}

inputs:
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files (one per sample)"
  fastq_rev:
    type: File[]
    doc: "Reverse read FASTQ files (one per sample)"
  fusioncatcher_db:
    type: Directory
    doc: "FusionCatcher data directory"
  sample_ids:
    type: string[]
    doc: "Sample identifiers"
  run_fusioncatcher:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  fusioncatcher:
    run: ../../../tools/fusioncatcher.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      data_dir: fusioncatcher_db
      sample_id: sample_ids
    out: [final_fusions, summary]

outputs:
  final_fusions:
    type: File[]
    outputSource: fusioncatcher/final_fusions
  summaries:
    type: File[]
    outputSource: fusioncatcher/summary
