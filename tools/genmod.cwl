#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GENMOD - Pedigree-aware variant ranking"
doc: |
  Annotate and rank variants using pedigree information. Runs genmod models
  (inheritance model annotation), genmod score (variant scoring), and
  genmod compound (compound heterozygote detection) in sequence.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_genmod.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          VCF="$1"
          FAMILY="$2"
          SAMPLE_ID="$3"

          genmod models "$VCF" -f "$FAMILY" \
            | genmod score - -f "$FAMILY" \
            | genmod compound - \
            > "${SAMPLE_ID}.ranked.vcf"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/genmod:3.8.2--pyh7cba7a3_0"

baseCommand: [bash, run_genmod.sh]

inputs:
  vcf:
    type: File
    doc: "Input VCF file (VEP-annotated recommended)"

  family_file:
    type: File
    doc: "PED format pedigree file"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - position: 1
    valueFrom: $(inputs.vcf.path)
  - position: 2
    valueFrom: $(inputs.family_file.path)
  - position: 3
    valueFrom: $(inputs.sample_id)

outputs:
  ranked_vcf:
    type: File
    outputBinding:
      glob: "*.ranked.vcf"
    doc: "VCF with inheritance models, scores, and compound het annotation"
