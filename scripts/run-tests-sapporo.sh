#!/bin/bash
# Run pa-cwl tests via Sapporo WES and collect RO-Run-Crate provenance
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAPPORO_URL="${SAPPORO_URL:-http://localhost:1122}"
POLL_INTERVAL=10

# 24 passing tests (workflow_dir:test_yaml)
TESTS=(
  "ampliseq:test-16s-se"
  "ampliseq:test-16s-dada2"
  "fetchngs:test-ftp-small"
  "fetchngs:test-sratools-small"
  "hic:test-mboi"
  "methylseq:test-bismark-yeast"
  "methylseq:test-bismark-rrbs-yeast"
  "nanoseq:test-nanopore"
  "nanoseq:test-nanopore-nanofilt-sniffles"
  "rnafusion:test-arriba"
  "rnaseq:test-star-salmon-yeast"
  "rnaseq:test-hisat2-salmon-yeast"
  "rnaseq:test-star-rsem-yeast"
  "rnaseq:test-star-salmon-multisample"
  "rnaseq:test-hisat2-salmon-docker-yeast"
  "sarek:test-germline-yeast"
  "sarek:test-germline-yeast-scatter"
  "sarek:test-germline-yeast-bqsr"
  "sarek:test-germline-yeast-joint"
  "sarek:test-germline-yeast-vep"
  "sarek:test-somatic-yeast"
  "raredisease:test-yeast"
  "raredisease:test-yeast-manta"
  "scrnaseq:test-starsolo-yeast"
  "viralrecon:test-amplicon"
)

log() { echo "[$(date +%H:%M:%S)] $*"; }

check_sapporo() {
  curl -fsSL "${SAPPORO_URL}/service-info" >/dev/null 2>&1 || {
    echo "ERROR: Sapporo not running at ${SAPPORO_URL}"
    exit 1
  }
  log "Sapporo is running at ${SAPPORO_URL}"
}

# Convert test YAML to JSON with absolute paths
resolve_params() {
  local workflow_dir="$1"
  local test_yaml="$2"
  python3 -c "
import yaml, json, os, sys

workflow_dir = '${workflow_dir}'
test_file = '${test_yaml}'

with open(test_file) as f:
    params = yaml.safe_load(f)

def resolve_paths(obj, base_dir):
    if isinstance(obj, dict):
        if obj.get('class') in ('File', 'Directory'):
            if 'path' in obj:
                obj['path'] = os.path.abspath(os.path.join(base_dir, obj['path']))
            if 'location' in obj:
                loc = obj['location']
                if not loc.startswith(('http://', 'https://', 'file://')):
                    obj['location'] = os.path.abspath(os.path.join(base_dir, loc))
            if 'secondaryFiles' in obj:
                for sf in obj['secondaryFiles']:
                    resolve_paths(sf, base_dir)
        for v in obj.values():
            resolve_paths(v, base_dir)
    elif isinstance(obj, list):
        for item in obj:
            resolve_paths(item, base_dir)

base = os.path.dirname(os.path.abspath(test_file))
resolve_paths(params, base)
json.dump(params, sys.stdout)
"
}

# Pack a CWL workflow
pack_workflow() {
  local main_cwl="$1"
  local packed="$2"
  cwltool --pack "$main_cwl" > "$packed" 2>/dev/null
}

# Submit a run to Sapporo
submit_run() {
  local packed_cwl="$1"
  local params_json="$2"
  curl -fsSL -X POST \
    -F "workflow_type=CWL" \
    -F "workflow_type_version=v1.2" \
    -F "workflow_engine=cwltool" \
    -F "workflow_url=file://${packed_cwl}" \
    -F "workflow_params=${params_json}" \
    "${SAPPORO_URL}/runs" | python3 -c "import sys,json; print(json.load(sys.stdin)['run_id'])"
}

# Poll until run completes
wait_for_run() {
  local run_id="$1"
  local test_name="$2"
  while true; do
    state=$(curl -fsSL "${SAPPORO_URL}/runs/${run_id}/status" | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")
    case "$state" in
      COMPLETE)
        log "  ${test_name}: COMPLETE"
        return 0
        ;;
      EXECUTOR_ERROR|SYSTEM_ERROR|CANCELED)
        log "  ${test_name}: FAILED (${state})"
        return 1
        ;;
      *)
        sleep "${POLL_INTERVAL}"
        ;;
    esac
  done
}

# Download RO-Crate metadata
fetch_ro_crate() {
  local run_id="$1"
  local output_dir="$2"
  mkdir -p "$output_dir"
  curl -fsSL "${SAPPORO_URL}/runs/${run_id}/ro-crate" | python3 -m json.tool > "${output_dir}/ro-crate-metadata.json"
}

# === Main ===
check_sapporo

RESULTS_FILE="/tmp/sapporo-test-results.txt"
> "$RESULTS_FILE"

for test_spec in "${TESTS[@]}"; do
  IFS=: read -r workflow test_name <<< "$test_spec"
  workflow_dir="${REPO_ROOT}/workflows/${workflow}"
  test_yaml="${workflow_dir}/tests/${test_name}.yaml"
  main_cwl="${workflow_dir}/main.cwl"
  ro_crate_dir="${workflow_dir}/tests/ro-crate"

  if [ ! -f "$test_yaml" ]; then
    log "SKIP ${workflow}/${test_name}: test YAML not found"
    echo "SKIP ${workflow}/${test_name}" >> "$RESULTS_FILE"
    continue
  fi

  log "Submitting ${workflow}/${test_name}..."

  # Pack workflow
  packed="/tmp/${workflow}-packed.cwl"
  if ! pack_workflow "$main_cwl" "$packed"; then
    log "  ERROR: Failed to pack ${workflow}/main.cwl"
    echo "PACK_ERROR ${workflow}/${test_name}" >> "$RESULTS_FILE"
    continue
  fi

  # Resolve params
  params_json=$(resolve_params "$workflow_dir" "$test_yaml")

  # Submit
  run_id=$(submit_run "$packed" "$params_json") || {
    log "  ERROR: Failed to submit ${workflow}/${test_name}"
    echo "SUBMIT_ERROR ${workflow}/${test_name}" >> "$RESULTS_FILE"
    continue
  }
  log "  Run ID: ${run_id}"

  # Store run_id for later polling
  echo "${run_id} ${workflow} ${test_name}" >> /tmp/sapporo-pending-runs.txt
done

log ""
log "All tests submitted. Polling for completion..."
log ""

# Poll all runs
while IFS=' ' read -r run_id workflow test_name; do
  if wait_for_run "$run_id" "${workflow}/${test_name}"; then
    # Fetch RO-Crate
    ro_crate_dir="${REPO_ROOT}/workflows/${workflow}/tests/ro-crate"
    # Use test_name as subdirectory if multiple tests per workflow
    test_count=$(grep -c "^${workflow}:" <<< "$(printf '%s\n' "${TESTS[@]}")" || true)
    if [ "$test_count" -gt 1 ]; then
      output_dir="${ro_crate_dir}/${test_name}"
    else
      output_dir="${ro_crate_dir}"
    fi
    fetch_ro_crate "$run_id" "$output_dir"
    log "  RO-Crate saved to ${output_dir}/ro-crate-metadata.json"
    echo "PASS ${workflow}/${test_name} ${run_id}" >> "$RESULTS_FILE"
  else
    echo "FAIL ${workflow}/${test_name} ${run_id}" >> "$RESULTS_FILE"
  fi
done < /tmp/sapporo-pending-runs.txt

log ""
log "=== Results ==="
cat "$RESULTS_FILE"
rm -f /tmp/sapporo-pending-runs.txt
