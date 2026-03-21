#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Medaka variant calling"
doc: |
  Haploid variant calling from Nanopore reads using medaka.
  Runs medaka inference → vcf → annotate on a pre-aligned BAM,
  then bgzips and indexes the output VCF.

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 8192
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/medaka:2.0.1--py39hf77f13f_0"

baseCommand: [bash, -c]

arguments:
  - valueFrom: |
      ${
        var cmd = "set -euo pipefail && ";
        cmd += "medaka inference " + inputs.bam.path + " consensus_probs.hdf";
        cmd += " --model " + inputs.model;
        cmd += " --threads " + inputs.threads;
        cmd += " --batch_size " + inputs.batch_size;
        cmd += " && medaka vcf consensus_probs.hdf " + inputs.reference.path + " medaka.vcf";
        cmd += " && bcftools sort medaka.vcf -o medaka.sorted.vcf";
        cmd += " && medaka tools annotate medaka.sorted.vcf " + inputs.reference.path + " " + inputs.bam.path + " " + inputs.sample_id + ".medaka.vcf";
        cmd += " && bcftools view -Oz -o " + inputs.sample_id + ".medaka.vcf.gz " + inputs.sample_id + ".medaka.vcf";
        cmd += " && bcftools index -t " + inputs.sample_id + ".medaka.vcf.gz";
        return cmd;
      }

inputs:
  bam:
    type: File
    secondaryFiles:
      - .bai
    doc: "Sorted, indexed BAM file from minimap2 alignment"

  reference:
    type: File
    secondaryFiles:
      - .fai
    doc: "Reference genome FASTA with .fai index"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

  model:
    type: string
    default: "r1041_e82_400bps_sup_variant_v4.3.0"
    doc: "Medaka model for variant calling"

  threads:
    type: int
    default: 2
    doc: "Number of threads"

  batch_size:
    type: int
    default: 100
    doc: "Inference batch size (controls memory usage)"

outputs:
  vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputBinding:
      glob: "*.medaka.vcf.gz"
