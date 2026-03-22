#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "ExpansionHunter - Repeat expansion detection"
doc: |
  Detect repeat expansions from short-read sequencing data using
  ExpansionHunter. Requires a variant catalog JSON specifying the
  repeat loci to genotype.

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/expansionhunter:5.0.0--hd03093a_2"

baseCommand: [ExpansionHunter]

inputs:
  bam:
    type: File
    secondaryFiles:
      - ^.bai
    inputBinding:
      prefix: --reads
    doc: "Input BAM file (sorted, indexed)"

  reference:
    type: File
    secondaryFiles:
      - .fai
    inputBinding:
      prefix: --reference
    doc: "Reference genome FASTA with .fai index"

  variant_catalog:
    type: File
    inputBinding:
      prefix: --variant-catalog
    doc: "ExpansionHunter variant catalog JSON"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - prefix: --output-prefix
    valueFrom: $(inputs.sample_id).expansionhunter
  - prefix: --threads
    valueFrom: $(runtime.cores)

outputs:
  vcf:
    type: File
    outputBinding:
      glob: "*.expansionhunter.vcf"
    doc: "Repeat expansion genotypes in VCF format"

  json_results:
    type: File
    outputBinding:
      glob: "*.expansionhunter.json"
    doc: "Detailed repeat expansion results in JSON format"
