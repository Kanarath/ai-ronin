# Construye el paquete de Linux de AI RONIN: build\AI-RONIN-linux-x86_64.tar.gz
#   1. Exporta el juego con Godot 4.7.2 (preset «Linux») a build\linux\AI-RONIN.x86_64
#   2. Copia la Forja (solo los ficheros del repositorio) y LECTURAS.md
#   3. Empaqueta todo en un .tar.gz (Linux no usa instalador tipo Windows)
# Uso (desde la raíz del proyecto):  powershell -ExecutionPolicy Bypass -File instalador\construir_linux.ps1
# Necesita: Godot 4.7.2 (variable GODOT o junto a la carpeta del proyecto) y SUS PLANTILLAS DE
# EXPORTACIÓN DE LINUX. Si faltan, instálalas desde el editor de Godot:
#   Proyecto → Exportar → «Gestionar plantillas de exportación» → Descargar e instalar.
# El .tar.gz se puede construir desde Windows o desde Linux con el Godot de esa plataforma.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$godot = $env:GODOT
if (-not $godot) {
    $godot = Join-Path (Split-Path -Parent $root) "Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path $godot)) { throw "No encuentro Godot 4.7.2. Pon su ruta (la versión _console) en la variable GODOT." }

$out = Join-Path $root "build\linux"
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null

Write-Host "1/3 Exportando el juego para Linux…"
& $godot --headless --path game --export-release "Linux" "$out\AI-RONIN.x86_64" | Out-Null
if (-not (Test-Path "$out\AI-RONIN.x86_64")) {
    throw "La exportación no ha generado el binario. ¿Están instaladas las plantillas de exportación de Linux? (editor de Godot → Gestionar plantillas de exportación)."
}
Remove-Item -Recurse -Force "$out\forja", "$out\musica" -ErrorAction SilentlyContinue

Write-Host "2/3 Copiando la Forja y LECTURAS.md…"
foreach ($f in (git ls-files forja)) {
    $dest = Join-Path $out $f
    New-Item -ItemType Directory -Force (Split-Path -Parent $dest) | Out-Null
    Copy-Item $f $dest
}
Copy-Item LECTURAS.md $out
# Pequeño lanzador y nota de uso.
Set-Content -Encoding utf8 (Join-Path $out "JUGAR.txt") @"
AI RONIN · Linux

1. Dale permiso de ejecución una sola vez:   chmod +x AI-RONIN.x86_64
2. Ejecútalo:                                ./AI-RONIN.x86_64

Tus ejercicios de la Forja están en la carpeta forja/.
Tus partidas se guardan en ~/.local/share/godot/app_userdata/AI RONIN/.
"@

Write-Host "3/3 Empaquetando el .tar.gz…"
$tar = Join-Path $root "build\AI-RONIN-linux-x86_64.tar.gz"
if (Test-Path $tar) { Remove-Item -Force $tar }
tar -czf $tar -C (Join-Path $root "build") linux
Get-ChildItem $tar | ForEach-Object { Write-Host ("Listo: {0} ({1:N1} MB)" -f $_.FullName, ($_.Length / 1MB)) }
