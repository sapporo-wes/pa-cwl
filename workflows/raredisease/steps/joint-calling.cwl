#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Joint calling subworkflow for raredisease"
doc: |
  Joint germline variant calling: imports per-sample gVCFs into
  GenomicsDB, then runs GenotypeGVCFs to produce a multi-sample VCF.

requirements:
  InlineJavascriptRequirement: {}

inputs:
  gvcfs:
    type: File[]
    secondaryFiles:
      - .tbi
  reference:
    type: File
    secondaryFiles:
      - .fai
      - ^.dict
  dbsnp:
    type: File?
    secondaryFiles:
      - .tbi
  intervals:
    type: File?
  cohort_id:
    type: string
  emit_gvcf:
    type: boolean?
    doc: "Passed through for conditional evaluation only"

steps:
  genomicsdbimport:
    run: ../../../tools/gatk4-genomicsdbimport.cwl
    in:
      gvcfs: gvcfs
      intervals: intervals
      cohort_id: cohort_id
    out: [genomicsdb_workspace]

  genotypegvcfs:
    run: ../../../tools/gatk4-genotypegvcfs.cwl
    in:
      genomicsdb_workspace: genomicsdbimport/genomicsdb_workspace
      reference: reference
      dbsnp: dbsnp
      intervals: intervals
      cohort_id: cohort_id
    out: [joint_vcf]

outputs:
  joint_vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputSource: genotypegvcfs/joint_vcf
