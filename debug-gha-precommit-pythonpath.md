# [OPEN] gha-precommit-pythonpath

## Bug Summary
- Symptom: when ansible-lint GitHub Action installs collection dependencies via `requirements_file`, the subsequent pre-commit hook execution cannot resolve those dependencies.
- Expected: the same dependencies installed during the Action setup remain discoverable when ansible-lint is launched from the pre-commit subprocess.
- Actual: pre-commit runs ansible-lint in an isolated process/environment where the Action-populated Python search path is not preserved, causing collection/module resolution failures.

## Hypotheses
1. The Action installs collections into a custom path that is only exported in the parent GitHub Action shell, not persisted for child hook invocations.
2. The pre-commit hook entry resets or rebuilds the environment, so `PYTHONPATH` from the Action step is not present when `ansible-lint` resolves dependencies.
3. The hook shell wrapper launches `ansible-lint` without rehydrating the collection install path into `PYTHONPATH`/related Ansible env vars.
4. The workflow passes `requirements_file`, but the installed content lands outside the default Ansible collection lookup paths used by the hook process.

## Plan
- Inspect config and execution chain.
- Reproduce the failure with a temporary requirements file and collect logs.
- Implement a joint fix in the Action and the pre-commit hook.
- Verify the environment is inherited correctly and summarize the root cause.
