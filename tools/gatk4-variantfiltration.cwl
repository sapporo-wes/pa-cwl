#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 VariantFiltration"
doc: "Apply hard filters to a VCF using GATK recommended thresholds"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, VariantFiltration]

inputs:
  vcf:
    type: File
    secondaryFiles:
      - .tbi
    inputBinding:
      prefix: -V
    doc: "Input VCF file"

  reference:
    type: File
    secondaryFiles:
      - .fai
      - ^.dict
    inputBinding:
      prefix: -R
    doc: "Reference genome FASTA"

  sample_id:
    type: string
    doc: "Sample identifier"

  snp_filters:
    type: string[]?
    default:
      - "QD < 2.0"
      - "FS > 60.0"
      - "MQ < 40.0"
      - "MQRankSum < -12.5"
      - "ReadPosRankSum < -8.0"
      - "SOR > 3.0"
    doc: "GATK hard filter expressions for SNPs"

  snp_filter_names:
    type: string[]?
    default:
      - "LowQD"
      - "HighFS"
      - "LowMQ"
      - "LowMQRankSum"
      - "LowReadPosRankSum"
      - "HighSOR"
    doc: "Names for each SNP filter"

arguments:
  - prefix: -O
    valueFrom: $(inputs.sample_id).filtered.vcf.gz
  - valueFrom: |
      ${
        var args = [];
        var filters = inputs.snp_filters;
        var names = inputs.snp_filter_names;
        for (var i = 0; i < filters.length; i++) {
          args.push("--filter-expression");
          args.push(filters[i]);
          args.push("--filter-name");
          args.push(names[i]);
        }
        return args;
      }

outputs:
  filtered_vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputBinding:
      glob: "*.filtered.vcf.gz"
