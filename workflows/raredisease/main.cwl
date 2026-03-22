#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "raredisease - Rare disease variant calling and annotation pipeline"
doc: |
  Germline variant calling with GATK HaplotypeCaller and functional annotation
  with Ensembl VEP. Extends the sarek germline pipeline with clinical-grade
  variant annotation for rare disease analysis.

  Optional features: DeepVariant calling, joint calling (GenomicsDBImport +
  GenotypeGVCFs), structural variant calling (Manta), CADD score annotation,
  GENMOD pedigree-aware ranking, and ExpansionHunter repeat expansion detection.

  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  # === Samples ===
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files (one per sample)"

  fastq_rev:
    type: File[]
    doc: "Reverse read FASTQ files (one per sample)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  # === Reference genome ===
  genome_fasta:
    type: File
    doc: "Reference genome FASTA"

  # === Pre-built BWA index (optional) ===
  bwa_index:
    type: File?
    secondaryFiles:
      - pattern: ".0123"
      - pattern: .amb
      - pattern: .ann
      - pattern: .bwt.2bit.64
      - pattern: .pac
    doc: "Pre-built BWA-MEM2 indexed genome FASTA"

  # === Variant calling options ===
  dbsnp:
    type: File?
    secondaryFiles:
      - .tbi
    doc: "dbSNP VCF for HaplotypeCaller annotation"

  intervals:
    type: File?
    doc: "Intervals BED file for WES/targeted sequencing"

  # === VEP annotation ===
  vep_cache_dir:
    type: Directory?
    doc: "VEP cache directory (for full annotation with SIFT, PolyPhen, gnomAD)"

  vep_gff:
    type: File?
    doc: "GFF3 annotation file (alternative to VEP cache)"

  vep_species:
    type: string?
    default: homo_sapiens
    doc: "Species for VEP annotation"

  vep_assembly:
    type: string?
    default: GRCh38
    doc: "Genome assembly for VEP annotation"

  # === DeepVariant ===
  run_deepvariant:
    type: boolean?
    default: false
    doc: "Run DeepVariant as alternative SNV/indel caller"

  deepvariant_model_type:
    type: string?
    default: "WGS"
    doc: "DeepVariant model type: WGS, WES, or PACBIO"

  # === Joint calling ===
  cohort_id:
    type: string?
    doc: "Cohort identifier for joint calling output"

  emit_gvcf:
    type: boolean?
    default: false
    doc: "Enable joint calling via GenomicsDBImport + GenotypeGVCFs"

  # === Manta SV calling ===
  run_manta:
    type: boolean?
    default: false
    doc: "Run Manta structural variant caller"

  # === CADD annotation ===
  cadd_db:
    type: File?
    secondaryFiles:
      - .tbi
    doc: "CADD pre-computed scores TSV.GZ with tabix index"

  # === GENMOD ranking ===
  family_file:
    type: File?
    doc: "PED format pedigree file for GENMOD ranking"

  # === ExpansionHunter ===
  variant_catalog:
    type: File?
    doc: "ExpansionHunter variant catalog JSON for repeat expansion detection"

