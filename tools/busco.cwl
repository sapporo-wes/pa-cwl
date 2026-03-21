#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "BUSCO - Genome/bin completeness assessment"
doc: |
  Assess genome assembly or bin completeness using Benchmarking Universal
  Single-Copy Orthologs (BUSCO). Reports completeness, duplication, and
  fragmentation metrics.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/busco:5.7.1--pyhdfd78af_1"

baseCommand: [busco]

inputs:
  fasta:
    type: File
    inputBinding:
      prefix: -i
    doc: "Input genome/bin FASTA file"

  lineage:
    type: string
    inputBinding:
      prefix: -l
    doc: "BUSCO lineage dataset (e.g., bacteria_odb10, archaea_odb10, auto)"

  mode:
    type: string?
    default: genome
    inputBinding:
      prefix: -m
    doc: "Assessment mode: genome, transcriptome, or proteins"

  sample_id:
    type: string
    doc: "Sample/bin identifier"

arguments:
  - prefix: -o
    valueFrom: $(inputs.sample_id)
  - prefix: -c
    valueFrom: $(runtime.cores)
  - --offline

outputs:
  short_summary:
    type: File
    outputBinding:
      glob: $(inputs.sample_id)/short_summary.*.txt
    doc: "BUSCO short summary text file"

  full_table:
    type: File
    outputBinding:
      glob: $(inputs.sample_id)/run_*/full_table.tsv
    doc: "Full BUSCO results table"

  missing_list:
    type: File
    outputBinding:
      glob: $(inputs.sample_id)/run_*/missing_busco_list.tsv
    doc: "List of missing BUSCOs"
