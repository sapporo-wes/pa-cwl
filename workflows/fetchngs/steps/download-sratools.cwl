#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Download FASTQ via SRA-tools"
doc: "Download FASTQ files for multiple accessions using fasterq-dump and compress"

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 4096
  NetworkAccess:
    networkAccess: true
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: download_all.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          while IFS= read -r acc; do
            [ -z "$acc" ] && continue
            echo "Downloading: $acc"
            fasterq-dump --threads "$1" --split-files --skip-technical "$acc"
            for f in ${acc}*.fastq; do
              gzip "$f"
            done
            echo "Done: $acc"
          done < "$2"
      - entryname: accessions.txt
        entry: $(inputs.accessions.join("\n"))

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/sra-tools:3.0.10--h9f5acd7_0"

baseCommand: [bash, download_all.sh]

inputs:
  accessions:
    type: string[]
    doc: "SRA run accessions"

arguments:
  - position: 1
    valueFrom: $(runtime.cores)
  - position: 2
    valueFrom: accessions.txt

outputs:
  fastq_files:
    type: File[]
    outputBinding:
      glob: "*.fastq.gz"
    doc: "Downloaded and compressed FASTQ files"
