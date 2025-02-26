param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,

    [Parameter(Mandatory=$true)]
    [string]$PythonVersion
)

# -----------------------------------------------------------------------------
# 1) Build a valid Python version range for pyproject.toml:
#    E.g., if user passes "3.12", we make ">=3.12,<3.13"
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
$pythonInterpreter = "python$($major).$($minor).exe"
Write-Host "Python interpreter for venv creation: $pythonInterpreter"


# -----------------------------------------------------------------------------
# 2) Create and activate python env
# -----------------------------------------------------------------------------
& $pythonInterpreter -m venv env
if (!(Test-Path .\env)) {
    Write-Host "ERROR: Failed to create venv. Ensure '$pythonInterpreter' is on PATH." -ForegroundColor Red
    exit 1
}
.\env\Scripts\activate
python -m pip install --upgrade pip


# -----------------------------------------------------------------------------
# 3) Install and setup poetry
#    Update pyproject.toml to pin Python to the requested range
# -----------------------------------------------------------------------------
pip install poetry
poetry new $ProjectName
Set-Location $ProjectName
$pyprojectContent = Get-Content .\pyproject.toml
$updatedContent = $pyprojectContent -replace '(?<=python\s=\s")([^"]+)(?=")', $pythonVersionRange
$updatedContent | Set-Content .\pyproject.toml

# -----------------------------------------------------------------------------
# 4) Add and configure dev dependencies (pre-commit, ruff, mypy, pytest)
# -----------------------------------------------------------------------------
poetry add --group dev pre-commit ruff mypy pytest
Add-Content pyproject.toml @"
[tool.ruff]
# Enable isort-compatible import sorting
extend_select = ["I"]
# Optionally enable automatic unused imports removal with autofix:
fix = true
"@

@"
repos:
  - repo: local
    hooks:
      # (Optional) 1) Ensure dependencies match the lock file
      - id: ensure-poetry-install
        name: Ensure Poetry Dependencies Are Synced
        entry: poetry install --sync --no-root
        language: system
        pass_filenames: false

      # 2) Ruff for linting, import removal, sorting
      - id: ruff
        name: Ruff Lint & Fix
        entry: poetry run ruff check --fix
        language: system
        # If you want to only lint staged files, leave pass_filenames: true
        pass_filenames: true

      # 3) Mypy for type checking
      - id: mypy
        name: Mypy Type Check
        entry: poetry run mypy .
        language: system
        pass_filenames: false

      # 4) Pytest for unit tests
      - id: pytest
        name: Run Unit Tests
        entry: poetry run pytest
        language: system
        pass_filenames: false
"@ | Out-File .pre-commit-config.yaml -Encoding utf8


# -----------------------------------------------------------------------------
# 5) Add dev dependencies (setuptools, pyinstaller)
# -----------------------------------------------------------------------------
poetry add --group build setuptools pyinstaller


# -----------------------------------------------------------------------------
# 6) Install the project and register pre-commit hook
# -----------------------------------------------------------------------------
poetry install --with dev,build
poetry run pre-commit install
Write-Host "Successfully created and initialized new Poetry project '$ProjectName' with pre-commit hooks."