# ZeroQ Watchdog (minimalista y robusto)
# - Distro: Ubuntu-ZeroQ
# - Revisa Docker y contenedores críticos en WSL
# - Si falta alguno o no está running => docker compose up -d
# - Logs diarios en C:\local\logs
# Requisitos:
#   - wsl.exe funcional
#   - docker + docker compose funcionando dentro de la distro
#   - /mnt/c/local/docker-compose.yml existente

$ErrorActionPreference = "Stop"

# ==== Config ====
$distro    = "Ubuntu-ZeroQ"
$linuxUser = "oangel"

$workDirWsl   = "/mnt/c/local"
$composeName  = "docker-compose.yml"   # relativo al workDirWsl
$composeWsl   = "$workDirWsl/$composeName" # solo para checks/logs

$critical = @("zeroq","postgres","redis","printer")

# ==== Logging ====
$logDir = "C:\local\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = Join-Path $logDir ("watchdog-" + (Get-Date -Format "yyyyMMdd") + ".log")

function Log([string]$m) {
  $line = ("[{0}] {1}" -f (Get-Date -Format o), $m)
  $line | Out-File -FilePath $logFile -Append -Encoding utf8
}

# ==== WSL runner (captura stdout+stderr y exitcode) ====
function RunWsl([string]$cmd) {
  # Importante: cmd debe ser una sola línea o usar ';' (evitar CRLF)
  # Forzar que todo sea string, no objetos de PowerShell
  $out = @()
  $output = & wsl.exe -d $distro -u $linuxUser -- bash -lc $cmd 2>&1
  foreach ($line in $output) {
    $out += $line.ToString()
  }
  $code = $LASTEXITCODE
  return @{
    Code = $code
    Out  = ($out -join "`n")
  }
}

# ==== Start ====
Log "START watchdog (distro=$distro user=$linuxUser)"

# 0) sanity: compose existe (para que el recovery no sea humo)
$existsCompose = RunWsl "test -f '$composeWsl'"
if ($existsCompose.Code -ne 0) {
  Log "ERROR: compose file not found in WSL: $composeWsl"
  exit 2
}

# 1) Warmup: espera hasta 90s a que docker responda
$deadline = (Get-Date).AddSeconds(90)
$dockerReady = $false

do {
  $r = RunWsl "docker ps >/dev/null 2>&1"
  if ($r.Code -eq 0) { $dockerReady = $true; break }
  Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)

if (-not $dockerReady) {
  Log "WARMUP: docker not ready (no recovery)."
  exit 0
}

# 2) Check determinístico: para cada contenedor => existe y running
# Vamos a verificar cada contenedor individualmente para evitar problemas de parsing
$needsFix = $false
$problems = New-Object System.Collections.Generic.List[string]

foreach ($containerName in $critical) {
  $checkCmd = "docker inspect -f '{{.Name}} {{.State.Running}}' $containerName 2>/dev/null"
  $result = RunWsl $checkCmd
  
  if ($result.Code -ne 0) {
    $needsFix = $true
    $problems.Add("MISSING $containerName")
  } else {
    $output = $result.Out.Trim()
    if ($output -match '/(.*?)\s+(true|false)') {
      $running = $Matches[2]
      if ($running -ne 'true') {
        $needsFix = $true
        $problems.Add("NOTRUNNING $containerName")
      }
    } else {
      # Si no coincide el patrón esperado
      $needsFix = $true
      $problems.Add("BADFORMAT $containerName : $output")
    }
  }
}

# 3) Aplicar recovery si es necesario
if ($needsFix) {
  Log ("FAIL: critical containers unhealthy => " + ($problems -join ", "))

  # 3) Recovery: compose up -d
  Log "RECOVERY: docker compose up -d (workdir=$workDirWsl, compose=$composeName)"
  $fix = RunWsl "cd '$workDirWsl' && docker compose -f '$composeName' up -d"

  if ($fix.Code -ne 0) {
    Log "RECOVERY-ERROR: exit=$($fix.Code) output=$($fix.Out)"
    exit 1
  }

  Start-Sleep -Seconds 3

  # Re-check: verificar estado después de recovery
  $recheckResults = New-Object System.Collections.Generic.List[string]
  foreach ($containerName in $critical) {
    $recheckCmd = "docker inspect -f '{{.Name}} {{.State.Running}}' $containerName 2>/dev/null"
    $recheckRes = RunWsl $recheckCmd
    if ($recheckRes.Code -eq 0) {
      $recheckResults.Add("$containerName : $($recheckRes.Out.Trim())")
    } else {
      $recheckResults.Add("$containerName : STILL_MISSING")
    }
  }
  Log ("RECOVERY-DONE: " + ($recheckResults -join " | "))
  exit 0
}

Log "OK: all critical containers running."
exit 0

