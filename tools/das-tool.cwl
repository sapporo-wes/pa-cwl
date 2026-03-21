#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "DAS Tool - Bin refinement"
doc: |
  DAS Tool for automated refinement of metagenome-assembled genomes.
  Integrates results from multiple binning tools to produce an optimized,
  non-redundant set of bins.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: prepare_scaffolds2bin.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          BIN_DIR="$1"
          OUTPUT="$2"

          > "$OUTPUT"
          for f in "$BIN_DIR"/*.fa; do
            if [ -f "$f" ]; then
              BIN=$(basename "$f" .fa)
              grep ">" "$f" | sed "s/>//" | while read -r contig; do
                printf "%s\t%s\n" "$contig" "$BIN"
              done >> "$OUTPUT"
            fi
          done

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/das_tool:1.1.7--r43hdfd78af_0"

baseCommand: [bash, -c]

inputs:
  contigs:
    type: File
    doc: "Assembly contigs FASTA"

  bins:
    type: File[]
    doc: "Genome bin FASTA files from MetaBAT2 (or other binner)"

  sample_id:
    type: string?
    default: "das_tool"
    doc: "Output prefix"

  search_engine:
    type: string?
    default: "diamond"
    doc: "Gene identifier search engine (diamond, blast, prodigal)"

  run_das_tool:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

arguments:
  - valueFrom: |
      ${
        var cmd = "set -euo pipefail && ";
        cmd += "mkdir -p bin_input && ";
        for (var i = 0; i < inputs.bins.length; i++) {
          cmd += "ln -s " + inputs.bins[i].path + " bin_input/ && ";
        }
        cmd += "bash prepare_scaffolds2bin.sh bin_input scaffolds2bin.tsv && ";
        cmd += "DAS_Tool";
        cmd += " -i scaffolds2bin.tsv";
        cmd += " -l metabat2";
        cmd += " -c " + inputs.contigs.path;
        cmd += " -o " + inputs.sample_id;
        cmd += " --search_engine " + inputs.search_engine;
        cmd += " -t " + runtime.cores;
        cmd += " --write_bins";
        return cmd;
      }

outputs:
  refined_bins:
    type: File[]
    outputBinding:
      glob: $(inputs.sample_id)_DASTool_bins/*.fa
    doc: "Refined genome bin FASTA files"

  summary:
    type: File
    outputBinding:
      glob: $(inputs.sample_id)_DASTool_summary.tsv
    doc: "DAS Tool summary with bin scores"

  log:
    type: File
    outputBinding:
      glob: $(inputs.sample_id)_DASTool.log
    doc: "DAS Tool log file"
