#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Download FASTQ via SRA-tools"
doc: "Download FASTQ files using fasterq-dump and compress with pigz"

requirements:
  InlineJavascriptRequirement: {}

inputs:
  accession:
    type: string
    doc: "SRA run accession"

steps:
  fasterq_dump:
    run: ../../../tools/fasterq-dump.cwl
    in:
      accession: accession
    out: [fastq_files]

  compress:
    run: ../../../tools/pigz.cwl
    scatter: input_file
    in:
      input_file: fasterq_dump/fastq_files
    out: [compressed_file]

outputs:
  fastq_files:
    type: File[]
    outputSource: compress/compressed_file
    doc: "Compressed FASTQ files"
