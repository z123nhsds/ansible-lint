#!/usr/bin/env bash
set -euo pipefail

GITHUB_ACTION_PATH="${GITHUB_ACTION_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"

ANSIBLE_LINT_ARGS="${ANSIBLE_LINT_ARGS:-}"
ANSIBLE_LINT_REQUIREMENTS_FILE="${ANSIBLE_LINT_REQUIREMENTS_FILE:-}"
ANSIBLE_LINT_WORKING_DIR="${ANSIBLE_LINT_WORKING_DIR:-}"

C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'
C_NC='\033[0m'

_cleanup() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        echo -e "${C_RED}[ERROR]${C_NC} ansible-lint exited with code ${exit_code}" >&2
    fi
    exit ${exit_code}
}
trap _cleanup EXIT

_log() {
    local level="${1}"
    local msg="${2}"
    local color=""
    case "${level}" in
        INFO)  color="${C_CYAN}" ;;
        OK)    color="${C_GREEN}" ;;
        WARN)  color="${C_YELLOW}" ;;
        ERROR) color="${C_RED}" ;;
        *)     color="${C_NC}" ;;
    esac
    echo -e "${color}[${level}]${C_NC} ${msg}"
}

_resolve_working_dir() {
    local wd="${ANSIBLE_LINT_WORKING_DIR}"
    if [[ -z "${wd}" ]]; then
        wd="${GITHUB_WORKSPACE}"
    fi
    if [[ ! -d "${wd}" ]]; then
        _log ERROR "working directory does not exist: ${wd}"
        exit 1
    fi
    echo "${wd}"
}

_verify_tool() {
    local cmd="${1}"
    if ! command -v "${cmd}" &>/dev/null; then
        _log ERROR "'${cmd}' is not installed or not in PATH"
        exit 2
    fi
    _log INFO "$(${cmd} --version 2>&1 | head -1)"
}

_run_galaxy_install() {
    local reqs_file="${1}"
    local wd="${2}"
    if [[ -z "${reqs_file}" ]]; then
        return 0
    fi
    local reqs_path="${reqs_file}"
    if [[ "${reqs_file}" != /* ]]; then
        reqs_path="${wd}/${reqs_file}"
    fi
    if [[ ! -f "${reqs_path}" ]]; then
        _log ERROR "requirements file not found: ${reqs_path}"
        exit 3
    fi
    _log INFO "installing Ansible Galaxy dependencies from ${reqs_file}"
    if ! ansible-galaxy install -r "${reqs_path}" 2>&1; then
        _log ERROR "ansible-galaxy install failed"
        exit 4
    fi
    _log OK "Ansible Galaxy dependencies installed"
}

_run_lint() {
    local args="${1}"
    local wd="${2}"
    local exit_code=0

    _log INFO "running ansible-lint in ${wd}"
    cd "${wd}"

    if [[ -z "${args}" ]]; then
        ansible-lint || exit_code=$?
    else
        IFS=' ' read -ra split_args <<< "${args}"
        ansible-lint "${split_args[@]}" || exit_code=$?
    fi

    return ${exit_code}
}

main() {
    local working_dir
    working_dir="$(_resolve_working_dir)"

    _verify_tool "python3"
    _verify_tool "ansible-lint"

    _run_galaxy_install "${ANSIBLE_LINT_REQUIREMENTS_FILE}" "${working_dir}"

    _run_lint "${ANSIBLE_LINT_ARGS}" "${working_dir}"
    local lint_exit_code=$?

    if [[ ${lint_exit_code} -eq 0 ]]; then
        _log OK "ansible-lint passed"
    fi

    exit ${lint_exit_code}
}

main "$@"