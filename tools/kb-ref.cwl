#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "kb ref - Build kallisto-BUStools reference"
doc: |
  Build a kallisto index and transcript-to-gene map from a reference genome
  and gene annotation using kb-python (kallisto-BUStools wrapper).

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 16384
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_kb_ref.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          GENOME="$1"
          GTF="$2"

          kb ref \
            -i index.idx \
            -g t2g.txt \
            -f1 cdna.fa \
            "$GENOME" \
            "$GTF"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/kb-python:0.28.2--pyhdfd78af_2"

baseCommand: [bash, run_kb_ref.sh]

inputs:
  genome_fasta:
    type: File
    doc: "Reference genome FASTA"

  gtf:
    type: File
    doc: "Gene annotation GTF"

arguments:
  - position: 1
    valueFrom: $(inputs.genome_fasta.path)
  - position: 2
    valueFrom: $(inputs.gtf.path)

outputs:
  index:
    type: File
    outputBinding:
      glob: index.idx
    doc: "Kallisto index file"

  t2g:
    type: File
    outputBinding:
      glob: t2g.txt
    doc: "Transcript-to-gene mapping file"

  cdna_fasta:
    type: File
    outputBinding:
      glob: cdna.fa
    doc: "cDNA FASTA sequences"
