#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Bismark genome preparation"
doc: "Build Bismark bisulfite genome index using bowtie2"

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 16384
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: genome_dir/genome.fa
        entry: $(inputs.genome_fasta)
        writable: true

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bismark:0.24.2--hdfd78af_0"

baseCommand: [bismark_genome_preparation]

inputs:
  genome_fasta:
    type: File
    doc: "Reference genome FASTA"

arguments:
  - --bowtie2
  - --parallel
  - valueFrom: "2"
  - genome_dir

outputs:
  bismark_index_dir:
    type: Directory
    outputBinding:
      glob: genome_dir
