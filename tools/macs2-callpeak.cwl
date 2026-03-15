#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "MACS2 callpeak - Peak calling"
doc: "Call peaks from ChIP-seq or ATAC-seq data using MACS2"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/macs2:2.2.9.1--py310h1fe012e_5"

baseCommand: [macs2, callpeak]

inputs:
  treatment_bam:
    type: File
    inputBinding:
      prefix: -t
    doc: "Treatment/IP BAM file"

  control_bam:
    type: File?
    inputBinding:
      prefix: -c
    doc: "Control/input BAM file (optional)"

  sample_id:
    type: string
    inputBinding:
      prefix: -n
    doc: "Sample name for output files"

  genome_size:
    type: string
    inputBinding:
      prefix: -g
    doc: "Effective genome size (e.g. hs, mm, ce, dm, or number)"

  broad:
    type: boolean?
    default: false
    inputBinding:
      prefix: --broad
    doc: "Call broad peaks (histone marks)"

  qvalue:
    type: float?
    default: 0.05
    inputBinding:
      prefix: -q
    doc: "Minimum FDR (q-value) cutoff"

  format:
    type: string?
    default: "BAMPE"
    inputBinding:
      prefix: -f
    doc: "Input format (BAMPE for paired-end BAM)"

  keep_dup:
    type: string?
    default: "1"
    inputBinding:
      prefix: --keep-dup
    doc: "How to handle duplicates (1=keep 1, all=keep all, auto)"

  nomodel:
    type: boolean?
    default: false
    inputBinding:
      prefix: --nomodel
    doc: "Skip MACS2 fragment size model (required for ATAC-seq)"

  outdir:
    type: string?
    default: "."
    inputBinding:
      prefix: --outdir

arguments:
  - --bdg
  - --SPMR

outputs:
  narrow_peaks:
    type: File?
    outputBinding:
      glob: "*_peaks.narrowPeak"

  broad_peaks:
    type: File?
    outputBinding:
      glob: "*_peaks.broadPeak"

  summits:
    type: File?
    outputBinding:
      glob: "*_summits.bed"

  xls:
    type: File
    outputBinding:
      glob: "*_peaks.xls"

  treat_pileup:
    type: File
    outputBinding:
      glob: "*_treat_pileup.bdg"

  control_lambda:
    type: File
    outputBinding:
      glob: "*_control_lambda.bdg"
