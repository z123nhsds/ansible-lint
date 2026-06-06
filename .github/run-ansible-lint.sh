#!/usr/bin/env bash
# Ansible Lint Runner Script
# This script provides robust execution of ansible-lint with proper error handling

set -eo pipefail

# Default values
ANSIBLE_LINT_ARGS=""
REQUIREMENTS_FILE=""
WORKING_DIR="."
PYTHON_VERSION="3.14"

# Color constants for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --args)
            ANSIBLE_LINT_ARGS="$2"
            shift 2
            ;;
        --requirements-file)
            REQUIREMENTS_FILE="$2"
            shift 2
            ;;
        --working-directory)
            WORKING_DIR="$2"
            shift 2
            ;;
        --python-version)
            PYTHON_VERSION="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to check if python is available
check_python() {
    if ! command -v python &> /dev/null; then
        log_error "Python not found"
        return 1
    fi
    PYTHON_VERSION_ACTUAL=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    log_info "Python version: $PYTHON_VERSION_ACTUAL"
    return 0
}

# Function to install ansible-lint from main branch
install_ansible_lint() {
    log_info "Installing ansible-lint from main branch..."
    python -m pip install --upgrade pip
    pip install git+https://github.com/ansible/ansible-lint.git@main
    if command -v ansible-lint &> /dev/null; then
        log_info "ansible-lint installed successfully"
        ansible-lint --version
    else
        log_error "Failed to install ansible-lint"
        return 1
    fi
    return 0
}

# Function to install additional requirements
install_requirements() {
    if [ -n "$REQUIREMENTS_FILE" ]; then
        if [ -f "$REQUIREMENTS_FILE" ]; then
            log_info "Installing additional dependencies from $REQUIREMENTS_FILE"
            pip install -r "$REQUIREMENTS_FILE"
        else
            log_warning "Requirements file not found: $REQUIREMENTS_FILE"
        fi
    fi
}

# Function to run ansible-lint
run_ansible_lint() {
    log_info "Changing to working directory: $WORKING_DIR"
    cd "$WORKING_DIR" || {
        log_error "Failed to change directory to $WORKING_DIR"
        return 1
    }

    log_info "Running ansible-lint with args: $ANSIBLE_LINT_ARGS"
    ansible-lint $ANSIBLE_LINT_ARGS
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log_info "ansible-lint completed successfully"
    else
        log_error "ansible-lint failed with exit code $exit_code"
    fi

    return $exit_code
}

# Main execution
main() {
    log_info "Starting ansible-lint execution"

    # Check Python
    if ! check_python; then
        exit 1
    fi

    # Install ansible-lint
    if ! install_ansible_lint; then
        exit 1
    fi

    # Install additional requirements
    install_requirements

    # Run ansible-lint
    run_ansible_lint
}

# Run main
main "$@"
