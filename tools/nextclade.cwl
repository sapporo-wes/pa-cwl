#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Nextclade - Viral genome clade assignment and mutation calling"
doc: |
  Assign clades, call mutations, and perform quality checks on viral
  consensus sequences using Nextclade v3.

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 4096
  InlineJavascriptRequirement: {}
  NetworkAccess:
    networkAccess: true

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/nextclade:3.8.2--h9ee0642_0"

baseCommand: [nextclade, run]

inputs:
  sequences:
    type: File
    inputBinding:
      position: 100
    doc: "Consensus FASTA sequences"

  dataset_name:
    type: string
    default: "sars-cov-2"
    inputBinding:
      prefix: --dataset-name
    doc: "Nextclade dataset name (e.g. sars-cov-2)"

  output_prefix:
    type: string
    doc: "Prefix for output file names"

arguments:
  - prefix: --output-tsv
    valueFrom: $(inputs.output_prefix)_nextclade.tsv
  - prefix: --output-fasta
    valueFrom: $(inputs.output_prefix)_nextclade.aligned.fasta
  - prefix: --output-json
    valueFrom: $(inputs.output_prefix)_nextclade.json
  - prefix: --jobs
    valueFrom: $(runtime.cores)

outputs:
  tsv:
    type: File
    outputBinding:
      glob: "*_nextclade.tsv"
    doc: "TSV with clade assignments and mutations"

  aligned_fasta:
    type: File
    outputBinding:
      glob: "*_nextclade.aligned.fasta"
    doc: "Reference-aligned FASTA sequences"

  json_results:
    type: File
    outputBinding:
      glob: "*_nextclade.json"
    doc: "Full Nextclade results in JSON format"
