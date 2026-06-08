import subprocess
import os

# Test 1: pre-commit configuration of yamllint vs pyproject.toml
# Write a minimal python script to run pre-commit or cspell.
# Actually I can just run it.

result = subprocess.run(["npx", "cspell", "--help"], capture_output=True, text=True)
print("cspell help:", result.stdout)

result2 = subprocess.run(["npx", "cspell", "lint", "--help"], capture_output=True, text=True)
print("cspell lint help:", result2.stdout)
