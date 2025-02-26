#!/usr/bin/env bash
set -euo pipefail

# Usage check
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <ProjectName> <PythonVersion (e.g., 3.12)>"
  exit 1
fi

ProjectName="$1"
PythonVersion="$2"

# -----------------------------------------------------------------------------
# 1) Build a valid Python version range for pyproject.toml:
#    e.g., if user passes "3.12", we make ">=3.12,<3.13"
# -----------------------------------------------------------------------------
IFS='.' read -r major minor extra <<< "$PythonVersion"
if [ -z "$minor" ]; then
  echo "ERROR: Please specify a valid MAJOR.MINOR Python version (e.g., '3.12')."
  exit 1
fi
nextMinor=$((minor + 1))
pythonVersionRange=">=${major}.${minor},<${major}.${nextMinor}"
echo "Python version range to set in pyproject.toml: $pythonVersionRange"

# Construct the Python interpreter name (on Ubuntu, e.g. "python3.12")
pythonInterpreter="python${major}.${minor}"
echo "Python interpreter for venv creation: $pythonInterpreter"

# -----------------------------------------------------------------------------
# 2) Create and activate a local Python virtual environment
# -----------------------------------------------------------------------------
$pythonInterpreter -m venv env
if [ ! -d "env" ]; then
  echo "ERROR: Failed to create venv. Ensure '$pythonInterpreter' is installed and on PATH."
  exit 1
fi
# Activate the virtual environment
chmod 755 enc/bin/activate
source env/bin/activate
python -m pip install --upgrade pip

# -----------------------------------------------------------------------------
# 3) Install Poetry, then create a new folder structure with "poetry new"
# -----------------------------------------------------------------------------
pip install poetry
poetry new "$ProjectName"

# Move into the newly created project folder
cd "$ProjectName"

# -----------------------------------------------------------------------------
# 4) Update the pyproject.toml to pin Python to the requested range
#    (poetry new creates a pyproject.toml with a line like: python = "^3.10")
# -----------------------------------------------------------------------------
# Use sed with extended regex; creates a backup file with .bak extension
sed -E -i.bak 's/(python\s*=\s*")[^"]+(")/\1'"$pythonVersionRange"'\2/' pyproject.toml

# Install the Poetry export plugin so that `poetry export` becomes available
poetry self add poetry-plugin-export

# -----------------------------------------------------------------------------
# 5) Add dev dependencies (pre-commit, pytest, pytest-timeout)
# -----------------------------------------------------------------------------
poetry add --group dev pre-commit pytest pytest-timeout

# Append a minimal [tool.ruff] config to pyproject.toml
cat <<EOF >> pyproject.toml

[tool.ruff]
extend_select = ["I"]
fix = true
EOF

# Create a .pre-commit-config.yaml with all configuration contained in the file.
# Note: The hooks below use inline Python to change directory into the project folder.
cat <<EOF > .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-yaml
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: check-case-conflict
      - id: check-ast
      - id: check-added-large-files
        args: ["--maxkb=1000"]

  - repo: https://github.com/hadialqattan/pycln.git
    rev: v2.5.0
    hooks:
      - id: pycln
        name: pycln
        description: "A formatter for finding and removing unused import statements."
        entry: pycln
        language: python
        language_version: python3
        types: [python]

  - repo: https://github.com/psf/black
    rev: 23.10.1
    hooks:
      - id: black

  - repo: https://github.com/pycqa/isort
    rev: 5.12.0
    hooks:
      - id: isort
        name: isort (python)

  - repo: https://github.com/pycqa/pylint
    rev: v3.0.2
    hooks:
      - id: pylint
        types: [python]
        args:
          - "--disable=C0116,E0401"

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.6.1
    hooks:
      - id: mypy
        name: mypy
        args:
          - --follow-imports=silent
          - --ignore-missing-imports
          - --show-column-numbers
          - --no-pretty
          - --strict
        additional_dependencies: ["toml", "types-toml", "types-requests"]

  - repo: local
    hooks:
      - id: poetry-install
        name: Install project deps
        entry: python
        language: python
        additional_dependencies: [pre-commit, poetry]
        always_run: true
        pass_filenames: false
        args:
          - -c
          - |
            import os, sys, subprocess
            os.chdir("$ProjectName")
            result = subprocess.run(["poetry", "install"])
            sys.exit(result.returncode)
      - id: run-tests
        name: Run tests
        entry: python
        language: python
        additional_dependencies: [pre-commit, poetry]
        always_run: true
        pass_filenames: false
        args:
          - -c
          - |
            import os, sys, subprocess
            os.chdir("$ProjectName")
            result = subprocess.run(["poetry", "run", "pytest"])
            sys.exit(result.returncode)
EOF

# -----------------------------------------------------------------------------
# 6) Add build dependencies (setuptools, pyinstaller)
# -----------------------------------------------------------------------------
poetry add --group build setuptools pyinstaller

# -----------------------------------------------------------------------------
# 7) Install the project (with dev & build groups) and register the pre-commit hook
# -----------------------------------------------------------------------------
poetry install --with dev,build
poetry run pre-commit install

echo ""
echo "=========================================================================="
echo "Successfully created and initialized new Poetry project '$ProjectName'."
echo "Project structure (in ./$ProjectName):"
echo "  - pyproject.toml pinned to Python $pythonVersionRange"
echo "  - README.md"
echo "  - src/$(echo "$ProjectName" | tr '[:upper:]' '[:lower:]')/__init__.py"
echo "  - tests/"
echo "Pre-commit hooks installed."
echo "=========================================================================="
