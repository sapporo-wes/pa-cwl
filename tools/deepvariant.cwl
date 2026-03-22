#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "DeepVariant - Deep learning variant caller"
doc: |
  Call germline SNPs and indels using a deep neural network.
  Produces both VCF and gVCF outputs for downstream joint calling
  or single-sample analysis.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 16384
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "google/deepvariant:1.6.1"

baseCommand: [/opt/deepvariant/bin/run_deepvariant]

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
      prefix: --ref
    doc: "Reference genome FASTA with .fai index"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

  model_type:
    type: string?
    default: "WGS"
    inputBinding:
      prefix: --model_type
    doc: "Model type: WGS, WES, or PACBIO"

arguments:
  - prefix: --output_vcf
    valueFrom: $(inputs.sample_id).deepvariant.vcf.gz
  - prefix: --output_gvcf
    valueFrom: $(inputs.sample_id).deepvariant.g.vcf.gz
  - prefix: --num_shards
    valueFrom: $(runtime.cores)

outputs:
  vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputBinding:
      glob: "*.deepvariant.vcf.gz"
    doc: "DeepVariant variant calls in VCF format"

  gvcf:
    type: File
    secondaryFiles:
      - .tbi
    outputBinding:
      glob: "*.deepvariant.g.vcf.gz"
    doc: "DeepVariant gVCF for joint calling"
