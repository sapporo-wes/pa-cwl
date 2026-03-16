#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "samtools faidx - Index FASTA"
doc: "Create .fai index for a reference genome FASTA"

requirements:
  InitialWorkDirRequirement:
    listing:
      - entryname: $(inputs.fasta.basename)
        entry: $(inputs.fasta)
        writable: true

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1"

baseCommand: [samtools, faidx]

inputs:
  fasta:
    type: File
    doc: "Reference genome FASTA"

arguments:
  - $(inputs.fasta.basename)

outputs:
  indexed_fasta:
    type: File
    secondaryFiles:
      - .fai
    outputBinding:
      glob: $(inputs.fasta.basename)
