#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "GTDB-Tk bin classification subworkflow"
doc: |
  Run GTDB-Tk classify_wf on genome bins. Wraps the GTDB-Tk tool
  to handle linking bins into a directory, as required by the tool.

requirements:
  InlineJavascriptRequirement: {}

inputs:
  bins:
    type: File[]
  gtdbtk_db:
    type: Directory
    doc: "GTDB-Tk reference database directory"

steps:
  classify:
    run: ../../../tools/gtdbtk.cwl
    in:
      bins: bins
      gtdbtk_db: gtdbtk_db
    out: [classification, bac120_summary, ar53_summary]

outputs:
  classification:
    type: File
    outputSource: classify/classification
  bac120_summary:
    type: File?
    outputSource: classify/bac120_summary
  ar53_summary:
    type: File?
    outputSource: classify/ar53_summary
