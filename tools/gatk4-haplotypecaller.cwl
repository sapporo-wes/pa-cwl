#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 HaplotypeCaller"
doc: "Call germline SNPs and indels via local assembly of haplotypes"

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, HaplotypeCaller]

inputs:
  bam:
    type: File
    secondaryFiles:
      - ^.bai
    inputBinding:
      prefix: -I
    doc: "Input BAM file (sorted, indexed)"

  reference:
    type: File
    secondaryFiles:
      - .fai
      - ^.dict
    inputBinding:
      prefix: -R
    doc: "Reference genome FASTA with .fai and .dict"

  dbsnp:
    type: File?
    secondaryFiles:
      - .tbi
    inputBinding:
      prefix: --dbsnp
    doc: "dbSNP VCF for annotation of known variants"

  intervals:
    type: File?
    inputBinding:
      prefix: -L
    doc: "Intervals BED file (for WES/targeted)"

  sample_id:
    type: string
    doc: "Sample identifier"

  emit_gvcf:
    type: boolean?
    default: false
    inputBinding:
      prefix: -ERC
      valueFrom: |
        ${
          if (self) return "GVCF";
          return null;
        }
    doc: "Emit per-sample gVCF for joint calling"

arguments:
  - prefix: -O
    valueFrom: |
      ${
        if (inputs.emit_gvcf) return inputs.sample_id + ".g.vcf.gz";
        return inputs.sample_id + ".vcf.gz";
      }

outputs:
  vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputBinding:
      glob: "*.vcf.gz"
