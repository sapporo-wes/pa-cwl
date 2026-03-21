#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "bcftools mpileup + call"
doc: |
  Variant calling using bcftools mpileup and call pipeline.
  Produces a bgzipped, tabix-indexed VCF file.

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 4096
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bcftools:1.19--h8b25389_1"

baseCommand: [bash, -c]

arguments:
  - valueFrom: |
      ${
        var cmd = "set -euo pipefail && ";
        cmd += "bcftools mpileup -f " + inputs.reference.path;
        cmd += " --threads " + runtime.cores;
        if (inputs.min_bq) cmd += " --min-BQ " + inputs.min_bq;
        if (inputs.max_depth) cmd += " --max-depth " + inputs.max_depth;
        cmd += " " + inputs.bam.path;
        cmd += " | bcftools call -mv --ploidy " + inputs.ploidy;
        cmd += " -Oz -o " + inputs.sample_id + ".bcftools.vcf.gz";
        cmd += " && bcftools index -t " + inputs.sample_id + ".bcftools.vcf.gz";
        return cmd;
      }

inputs:
  bam:
    type: File
    secondaryFiles:
      - .bai
    doc: "Sorted, indexed BAM file"

  reference:
    type: File
    secondaryFiles:
      - .fai
    doc: "Reference genome FASTA with .fai index"

  sample_id:
    type: string
    doc: "Sample identifier"

  ploidy:
    type: string
    default: "1"
    doc: "Sample ploidy (1 for haploid/viral, 2 for diploid)"

  min_bq:
    type: int?
    default: 20
    doc: "Minimum base quality for pileup"

  max_depth:
    type: int?
    default: 8000
    doc: "Maximum read depth for pileup"

outputs:
  vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputBinding:
      glob: "*.bcftools.vcf.gz"
