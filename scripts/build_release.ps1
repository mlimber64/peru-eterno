# =============================================================================
#  Perú Eterno — build de release para Google Play
# -----------------------------------------------------------------------------
#  Genera el App Bundle (.aab) firmado con la clave de release e inyectando
#  los secretos de compilación desde env.json.
#
#  Uso:
#    powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1
#    powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1 -Apk
#
#  Existe porque los dos errores que rompen una publicación son silenciosos:
#   1. Compilar sin --dart-define: el binario queda en modo 100% local (sin
#      Supabase) y no hay forma de arreglarlo salvo recompilando.
#   2. Compilar sin android/key.properties: el build NO falla, cae a la firma
#      debug — y Play rechaza ese artefacto al subirlo.
#  Este script comprueba ambas cosas ANTES de compilar.
# =============================================================================

param(
    # Construye también un APK universal (para instalar y probar en un
    # dispositivo real). Play solo acepta el .aab.
    [switch]$Apk
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host ''
Write-Host '── Perú Eterno · build de release ─────────────────────────────' -ForegroundColor Cyan

# 1. Secretos de compilación -------------------------------------------------
$envFile = Join-Path $root 'env.json'
if (-not (Test-Path $envFile)) {
    Write-Host ''
    Write-Host 'FALTA env.json' -ForegroundColor Red
    Write-Host '  Copia la plantilla y rellena los valores reales:' -ForegroundColor Yellow
    Write-Host '    Copy-Item env.example.json env.json' -ForegroundColor Yellow
    Write-Host '  Sin esto la app se compila SIN Supabase (modo local permanente).' -ForegroundColor Yellow
    exit 1
}

$envData = Get-Content $envFile -Raw | ConvertFrom-Json
foreach ($key in @('SUPABASE_URL', 'SUPABASE_ANON_KEY')) {
    $value = $envData.$key
    if ([string]::IsNullOrWhiteSpace($value) -or $value -like 'TU_*' -or $value -like '*TU-PROYECTO*') {
        Write-Host ''
        Write-Host "env.json: '$key' sigue con el valor de la plantilla." -ForegroundColor Red
        exit 1
    }
}
Write-Host '  [ok] env.json con SUPABASE_URL y SUPABASE_ANON_KEY' -ForegroundColor Green

# 2. Firma de release --------------------------------------------------------
$keyProps = Join-Path $root 'android/key.properties'
if (-not (Test-Path $keyProps)) {
    Write-Host ''
    Write-Host 'FALTA android/key.properties' -ForegroundColor Red
    Write-Host '  El build caeria a la firma DEBUG y Play rechazaria el artefacto.' -ForegroundColor Yellow
    Write-Host '  Ver RELEASE.md (seccion "Crear el keystore") para generarlo.' -ForegroundColor Yellow
    exit 1
}

$storeLine = (Get-Content $keyProps | Where-Object { $_ -match '^\s*storeFile\s*=' })
if ($storeLine) {
    $storePath = ($storeLine -split '=', 2)[1].Trim()
    if (-not [System.IO.Path]::IsPathRooted($storePath)) {
        $storePath = Join-Path (Join-Path $root 'android') $storePath
    }
    if (-not (Test-Path $storePath)) {
        Write-Host ''
        Write-Host "key.properties apunta a un keystore inexistente: $storePath" -ForegroundColor Red
        exit 1
    }
}
Write-Host '  [ok] android/key.properties y keystore presentes' -ForegroundColor Green

# 3. Build -------------------------------------------------------------------
Write-Host ''
Write-Host '  flutter clean + pub get…' -ForegroundColor DarkGray
flutter clean | Out-Null
flutter pub get | Out-Null

Write-Host '  flutter build appbundle --release…' -ForegroundColor DarkGray
flutter build appbundle --release --dart-define-from-file=env.json
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$aab = Join-Path $root 'build/app/outputs/bundle/release/app-release.aab'
Write-Host ''
Write-Host "  AAB: $aab" -ForegroundColor Green
if (Test-Path $aab) {
    $sizeMb = [math]::Round((Get-Item $aab).Length / 1MB, 1)
    Write-Host "       $sizeMb MB" -ForegroundColor DarkGray
}

if ($Apk) {
    Write-Host ''
    Write-Host '  flutter build apk --release…' -ForegroundColor DarkGray
    flutter build apk --release --dart-define-from-file=env.json
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  APK: $(Join-Path $root 'build/app/outputs/flutter-apk/app-release.apk')" -ForegroundColor Green
    }
}

Write-Host ''
Write-Host 'Siguiente paso: subir el .aab a Play Console → Producción → Crear nueva versión.' -ForegroundColor Cyan
Write-Host 'Verifica la firma con:' -ForegroundColor DarkGray
Write-Host '  keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab' -ForegroundColor DarkGray
Write-Host ''
