#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Prepare GATK reference - faidx + dict"
doc: |
  Prepare reference genome for GATK tools by creating .fai index
  and .dict sequence dictionary.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  ShellCommandRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: genome.fa
        entry: $(inputs.genome_fasta)
        writable: true

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: []

inputs:
  genome_fasta:
    type: File
    doc: "Reference genome FASTA"

arguments:
  - shellQuote: false
    valueFrom: "samtools faidx genome.fa && gatk CreateSequenceDictionary -R genome.fa"

outputs:
  reference:
    type: File
    secondaryFiles:
      - .fai
      - ^.dict
    outputBinding:
      glob: genome.fa
