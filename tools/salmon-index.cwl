#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Salmon index - Build Salmon transcriptome index"
doc: "Generate Salmon index from transcriptome FASTA"

requirements:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/salmon:1.10.3--h6dccd9a_1"
  ResourceRequirement:
    coresMin: 8
    ramMin: 16384

baseCommand: [salmon, index]

inputs:
  transcriptome_fasta:
    type: File
    inputBinding:
      prefix: --transcripts
    doc: "Transcriptome FASTA file"

  genome_fasta:
    type: File?
    inputBinding:
      prefix: --decoys
    doc: "Genome FASTA for decoy-aware index (recommended)"

arguments:
  - prefix: --index
    valueFrom: salmon_index
  - prefix: --threads
    valueFrom: $(runtime.cores)

outputs:
  index_dir:
    type: Directory
    outputBinding:
      glob: salmon_index
