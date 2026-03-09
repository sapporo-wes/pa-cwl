#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "RSEM calculate-expression - Quantify gene/isoform expression"
doc: "Estimate gene and isoform expression levels from RNA-seq data"

requirements:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/rsem:1.3.3--h93d5f22_6"
  ResourceRequirement:
    coresMin: 8
    ramMin: 16384

baseCommand: [rsem-calculate-expression]

inputs:
  transcriptome_bam:
    type: File
    inputBinding:
      position: 1
    doc: "Transcriptome-aligned BAM from STAR"

  reference_dir:
    type: Directory
    doc: "RSEM reference directory"

  sample_id:
    type: string
    doc: "Sample identifier"

  paired:
    type: boolean?
    default: true
    inputBinding:
      prefix: --paired-end
    doc: "Paired-end reads"

arguments:
  - prefix: --num-threads
    valueFrom: $(runtime.cores)
  - "--bam"
  - "--no-bam-output"
  - "--estimate-rspd"
  - position: 2
    valueFrom: $(inputs.reference_dir.path)/rsem
  - position: 3
    valueFrom: $(inputs.sample_id)

outputs:
  genes_results:
    type: File
    outputBinding:
      glob: "*.genes.results"

  isoforms_results:
    type: File
    outputBinding:
      glob: "*.isoforms.results"

  stat_dir:
    type: Directory
    outputBinding:
      glob: "*.stat"
