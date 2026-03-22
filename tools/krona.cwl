#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Krona - Interactive metagenomic visualization"
doc: |
  Generate interactive HTML pie charts from taxonomic classification
  reports using KronaTools ktImportTaxonomy.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 2048
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/krona:2.7.1--pl526_5"

baseCommand: []

inputs:
  reports:
    type: File[]
    doc: "Kraken2-style report files to visualize"

  sample_ids:
    type: string[]
    doc: "Sample identifiers corresponding to each report"

arguments:
  - shellQuote: false
    valueFrom: |
      ${
        var cmd = "ktImportTaxonomy -t 5 -m 3 -o krona.html";
        for (var i = 0; i < inputs.reports.length; i++) {
          cmd += " " + inputs.reports[i].path + "," + inputs.sample_ids[i];
        }
        return cmd;
      }

outputs:
  html:
    type: File
    outputBinding:
      glob: "krona.html"
    doc: "Interactive Krona HTML visualization"
