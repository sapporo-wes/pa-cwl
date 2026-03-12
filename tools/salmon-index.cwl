#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Salmon index - Build Salmon transcriptome index"
doc: |
  Generate Salmon index from transcriptome FASTA. Optionally builds a
  decoy-aware index using genome FASTA (recommended for accuracy).

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 16384
  ShellCommandRequirement: {}
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: build_index.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          THREADS="$1"
          TRANSCRIPTOME="$2"
          GENOME="\${3:-}"

          if [ -n "$GENOME" ]; then
            echo "Building decoy-aware index..."
            grep "^>" "$GENOME" | cut -d' ' -f1 | sed 's/>//' > decoys.txt
            cat "$TRANSCRIPTOME" "$GENOME" > gentrome.fa
            salmon index -t gentrome.fa -d decoys.txt -i salmon_index -p "$THREADS"
            rm -f gentrome.fa decoys.txt
          else
            echo "Building index without decoys..."
            salmon index -t "$TRANSCRIPTOME" -i salmon_index -p "$THREADS"
          fi

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/salmon:1.10.3--h45fbf2d_5"

baseCommand: [bash, build_index.sh]

inputs:
  transcriptome_fasta:
    type: File
    doc: "Transcriptome FASTA file"

  genome_fasta:
    type: File?
    doc: "Genome FASTA for decoy-aware index (recommended)"

arguments:
  - position: 1
    valueFrom: $(runtime.cores)
  - position: 2
    valueFrom: $(inputs.transcriptome_fasta.path)
  - position: 3
    valueFrom: |
      ${
        if (inputs.genome_fasta) {
          return inputs.genome_fasta.path;
        }
        return "";
      }

outputs:
  index_dir:
    type: Directory
    outputBinding:
      glob: salmon_index
