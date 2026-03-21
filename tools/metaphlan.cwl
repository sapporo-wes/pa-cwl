#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "MetaPhlAn - Marker-gene taxonomic profiling"
doc: |
  Taxonomic profiling of metagenomic samples using clade-specific
  marker genes. Produces relative abundance profiles per sample.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/metaphlan:4.2.4--pyhdfd78af_0"

baseCommand: [metaphlan]

inputs:
  fastq_fwd:
    type: File
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File?
    doc: "Reverse read FASTQ (omit for single-end)"

  database:
    type: Directory
    inputBinding:
      prefix: --bowtie2db
    doc: "MetaPhlAn database directory"

  database_index:
    type: string?
    inputBinding:
      prefix: -x
    doc: "Database index name (default: latest in db dir)"

  prefix:
    type: string
    doc: "Output file prefix"

  tax_level:
    type: string?
    default: "a"
    inputBinding:
      prefix: --tax_lev
    doc: "Taxonomic level: a (all), k, p, c, o, f, g, s, t"

  min_alignment_len:
    type: int?
    inputBinding:
      prefix: --min_alignment_len
    doc: "Minimum alignment length for a read to be considered"

arguments:
  - prefix: --input_type
    valueFrom: fastq
  - prefix: --nproc
    valueFrom: $(runtime.cores)
  - prefix: -o
    valueFrom: $(inputs.prefix)_metaphlan.txt
  - prefix: -s
    valueFrom: $(inputs.prefix)_metaphlan.sam.bz2
  - prefix: --bowtie2out
    valueFrom: $(inputs.prefix)_metaphlan.bowtie2.bz2
  - valueFrom: |
      ${
        if (inputs.fastq_rev) {
          return inputs.fastq_fwd.path + "," + inputs.fastq_rev.path;
        }
        return inputs.fastq_fwd.path;
      }
    position: 1

outputs:
  profile:
    type: File
    outputBinding:
      glob: "*_metaphlan.txt"
    doc: "MetaPhlAn taxonomic profile (relative abundances)"

  sam:
    type: File
    outputBinding:
      glob: "*_metaphlan.sam.bz2"
    doc: "Compressed SAM alignment to marker genes"
