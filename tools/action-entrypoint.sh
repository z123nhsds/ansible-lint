#!/usr/bin/env bash
set -euo pipefail

error() {
  echo "::error::$*" >&2
  exit 1
}

handle_error() {
  local exit_code=$?
  local line_no=$1
  echo "::error::ansible-lint composite action failed at line ${line_no} with exit code ${exit_code}" >&2
  exit "${exit_code}"
}

resolve_directory() {
  local raw_path=$1

  if [[ -z "${raw_path}" ]]; then
    printf '%s\n' "${GITHUB_WORKSPACE}"
    return
  fi

  if [[ "${raw_path}" = /* ]]; then
    printf '%s\n' "${raw_path}"
    return
  fi

  printf '%s/%s\n' "${GITHUB_WORKSPACE}" "${raw_path}"
}

resolve_file() {
  local base_dir=$1
  local raw_path=$2

  if [[ -z "${raw_path}" ]]; then
    printf '%s\n' ""
    return
  fi

  if [[ "${raw_path}" = /* ]]; then
    printf '%s\n' "${raw_path}"
    return
  fi

  printf '%s/%s\n' "${base_dir}" "${raw_path}"
}

trap 'handle_error ${LINENO}' ERR

python_bin=$(command -v python || true)
if [[ -z "${python_bin}" ]]; then
  python_bin=$(command -v python3 || true)
fi
if [[ -z "${python_bin}" ]]; then
  error "Python was not found on PATH after setup."
fi

working_directory=$(resolve_directory "${INPUT_WORKING_DIRECTORY:-}")
if [[ ! -d "${working_directory}" ]]; then
  error "Working directory does not exist: ${working_directory}"
fi
working_directory=$(cd "${working_directory}" && pwd)

requirements_file=$(resolve_file "${working_directory}" "${INPUT_REQUIREMENTS_FILE:-}")
if [[ -n "${requirements_file}" && ! -f "${requirements_file}" ]]; then
  error "Requirements file does not exist: ${requirements_file}"
fi

export PIP_ROOT_USER_ACTION=ignore

"${python_bin}" -m pip install --disable-pip-version-check --upgrade pip setuptools wheel
"${python_bin}" -m pip install --disable-pip-version-check --upgrade "git+https://github.com/ansible/ansible-lint@main"

if ! command -v ansible-lint >/dev/null 2>&1; then
  error "ansible-lint was installed but is not available on PATH."
fi

ansible-lint --version

if [[ -n "${requirements_file}" ]]; then
  if ! command -v ansible-galaxy >/dev/null 2>&1; then
    error "ansible-galaxy is not available after installing ansible-lint dependencies."
  fi
  ansible-galaxy install -r "${requirements_file}"
fi

lint_args=()
if [[ -n "${INPUT_ARGS:-}" ]]; then
  mapfile -t lint_args < <(
    INPUT_ARGS="${INPUT_ARGS}" "${python_bin}" - <<'PY'
import os
import shlex

for argument in shlex.split(os.environ.get("INPUT_ARGS", "")):
    print(argument)
PY
  )
fi

cd "${working_directory}"
ansible-lint "${lint_args[@]}"
