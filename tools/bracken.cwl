#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Bracken - Bayesian re-estimation of abundance"
doc: |
  Re-estimate taxonomic abundance from Kraken2 reports using
  Bayesian probability redistribution of reads.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bracken:3.1--h9948957_0"

baseCommand: [bracken]

inputs:
  kraken2_report:
    type: File
    inputBinding:
      prefix: -i
    doc: "Kraken2 report file"

  database:
    type: Directory
    inputBinding:
      prefix: -d
    doc: "Kraken2/Bracken database directory"

  prefix:
    type: string
    doc: "Output file prefix"

  read_length:
    type: int?
    default: 150
    inputBinding:
      prefix: -r
    doc: "Read length used for Bracken database"

  level:
    type: string?
    default: S
    inputBinding:
      prefix: -l
    doc: "Taxonomic level (D=domain, P=phylum, C=class, O=order, F=family, G=genus, S=species)"

  threshold:
    type: int?
    default: 10
    inputBinding:
      prefix: -t
    doc: "Minimum reads required for a classification at taxonomic level"

arguments:
  - prefix: -o
    valueFrom: $(inputs.prefix)_bracken.tsv

outputs:
  abundance:
    type: File
    outputBinding:
      glob: "*_bracken.tsv"
    doc: "Bracken abundance estimates"

  adjusted_report:
    type: File
    outputBinding:
      glob: "*_kraken2.report_bracken_species.txt"
    doc: "Bracken-adjusted Kraken2-style report"
