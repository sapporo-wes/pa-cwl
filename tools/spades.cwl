#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "SPAdes - Genome/metagenome assembler"
doc: |
  De novo genome assembler. Supports metaSPAdes mode for metagenome assembly.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 16384
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_spades.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          FWD_FILES="$(inputs.fastq_fwd.map(function(f){ return f.path; }).join(','))"
          REV_FILES="$(inputs.fastq_rev.map(function(f){ return f.path; }).join(','))"
          THREADS=$(runtime.cores)
          MEM_GB=\$(( $(runtime.ram) / 1024 ))
          MODE="$(inputs.mode)"
          MIN_CONTIG=$(inputs.min_contig_len)

          # Build SPAdes command
          ARGS=""
          if [ "$MODE" = "meta" ]; then
            ARGS="--meta"
          elif [ "$MODE" = "isolate" ]; then
            ARGS="--isolate"
          fi

          spades.py $ARGS \
            -1 "$FWD_FILES" \
            -2 "$REV_FILES" \
            -t $THREADS \
            -m $MEM_GB \
            --only-assembler \
            -o spades_out

          # Filter contigs by minimum length and rename
          python3 -c "
          import sys
          min_len = $MIN_CONTIG
          write = False
          with open('spades_out/contigs.fasta') as f, open('assembly_contigs.fasta', 'w') as out:
              for line in f:
                  if line.startswith('>'):
                      length = int(line.split('_length_')[1].split('_')[0])
                      write = length >= min_len
                  if write:
                      out.write(line)
          "

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/spades:4.2.0--h8d6e82b_2"

baseCommand: [bash, run_spades.sh]

inputs:
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files"

  fastq_rev:
    type: File[]
    doc: "Reverse read FASTQ files"

  mode:
    type: string?
    default: meta
    doc: "Assembly mode: meta (metagenome), isolate, or normal"

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

  spades_log:
    type: File
    outputBinding:
      glob: "spades_out/spades.log"
    doc: "SPAdes assembly log"
