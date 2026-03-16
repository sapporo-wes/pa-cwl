#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Bismark - Bisulfite-aware alignment"
doc: "Align bisulfite-treated reads to a reference genome using Bismark (bowtie2 backend)"

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 16384
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bismark:0.24.2--hdfd78af_0"

baseCommand: [bismark]

inputs:
  genome_dir:
    type: Directory
    inputBinding:
      prefix: --genome_folder
    doc: "Bismark genome directory (containing FASTA + index)"

  fastq_fwd:
    type: File
    inputBinding:
      prefix: "-1"
      position: 100
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File?
    inputBinding:
      prefix: "-2"
      position: 101
    doc: "Reverse read FASTQ (omit for single-end)"

  sample_id:
    type: string
    doc: "Sample identifier"

  pbat:
    type: boolean?
    default: false
    inputBinding:
      prefix: --pbat
    doc: "Post-Bisulfite Adaptor Tagging (PBAT) mode"

  non_directional:
    type: boolean?
    default: false
    inputBinding:
      prefix: --non_directional
    doc: "Non-directional bisulfite library"

arguments:
  - --bowtie2
  - prefix: --parallel
    valueFrom: "2"
  - prefix: --temp_dir
    valueFrom: "."
  - --unmapped

outputs:
  aligned_bam:
    type: File
    outputBinding:
      glob: "*.bam"

  report:
    type: File
    outputBinding:
      glob: "*_report.txt"

  unmapped_fwd:
    type: File?
    outputBinding:
      glob: "*unmapped_reads_1*"

  unmapped_rev:
    type: File?
    outputBinding:
      glob: "*unmapped_reads_2*"
