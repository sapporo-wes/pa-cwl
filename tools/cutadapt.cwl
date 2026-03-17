#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Cutadapt - Adapter and primer trimming"
doc: |
  Remove adapter and primer sequences from sequencing reads.
  Commonly used for amplicon sequencing primer removal.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/cutadapt:4.9--py312hf67a6ed_2"

baseCommand: [cutadapt]

inputs:
  fastq_fwd:
    type: File
    inputBinding:
      position: 100
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File?
    inputBinding:
      position: 101
    doc: "Reverse read FASTQ"

  adapter_fwd:
    type: string
    inputBinding:
      prefix: -g
    doc: "Forward primer/adapter sequence (5' anchored: ^SEQUENCE)"

  adapter_rev:
    type: string?
    inputBinding:
      prefix: -G
    doc: "Reverse primer/adapter sequence (5' anchored: ^SEQUENCE)"

  prefix:
    type: string
    doc: "Output file prefix"

  min_length:
    type: int?
    default: 1
    inputBinding:
      prefix: --minimum-length
    doc: "Discard reads shorter than this"

  max_expected_errors:
    type: float?
    inputBinding:
      prefix: --max-expected-errors
    doc: "Maximum expected errors for filtering"

  discard_untrimmed:
    type: boolean?
    default: true
    inputBinding:
      prefix: --discard-untrimmed
    doc: "Discard reads without adapter/primer"

arguments:
  - prefix: -j
    valueFrom: $(runtime.cores)
  - prefix: -o
    valueFrom: $(inputs.prefix)_trimmed_R1.fastq.gz
  - prefix: -p
    valueFrom: |
      ${
        if (inputs.fastq_rev) {
          return inputs.prefix + "_trimmed_R2.fastq.gz";
        }
        return null;
      }

outputs:
  trimmed_fwd:
    type: File
    outputBinding:
      glob: "*_trimmed_R1.fastq.gz"

  trimmed_rev:
    type: File?
    outputBinding:
      glob: "*_trimmed_R2.fastq.gz"

  stdout_log:
    type: stdout

stdout: cutadapt.log
