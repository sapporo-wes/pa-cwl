#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "taxpasta - Standardize taxonomic profiles"
doc: |
  Merge and standardize taxonomic profiles from different profilers
  into a single unified output table.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/taxpasta:0.7.0--pyhdfd78af_1"

baseCommand: [taxpasta, merge]

inputs:
  reports:
    type: File[]
    inputBinding:
      position: 100
    doc: "Taxonomic profile report files to merge"

  profiler:
    type: string?
    default: "kraken2"
    inputBinding:
      prefix: -p
    doc: "Profiler that generated the reports (kraken2, centrifuge, metaphlan, etc.)"

  output_format:
    type: string?
    default: "tsv"
    doc: "Output format (tsv, csv, biom, xlsx)"

arguments:
  - prefix: -o
    valueFrom: |
      ${
        return "taxpasta_merged." + (inputs.output_format || "tsv");
      }

outputs:
  merged_profile:
    type: File
    outputBinding:
      glob: "taxpasta_merged.*"
    doc: "Standardized merged taxonomic profile"
