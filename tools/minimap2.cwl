#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "minimap2 - Long-read aligner"
doc: |
  Align long reads (Nanopore, PacBio) or short reads to a reference genome.
  Supports spliced alignment for RNA-seq with -ax splice preset.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/minimap2:2.30--h577a1d6_0"

baseCommand: [minimap2]

stdout: $(inputs.sample_id).sam

arguments:
  - prefix: -t
    valueFrom: $(runtime.cores)
    position: 1
  - prefix: --secondary
    valueFrom: "no"
    position: 2

inputs:
  reference:
    type: File
    inputBinding:
      position: 10
    doc: "Reference genome FASTA"

  reads:
    type: File
    inputBinding:
      position: 11
    doc: "Input reads (FASTQ or FASTA, gzipped supported)"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

  preset:
    type: string?
    default: map-ont
    inputBinding:
      prefix: -ax
      position: 3
    doc: "Preset: map-ont (Nanopore), map-pb (PacBio CLR), map-hifi, splice (RNA)"

outputs:
  sam:
    type: File
    outputBinding:
      glob: "*.sam"
