$SDK_VERSION = "3.9.2"
$PLATFORM = "windows"
$ARCH = "x64"
$ZIP_URL = "https://storage.googleapis.com/dart-archive/channels/stable/release/$SDK_VERSION/sdk/dartsdk-$PLATFORM-$ARCH-release.zip"
$BASE_DIR = Get-Location
$TEMP_DIR = Join-Path $BASE_DIR "data"
$PROJECT_DIR = Join-Path $BASE_DIR "projects/chronon_helm"
$ENTRY_POINT = "bin/chronon_helm.dart"
$DART_BIN = Join-Path $TEMP_DIR "dart-sdk/bin/dart"

Write-Output "Current directory: $BASE_DIR"
Write-Output "Checking for Dart binary at: $DART_BIN"

if (Test-Path $DART_BIN) {
    Write-Output "Dart SDK found at $(Join-Path $TEMP_DIR 'dart-sdk')"
} else {
    Write-Output "Downloading Dart SDK..."
    Invoke-WebRequest -Uri $ZIP_URL -OutFile "dart_sdk.zip"
    if (!$?) { exit 1 }
    Write-Output "Extracting SDK..."
    New-Item -ItemType Directory -Force -Path $TEMP_DIR | Out-Null
    Expand-Archive -Path "dart_sdk.zip" -DestinationPath $TEMP_DIR
    if (!$?) { exit 1 }
    if (-not (Test-Path $DART_BIN)) {
        Write-Output "Error: Dart binary not found at $DART_BIN after extraction"
        exit 1
    }
    # chmod +x not typically needed in PowerShell, but if on Unix-like, could use chmod if available
    Remove-Item -Path "dart_sdk.zip"
}

Write-Output "Verifying Dart SDK version..."
& $DART_BIN --version
if (!$?) { exit 1 }
Write-Output "Fetching dependencies..."
Push-Location $PROJECT_DIR
if (!$?) { exit 1 }
& $DART_BIN pub get
if (!$?) { exit 1 }
Pop-Location
if (!$?) { exit 1 }
Write-Output "Pulling Images..."
docker compose build
Write-Output "Running Dart project..."
Push-Location $PROJECT_DIR
if (!$?) { exit 1 }
if (Test-Path $ENTRY_POINT) {
    & $DART_BIN run $ENTRY_POINT
    if (!$?) { exit 1 }
} else {
    Write-Output "Error: Entry point not found at $(Join-Path $PROJECT_DIR $ENTRY_POINT)"
    exit 1
}