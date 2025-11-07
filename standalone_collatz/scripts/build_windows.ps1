Param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

if (-not (Test-Path ".venv")) {
    Write-Host "Creating virtual environment..."
    python -m venv .venv
}

& .\.venv\Scripts\python -m pip install --upgrade pip
& .\.venv\Scripts\python -m pip install -e . "pyinstaller>=5.13"

$pyInstallerArgs = @(
    "--name=CollatzExplorer",
    "--windowed",
    "--noconfirm",
    "--clean"
)

if ($Configuration -eq "Debug") {
    $pyInstallerArgs += "--debug=all"
}

Write-Host "Building executable..."
& .\.venv\Scripts\pyinstaller @pyInstallerArgs -m collatz_standalone

Write-Host "Build artifacts available in dist/CollatzExplorer.exe"
