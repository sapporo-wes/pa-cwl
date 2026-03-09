#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "fetchngs - Fetch sequencing data from public repositories"
doc: |
  Downloads FASTQ files and metadata from SRA/ENA/DDBJ given accession numbers.
  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}

inputs:
  accessions:
    type: string[]
    doc: "SRA/ENA/DDBJ run accession numbers"

  download_method:
    type:
      type: enum
      symbols: [fasterq-dump, wget, aspera]
    default: fasterq-dump
    doc: "Download method to use"

  output_format:
    type:
      type: enum
      symbols: [fastq, bam]
    default: fastq
    doc: "Output format"

steps:
  # TODO: Implement steps
  # - fetch_metadata: query NCBI/ENA for run metadata
  # - download_reads: download FASTQ/BAM files per accession
  # - validate_downloads: verify checksums
  []

outputs:
  fastq_files:
    type: File[]
    doc: "Downloaded FASTQ files"
    outputSource: []  # TODO: wire to download step

  run_metadata:
    type: File
    doc: "TSV file with run metadata"
    outputSource: []  # TODO: wire to metadata step
