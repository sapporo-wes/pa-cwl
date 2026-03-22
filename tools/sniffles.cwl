#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Sniffles2 - Structural variant caller for long reads"
doc: |
  Detect structural variants (SVs) from long-read sequencing data
  (Oxford Nanopore, PacBio). Sniffles2 identifies insertions, deletions,
  inversions, duplications, and translocations from sorted BAM files.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/sniffles:2.7.3--pyhdfd78af_0"

baseCommand: [sniffles]

arguments:
  - prefix: --threads
    valueFrom: $(runtime.cores)
  - prefix: --vcf
    valueFrom: $(inputs.sample_id).sniffles.vcf

inputs:
  bam:
    type: File
    secondaryFiles:
      - .bai
    inputBinding:
      prefix: --input
    doc: "Sorted, indexed BAM file from long-read alignment"

  sample_id:
    type: string
    inputBinding:
      prefix: --sample-id
    doc: "Sample identifier for VCF sample column"

  reference:
    type: File?
    inputBinding:
      prefix: --reference
    doc: "Reference genome FASTA (recommended for accurate SV calling)"

  vcf_output:
    type: string?
    doc: "Output VCF filename (auto-generated from sample_id if not provided)"

  min_sv_length:
    type: int?
    default: 50
    inputBinding:
      prefix: --minsvlen
    doc: "Minimum SV length to report (default: 50)"

  min_support:
    type: int?
    inputBinding:
      prefix: --minsupport
    doc: "Minimum number of supporting reads for an SV"

  max_sv_length:
    type: int?
    inputBinding:
      prefix: --maxsvlen
    doc: "Maximum SV length to report"

  output_rnames:
    type: boolean?
    inputBinding:
      prefix: --output-rnames
    doc: "Include read names in VCF output"

outputs:
  vcf:
    type: File
    outputBinding:
      glob: "*.sniffles.vcf"
    doc: "Structural variant calls in VCF format"
