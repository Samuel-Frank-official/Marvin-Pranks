<# : Skipper-Stopp
@echo off
:: Beendet den laufenden Skipper-Gag. Einfach doppelklicken, das Fenster schließt sich nach ein paar Sekunden von selbst.
setlocal
set "SKIPPER_STOPP_DATEI=%~f0"
powershell.exe -NoLogo -NoProfile -Command "& ([scriptblock]::Create([IO.File]::ReadAllText($env:SKIPPER_STOPP_DATEI, [Text.Encoding]::UTF8)))"
if errorlevel 1 (pause) else (timeout /t 4 >nul)
exit /b
#>
# Ab hier PowerShell. Diese beiden Namen müssen exakt zu Skipper.bat passen.
$MutexName = 'Local\SkipperGag'
$StoppName = 'Local\SkipperGag-Stopp'

# Läuft überhaupt ein Skipper? Nur dann existiert das Stopp-Signal.
$signal = $null
if (-not [System.Threading.EventWaitHandle]::TryOpenExisting($StoppName, [ref]$signal)) {
    Write-Host 'Skipper läuft gerade nicht, es gibt nichts zu beenden.'
    return
}

# Signal setzen: Skipper prüft das jede halbe Sekunde und beendet sich dann selbst.
[void]$signal.Set()
$signal.Dispose()

# Kurz warten, bis er sich wirklich verabschiedet hat (höchstens etwa 5 Sekunden).
for ($i = 0; $i -lt 25; $i++) {
    Start-Sleep -Milliseconds 200
    $sperre = $null
    if (-not [System.Threading.Mutex]::TryOpenExisting($MutexName, [ref]$sperre)) {
        Write-Host 'Skipper wurde beendet. Bis zum nächsten Mal!'
        return
    }
    $sperre.Dispose()
}
Write-Host 'Stopp-Signal gesendet, aber Skipper reagiert nicht. Notfalls im Task-Manager den Prozess "Windows PowerShell" beenden.'
