#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# ansible-lint pre-commit hook wrapper
#
# This script bridges the environment isolation gap between GitHub Actions
# and pre-commit.  When a user installs Ansible collections via the
# ansible-lint GitHub Action (action.yml → requirements_file), the
# collection paths are set in $ANSIBLE_COLLECTIONS_PATHS.  Pre-commit
# intentionally strips most environment variables from its hook environment
# (see "Environment isolation" in https://pre-commit.com/#hooks).
#
# This wrapper re-assembles those paths before launching ansible-lint so
# that collections installed by ansible-galaxy remain discoverable.
#
# Usage (in .pre-commit-hooks.yaml):
#     entry: tools/ansible-lint-hook.sh
#     language: script
#     always_run: true
#     pass_filenames: false
# ---------------------------------------------------------------------------

build_pythonpath() {
    local paths=""

    # 1.  ANSIBLE_COLLECTIONS_PATHS – the canonical way to tell ansible-core
    #     where to look for collections.  The GitHub Action exports this to
    #     $GITHUB_ENV so it is available as a normal env-var in the runner.
    if [[ -n "${ANSIBLE_COLLECTIONS_PATHS:-}" ]]; then
        IFS=':' read -ra coll_dirs <<<"${ANSIBLE_COLLECTIONS_PATHS}"
        for d in "${coll_dirs[@]}"; do
            if [[ -d "$d" ]]; then
                paths="${paths:+${paths}:}${d}"
            fi
        done
    fi

    # 2.  Default collections location (~/.ansible/collections)
    local default_coll="${HOME:-~}/.ansible/collections"
    if [[ -d "$default_coll" ]]; then
        paths="${paths:+${paths}:}${default_coll}"
    fi

    # 3.  Project-local collections directory
    if [[ -d "./collections" ]]; then
        paths="${paths:+${paths}:}./collections"
    fi

    echo "$paths"
}

main() {
    local pythonpath
    pythonpath="$(build_pythonpath)"

    if [[ -n "$pythonpath" ]]; then
        export ANSIBLE_COLLECTIONS_PATHS="${pythonpath}"
        # Also append to PYTHONPATH so Python can import module_utils
        # and other Python modules shipped inside collections.
        export PYTHONPATH="${pythonpath}${PYTHONPATH:+:${PYTHONPATH}}"
    fi

    # Under pre-commit.ci the hook runs offline – skip galaxy install.
    if [[ "${PRE_COMMIT_CI:-}" != "true" ]] && [[ -f requirements.yml ]]; then
        if command -v ansible-galaxy &>/dev/null; then
            ansible-galaxy collection install -r requirements.yml --force 2>/dev/null || true
        fi
    fi

    exec python3 -m ansiblelint -v --force-color "$@"
}

main "$@"