#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Download FASTQ via aria2c"
doc: |
  Fast FASTQ download using aria2c with multi-connection parallel transfers.
  Supports three mirrors (DDBJ, ENA, NCBI) and picks URLs based on the
  preferred_source from latency testing. Falls back to ENA FTP URLs if the
  preferred source doesn't have the data.

  aria2c downloads with 8 connections per file (-x 8 -s 8) for much faster
  throughput compared to single-connection FTP.

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 2048
  NetworkAccess:
    networkAccess: true
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: download_aria2.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          METADATA_JSON="$1"
          PREFERRED_SOURCE="$2"
          if [ -z "$PREFERRED_SOURCE" ]; then PREFERRED_SOURCE="ena"; fi
          OUTDIR="\$(pwd)"
          FAILED=0

          echo "Preferred mirror: $PREFERRED_SOURCE"

          # Simple JSON field extractor using grep/sed (no jq/python needed)
          extract_field() {
            local json="$1" field="$2"
            echo "$json" | grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:.*"\(.*\)"/\1/'
          }

          # Convert ENA FTP URL to DDBJ HTTPS URL
          ena_to_ddbj() {
            local ena_url="$1"
            local filename accession sra_prefix
            filename=\$(basename "$ena_url")
            accession=\$(echo "$ena_url" | grep -oE '[SED]RR[0-9]+' | tail -1)
            if [ -z "$accession" ]; then
              return 1
            fi
            # DDBJ DRA only mirrors DRR accessions; SRR/ERR are not available
            case "$accession" in
              DRR*) ;;
              *) return 1 ;;
            esac
            sra_prefix=\$(echo "$accession" | cut -c1-6)
            echo "https://ddbj.nig.ac.jp/public/ddbj_database/dra/fastq/$sra_prefix/$accession/$filename"
          }

          # Build download URL based on preferred source
          build_url() {
            local ena_url="$1"
            if [ "$PREFERRED_SOURCE" = "ddbj" ]; then
              local ddbj_url
              ddbj_url=\$(ena_to_ddbj "$ena_url" 2>/dev/null) && echo "$ddbj_url" && return 0
            fi
            # Default: use ENA FTP
            case "$ena_url" in
              ftp://*|http://*|https://*) echo "$ena_url" ;;
              *) echo "ftp://$ena_url" ;;
            esac
          }

          # Download a single file with aria2c (8 parallel connections)
          download_one() {
            local url="$1"
            local md5="$2"
            local filename
            filename=\$(basename "$url")
            local checksum_arg=""
            if [ -n "$md5" ]; then
              checksum_arg="--checksum=md5=$md5"
            fi
            echo "Downloading: $url"
            echo "  aria2c -x 8 -s 8 -> $filename"
            if aria2c -x 8 -s 8 -d "$OUTDIR" -o "$filename" \
                --console-log-level=warn --file-allocation=none \
                --auto-file-renaming=false --allow-overwrite=true \
                $checksum_arg "$url"; then
              local size
              size=\$(du -h "$OUTDIR/$filename" | cut -f1)
              echo "  Downloaded: $filename ($size)"
              return 0
            fi
            return 1
          }

          # Download with fallback to ENA
          download_with_fallback() {
            local ena_url="$1"
            local md5="$2"
            local url
            url=\$(build_url "$ena_url")
            if download_one "$url" "$md5"; then
              return 0
            fi
            if [ "$PREFERRED_SOURCE" != "ena" ]; then
              local fallback_url="$ena_url"
              case "$fallback_url" in
                ftp://*|http://*|https://*) ;;
                *) fallback_url="ftp://$fallback_url" ;;
              esac
              echo "  Retrying with ENA FTP: $fallback_url"
              if download_one "$fallback_url" "$md5"; then
                return 0
              fi
            fi
            echo "  ERROR: All download attempts failed for $ena_url" >&2
            return 1
          }

          # Flatten JSON array to one object per line (handle pretty-printed JSON)
          RECORDS=\$(cat "$METADATA_JSON" | tr -d '\n' | sed 's/}[[:space:]]*,[[:space:]]*{/}\n{/g' | sed 's/^[[:space:]]*\[//;s/\][[:space:]]*$//')

          TOTAL=\$(echo "$RECORDS" | grep -c '{' || true)
          echo "Records to download: $TOTAL"
          echo

          while IFS= read -r record; do
            [ -z "$record" ] && continue
            accession=\$(extract_field "$record" "run_accession")
            fastq_ftp=\$(extract_field "$record" "fastq_ftp")
            fastq_md5=\$(extract_field "$record" "fastq_md5")

            if [ -z "$fastq_ftp" ]; then
              echo "No FTP URLs for $accession, skipping" >&2
              continue
            fi

            # Process semicolon-delimited URLs using tr + while read
            idx=1
            echo "$fastq_ftp" | tr ';' '\n' | while IFS= read -r url; do
              [ -z "$url" ] && continue
              md5=\$(echo "$fastq_md5" | cut -d';' -f"$idx")
              download_with_fallback "$url" "$md5" || FAILED=\$((FAILED + 1))
              idx=\$((idx + 1))
            done
            echo "Completed: $accession"
            echo
          done <<< "$RECORDS"

          echo "All downloads complete"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/aria2:1.36.0"

baseCommand: [bash, download_aria2.sh]

inputs:
  metadata_json:
    type: File
    inputBinding:
      position: 1
    doc: "JSON metadata from fetch-ena-metadata"

  preferred_source:
    type: string
    default: "ena"
    inputBinding:
      position: 2
    doc: "Preferred mirror: ddbj, ena, or ncbi"

outputs:
  fastq_files:
    type: File[]
    outputBinding:
      glob: "*.fastq.gz"
    doc: "Downloaded FASTQ files"
