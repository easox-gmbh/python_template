param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,

    [Parameter(Mandatory=$true)]
    [string]$PythonVersion
)

# -----------------------------------------------------------------------------
# 1) Build a valid Python version range for pyproject.toml:
#    e.g., if user passes "3.12", we make ">=3.12,<3.13"
# -----------------------------------------------------------------------------
$versionParts = $PythonVersion -split "\."
if ($versionParts.Count -lt 2) {
    Write-Host "ERROR: Please specify a valid MAJOR.MINOR Python version (e.g., '3.12')." -ForegroundColor Red
    exit 1
}
$major = $versionParts[0]
$minor = $versionParts[1]
$nextMinor = [int]$minor + 1
$pythonVersionRange = ">=${major}.${minor},<${major}.${nextMinor}"
Write-Host "Python version range to set in pyproject.toml: $pythonVersionRange"

# Construct the Python interpreter name (for Windows, e.g. "python3.12.exe")
$pythonInterpreter = "python$($major).$($minor).exe"
Write-Host "Python interpreter for venv creation: $pythonInterpreter"

# -----------------------------------------------------------------------------
# 2) Create and activate a local Python virtual environment
# -----------------------------------------------------------------------------
& $pythonInterpreter -m venv env
if (!(Test-Path .\env)) {
    Write-Host "ERROR: Failed to create venv. Ensure '$pythonInterpreter' is on PATH." -ForegroundColor Red
    exit 1
}
.\env\Scripts\activate
python -m pip install --upgrade pip

# -----------------------------------------------------------------------------
# 3) Install Poetry, then create a new folder structure with "poetry new"
# -----------------------------------------------------------------------------
pip install poetry
poetry new $ProjectName

# Move into the newly created project folder
Set-Location $ProjectName

# -----------------------------------------------------------------------------
# 4) Update the pyproject.toml to pin Python to the requested range
#    "poetry new" automatically creates a pyproject.toml with e.g. python="^3.10"
# -----------------------------------------------------------------------------
$pyprojectContent = Get-Content .\pyproject.toml
$updatedContent = $pyprojectContent -replace '(?<=python\s=\s")([^"]+)(?=")', $pythonVersionRange
$updatedContent | Set-Content .\pyproject.toml

# -----------------------------------------------------------------------------
# 5) Add dev dependencies (pre-commit, ruff, mypy, pytest, pytest-timeout)
# -----------------------------------------------------------------------------
poetry add --group dev pre-commit ruff mypy pytest pytest-timeout

# Append a minimal [tool.ruff] config to pyproject.toml
Add-Content .\pyproject.toml @"
[tool.ruff]
# Enable isort-compatible import sorting
extend_select = ["I"]
# Optionally enable automatic unused imports removal with autofix:
fix = true
"@

# Create a .pre-commit-config.yaml
@"
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

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.9.7
    hooks:
      - id: ruff
        name: Ruff Lint & Fix
        entry: python
        language: system
        pass_filenames: true

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.6.1
    hooks:
      - id: mypy
        name: mypy
        args:
          [
            --follow-imports=silent,
            --ignore-missing-imports,
            --show-column-numbers,
            --no-pretty,
            --strict,
          ]
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
"@ | Out-File .pre-commit-config.yaml -Encoding utf8

# -----------------------------------------------------------------------------
# 6) Add build dependencies (setuptools, pyinstaller)
# -----------------------------------------------------------------------------
poetry add --group build setuptools pyinstaller

# -----------------------------------------------------------------------------
# 7) Install the project (with dev & build groups) and register the pre-commit hook
# -----------------------------------------------------------------------------
poetry install --with dev,build
poetry run pre-commit install

Write-Host "`n=========================================================================="
Write-Host "Successfully created and initialized new Poetry project '$ProjectName'."
Write-Host "Project structure (under .\$ProjectName):"
Write-Host "  - pyproject.toml pinned to Python $pythonVersionRange"
Write-Host "  - README.md"
Write-Host "  - src/$($ProjectName.ToLower())/__init__.py"
Write-Host "  - tests/"
Write-Host "Pre-commit hooks installed."
Write-Host "=========================================================================="
