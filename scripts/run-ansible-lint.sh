#!/usr/bin/env bash
set -euo pipefail

COMMAND="${1:-}"
GH_ACTION_REF="${GH_ACTION_REF:-main}"
SETUP_PYTHON="${SETUP_PYTHON:-true}"
PYTHON_VERSION="${PYTHON_VERSION:-3.14}"
REQS_FILE="${REQS_FILE:-}"
ANSIBLE_LINT_ARGS="${ANSIBLE_LINT_ARGS:-}"
EXPECTED_RETURN_CODE="${EXPECTED_RETURN_CODE:-0}"

log_info() {
  echo "::notice::[ansible-lint-action] $*"
}

log_warn() {
  echo "::warning::[ansible-lint-action] $*"
}

log_error() {
  echo "::error::[ansible-lint-action] $*"
}

validate_env() {
  if [[ -z "${GH_ACTION_REF}" ]]; then
    log_error "GH_ACTION_REF is not set. Cannot determine ansible-lint version."
    exit 1
  fi

  if [[ "${SETUP_PYTHON}" == "true" ]]; then
    if ! command -v uv &>/dev/null; then
      log_error "uv is not installed but setup_python is true. Ensure astral-sh/setup-uv action runs before this step."
      exit 1
    fi
  else
    if ! command -v pip &>/dev/null; then
      log_error "pip is not installed but setup_python is false. Ensure pip is available in the environment."
      exit 1
    fi
  fi
}

do_install() {
  validate_env

  local install_spec="ansible-lint[lock] @ git+https://github.com/ansible/ansible-lint@${GH_ACTION_REF}"

  if [[ "${SETUP_PYTHON}" == "true" ]]; then
    log_info "Installing ansible-lint via uv tool (Python ${PYTHON_VERSION}, ref: ${GH_ACTION_REF})"

    if [[ -n "${REQS_FILE}" && -f "${REQS_FILE}" ]]; then
      log_info "Using locked requirements from ${REQS_FILE}"
      if ! uv tool install --python "${PYTHON_VERSION}" \
        --with-requirements "${REQS_FILE}" \
        "${install_spec}"; then
        log_warn "uv tool install with requirements failed, falling back to install without lock file"
        uv tool install --python "${PYTHON_VERSION}" "${install_spec}"
      fi
    else
      log_info "No lock file available, installing without pinned requirements"
      uv tool install --python "${PYTHON_VERSION}" "${install_spec}"
    fi
  else
    log_info "Installing ansible-lint via pip (ref: ${GH_ACTION_REF})"

    if [[ -n "${REQS_FILE}" && -f "${REQS_FILE}" ]]; then
      log_info "Using locked requirements from ${REQS_FILE}"
      if ! pip install -r "${REQS_FILE}" "${install_spec}"; then
        log_warn "pip install with requirements failed, falling back to install without lock file"
        pip install "${install_spec}"
      fi
    else
      log_info "No lock file available, installing without pinned requirements"
      pip install "${install_spec}"
    fi
  fi

  if ! ansible-lint --version; then
    log_error "ansible-lint installation verification failed"
    exit 1
  fi

  log_info "ansible-lint installed successfully"
}

do_lint() {
  if ! command -v ansible-lint &>/dev/null; then
    log_error "ansible-lint is not installed. Run the 'install' command first."
    exit 1
  fi

  log_info "Running ansible-lint with args: ${ANSIBLE_LINT_ARGS:-<none>}"

  local exit_code=0
  ansible-lint ${ANSIBLE_LINT_ARGS} || exit_code=$?

  if [[ "${exit_code}" -ne "${EXPECTED_RETURN_CODE}" ]]; then
    log_error "ansible-lint exited with code ${exit_code}, expected ${EXPECTED_RETURN_CODE}"
    exit 1
  fi

  if [[ "${exit_code}" -eq 0 ]]; then
    log_info "ansible-lint completed successfully"
  else
    log_info "ansible-lint exited with expected code ${exit_code}"
  fi
}

case "${COMMAND}" in
  install)
    do_install
    ;;
  lint)
    do_lint
    ;;
  *)
    log_error "Unknown command: ${COMMAND}. Use 'install' or 'lint'."
    exit 1
    ;;
esac
