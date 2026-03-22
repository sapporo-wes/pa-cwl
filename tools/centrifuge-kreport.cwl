#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Centrifuge kreport - Convert to Kraken-style report"
doc: |
  Convert Centrifuge classification output to Kraken-style report format
  for downstream compatibility with tools expecting Kraken2 reports.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: cf_db
        writable: false
        entry: "$({class: 'Directory', listing: inputs.index_files})"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/centrifuge:1.0.4.2--h077b44d_1"

baseCommand: [centrifuge-kreport]

inputs:
  classification:
    type: File
    inputBinding:
      position: 100
    doc: "Centrifuge classification output file"

  index_base:
    type: string
    doc: "Base name of the Centrifuge index"

  index_files:
    type: File[]
    doc: "Centrifuge index files (.cf files)"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - prefix: -x
    valueFrom: cf_db/$(inputs.index_base)

stdout: $(inputs.sample_id)_centrifuge.kreport.txt

outputs:
  kreport:
    type: File
    outputBinding:
      glob: "*_centrifuge.kreport.txt"
    doc: "Kraken-style report from Centrifuge results"