steps:
  # =====================
  # Reference preparation (faidx + dict)
  # =====================
  prepare_reference:
    run: ../../tools/prepare-gatk-reference.cwl
    in:
      genome_fasta: genome_fasta
    out: [reference]

  # =====================
  # BWA-MEM2 index building (conditional)
  # =====================
  build_bwa_index:
    run: ../../tools/bwa-mem2-index.cwl
    when: $(inputs.bwa_index == null)
    in:
      genome_fasta: genome_fasta
      bwa_index: bwa_index
    out: [genome_with_index]

  # =====================
  # QC + Trimming (per sample)
  # =====================
  qc_trim:
    run: ../sarek/steps/qc-trim.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_ids
      trimmer:
        default: fastp
    out: [trimmed_fwd, trimmed_rev, fastqc_raw_zip, fastp_json]

  # =====================
  # Alignment + sort + markdup (per sample)
  # =====================
  align:
    run: ../sarek/steps/align-bwa.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: qc_trim/trimmed_fwd
      fastq_rev: qc_trim/trimmed_rev
      sample_id: sample_ids
      genome_fasta:
        source:
          - bwa_index
          - build_bwa_index/genome_with_index
        pickValue: first_non_null
    out: [aligned_bam, markdup_metrics]

  # =====================
  # Alignment QC
  # =====================
  samtools_stats:
    run: ../../tools/samtools-stats.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: align/aligned_bam
      sample_id: sample_ids
    out: [stats]

  # =====================
  # GATK HaplotypeCaller
  # =====================
  haplotypecaller:
    run: ../../tools/gatk4-haplotypecaller.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: align/aligned_bam
      reference: prepare_reference/reference
      dbsnp: dbsnp
      intervals: intervals
      sample_id: sample_ids
      emit_gvcf: emit_gvcf
    out: [vcf]

  # =====================
  # Hard filtering
  # =====================
  variant_filtration:
    run: ../../tools/gatk4-variantfiltration.cwl
    scatter: [vcf, sample_id]
    scatterMethod: dotproduct
    in:
      vcf: haplotypecaller/vcf
      reference: prepare_reference/reference
      sample_id: sample_ids
    out: [filtered_vcf]

  # =====================
  # VEP annotation (HaplotypeCaller VCFs)
  # =====================
  vep:
    run: ../../tools/ensembl-vep.cwl
    scatter: [vcf, prefix]
    scatterMethod: dotproduct
    in:
      vcf: variant_filtration/filtered_vcf
      reference_fasta: genome_fasta
      prefix: sample_ids
      cache_dir: vep_cache_dir
      gff: vep_gff
      species: vep_species
      assembly: vep_assembly
    out: [annotated_vcf]

  # =====================
  # DeepVariant (conditional, per sample)
  # =====================
  deepvariant:
    run: ../../tools/deepvariant.cwl
    when: $(inputs.run_deepvariant === true)
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: align/aligned_bam
      reference: prepare_reference/reference
      sample_id: sample_ids
      model_type: deepvariant_model_type
      run_deepvariant: run_deepvariant
    out: [vcf, gvcf]

  # =====================
  # VEP annotation for DeepVariant VCFs (conditional)
  # =====================
  vep_deepvariant:
    run: ../../tools/ensembl-vep.cwl
    when: $(inputs.run_deepvariant === true)
    scatter: [vcf, prefix]
    scatterMethod: dotproduct
    in:
      vcf: deepvariant/vcf
      reference_fasta: genome_fasta
      prefix:
        source: sample_ids
        valueFrom: $(self + ".deepvariant")
      cache_dir: vep_cache_dir
      gff: vep_gff
      species: vep_species
      assembly: vep_assembly
      run_deepvariant: run_deepvariant
    out: [annotated_vcf]

  # =====================
  # Joint calling (conditional on emit_gvcf)
  # =====================
  joint_calling:
    run: steps/joint-calling.cwl
    when: $(inputs.emit_gvcf === true)
    in:
      gvcfs: haplotypecaller/vcf
      reference: prepare_reference/reference
      dbsnp: dbsnp
      intervals: intervals
      cohort_id:
        source: cohort_id
        default: "cohort"
      emit_gvcf: emit_gvcf
    out: [joint_vcf]

  # =====================
  # Manta SV calling (conditional, per sample)
  # =====================
  manta:
    run: ../../tools/manta.cwl
    when: $(inputs.run_manta === true)
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: align/aligned_bam
      reference: prepare_reference/reference
      sample_id: sample_ids
      run_manta: run_manta
    out: [diploid_sv_vcf, candidate_sv_vcf, candidate_small_indels_vcf]

  # =====================
  # CADD score annotation (conditional, per sample)
  # =====================
  cadd_annotate:
    run: ../../tools/bcftools-annotate-cadd.cwl
    when: $(inputs.cadd_db != null)
    scatter: [vcf, sample_id]
    scatterMethod: dotproduct
    in:
      vcf: vep/annotated_vcf
      cadd_db: cadd_db
      sample_id: sample_ids
    out: [annotated_vcf]

  # =====================
  # GENMOD ranking (conditional, per sample)
  # =====================
  genmod:
    run: ../../tools/genmod.cwl
    when: $(inputs.family_file != null)
    scatter: [vcf, sample_id]
    scatterMethod: dotproduct
    in:
      vcf: vep/annotated_vcf
      family_file: family_file
      sample_id: sample_ids
    out: [ranked_vcf]

  # =====================
  # ExpansionHunter (conditional, per sample)
  # =====================
  expansionhunter:
    run: ../../tools/expansionhunter.cwl
    when: $(inputs.variant_catalog != null)
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: align/aligned_bam
      reference: prepare_reference/reference
      variant_catalog: variant_catalog
      sample_id: sample_ids
    out: [vcf, json_results]

  # =====================
  # VCF QC
  # =====================
  bcftools_stats:
    run: ../../tools/bcftools-stats.cwl
    scatter: [vcf, sample_id]
    scatterMethod: dotproduct
    in:
      vcf: variant_filtration/filtered_vcf
      sample_id: sample_ids
    out: [stats]

  # =====================
  # MultiQC reporting
  # =====================
  multiqc:
    run: ../../tools/multiqc.cwl
    in:
      report_files:
        source:
          - qc_trim/fastqc_raw_zip
          - qc_trim/fastp_json
          - align/markdup_metrics
          - samtools_stats/stats
          - bcftools_stats/stats
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl raredisease"
    out: [html_report, data_dir]

