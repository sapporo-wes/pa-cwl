#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Salmon quant - Transcript quantification"
doc: "Quantify transcript abundance using Salmon"

requirements:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/salmon:1.10.3--h6dccd9a_1"
  ResourceRequirement:
    coresMin: 8
    ramMin: 8192

baseCommand: [salmon, quant]

inputs:
  index_dir:
    type: Directory
    inputBinding:
      prefix: --index
    doc: "Salmon index directory"

  fastq_fwd:
    type: File?
    doc: "Forward read FASTQ (for mapping-based mode)"

  fastq_rev:
    type: File?
    doc: "Reverse read FASTQ (for mapping-based mode)"

  aligned_bam:
    type: File?
    doc: "Transcriptome-aligned BAM (for alignment-based mode)"

  sample_id:
    type: string
    doc: "Sample identifier"

  lib_type:
    type: string?
    default: "A"
    inputBinding:
      prefix: --libType
    doc: "Library type (A for automatic detection)"

  mode:
    type:
      type: enum
      symbols: [mapping, alignment]
    default: mapping
    doc: "Quantification mode"

arguments:
  - prefix: --threads
    valueFrom: $(runtime.cores)
  - prefix: --output
    valueFrom: $(inputs.sample_id)_salmon
  - prefix: -1
    valueFrom: |
      ${
        if (inputs.mode == "mapping" && inputs.fastq_fwd) {
          return inputs.fastq_fwd.path;
        }
        return null;
      }
  - prefix: -2
    valueFrom: |
      ${
        if (inputs.mode == "mapping" && inputs.fastq_rev) {
          return inputs.fastq_rev.path;
        }
        return null;
      }
  - prefix: -a
    valueFrom: |
      ${
        if (inputs.mode == "alignment" && inputs.aligned_bam) {
          return inputs.aligned_bam.path;
        }
        return null;
      }
  - "--validateMappings"
  - "--gcBias"

outputs:
  quant_dir:
    type: Directory
    outputBinding:
      glob: "*_salmon"

  quant_sf:
    type: File
    outputBinding:
      glob: "*_salmon/quant.sf"
