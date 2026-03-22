#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Centrifuge classification + kreport subworkflow"
doc: |
  Run Centrifuge classification on each sample and convert results
  to Kraken-style report format. Wraps scattered tool invocations
  for conditional use in the parent workflow.

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files"

  fastq_rev:
    type:
      type: array
      items: ["null", "File"]
    doc: "Reverse read FASTQ files (items may be null for single-end)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers"

  index_base:
    type: string
    doc: "Base name of the Centrifuge index"

  index_files:
    type: File[]
    doc: "Centrifuge index files (.cf files)"

  centrifuge_db:
    type: File[]?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  centrifuge:
    run: ../../../tools/centrifuge.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      index_base: index_base
      index_files: index_files
      sample_id: sample_ids
    out: [classification, report]

  centrifuge_kreport:
    run: ../../../tools/centrifuge-kreport.cwl
    scatter: [classification, sample_id]
    scatterMethod: dotproduct
    in:
      classification: centrifuge/classification
      index_base: index_base
      index_files: index_files
      sample_id: sample_ids
    out: [kreport]

outputs:
  classifications:
    type: File[]
    outputSource: centrifuge/classification
    doc: "Centrifuge per-read classification outputs"

  reports:
    type: File[]
    outputSource: centrifuge/report
    doc: "Centrifuge classification summary reports"

  kreports:
    type: File[]
    outputSource: centrifuge_kreport/kreport
    doc: "Kraken-style reports from Centrifuge results"
