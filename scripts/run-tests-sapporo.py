#!/usr/bin/env python3
"""Run pa-cwl tests via Sapporo WES and collect RO-Run-Crate provenance."""

import json
import os
import subprocess
import sys
import time
import urllib.request
import yaml

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAPPORO_URL = os.environ.get("SAPPORO_URL", "http://localhost:1122")
POLL_INTERVAL = 10
PACK_DIR = "/tmp/pa-cwl-packed"

# 24 passing tests + 1 already verified
TESTS = [
    ("ampliseq", "test-16s-se"),
    ("ampliseq", "test-16s-dada2"),
    ("fetchngs", "test-ftp-small"),
    ("fetchngs", "test-sratools-small"),
    ("hic", "test-mboi"),
    ("methylseq", "test-bismark-yeast"),
    ("methylseq", "test-bismark-rrbs-yeast"),
    ("nanoseq", "test-nanopore"),
    ("nanoseq", "test-nanopore-nanofilt-sniffles"),
    ("rnafusion", "test-arriba"),
    ("rnaseq", "test-star-salmon-yeast"),
    ("rnaseq", "test-hisat2-salmon-yeast"),
    ("rnaseq", "test-star-rsem-yeast"),
    ("rnaseq", "test-star-salmon-multisample"),
    ("rnaseq", "test-hisat2-salmon-docker-yeast"),
    ("sarek", "test-germline-yeast"),
    ("sarek", "test-germline-yeast-scatter"),
    ("sarek", "test-germline-yeast-bqsr"),
    ("sarek", "test-germline-yeast-joint"),
    ("sarek", "test-germline-yeast-vep"),
    ("sarek", "test-somatic-yeast"),
    ("raredisease", "test-yeast"),
    ("raredisease", "test-yeast-manta"),
    ("scrnaseq", "test-starsolo-yeast"),
    ("viralrecon", "test-amplicon"),
]


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def sapporo_get(path):
    url = f"{SAPPORO_URL}{path}"
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def sapporo_post_run(packed_cwl, params_json):
    """Submit a run via multipart form POST."""
    import http.client
    import uuid
    from urllib.parse import urlparse

    parsed = urlparse(SAPPORO_URL)
    boundary = uuid.uuid4().hex

    fields = {
        "workflow_type": "CWL",
        "workflow_type_version": "v1.2",
        "workflow_engine": "cwltool",
        "workflow_url": f"file://{packed_cwl}",
        "workflow_params": params_json,
    }

    body = b""
    for key, value in fields.items():
        body += f"--{boundary}\r\n".encode()
        body += f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode()
        body += f"{value}\r\n".encode()
    body += f"--{boundary}--\r\n".encode()

    conn = http.client.HTTPConnection(parsed.hostname, parsed.port)
    headers = {"Content-Type": f"multipart/form-data; boundary={boundary}"}
    conn.request("POST", "/runs", body, headers)
    resp = conn.getresponse()
    data = json.loads(resp.read())
    conn.close()
    return data["run_id"]


