#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "BUSCO bin quality assessment subworkflow"
doc: "Run BUSCO on each genome bin to assess completeness."

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  bins:
    type: File[]
  lineage:
    type: string
  busco_lineage:
    type: string?
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

  busco:
    run: ../../../tools/busco.cwl
    scatter: [fasta, sample_id]
    scatterMethod: dotproduct
    in:
      fasta: bins
      lineage: lineage
      sample_id: extract_bin_ids/bin_ids
    out: [short_summary]

outputs:
  summaries:
    type: File[]
    outputSource: busco/short_summary
