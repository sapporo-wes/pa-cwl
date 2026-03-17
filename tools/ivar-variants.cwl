#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "iVar variants - Call variants from amplicon sequencing"
doc: |
  Call variants from amplicon sequencing using samtools mpileup piped to
  ivar variants. Outputs TSV with variant calls including allele frequencies.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_ivar_variants.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          samtools mpileup \
            -A -d $(inputs.max_depth) -B \
            -Q $(inputs.min_base_quality) \
            --reference "$(inputs.reference.path)" \
            "$(inputs.bam.path)" \
          | ivar variants \
            -p "$(inputs.prefix)" \
            -q $(inputs.min_quality) \
            -t $(inputs.min_freq_threshold) \
            -m $(inputs.min_depth) \
            -r "$(inputs.reference.path)" \
            $(inputs.gff ? '-g "' + inputs.gff.path + '"' : '')

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/ivar:1.4.3--h43eeafb_0"

baseCommand: [bash, run_ivar_variants.sh]

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

  gff:
    type: File?
    doc: "GFF3 annotation for amino acid annotation"

  prefix:
    type: string
    doc: "Output prefix"

  min_quality:
    type: int?
    default: 20
    doc: "Minimum quality score for ivar"

  min_freq_threshold:
    type: float?
    default: 0.25
    doc: "Minimum frequency threshold for calling variants"

  min_depth:
    type: int?
    default: 10
    doc: "Minimum read depth at position"

  min_base_quality:
    type: int?
    default: 20
    doc: "Minimum base quality for mpileup"

  max_depth:
    type: int?
    default: 600
    doc: "Maximum read depth for mpileup"

outputs:
  variants_tsv:
    type: File
    outputBinding:
      glob: "*.tsv"
    doc: "Variant calls in TSV format"
