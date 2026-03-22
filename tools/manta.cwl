#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Manta - Structural variant and indel caller"
doc: |
  Detect structural variants and large indels from short-read sequencing data.
  Manta uses a two-step process: configManta.py to configure the analysis,
  then runWorkflow.py to execute it.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_manta.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          BAM="$1"
          REFERENCE="$2"
          SAMPLE_ID="$3"
          THREADS="$4"

          configManta.py \
            --bam "$BAM" \
            --referenceFasta "$REFERENCE" \
            --runDir manta_run

          manta_run/runWorkflow.py -j "$THREADS"

          # Copy outputs with sample-prefixed names
          cp manta_run/results/variants/diploidSV.vcf.gz "$SAMPLE_ID.manta.diploidSV.vcf.gz"
          cp manta_run/results/variants/diploidSV.vcf.gz.tbi "$SAMPLE_ID.manta.diploidSV.vcf.gz.tbi"
          cp manta_run/results/variants/candidateSV.vcf.gz "$SAMPLE_ID.manta.candidateSV.vcf.gz"
          cp manta_run/results/variants/candidateSV.vcf.gz.tbi "$SAMPLE_ID.manta.candidateSV.vcf.gz.tbi"
          cp manta_run/results/variants/candidateSmallIndels.vcf.gz "$SAMPLE_ID.manta.candidateSmallIndels.vcf.gz"
          cp manta_run/results/variants/candidateSmallIndels.vcf.gz.tbi "$SAMPLE_ID.manta.candidateSmallIndels.vcf.gz.tbi"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/manta:1.6.0--h9ee0642_2"

baseCommand: [bash, run_manta.sh]

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
    doc: "Reference genome FASTA with .fai index"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - position: 1
    valueFrom: $(inputs.bam.path)
  - position: 2
    valueFrom: $(inputs.reference.path)
  - position: 3
    valueFrom: $(inputs.sample_id)
  - position: 4
    valueFrom: $(runtime.cores)

outputs:
  diploid_sv_vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputBinding:
      glob: "*.manta.diploidSV.vcf.gz"
    doc: "Diploid structural variant calls"

  candidate_sv_vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputBinding:
      glob: "*.manta.candidateSV.vcf.gz"
    doc: "Candidate structural variant calls"

  candidate_small_indels_vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputBinding:
      glob: "*.manta.candidateSmallIndels.vcf.gz"
    doc: "Candidate small indel calls"
