#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Prokka - Prokaryotic genome annotation"
doc: |
  Rapid prokaryotic genome annotation. Annotates protein-coding genes,
  rRNAs, tRNAs, and other features. Supports metagenome mode.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/prokka:1.14.6--pl5321hdfd78af_7"

baseCommand: [prokka]

inputs:
  fasta:
    type: File
    inputBinding:
      position: 100
    doc: "Input genome/bin FASTA file"

  prefix:
    type: string
    doc: "Output file prefix"

  metagenome:
    type: boolean?
    default: true
    inputBinding:
      prefix: --metagenome
    doc: "Enable metagenome mode"

arguments:
  - prefix: --outdir
    valueFrom: $(inputs.prefix)_prokka
  - prefix: --prefix
    valueFrom: $(inputs.prefix)
  - prefix: --cpus
    valueFrom: $(runtime.cores)
  - --force

outputs:
  gff:
    type: File
    outputBinding:
      glob: $(inputs.prefix)_prokka/$(inputs.prefix).gff
    doc: "Gene annotations in GFF3 format"

  faa:
    type: File
    outputBinding:
      glob: $(inputs.prefix)_prokka/$(inputs.prefix).faa
    doc: "Predicted protein sequences"

  fna:
    type: File
    outputBinding:
      glob: $(inputs.prefix)_prokka/$(inputs.prefix).fna
    doc: "Annotated nucleotide sequences"

  gbk:
    type: File
    outputBinding:
      glob: $(inputs.prefix)_prokka/$(inputs.prefix).gbk
    doc: "GenBank format annotation"

  log:
    type: File
    outputBinding:
      glob: $(inputs.prefix)_prokka/$(inputs.prefix).log
    doc: "Prokka log file"
