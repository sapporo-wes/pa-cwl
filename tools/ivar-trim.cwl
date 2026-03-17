#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "iVar trim - Remove primer sequences from amplicon BAMs"
doc: "Trim primer sequences from aligned amplicon sequencing reads using iVar"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/ivar:1.4.3--h43eeafb_0"

baseCommand: [ivar, trim]

inputs:
  bam:
    type: File
    inputBinding:
      prefix: -i
    secondaryFiles:
      - .bai
    doc: "Sorted, indexed BAM file"

  primer_bed:
    type: File
    inputBinding:
      prefix: -b
    doc: "BED file with primer coordinates"

  prefix:
    type: string
    inputBinding:
      prefix: -p
    doc: "Output prefix"

  min_quality:
    type: int?
    default: 20
    inputBinding:
      prefix: -q
    doc: "Minimum quality threshold for sliding window"

  min_length:
    type: int?
    default: 30
    inputBinding:
      prefix: -m
    doc: "Minimum read length after trimming"

  window_size:
    type: int?
    default: 4
    inputBinding:
      prefix: -s
    doc: "Sliding window width"

  include_reads_no_primer:
    type: boolean?
    default: true
    inputBinding:
      prefix: -e
    doc: "Include reads without primers"

outputs:
  trimmed_bam:
    type: File
    outputBinding:
      glob: "*.bam"
    doc: "Primer-trimmed BAM file"
