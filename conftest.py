"""PyTest Fixtures."""

import os
import platform
import subprocess
import sys
import warnings
from importlib.util import find_spec
from pathlib import Path

import pytest

# Ensure we always run from the root of the repository
if Path.cwd() != Path(__file__).parent:
    os.chdir(Path(__file__).parent)

# checking if user is running pytest without installing test dependencies:
missing = [module for module in ["ansible", "black", "mypy"] if not find_spec(module)]
if missing:
    pytest.exit(
        reason=f"FATAL: Missing modules: {', '.join(missing)} -- probably you missed installing test requirements with: uv pip install --group dev -e '.'",
        returncode=1,
    )


def pytest_addoption(parser: pytest.Parser) -> None:
    """Add pytest options for coverage configuration."""
    group = parser.getgroup("coverage")
    group.addoption(
        "--coverage-file",
        action="store",
        dest="coverage_file",
        default=None,
        help="Path to the coverage data file. If not specified, defaults to .coverage.",
    )
    group.addoption(
        "--coverage-dir",
        action="store",
        dest="coverage_dir",
        default=None,
        help="Directory to store coverage data files. If not specified, defaults to project root.",
    )


# See: https://github.com/pytest-dev/pytest/issues/1402#issuecomment-186299177
def pytest_configure(config: pytest.Config) -> None:
    """Configure coverage based on pytest options and run preparation only on master thread when running in parallel."""
    coverage_file = config.getoption("coverage_file")
    coverage_dir = config.getoption("coverage_dir")
    
    if coverage_file:
        os.environ["COVERAGE_FILE"] = coverage_file
    elif coverage_dir:
        os.environ["COVERAGE_DIR"] = coverage_dir
    
    if is_help_option_present(config):
        return
    if is_master(config):
        # linter should be able de detect and convert some deprecation warnings
        # into validation errors but during testing we disable this to avoid
        # unnecessary noise. Still, we might want to enable it for particular
        # tests, for testing our ability to detect deprecations.
        os.environ["ANSIBLE_DEPRECATION_WARNINGS"] = "False"
        # we need to be sure that we have the requirements installed as some tests
        # might depend on these. This approach is compatible with GHA caching.
        try:
            subprocess.check_output(
                ["./tools/install-reqs.sh"],
                stderr=subprocess.PIPE,
                text=True,
            )
        except subprocess.CalledProcessError as exc:
            print(f"{exc}\n{exc.stderr}\n{exc.stdout}", file=sys.stderr)  # noqa: T201
            sys.exit(1)


def is_help_option_present(config: pytest.Config) -> bool:
    """Return true if pytest invocation was not about running tests."""
    return any(config.getoption(x) for x in ["--fixtures", "--help", "--collect-only"])


def is_master(config: pytest.Config) -> bool:
    """Return true if is run on master thread."""
    return not hasattr(config, "workerinput")


# ruff: noqa: E402
from ansible.module_utils.common.yaml import (  # pylint: disable=wrong-import-position
    HAS_LIBYAML,
)

if not HAS_LIBYAML:
    # While presence of libyaml is not required for runtime, we keep this error
    # fatal here in order to be sure that we spot libyaml errors during testing.
    arch = platform.machine()
    if arch not in ("arm64", "x86_64"):
        warnings.warn(
            f"This architecture ({arch}) is not supported by libyaml, performance will be degraded.",
            category=pytest.PytestWarning,
            stacklevel=1,
        )
    else:
        warnings.warn(
            "Some tests are skipped because when pyyaml precompile lib is missing they produce different results. This is also making testing 3x slower.",
            category=pytest.PytestWarning,
            stacklevel=1,
        )


@pytest.fixture(name="project_path")
def fixture_project_path() -> Path:
    """Fixture to linter root folder."""
    return Path(__file__).resolve().parent


def pytest_runtest_setup(item: pytest.Item) -> None:
    """Filters some tests if libyaml is not available."""
    if not HAS_LIBYAML and list(item.iter_markers("libyaml")):
        pytest.skip("skipped because libyaml is not installed")
