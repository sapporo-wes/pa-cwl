#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Kraken2 host read filtering"
doc: |
  Filter out host reads using Kraken2. Unclassified reads (viral) are
  kept; classified reads (host) are discarded. For paired-end data,
  Kraken2 uses the '#' convention to split output into _1 and _2 files.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 16384
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - $(inputs.fastq_fwd)
      - $(inputs.fastq_rev)

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/kraken2:2.1.3--pl5321hdcf5f25_1"

baseCommand: [kraken2]

inputs:
  fastq_fwd:
    type: File
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File?
    doc: "Reverse read FASTQ (omit for single-end)"

  kraken2_host_db:
    type: Directory
    inputBinding:
      prefix: --db
    doc: "Kraken2 database directory (e.g. human host DB)"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - prefix: --threads
    valueFrom: $(runtime.cores)
  - prefix: --report
    valueFrom: $(inputs.sample_id)_kraken2_host.report.txt
  - prefix: --output
    valueFrom: $(inputs.sample_id)_kraken2_host.output.txt
  - prefix: --unclassified-out
    valueFrom: $(inputs.sample_id)_unclassified#.fastq
  - valueFrom: |
      ${
        if (inputs.fastq_rev) {
          return "--paired";
        }
        return null;
      }
  - valueFrom: $(inputs.fastq_fwd.path)
    position: 100
  - valueFrom: |
      ${
        if (inputs.fastq_rev) {
          return inputs.fastq_rev.path;
        }
        return null;
      }
    position: 101

outputs:
  filtered_fwd:
    type: File
    outputBinding:
      glob: $(inputs.sample_id)_unclassified_1.fastq
    doc: "Forward reads not classified as host (viral)"

  filtered_rev:
    type: File?
    outputBinding:
      glob: |
        ${
          if (inputs.fastq_rev) {
            return inputs.sample_id + "_unclassified_2.fastq";
          }
          return "NONEXISTENT_FILE_GLOB";
        }
    doc: "Reverse reads not classified as host (viral)"

  kraken2_report:
    type: File
    outputBinding:
      glob: "*_kraken2_host.report.txt"
    doc: "Kraken2 classification report"
