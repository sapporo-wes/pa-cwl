#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Prokka bin annotation subworkflow"
doc: "Run Prokka on each genome bin to annotate genes."

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  bins:
    type: File[]
  run_prokka:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  extract_bin_ids:
    run:
      class: ExpressionTool
      requirements:
        InlineJavascriptRequirement: {}
      inputs:
        bins:
          type: File[]
      outputs:
        bin_ids:
          type: string[]
      expression: |
        ${
          var ids = [];
          for (var i = 0; i < inputs.bins.length; i++) {
            var name = inputs.bins[i].basename;
            var id = name.replace(/\.(fa|fasta|fna)(\.gz)?$/, "");
            ids.push(id);
          }
          return {bin_ids: ids};
        }
    in:
      bins: bins
    out: [bin_ids]

  prokka:
    run: ../../../tools/prokka.cwl
    scatter: [fasta, prefix]
    scatterMethod: dotproduct
    in:
      fasta: bins
      prefix: extract_bin_ids/bin_ids
    out: [gff, faa, fna, gbk, log]

outputs:
  gff_files:
    type: File[]
    outputSource: prokka/gff
  faa_files:
    type: File[]
    outputSource: prokka/faa
  gbk_files:
    type: File[]
    outputSource: prokka/gbk
