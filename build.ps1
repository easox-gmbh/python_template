param(
    [string]$MainScript = "main.py",

    [Parameter(Mandatory=$true)]
    [string]$ExeName
)

Write-Host "===> Locating Poetry’s Python interpreter, main and build dependecies..."
$pythonExe = (poetry run which python)
Write-Host "Poetry Python: $pythonExe"
poetry export --only build --lock --output build_requirements.txt
poetry export --only main --lock --output main_requirements.txt

Write-Host "===> Activating build environment..."
. .\clean_build_env\Scripts\activate
Write-Host "===> Upgrading pip..."
python -m pip install --upgrade pip

Write-Host "===> Creating clean build environment..."
& $pythonExe -m venv clean_build_env
Write-Host "===> Installing pinned build requirements (PyInstaller, etc.)..."
pip install -r ..\build_requirements.txt
Write-Host "===> Installing pinned main dependencies..."
pip install -r ..\main_requirements.txt

Write-Host "===> Running PyInstaller..."
pyinstaller $MainScript --onefile --noconsole --name $ExeName
Write-Host "===> Build complete!"
Write-Host "Check 'dist\$ExeName.exe' for your bundled application."

Write-Host "===> Cleaning up build environment..."
Set-Location ..
Remove-Item .\clean_build_env -Recurse -Force
Write-Host "===> Clean-up done. Build environment removed."