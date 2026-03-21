#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "bwa-meth index"
doc: "Build bwa-meth index for bisulfite-aware alignment"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 8192
  InitialWorkDirRequirement:
    listing:
      - entryname: $(inputs.genome_fasta.basename)
        entry: $(inputs.genome_fasta)
        writable: true

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bwameth:0.2.7--pyhdfd78af_1"

baseCommand: [bwameth.py, index]

inputs:
  genome_fasta:
    type: File
    inputBinding:
      position: 1
      valueFrom: $(self.basename)
    doc: "Reference genome FASTA"

outputs:
  indexed_fasta:
    type: File
    secondaryFiles:
      - .bwameth.c2t
      - .bwameth.c2t.amb
      - .bwameth.c2t.ann
      - .bwameth.c2t.bwt
      - .bwameth.c2t.pac
      - .bwameth.c2t.sa
    outputBinding:
      glob: $(inputs.genome_fasta.basename)
