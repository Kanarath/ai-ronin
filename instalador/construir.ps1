# Construye el instalador de AI RONIN: build\AI-RONIN-Setup-<versión>.exe
#   1. Exporta el juego con Godot 4.7.2 (preset «Windows Desktop») a build\staging\AI-RONIN.exe
#   2. Comprueba el .exe con su autoprueba (misiones, datasets y música dentro)
#   3. Copia la Forja (solo los ficheros del repositorio: nada de evidencias ni entornos) y LECTURAS.md
#   4. Compila instalador\ai-ronin.iss con Inno Setup 6
# Uso (desde la raíz del proyecto):  powershell -ExecutionPolicy Bypass -File instalador\construir.ps1
# Necesita: Godot 4.7.2 (variable GODOT o junto a la carpeta del proyecto), sus plantillas de
# exportación y Inno Setup 6 (en tu usuario o en Program Files).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$godot = $env:GODOT
if (-not $godot) {
    $godot = Join-Path (Split-Path -Parent $root) "Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path $godot)) { throw "No encuentro Godot 4.7.2. Pon su ruta (la versión _console) en la variable GODOT." }
$iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw "No encuentro Inno Setup 6 (ISCC.exe)." }

$staging = Join-Path $root "build\staging"
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Force $staging | Out-Null

Write-Host "1/4 Exportando el juego…"
& $godot --headless --path game --export-release "Windows Desktop" "$staging\AI-RONIN.exe" | Out-Null
if (-not (Test-Path "$staging\AI-RONIN.exe")) { throw "La exportación no ha generado el .exe." }

Write-Host "2/4 Autoprueba del .exe…"
$out = & "$staging\AI-RONIN.exe" --headless -- --autoprueba 2>&1 | Out-String
$out -split "`n" | Where-Object { $_ -match "AUTOPRUEBA" } | ForEach-Object { Write-Host "   $_" }
if ($out -notmatch "AUTOPRUEBA: OK") { throw "La autoprueba del .exe ha fallado." }
Remove-Item -Recurse -Force "$staging\forja", "$staging\musica" -ErrorAction SilentlyContinue

Write-Host "3/4 Copiando la Forja y LECTURAS.md…"
foreach ($f in (git ls-files forja)) {
    $dest = Join-Path $staging $f
    New-Item -ItemType Directory -Force (Split-Path -Parent $dest) | Out-Null
    Copy-Item $f $dest
}
Copy-Item LECTURAS.md $staging
Copy-Item "game\icon.ico" (Join-Path $staging "icon.ico")

Write-Host "4/4 Compilando el instalador…"
& $iscc /Q "instalador\ai-ronin.iss"
if ($LASTEXITCODE -ne 0) { throw "ISCC ha fallado." }
Get-ChildItem build\AI-RONIN-Setup-*.exe | ForEach-Object { Write-Host ("Listo: {0} ({1:N1} MB)" -f $_.FullName, ($_.Length / 1MB)) }
