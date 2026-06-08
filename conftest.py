"""PyTest Fixtures."""

import os
import platform
import subprocess
import sys
import warnings
from importlib.util import find_spec
from pathlib import Path
from typing import TYPE_CHECKING

import pytest

if TYPE_CHECKING:
    from _pytest.config.argparsing import Parser

if Path.cwd() != Path(__file__).parent:
    os.chdir(Path(__file__).parent)

missing = [module for module in ["ansible", "black", "mypy"] if not find_spec(module)]
if missing:
    pytest.exit(
        reason=f"FATAL: Missing modules: {', '.join(missing)} -- probably you missed installing test requirements with: uv pip install --group dev -e '.'",
        returncode=1,
    )


def pytest_addoption(parser: "Parser") -> None:
    """Add --coverage-file option to pytest."""
    parser.addoption(
        "--coverage-file",
        action="store",
        default=os.environ.get("COVERAGE_FILE", ""),
        help="Path used for coverage data output.",
    )


# See: https://github.com/pytest-dev/pytest/issues/1402#issuecomment-186299177
def pytest_configure(config: pytest.Config) -> None:
    """Ensure we run preparation only on master thread when running in parallel."""
    coverage_file = config.getoption("--coverage-file")
    if coverage_file:
        coverage_path = Path(coverage_file).expanduser()
        coverage_path.parent.mkdir(parents=True, exist_ok=True)
        os.environ["COVERAGE_FILE"] = str(coverage_path)
    if is_help_option_present(config):
        return
    if is_master(config):
        os.environ["ANSIBLE_DEPRECATION_WARNINGS"] = "False"
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
