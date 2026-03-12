#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "fetchngs - Fetch sequencing data from public repositories"
doc: |
  Downloads FASTQ files and metadata from SRA/ENA/DDBJ given accession numbers.
  Supports FTP download with md5 verification, or SRA-tools fasterq-dump.
  Produces a samplesheet CSV compatible with downstream pa-cwl analysis workflows.
  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}

inputs:
  accessions:
    type: string[]
    doc: "Accession numbers: run (SRR/ERR/DRR), experiment (SRX/ERX/DRX), sample (SRS/ERS/DRS), study (SRP/ERP/DRP), BioProject (PRJNA/PRJEB/PRJDB), BioSample (SAMN/SAME/SAMD), or GEO (GSE/GSM)"

  download_method:
    type:
      type: enum
      symbols:
        - ftp
        - sratools
    default: ftp
    doc: "Download method: ftp (wget with md5 verification) or sratools (fasterq-dump)"

steps:
  fetch_metadata:
    run: steps/fetch-ena-metadata.cwl
    in:
      accessions: accessions
    out: [metadata_json, metadata_tsv]
    doc: "Query ENA API for run metadata and FTP download URLs"

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
