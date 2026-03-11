#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "RSEM quantification subworkflow"
doc: "Quantify gene and isoform expression using RSEM from STAR transcriptome BAM"

requirements:
  InlineJavascriptRequirement: {}

inputs:
  transcriptome_bam:
    type: File?
    doc: "Transcriptome-aligned BAM from STAR"
  reference_dir:
    type: Directory?
    doc: "RSEM reference directory"
  sample_id:
    type: string
  paired:
    type: boolean?
    default: true

steps:
  rsem_quant:
    run: ../../../tools/rsem-calculate-expression.cwl
    in:
      transcriptome_bam: transcriptome_bam
      reference_dir: reference_dir
      sample_id: sample_id
      paired: paired
    out: [genes_results, isoforms_results, stat_dir]

outputs:
  genes_results:
    type: File
    outputSource: rsem_quant/genes_results

  isoforms_results:
    type: File
    outputSource: rsem_quant/isoforms_results
