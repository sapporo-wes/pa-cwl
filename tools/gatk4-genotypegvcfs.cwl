#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 GenotypeGVCFs"
doc: "Perform joint genotyping on a GenomicsDB workspace"

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, GenotypeGVCFs]

inputs:
  genomicsdb_workspace:
    type: Directory
    inputBinding:
      prefix: -V
      valueFrom: $("gendb://" + self.path)
    doc: "GenomicsDB workspace from GenomicsDBImport"

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
    doc: "dbSNP VCF for annotation"

  intervals:
    type: File?
    inputBinding:
      prefix: -L
    doc: "Intervals BED file"

  cohort_id:
    type: string
    default: "cohort"
    doc: "Cohort identifier for output naming"

arguments:
  - prefix: -O
    valueFrom: $(inputs.cohort_id).joint.vcf.gz

outputs:
  joint_vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputBinding:
      glob: "*.joint.vcf.gz"
