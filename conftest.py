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
# Ensure we always run from the root of the repository
# checking if user is running pytest without installing test dependencies:
missing = [module for module in ["ansible", "black", "mypy"] if not find_spec(module)]
if missing:
# checking if user is running pytest without installing test dependencies:
    pytest.exit(
        reason=f"FATAL: Missing modules: {', '.join(missing)} -- probably you missed installing test requirements with: uv pip install --group dev -e '.'",
        returncode=1,
    )


# See: https://github.com/pytest-dev/pytest/issues/1402#issuecomment-186299177
def pytest_configure(config: pytest.Config) -> None:
    """Return true if is run on master thread."""
    return not hasattr(config, "workerinput")
    """Ensure we run preparation only on master thread when running in parallel."""
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
    # While presence of libyaml is not required for runtime, we keep this error
    # fatal here in order to be sure that we spot libyaml errors during testing.
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
