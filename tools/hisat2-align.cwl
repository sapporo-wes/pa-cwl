#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "HISAT2 - Spliced-aware aligner"
doc: "Align RNA-seq reads using HISAT2 with lower memory footprint"

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing: |
      ${
        return inputs.index_files.map(function(f) {
          return {"entry": f, "entryname": f.basename, "writable": true};
        });
      }

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/hisat2:2.2.1--h87f3376_4"

baseCommand: [hisat2]

stdout: $(inputs.sample_id).sam

inputs:
  index_files:
    type: File[]
    doc: "HISAT2 index files"

  index_basename:
    type: string?
    default: "hisat2_index"
    doc: "Basename used when building the index"

  fastq_fwd:
    type: File
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File?
    doc: "Reverse read FASTQ"

  sample_id:
    type: string
    doc: "Sample identifier"

  strandedness:
    type:
      type: enum
      symbols: [unstranded, forward, reverse]
    default: unstranded
    doc: "Library strandedness"

arguments:
  - prefix: -p
    valueFrom: $(runtime.cores)
  - prefix: -x
    valueFrom: $(inputs.index_basename)
  - valueFrom: |
      ${
        if (inputs.fastq_rev) {
          return ["-1", inputs.fastq_fwd.path, "-2", inputs.fastq_rev.path];
        }
        return ["-U", inputs.fastq_fwd.path];
      }
  - valueFrom: |
      ${
        if (inputs.strandedness == "forward") return "--rna-strandness FR";
        if (inputs.strandedness == "reverse") return "--rna-strandness RF";
        return "";
      }
    shellQuote: false
  - --new-summary
  - prefix: --summary-file
    valueFrom: $(inputs.sample_id).hisat2.summary.log
  - prefix: --rg-id
    valueFrom: $(inputs.sample_id)
  - prefix: --rg
    valueFrom: $("SM:" + inputs.sample_id)

outputs:
  aligned_sam:
    type: File
    outputBinding:
      glob: "$(inputs.sample_id).sam"

  summary_log:
    type: File
    outputBinding:
      glob: "*.hisat2.summary.log"
