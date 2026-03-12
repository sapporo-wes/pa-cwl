#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Salmon quant - Transcript quantification"
doc: "Quantify transcript abundance using Salmon"

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/salmon:1.10.3--h45fbf2d_5"

baseCommand: [salmon, quant]

inputs:
  index_dir:
    type: Directory?
    doc: "Salmon index directory (required for mapping mode)"

  transcriptome_fasta:
    type: File?
    doc: "Transcriptome FASTA (for alignment-based mode targets)"

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
  - valueFrom: |
      ${
        if (inputs.mode == "mapping" && inputs.index_dir) {
          return ["--index", inputs.index_dir.path];
        }
        return [];
      }
  - valueFrom: |
      ${
        if (inputs.mode == "mapping" && inputs.fastq_fwd) {
          return ["-1", inputs.fastq_fwd.path];
        }
        return [];
      }
  - valueFrom: |
      ${
        if (inputs.mode == "mapping" && inputs.fastq_rev) {
          return ["-2", inputs.fastq_rev.path];
        }
        return [];
      }
  - valueFrom: |
      ${
        if (inputs.mode == "alignment" && inputs.aligned_bam) {
          return ["-a", inputs.aligned_bam.path];
        }
        return [];
      }
  - valueFrom: |
      ${
        if (inputs.mode == "alignment" && inputs.transcriptome_fasta) {
          return ["-t", inputs.transcriptome_fasta.path];
        }
        return [];
      }
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
