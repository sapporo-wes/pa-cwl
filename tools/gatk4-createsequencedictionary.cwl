#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 CreateSequenceDictionary"
doc: "Create sequence dictionary (.dict) for reference genome FASTA"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InitialWorkDirRequirement:
    listing:
      - entryname: $(inputs.fasta.basename)
        entry: $(inputs.fasta)
        writable: true

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, CreateSequenceDictionary]

inputs:
  fasta:
    type: File
    doc: "Reference genome FASTA"

arguments:
  - prefix: -R
    valueFrom: $(inputs.fasta.basename)

outputs:
  dict:
    type: File
    outputBinding:
      glob: "*.dict"

  fasta_with_dict:
    type: File
    secondaryFiles:
      - ^.dict
    outputBinding:
      glob: $(inputs.fasta.basename)
