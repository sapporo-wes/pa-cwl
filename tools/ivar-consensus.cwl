#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "iVar consensus - Generate consensus sequence"
doc: |
  Generate a consensus sequence from amplicon sequencing using samtools
  mpileup piped to ivar consensus. Low-coverage positions are masked with N.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_ivar_consensus.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          samtools mpileup \
            -A -d $(inputs.max_depth) -B \
            -Q $(inputs.min_base_quality) \
            --reference "$(inputs.reference.path)" \
            "$(inputs.bam.path)" \
          | ivar consensus \
            -p "$(inputs.prefix)" \
            -q $(inputs.min_quality) \
            -t $(inputs.min_freq_threshold) \
            -m $(inputs.min_depth) \
            -n N

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/ivar:1.4.3--h43eeafb_0"

baseCommand: [bash, run_ivar_consensus.sh]

inputs:
  bam:
    type: File
    secondaryFiles:
      - .bai
    doc: "Sorted, indexed BAM file"

  reference:
    type: File
    secondaryFiles:
      - .fai
    doc: "Reference genome FASTA with .fai index"

  prefix:
    type: string
    doc: "Output prefix"

  min_quality:
    type: int?
    default: 20
    doc: "Minimum quality score"

  min_freq_threshold:
    type: float?
    default: 0.5
    doc: "Minimum frequency threshold for consensus base"

  min_depth:
    type: int?
    default: 10
    doc: "Minimum depth to call consensus (below → N)"

  min_base_quality:
    type: int?
    default: 20
    doc: "Minimum base quality for mpileup"

  max_depth:
    type: int?
    default: 600
    doc: "Maximum read depth for mpileup"

outputs:
  consensus_fasta:
    type: File
    outputBinding:
      glob: "*.fa"
    doc: "Consensus sequence FASTA"

  consensus_qual:
    type: File
    outputBinding:
      glob: "*.qual.txt"
    doc: "Quality scores for consensus bases"
