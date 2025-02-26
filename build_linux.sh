#!/usr/bin/env bash
set -euo pipefail

# Check for required arguments: MainScript and ExeName.
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <MainScript> <ExeName>"
  exit 1
fi

MainScript="$1"
ExeName="$2"

echo "===> Locating Poetry’s Python interpreter, main and build dependencies..."

# Activate the main environment (assumed to be in ../env)
source ../env/bin/activate

# Get Poetry’s Python executable path (removes trailing newline)
pythonExe=$(poetry run python -c "import sys; print(sys.executable)" | tr -d '\n')
echo "Poetry Python: $pythonExe"

# Export build requirements (from the default group 'build') and main requirements (excluding dev and build)
poetry export --only build --output build_requirements.txt
poetry export --without dev,build --output main_requirements.txt

echo "===> Creating clean build environment..."
# Create a clean build environment using the Poetry Python interpreter.
"$pythonExe" -m venv clean_build_env

echo "===> Activating clean build environment..."
chmod 755 clean_build_env/bin/activate
source clean_build_env/bin/activate

echo "===> Upgrading pip..."
python -m pip install --upgrade pip

echo "===> Installing pinned build requirements (e.g. PyInstaller)..."
pip install -r build_requirements.txt

echo "===> Installing pinned main dependencies..."
pip install -r main_requirements.txt

echo "===> Running PyInstaller..."
pyinstaller "$MainScript" --onefile --name "$ExeName"
echo "===> Build complete!"
echo "Check 'dist/$ExeName' for your bundled application."

echo "===> Cleaning up build environment..."
deactivate
rm -rf clean_build_env
rm -f build_requirements.txt main_requirements.txt

echo "===> Reactivating main environment..."
source ../env/bin/activate

echo "===> Clean-up done. Build environment removed."
