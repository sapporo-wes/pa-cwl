#!/bin/bash
# Custom Sapporo run.sh for pa-cwl
# Uses local cwltool instead of Docker-wrapped cwltool
# Compatible with macOS /bin/bash 3.2 (no nameref/local -n)

set -euo pipefail

# Main function
function run_wf() {
    check_canceling
    echo "RUNNING" >"${state}"

    if [[ "${wf_engine}" == "cwltool" ]]; then
        run_cwltool
        generate_outputs_list
    else
        executor_error 1
    fi

    upload
    date -u +"%Y-%m-%dT%H:%M:%S" >"${end_time}"
    echo 0 >"${exit_code}"
    generate_ro_crate
    echo "COMPLETE" >"${state}"
    exit 0
}

# Run cwltool directly on host (not in Docker)
function run_cwltool() {
    local cmd_str="cwltool --outdir ${outputs_dir}"
    if [[ -n "${wf_engine_params}" ]]; then
        cmd_str="${cmd_str} ${wf_engine_params}"
    fi
    cmd_str="${cmd_str} ${wf_url} ${wf_params}"
    echo "${cmd_str}" >"${cmd}"
    eval "${cmd_str}" 1>"${stdout}" 2>"${stderr}" || { executor_error $?; }
}

function cancel() {
    cancel_by_request
}

function upload() {
    :
}

# ==============================================================
run_dir=$1

run_request="${run_dir}/run_request.json"
state="${run_dir}/state.txt"
exe_dir="${run_dir}/exe"
outputs_dir="${run_dir}/outputs"
outputs="${run_dir}/outputs.json"
wf_params="${run_dir}/exe/workflow_params.json"
start_time="${run_dir}/start_time.txt"
end_time="${run_dir}/end_time.txt"
exit_code="${run_dir}/exit_code.txt"
stdout="${run_dir}/stdout.log"
stderr="${run_dir}/stderr.log"
wf_engine_params_file="${run_dir}/workflow_engine_params.txt"
cmd="${run_dir}/cmd.txt"
system_logs="${run_dir}/system_logs.json"
ro_crate="${run_dir}/ro-crate-metadata.json"

wf_engine=$(jq -r ".workflow_engine" "${run_request}")
wf_url=$(jq -r ".workflow_url" "${run_request}")
wf_engine_params=$(head -n 1 "${wf_engine_params_file}")

function generate_outputs_list() {
    sapporo-cli dump-outputs "${run_dir}" || { executor_error $?; }
}

function generate_ro_crate() {
    sapporo-cli generate-ro-crate "${run_dir}" 2>>"${stderr}" \
        || echo '{"@error": "RO-Crate generation failed. Check stderr.log for details."}' >"${ro_crate}"
}

function desc_error() {
    echo "1" >"${exit_code}"
    date -u +"%Y-%m-%dT%H:%M:%S" >"${end_time}"
    echo "SYSTEM_ERROR" >"${state}"
    exit 1
}

function executor_error() {
    local ec=${1:-1}
    echo "${ec}" >"${exit_code}"
    date -u +"%Y-%m-%dT%H:%M:%S" >"${end_time}"
    echo "EXECUTOR_ERROR" >"${state}"
    generate_ro_crate
    exit "${ec}"
}

function kill_by_system() {
    local signal=$1
    local ec
    case "${signal}" in
    "SIGHUP") ec=129 ;;
    "SIGINT") ec=130 ;;
    "SIGQUIT") ec=131 ;;
    "SIGTERM") ec=143 ;;
    *) ec=1 ;;
    esac
    echo "${ec}" >"${exit_code}"
    date -u +"%Y-%m-%dT%H:%M:%S" >"${end_time}"
    echo "SYSTEM_ERROR" >"${state}"
    exit "${ec}"
}

function cancel_by_request() {
    echo "138" >"${exit_code}"
    date -u +"%Y-%m-%dT%H:%M:%S" >"${end_time}"
    echo "CANCELED" >"${state}"
    exit 138
}

function check_canceling() {
    local state_content
    state_content=$(cat "${state}")
    if [[ "${state_content}" == "CANCELING" ]]; then
        cancel
    fi
}

trap 'desc_error' ERR
trap 'kill_by_system SIGHUP' HUP
trap 'kill_by_system SIGINT' INT
trap 'kill_by_system SIGQUIT' QUIT
trap 'kill_by_system SIGTERM' TERM
trap 'cancel' USR1

run_wf &
bg_pid=$!
wait $bg_pid || true
