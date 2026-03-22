#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "FusionInspector subworkflow"
doc: |
  Subworkflow for FusionInspector fusion validation. Scatters
  over samples, validating fusion predictions against RNA-seq reads.

requirements:
  ScatterFeatureRequirement: {}

inputs:
  fusions_files:
    type: File[]
    doc: "Fusion prediction TSV files (one per sample)"
  ctat_lib:
    type: Directory
    doc: "CTAT genome library directory"
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files (one per sample)"
  fastq_rev:
    type: File[]
    doc: "Reverse read FASTQ files (one per sample)"
  sample_ids:
    type: string[]
    doc: "Sample identifiers"
  run_fusion_inspector:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

steps:
  fusion_inspector:
    run: ../../../tools/fusion-inspector.cwl
    scatter: [fusions_file, fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fusions_file: fusions_files
      ctat_lib: ctat_lib
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_ids
    out: [validated_fusions, evidence_bam]

outputs:
  validated_fusions:
    type: File[]
    outputSource: fusion_inspector/validated_fusions
  evidence_bams:
    type: File[]
    outputSource: fusion_inspector/evidence_bam
