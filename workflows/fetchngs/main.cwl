#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "fetchngs - Fetch sequencing data from public repositories"
doc: |
  Downloads FASTQ files and metadata from SRA/ENA/DDBJ given accession numbers.
  Three download methods:
    - aria2 (recommended): multi-connection parallel download via aria2c with
      automatic mirror selection (DDBJ/ENA/NCBI latency test)
    - ftp: single-connection FTP download with md5 verification
    - sratools: NCBI fasterq-dump
  Produces a samplesheet CSV compatible with downstream pa-cwl analysis workflows.
  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  accessions:
    type: string[]
    doc: "Accession numbers: run (SRR/ERR/DRR), experiment (SRX/ERX/DRX), sample (SRS/ERS/DRS), study (SRP/ERP/DRP), BioProject (PRJNA/PRJEB/PRJDB), BioSample (SAMN/SAME/SAMD), or GEO (GSE/GSM)"

  download_method:
    type:
      type: enum
      symbols:
        - aria2
        - ftp
        - sratools
    default: aria2
    doc: "Download method: aria2 (fast multi-connection, auto mirror selection), ftp (single-connection), or sratools (fasterq-dump)"

steps:
  fetch_metadata:
    run: steps/fetch-ena-metadata.cwl
    in:
      accessions: accessions
    out: [metadata_json, metadata_tsv]
    doc: "Query ENA API for run metadata and FTP download URLs"

  check_mirror:
    run: steps/check-mirror-latency.cwl
    when: $(inputs.download_method == "aria2")
    in:
      download_method: download_method
    out: [preferred_source, mirror_latency]
    doc: "Measure latency to DDBJ/ENA/NCBI and pick fastest mirror"

  download_aria2:
    run: steps/download-fastq-aria2.cwl
    when: $(inputs.download_method == "aria2")
    in:
      metadata_json: fetch_metadata/metadata_json
      preferred_source:
        source: check_mirror/preferred_source
        valueFrom: $(self || "ena")
      download_method: download_method
    out: [fastq_files]
    doc: "Download FASTQ files via aria2c with 8 parallel connections from fastest mirror"

  download_ftp:
    run: steps/download-fastq-ftp.cwl
    when: $(inputs.download_method == "ftp")
    in:
      metadata_json: fetch_metadata/metadata_json
      download_method: download_method
    out: [fastq_files]
    doc: "Download FASTQ files via FTP with md5 verification"

  download_sratools:
    run: steps/download-sratools.cwl
    when: $(inputs.download_method == "sratools")
    in:
      accessions: accessions
      download_method: download_method
    out: [fastq_files]
    doc: "Download FASTQ files via fasterq-dump"

  generate_samplesheet:
    run: steps/generate-samplesheet.cwl
    in:
      metadata_json: fetch_metadata/metadata_json
    out: [samplesheet]
    doc: "Generate samplesheet CSV from metadata"

outputs:
  fastq_files:
    type: File[]
    outputSource:
      - download_aria2/fastq_files
      - download_ftp/fastq_files
      - download_sratools/fastq_files
    pickValue: first_non_null
    doc: "Downloaded FASTQ files"

  samplesheet:
    type: File
    outputSource: generate_samplesheet/samplesheet
    doc: "Samplesheet CSV for downstream workflows"

  run_metadata:
    type: File
    outputSource: fetch_metadata/metadata_tsv
    doc: "TSV file with run metadata from ENA"