outputs:
  annotated_vcfs:
    type: File[]
    outputSource: vep/annotated_vcf
    doc: "VEP-annotated VCF files per sample"

  filtered_vcfs:
    type: File[]
    outputSource: variant_filtration/filtered_vcf
    doc: "Filtered VCF files per sample (before VEP)"

  aligned_bams:
    type: File[]
    outputSource: align/aligned_bam
    doc: "Marked-duplicate BAM files per sample"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"

  # === DeepVariant outputs ===
  deepvariant_vcfs:
    type: File[]?
    outputSource: deepvariant/vcf
    doc: "DeepVariant variant calls per sample"

  deepvariant_gvcfs:
    type: File[]?
    outputSource: deepvariant/gvcf
    doc: "DeepVariant gVCFs per sample"

  deepvariant_annotated_vcfs:
    type: File[]?
    outputSource: vep_deepvariant/annotated_vcf
    doc: "VEP-annotated DeepVariant VCFs per sample"

  # === Joint calling output ===
  joint_called_vcf:
    type: File?
    outputSource: joint_calling/joint_vcf
    doc: "Joint-called multi-sample VCF"

  # === Manta outputs ===
  manta_diploid_sv_vcfs:
    type: File[]?
    outputSource: manta/diploid_sv_vcf
    doc: "Manta diploid structural variant calls per sample"

  manta_candidate_sv_vcfs:
    type: File[]?
    outputSource: manta/candidate_sv_vcf
    doc: "Manta candidate structural variant calls per sample"

  manta_candidate_small_indels_vcfs:
    type: File[]?
    outputSource: manta/candidate_small_indels_vcf
    doc: "Manta candidate small indel calls per sample"

  # === CADD output ===
  cadd_annotated_vcfs:
    type: File[]?
    outputSource: cadd_annotate/annotated_vcf
    doc: "VCFs annotated with CADD scores per sample"

  # === GENMOD output ===
  genmod_ranked_vcfs:
    type: File[]?
    outputSource: genmod/ranked_vcf
    doc: "GENMOD ranked VCFs with inheritance models per sample"

  # === ExpansionHunter outputs ===
  expansionhunter_vcfs:
    type: File[]?
    outputSource: expansionhunter/vcf
    doc: "ExpansionHunter repeat expansion VCFs per sample"

  expansionhunter_json:
    type: File[]?
    outputSource: expansionhunter/json_results
    doc: "ExpansionHunter detailed results in JSON format per sample"
