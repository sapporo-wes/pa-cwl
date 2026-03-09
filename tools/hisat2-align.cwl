#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "HISAT2 - Spliced-aware aligner"
doc: "Align RNA-seq reads using HISAT2 with lower memory footprint"

requirements:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/hisat2:2.2.1--h87f3376_4"
  ResourceRequirement:
    coresMin: 8
    ramMin: 8192
  ShellCommandRequirement: {}

baseCommand: [hisat2]

inputs:
  index_files:
    type: File[]
    doc: "HISAT2 index files"

  index_basename:
    type: string?
    default: "hisat2_index"
    doc: "Basename used when building the index"

  fastq_fwd:
    type: File
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File?
    doc: "Reverse read FASTQ"

  sample_id:
    type: string
    doc: "Sample identifier"

  strandedness:
    type:
      type: enum
      symbols: [unstranded, forward, reverse]
    default: unstranded
    doc: "Library strandedness"

arguments:
  - prefix: -p
    valueFrom: $(runtime.cores)
  - prefix: -x
    valueFrom: $(inputs.index_basename)
  - prefix: "-1"
    valueFrom: $(inputs.fastq_fwd.path)
  - prefix: "-2"
    valueFrom: |
      ${
        if (inputs.fastq_rev) {
          return inputs.fastq_rev.path;
        }
        return null;
      }
  - prefix: --rna-strandness
    valueFrom: |
      ${
        var map = {"forward": "FR", "reverse": "RF", "unstranded": ""};
        return map[inputs.strandedness] || "";
      }
  - prefix: --new-summary
    valueFrom: ""
  - prefix: --summary-file
    valueFrom: $(inputs.sample_id).hisat2.summary.log
  - valueFrom: "|"
    shellQuote: false
  - "samtools"
  - "view"
  - "-bS"
  - "-"
  - prefix: "-o"
    valueFrom: $(inputs.sample_id).bam

outputs:
  aligned_bam:
    type: File
    outputBinding:
      glob: "$(inputs.sample_id).bam"

  summary_log:
    type: File
    outputBinding:
      glob: "*.hisat2.summary.log"
