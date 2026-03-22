#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Ensembl VEP - Variant Effect Predictor"
doc: |
  Annotate variants with predicted consequences, gene names, protein changes,
  allele frequencies, and clinical significance using Ensembl VEP.
  Supports offline mode with cache directory or GFF annotation.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_vep.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          VCF="$1"
          FASTA="$2"
          PREFIX="$3"
          THREADS="$4"
          CACHE_DIR="\${5:-}"
          GFF="\${6:-}"
          SPECIES="\${7:-homo_sapiens}"
          ASSEMBLY="\${8:-GRCh38}"

          # Copy FASTA to working dir so VEP can create index files
          LOCAL_FASTA="\$(basename $FASTA)"
          cp "$FASTA" "$LOCAL_FASTA"

          # Copy VCF to working dir; decompress if bgzipped
          LOCAL_VCF="\$(basename $VCF)"
          if [[ "$VCF" == *.gz ]]; then
            gunzip -c "$VCF" > "\${LOCAL_VCF%.gz}"
            LOCAL_VCF="\${LOCAL_VCF%.gz}"
          else
            cp "$VCF" "$LOCAL_VCF"
          fi

          CMD="vep -i $LOCAL_VCF --format vcf --fasta $LOCAL_FASTA -o \${PREFIX}_vep.vcf"
          CMD="$CMD --vcf --force_overwrite --no_stats --fork $THREADS"
          CMD="$CMD --symbol --biotype --canonical"

          if [ -n "$CACHE_DIR" ]; then
            CMD="$CMD --offline --dir_cache $CACHE_DIR --species $SPECIES --assembly $ASSEMBLY"
            CMD="$CMD --sift b --polyphen b --af --af_gnomade --max_af"
          elif [ -n "$GFF" ]; then
            # VEP requires bgzipped+tabix-indexed annotation
            # Detect GTF vs GFF3 by file extension
            GFF_FLAG="--gff"
            if [[ "$GFF" == *.gtf* ]]; then
              GFF_FLAG="--gtf"
            fi

            if [[ "$GFF" == *.gz ]]; then
              LOCAL_GFF="\$(basename $GFF)"
              cp "$GFF" "$LOCAL_GFF"
              # Ensure tabix index exists
              if [ ! -f "\${LOCAL_GFF}.tbi" ]; then
                tabix -p gff "$LOCAL_GFF"
              fi
            else
              grep -v "^#" "$GFF" | sort -k1,1 -k4,4n > sorted_annotation.gz_input
              bgzip -c sorted_annotation.gz_input > sorted_annotation.gz
              tabix -p gff sorted_annotation.gz
              LOCAL_GFF="sorted_annotation.gz"
            fi
            CMD="$CMD $GFF_FLAG $LOCAL_GFF"
          else
            CMD="$CMD --offline --dir /tmp"
          fi

          eval $CMD

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/ensembl-vep:115.2--pl5321h2a3209d_1"

baseCommand: [bash, run_vep.sh]

inputs:
  vcf:
    type: File
    doc: "Input VCF file"

  reference_fasta:
    type: File
    doc: "Reference genome FASTA"

  prefix:
    type: string
    doc: "Sample identifier for output naming"

  cache_dir:
    type: Directory?
    doc: "VEP cache directory (for offline annotation with full features)"

  gff:
    type: File?
    doc: "GFF3 annotation file (alternative to cache, for custom genomes)"

  species:
    type: string?
    default: homo_sapiens
    doc: "Species name (used with cache)"

  assembly:
    type: string?
    default: GRCh38
    doc: "Genome assembly version (used with cache)"

arguments:
  - position: 1
    valueFrom: $(inputs.vcf.path)
  - position: 2
    valueFrom: $(inputs.reference_fasta.path)
  - position: 3
    valueFrom: $(inputs.prefix)
  - position: 4
    valueFrom: $(runtime.cores)
  - position: 5
    valueFrom: |
      ${
        if (inputs.cache_dir) {
          return inputs.cache_dir.path;
        }
        return "";
      }
  - position: 6
    valueFrom: |
      ${
        if (inputs.gff) {
          return inputs.gff.path;
        }
        return "";
      }
  - position: 7
    valueFrom: $(inputs.species)
  - position: 8
    valueFrom: $(inputs.assembly)

outputs:
  annotated_vcf:
    type: File
    outputBinding:
      glob: "*_vep.vcf"
    doc: "VEP-annotated VCF"