def pack_workflow(workflow):
    """Pack a CWL workflow, caching the result."""
    os.makedirs(PACK_DIR, exist_ok=True)
    packed = os.path.join(PACK_DIR, f"{workflow}-packed.cwl")
    if os.path.exists(packed):
        return packed
    main_cwl = os.path.join(REPO_ROOT, "workflows", workflow, "main.cwl")
    result = subprocess.run(
        ["cwltool", "--pack", main_cwl],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        log(f"  ERROR packing {workflow}: {result.stderr[:200]}")
        return None
    with open(packed, "w") as f:
        f.write(result.stdout)
    return packed


def resolve_params(workflow, test_name):
    """Load test YAML, resolve relative paths to absolute."""
    test_yaml = os.path.join(REPO_ROOT, "workflows", workflow, "tests", f"{test_name}.yaml")
    if not os.path.exists(test_yaml):
        return None
    with open(test_yaml) as f:
        params = yaml.safe_load(f)
    base_dir = os.path.dirname(os.path.abspath(test_yaml))
    _resolve_paths(params, base_dir)
    return json.dumps(params)


def _resolve_paths(obj, base_dir):
    if isinstance(obj, dict):
        if obj.get("class") in ("File", "Directory"):
            if "path" in obj:
                obj["path"] = os.path.abspath(os.path.join(base_dir, obj["path"]))
            if "location" in obj and not obj["location"].startswith(("http://", "https://", "file://")):
                obj["location"] = os.path.abspath(os.path.join(base_dir, obj["location"]))
        for v in obj.values():
            _resolve_paths(v, base_dir)
    elif isinstance(obj, list):
        for item in obj:
            _resolve_paths(item, base_dir)


def wait_for_run(run_id, label, timeout=1800):
    """Poll until run completes or times out."""
    start = time.time()
    while time.time() - start < timeout:
        try:
            runs = sapporo_get("/runs")
            for r in runs["runs"]:
                if r["run_id"] == run_id:
                    state = r["state"]
                    if state == "COMPLETE":
                        return "COMPLETE"
                    elif state in ("EXECUTOR_ERROR", "SYSTEM_ERROR", "CANCELED"):
                        return state
                    break
        except Exception:
            pass
        time.sleep(POLL_INTERVAL)
    return "TIMEOUT"


def fetch_ro_crate(run_id, retries=3):
    """Get RO-Crate metadata JSON from Sapporo."""
    for i in range(retries):
        try:
            return sapporo_get(f"/runs/{run_id}/ro-crate")
        except Exception:
            if i < retries - 1:
                time.sleep(5)
            else:
                raise


def ro_crate_output_dir(workflow, test_name):
    """Determine where to save the RO-Crate."""
    # Count how many tests this workflow has
    test_count = sum(1 for w, _ in TESTS if w == workflow)
    base = os.path.join(REPO_ROOT, "workflows", workflow, "tests", "ro-crate")
    if test_count > 1:
        return os.path.join(base, test_name)
    return base


def main():
    # Check Sapporo is running
    try:
        info = sapporo_get("/service-info")
        log(f"Sapporo {info['version']} running at {SAPPORO_URL}")
    except Exception as e:
        log(f"ERROR: Cannot connect to Sapporo at {SAPPORO_URL}: {e}")
        sys.exit(1)

    # Phase 1: Pack workflows (deduplicate)
    log("Packing workflows...")
    packed_cache = {}
    for workflow, test_name in TESTS:
        if workflow not in packed_cache:
            packed = pack_workflow(workflow)
            packed_cache[workflow] = packed
            if packed:
                log(f"  Packed {workflow}")

    # Phase 2: Submit, wait, collect — one at a time
    log("")
    log(f"Running {len(TESTS)} tests sequentially...")
    results = []

    for i, (workflow, test_name) in enumerate(TESTS, 1):
        label = f"{workflow}/{test_name}"
        packed = packed_cache.get(workflow)
        if not packed:
            log(f"[{i}/{len(TESTS)}] SKIP {label}: pack failed")
            continue

        params = resolve_params(workflow, test_name)
        if not params:
            log(f"[{i}/{len(TESTS)}] SKIP {label}: test YAML not found")
            continue

        try:
            run_id = sapporo_post_run(packed, params)
            log(f"[{i}/{len(TESTS)}] {label} -> {run_id[:8]}")
        except Exception as e:
            log(f"[{i}/{len(TESTS)}] ERROR submitting {label}: {e}")
            results.append(("SUBMIT_ERROR", label, ""))
            continue

        state = wait_for_run(run_id, label)

        if state == "COMPLETE":
            try:
                ro_crate = fetch_ro_crate(run_id)
                out_dir = ro_crate_output_dir(workflow, test_name)
                os.makedirs(out_dir, exist_ok=True)
                out_file = os.path.join(out_dir, "ro-crate-metadata.json")
                with open(out_file, "w") as f:
                    json.dump(ro_crate, f, indent=2)
                log(f"  PASS — RO-Crate -> {os.path.relpath(out_file, REPO_ROOT)}")
                results.append(("PASS", label, run_id))
            except Exception as e:
                log(f"  RO_ERROR: {e}")
                results.append(("RO_ERROR", label, run_id))
        else:
            log(f"  {state}")
            results.append(("FAIL", label, run_id))

    # Summary
    log("")
    log("=== Results ===")
    pass_count = sum(1 for r in results if r[0] == "PASS")
    fail_count = sum(1 for r in results if r[0] != "PASS")
    log(f"PASS: {pass_count}  FAIL: {fail_count}")
    for status, label, run_id in results:
        if status != "PASS":
            log(f"  {status}: {label} ({run_id[:8]})")


if __name__ == "__main__":
    main()
