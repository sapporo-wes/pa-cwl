#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Kraken2 - Taxonomic sequence classification"
doc: |
  Assign taxonomic labels to metagenomic reads using exact k-mer matches
  against a reference database.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 16384
  InlineJavascriptRequirement: {}

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

  database:
    type: Directory
    inputBinding:
      prefix: --db
    doc: "Kraken2 database directory"

  prefix:
    type: string
    doc: "Output file prefix"

  confidence:
    type: float?
    default: 0.0
    inputBinding:
      prefix: --confidence
    doc: "Confidence score threshold"

  minimum_hit_groups:
    type: int?
    default: 2
    inputBinding:
      prefix: --minimum-hit-groups
    doc: "Minimum number of hit groups for classification"

arguments:
  - prefix: --threads
    valueFrom: $(runtime.cores)
  - prefix: --report
    valueFrom: $(inputs.prefix)_kraken2.report.txt
  - prefix: --output
    valueFrom: $(inputs.prefix)_kraken2.output.txt
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
  report:
    type: File
    outputBinding:
      glob: "*_kraken2.report.txt"
    doc: "Kraken2 report (taxa, counts, percentages)"

  output:
    type: File
    outputBinding:
      glob: "*_kraken2.output.txt"
    doc: "Per-read classification output"
