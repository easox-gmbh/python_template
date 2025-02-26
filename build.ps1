param(
    [Parameter(Mandatory=$true)]
    [string]$MainScript,

    [Parameter(Mandatory=$true)]
    [string]$ExeName
)

Write-Host "===> Locating Poetry’s Python interpreter, main and build dependecies..."
..\env\Scripts\activate
$pythonExe = (poetry run python -c "import sys; print(sys.executable)").Trim()
Write-Host "Poetry Python: $pythonExe"
poetry export --only build --output build_requirements.txt
poetry export --without dev,build --output main_requirements.txt

Write-Host "===> Creating clean build environment..."
& $pythonExe -m venv clean_build_env
Write-Host "===> Activating build environment..."
. .\clean_build_env\Scripts\activate
Write-Host "===> Upgrading pip..."
python -m pip install --upgrade pip
Write-Host "===> Installing pinned build requirements (PyInstaller, etc.)..."
pip install -r build_requirements.txt
Write-Host "===> Installing pinned main dependencies..."
pip install -r main_requirements.txt

Write-Host "===> Running PyInstaller..."
pyinstaller $MainScript --onefile --name $ExeName
Write-Host "===> Build complete!"
Write-Host "Check 'dist\$ExeName.exe' for your bundled application."

Write-Host "===> Cleaning up build environment..."
Remove-Item .\clean_build_env -Recurse -Force
Remove-Item build_requirements.txt
Remove-Item main_requirements.txt
..\env\Scripts\activate
Write-Host "===> Clean-up done. Build environment removed."
