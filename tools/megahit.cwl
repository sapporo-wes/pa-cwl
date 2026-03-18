#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "MEGAHIT - Metagenome assembler"
doc: |
  Ultra-fast single-node metagenome assembler using succinct de Bruijn graphs.
  Assembles short reads into contigs for downstream binning.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 16384
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_megahit.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          FWD_FILES="$(inputs.fastq_fwd.map(function(f){ return f.path; }).join(','))"
          REV_FILES="$(inputs.fastq_rev.map(function(f){ return f.path; }).join(','))"
          THREADS=$(runtime.cores)
          MIN_CONTIG=$(inputs.min_contig_len)

          # Use CWL ramMin (in MB) converted to bytes for MEGAHIT memory limit
          MEM_BYTES=\$(( $(runtime.ram) * 1048576 ))

          megahit \
            -1 "$FWD_FILES" \
            -2 "$REV_FILES" \
            -t $THREADS \
            -m $MEM_BYTES \
            --min-contig-len $MIN_CONTIG \
            -o megahit_out

          # Rename output for clarity
          cp megahit_out/final.contigs.fa assembly_contigs.fasta

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/megahit:1.2.9--haf24da9_8"

baseCommand: [bash, run_megahit.sh]

inputs:
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files"

  fastq_rev:
    type: File[]
    doc: "Reverse read FASTQ files"

  min_contig_len:
    type: int?
    default: 1000
    doc: "Minimum contig length to output"

outputs:
  contigs:
    type: File
    outputBinding:
      glob: "assembly_contigs.fasta"
    doc: "Assembled contigs FASTA"

  megahit_log:
    type: File
    outputBinding:
      glob: "megahit_out/log"
    doc: "MEGAHIT assembly log"
