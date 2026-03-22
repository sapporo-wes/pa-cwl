#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GTDB-Tk - Genome taxonomy classification"
doc: |
  Taxonomic classification of bacterial and archaeal genomes using the
  Genome Taxonomy Database (GTDB). Runs the classify workflow on a
  directory of genome bins.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 65536
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_gtdbtk.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          THREADS=$(runtime.cores)

          # Link bin files into a genome directory
          mkdir -p genome_dir
          $(inputs.bins.map(function(f){ return 'ln -s "' + f.path + '" genome_dir/'; }).join('\n          '))

          # Set GTDBTK_DATA_PATH
          export GTDBTK_DATA_PATH="$(inputs.gtdbtk_db.path)"

          gtdbtk classify_wf \
            --genome_dir genome_dir \
            --out_dir gtdbtk_output \
            --cpus $THREADS \
            --extension fa \
            --skip_ani_screen

          # Copy main classification files to working dir for output
          if [ -f gtdbtk_output/gtdbtk.bac120.summary.tsv ]; then
            cp gtdbtk_output/gtdbtk.bac120.summary.tsv .
          fi
          if [ -f gtdbtk_output/gtdbtk.ar53.summary.tsv ]; then
            cp gtdbtk_output/gtdbtk.ar53.summary.tsv .
          fi

          # Create a combined classification summary
          head -1 gtdbtk_output/gtdbtk.bac120.summary.tsv > gtdbtk_classification.tsv 2>/dev/null || true
          tail -n +2 gtdbtk_output/gtdbtk.bac120.summary.tsv >> gtdbtk_classification.tsv 2>/dev/null || true
          tail -n +2 gtdbtk_output/gtdbtk.ar53.summary.tsv >> gtdbtk_classification.tsv 2>/dev/null || true

          # If no classifications were produced, create a placeholder
          if [ ! -s gtdbtk_classification.tsv ]; then
            echo "No classifications produced" > gtdbtk_classification.tsv
          fi

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/gtdbtk:2.4.0--pyhdfd78af_1"

baseCommand: [bash, run_gtdbtk.sh]

inputs:
  bins:
    type: File[]
    doc: "Genome bin FASTA files"

  gtdbtk_db:
    type: Directory
    doc: "GTDB-Tk reference database directory"

outputs:
  classification:
    type: File
    outputBinding:
      glob: "gtdbtk_classification.tsv"
    doc: "Combined taxonomic classification summary"

  bac120_summary:
    type: File?
    outputBinding:
      glob: "gtdbtk.bac120.summary.tsv"
    doc: "Bacterial classification summary"

  ar53_summary:
    type: File?
    outputBinding:
      glob: "gtdbtk.ar53.summary.tsv"
    doc: "Archaeal classification summary"
