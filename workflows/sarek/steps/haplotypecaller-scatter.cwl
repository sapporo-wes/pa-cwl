#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "HaplotypeCaller scatter-gather subworkflow"
doc: |
  Scatter HaplotypeCaller over genomic intervals for a single sample,
  then merge the per-interval VCFs into one output VCF.

requirements:
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  MultipleInputFeatureRequirement: {}

inputs:
  bam:
    type: File
    secondaryFiles:
      - ^.bai
    doc: "Input BAM file (sorted, indexed)"

  reference:
    type: File
    secondaryFiles:
      - .fai
      - ^.dict
    doc: "Reference genome FASTA with .fai and .dict"

  interval_files:
    type: File[]
    doc: "Interval files from SplitIntervals (one per scatter shard)"

  sample_id:
    type: string
    doc: "Sample identifier"

  emit_gvcf:
    type: boolean?
    default: false
    doc: "Emit gVCF mode for joint calling"

  dbsnp:
    type: File?
    secondaryFiles:
      - .tbi
    doc: "dbSNP VCF for annotation"

steps:
  haplotypecaller_scattered:
    run: ../../../tools/gatk4-haplotypecaller.cwl
    scatter: intervals
    in:
      bam: bam
      reference: reference
      dbsnp: dbsnp
      intervals: interval_files
      sample_id: sample_id
      emit_gvcf: emit_gvcf
    out: [vcf]

  merge_vcfs:
    run: ../../../tools/gatk4-merge-vcfs.cwl
    in:
      vcfs: haplotypecaller_scattered/vcf
      output_name:
        source: [sample_id, emit_gvcf]
        valueFrom: |
          ${
            if (self[1]) return self[0] + ".g";
            return self[0];
          }
    out: [merged_vcf]

outputs:
  vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputSource: merge_vcfs/merged_vcf
