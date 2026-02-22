<# :
@echo off
if "%1"=="min" goto :run
start "" /min "%~f0" min
goto :eof
:run
:: =========================================================
:: --- KONFIGURATION (Hier anpassen) ---
set "COM_PORT=COM5"
set "BAUD_RATE=1500000"
:: =========================================================

title MATRIXLED FPS SERVER
cd /d "%~dp0"
echo.
echo  [ MATRIXLED NATIVE SERVER ]
echo  ---------------------------
echo  Port:     %COM_PORT%
echo  Speed:    %BAUD_RATE%
echo  Status:   Starte Engine...
echo.

:: Startet den PowerShell-Teil dieser Datei
copy /y "%~f0" "%temp%\matrix_fps.ps1" >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%temp%\matrix_fps.ps1"
del "%temp%\matrix_fps.ps1"
pause
goto :eof
#>

# --- AB HIER BEGINNT DER POWERSHELL CODE ---

$portName = $env:COM_PORT
$baudRate = [int]$env:BAUD_RATE

# Funktion zum Lesen der HWiNFO Registry
function Get-HWiNFO-FPS {
    $paths = @("HKCU:\Software\HWiNFO64\VSB", "HKCU:\Software\HWiNFO32\VSB")
    $candidate = -1
    $global:DebugInfo = ""
    $debugLabels = @()

    foreach ($path in $paths) {
        if (Test-Path $path) {
            $props = Get-ItemProperty -Path $path
            # Scanne Label0 bis Label200
            for ($i = 0; $i -lt 200; $i++) {
                $lKey = "Label$i"
                $vKey = "ValueRaw$i"
                
                if ($props.PSObject.Properties[$lKey]) {
                    $label = $props.$lKey
                    $valRaw = $props.$vKey
                    
                    # Debug: Erste 3 Labels sammeln
                    if ($debugLabels.Count -lt 3) { $debugLabels += "$label=$valRaw" }

                    # Suche nach FPS Schlüsselwörtern
                    if ($label -match "FPS" -or $label -match "Framerate" -or $label -match "Bildrate" -or $label -match "RTSS") {
                        if ($valRaw) {
                            # Komma zu Punkt konvertieren (für deutsche Systeme)
                            $valStr = $valRaw -replace ",", "."
                            try {
                                $val = [int][double]$valStr
                                if ($val -gt 0) {
                                    return $val
                                }
                                # Merke 0 als Kandidat
                                if ($candidate -eq -1) {
                                    $candidate = $val
                                }
                            } catch {}
                        }
                    }
                }
            }
        }
    }
    
    if ($candidate -ge 0) { return $candidate }
    
    if ($debugLabels.Count -gt 0) {
        $global:DebugInfo = $debugLabels -join ", "
    }
    return -1
}

# Serial Port öffnen
try {
    # Prüfen ob Port existiert
    $available = [System.IO.Ports.SerialPort]::GetPortNames()
    if ($available -notcontains $portName) {
        Write-Host " >> FEHLER: Port $portName nicht gefunden!" -ForegroundColor Red
        Write-Host "    Verfuegbare Ports: $($available -join ', ')" -ForegroundColor Yellow
        exit
    }

    $port = New-Object System.IO.Ports.SerialPort $portName, $baudRate
    $port.DtrEnable = $false
    $port.RtsEnable = $false
    $port.Open()
    Write-Host " >> VERBUNDEN! Lese HWiNFO..." -ForegroundColor Green
} catch {
    Write-Host " >> FEHLER: Konnte $portName nicht öffnen." -ForegroundColor Red
    Write-Host "    Details: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host "    TIPP: Schliesse das Python-Script oder andere Tools!" -ForegroundColor Yellow
    exit
}

# Hauptschleife
while ($true) {
    $fps = Get-HWiNFO-FPS
    
    if ($fps -ge 0) {
        try {
            $port.Write("FPS:$fps`n")
            Write-Host -NoNewline "`r >> GAME FPS: $fps      "
        } catch {
            Write-Host "`n >> VERBINDUNG VERLOREN!" -ForegroundColor Red
            break
        }
    } else {
        $msg = "Suche HWiNFO... "
        if ($global:DebugInfo) { $msg += "($global:DebugInfo)" }
        else { $msg += "(Sensoren offen?)" }
        
        if ($msg.Length -gt 78) { $msg = $msg.Substring(0, 75) + "..." }
        Write-Host -NoNewline "`r >> $msg   "
    }
    
    Start-Sleep -Milliseconds 800
}

if ($port.IsOpen) { $port.Close() }