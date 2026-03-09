#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "STAR - Spliced-aware RNA-seq aligner"
doc: "Align RNA-seq reads to a reference genome using STAR"

requirements:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/star:2.7.11b--h43eeafb_0"
  ResourceRequirement:
    coresMin: 8
    ramMin: 32768

baseCommand: [STAR]

inputs:
  index_dir:
    type: Directory
    inputBinding:
      prefix: --genomeDir
    doc: "STAR genome index directory"

  fastq_fwd:
    type: File
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File?
    doc: "Reverse read FASTQ"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

  quantmode:
    type: string?
    default: "TranscriptomeSAM"
    inputBinding:
      prefix: --quantMode
    doc: "Quantification mode (TranscriptomeSAM for Salmon/RSEM)"

arguments:
  - prefix: --runThreadN
    valueFrom: $(runtime.cores)
  - prefix: --readFilesIn
    valueFrom: |
      ${
        var files = [inputs.fastq_fwd.path];
        if (inputs.fastq_rev) {
          files.push(inputs.fastq_rev.path);
        }
        return files;
      }
  - prefix: --readFilesCommand
    valueFrom: "zcat"
  - prefix: --outFileNamePrefix
    valueFrom: $(inputs.sample_id).
  - prefix: --outSAMtype
    valueFrom: "BAM SortedByCoordinate"
  - "--outSAMunmapped Within"
  - "--outSAMattributes NH HI AS NM MD"
  - prefix: --outBAMsortingThreadN
    valueFrom: $(runtime.cores)

outputs:
  aligned_bam:
    type: File
    outputBinding:
      glob: "*.Aligned.sortedByCoord.out.bam"

  transcriptome_bam:
    type: File?
    outputBinding:
      glob: "*.Aligned.toTranscriptome.out.bam"

  log_final:
    type: File
    outputBinding:
      glob: "*.Log.final.out"

  log:
    type: File
    outputBinding:
      glob: "*.Log.out"

  splice_junctions:
    type: File
    outputBinding:
      glob: "*.SJ.out.tab"
