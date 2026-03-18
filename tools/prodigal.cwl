#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Prodigal - Prokaryotic gene prediction"
doc: "Predict protein-coding genes in prokaryotic genomes and metagenomes."

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 2048
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/prodigal:2.6.3--h577a1d6_11"

baseCommand: [prodigal]

inputs:
  input_fasta:
    type: File
    inputBinding:
      prefix: -i
    doc: "Input genome/metagenome FASTA"

  mode:
    type: string?
    default: meta
    inputBinding:
      prefix: -p
    doc: "Mode: single (isolate) or meta (metagenome)"

  prefix:
    type: string?
    default: prodigal
    doc: "Output file prefix"

arguments:
  - prefix: -o
    valueFrom: $(inputs.prefix)_genes.gff
  - prefix: -a
    valueFrom: $(inputs.prefix)_proteins.faa
  - prefix: -d
    valueFrom: $(inputs.prefix)_genes.fna
  - valueFrom: "-f"
  - valueFrom: "gff"

outputs:
  gene_annotations:
    type: File
    outputBinding:
      glob: "*_genes.gff"
    doc: "Gene annotations in GFF format"

  protein_sequences:
    type: File
    outputBinding:
      glob: "*_proteins.faa"
    doc: "Predicted protein sequences"

  gene_sequences:
    type: File
    outputBinding:
      glob: "*_genes.fna"
    doc: "Predicted gene nucleotide sequences"
