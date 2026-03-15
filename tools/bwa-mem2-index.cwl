#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "BWA-MEM2 index - Build genome index"
doc: "Build BWA-MEM2 index from reference genome FASTA"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 16384
  InitialWorkDirRequirement:
    listing:
      - entryname: genome.fa
        entry: $(inputs.genome_fasta)
        writable: true

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bwa-mem2:2.2.1--he70b90d_8"

baseCommand: [bwa-mem2, index]

inputs:
  genome_fasta:
    type: File
    doc: "Reference genome FASTA"

arguments:
  - "genome.fa"

outputs:
  index_files:
    type: File[]
    outputBinding:
      glob: "genome.fa.*"

  genome_with_index:
    type: File
    secondaryFiles:
      - pattern: ".0123"
      - pattern: .amb
      - pattern: .ann
      - pattern: .bwt.2bit.64
      - pattern: .pac
    outputBinding:
      glob: "genome.fa"
