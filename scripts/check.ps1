param([string]$Flutter = '.tools/flutter/bin/flutter.bat')
$ErrorActionPreference = 'Stop'
& $Flutter --version
& $Flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$dart = Join-Path (Split-Path $Flutter) 'dart.bat'
& $dart analyze lib test integration_test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Flutter test --reporter expanded
exit $LASTEXITCODE
