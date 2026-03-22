#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Centrifuge - Rapid metagenomic sequence classification"
doc: |
  Classify metagenomic reads against a Centrifuge index using
  a novel indexing scheme based on the Burrows-Wheeler transform
  and the Ferragina-Manzini index.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 16384
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: cf_db
        writable: false
        entry: "$({class: 'Directory', listing: inputs.index_files})"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/centrifuge:1.0.4.2--h077b44d_1"

baseCommand: [centrifuge]

inputs:
  fastq_fwd:
    type: File
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File?
    doc: "Reverse read FASTQ (omit for single-end)"

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
  - prefix: --threads
    valueFrom: $(runtime.cores)
  - prefix: -x
    valueFrom: cf_db/$(inputs.index_base)
  - prefix: -S
    valueFrom: $(inputs.sample_id)_centrifuge.tsv
  - prefix: --report-file
    valueFrom: $(inputs.sample_id)_centrifuge_report.tsv
  - valueFrom: |
      ${
        if (inputs.fastq_rev) {
          return "-1";
        }
        return "-U";
      }
  - valueFrom: $(inputs.fastq_fwd.path)
    position: 50
  - valueFrom: |
      ${
        if (inputs.fastq_rev) {
          return "-2";
        }
        return null;
      }
    position: 51
  - valueFrom: |
      ${
        if (inputs.fastq_rev) {
          return inputs.fastq_rev.path;
        }
        return null;
      }
    position: 52

outputs:
  classification:
    type: File
    outputBinding:
      glob: "*_centrifuge.tsv"
    doc: "Centrifuge per-read classification output"

  report:
    type: File
    outputBinding:
      glob: "*_centrifuge_report.tsv"
    doc: "Centrifuge classification summary report"
