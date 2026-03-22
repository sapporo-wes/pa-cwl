#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "bcftools annotate - CADD score annotation"
doc: |
  Annotate a VCF with pre-computed CADD scores (raw and PHRED-scaled)
  using bcftools annotate. Requires a CADD TSV.GZ file with tabix index.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: cadd_header.hdr
        entry: |
          ##INFO=<ID=CADD_RAW,Number=A,Type=Float,Description="CADD raw score">
          ##INFO=<ID=CADD_PHRED,Number=A,Type=Float,Description="CADD PHRED-scaled score">

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bcftools:1.19--h8b25389_1"

baseCommand: [bcftools, annotate]

inputs:
  vcf:
    type: File
    inputBinding:
      position: 100
    doc: "Input VCF file to annotate"

  cadd_db:
    type: File
    secondaryFiles:
      - .tbi
    inputBinding:
      prefix: -a
    doc: "CADD scores TSV.GZ file with tabix index"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - prefix: -h
    valueFrom: cadd_header.hdr
  - prefix: -c
    valueFrom: "CHROM,POS,REF,ALT,CADD_RAW,CADD_PHRED"
  - prefix: -Oz
  - prefix: -o
    valueFrom: $(inputs.sample_id).cadd.vcf.gz

outputs:
  annotated_vcf:
    type: File
    outputBinding:
      glob: "*.cadd.vcf.gz"
    doc: "VCF annotated with CADD scores"
