<# : Skipper-Gag
@echo off
:: SKIPPER-GAG: Doppelklick startet ihn unsichtbar im Hintergrund, alle paar Minuten taucht Skipper kurz auf.
:: Anpassen: Intervall, Anzeigedauer, Transparenz und Größe stehen weiter unten im Abschnitt EINSTELLUNGEN.
:: Bild: skipper.png in denselben Ordner legen. Fehlt es, erscheint stattdessen der Text "Du Skipper!".
:: Testen: Eingabeaufforderung im Ordner öffnen und "Skipper.bat test" eingeben, dann kommt er sofort einmal.
:: Beenden: Skipper-Stopp.bat doppelklicken. Abmelden oder Neustart beendet ihn auch, es gibt keinen Autostart.
setlocal
set "SKIPPER_DATEI=%~f0"
set "SKIPPER_MODUS=%~1"
powershell.exe -NoLogo -NoProfile -Sta -Command "& ([scriptblock]::Create([IO.File]::ReadAllText($env:SKIPPER_DATEI, [Text.Encoding]::UTF8)))"
if errorlevel 1 pause
exit /b
#>
# ------------------------------------------------------------------------------
# Ab hier PowerShell. Der Batch-Teil oben startet nur PowerShell mit dieser Datei,
# für PowerShell ist er ein einziger großer Kommentar.
# ------------------------------------------------------------------------------

# ================================ EINSTELLUNGEN ================================
$IntervallMinuten   = 10   # Alle wie viele Minuten Skipper auftaucht (Kommazahlen mit Punkt, z. B. 0.5)
$AnzeigeSekunden    = 1    # Wie lange er sichtbar bleibt (Ein- und Ausblenden kommen jeweils noch dazu)
$TransparenzProzent = 50   # 0 = voll deckend, 100 = unsichtbar
$HoeheAnteil        = 0.5  # Höhe von Skipper als Anteil der Bildschirmhöhe (0.25 = ein Viertel, 0.5 = die Hälfte, 1.0 = volle Höhe)
# ===============================================================================

# Ab hier nur ändern, wenn du weißt, was du tust.
$ErrorActionPreference = 'Stop'

# Wenn die IT PowerShell eingeschränkt hat, funktioniert die Anzeige nicht. Dann lieber gleich Bescheid geben.
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host 'PowerShell ist auf diesem PC eingeschränkt (vermutlich von der IT). Skipper kann hier leider nicht laufen.'
    exit 1
}

# Einstellungen in sinnvolle Grenzen bringen
$IntervallMinuten   = [Math]::Max(0.1, [double]$IntervallMinuten)
$AnzeigeSekunden    = [Math]::Max(0.5, [double]$AnzeigeSekunden)
$TransparenzProzent = [Math]::Min(100.0, [Math]::Max(0.0, [double]$TransparenzProzent))
$HoeheAnteil        = [Math]::Min(1.0, [Math]::Max(0.05, [double]$HoeheAnteil))

# Feste Werte
$BlendSekunden = 0.7                        # Dauer des sanften Ein- bzw. Ausblendens
$MutexName     = 'Local\SkipperGag'         # Merker "Skipper läuft schon" (gilt nur für diese Windows-Anmeldung)
$StoppName     = 'Local\SkipperGag-Stopp'   # Signal, das Skipper-Stopp.bat setzt
$Ordner        = Split-Path -Parent $env:SKIPPER_DATEI
$BildPfad      = Join-Path $Ordner 'skipper.png'
$Modus         = "$env:SKIPPER_MODUS".Trim().ToLowerInvariant()

# Windows-Fensterstile
$WS_POPUP          = [int]-2147483648   # 0x80000000: Fenster ohne Rahmen und Titelleiste
$WS_VISIBLE        = 0x10000000         # sofort sichtbar (der Inhalt startet aber komplett durchsichtig)
$WS_DISABLED       = 0x08000000         # nimmt keinerlei Eingaben an
$WS_EX_TOPMOST     = 0x00000008         # immer im Vordergrund
$WS_EX_TRANSPARENT = 0x00000020         # Mausklicks gehen durch das Fenster hindurch
$WS_EX_TOOLWINDOW  = 0x00000080         # kein Taskleisteneintrag, nicht in Alt+Tab
$WS_EX_LAYERED     = 0x00080000         # echte Transparenz pro Pixel
$WS_EX_NOACTIVATE  = 0x08000000         # stiehlt nie den Fokus

# Gemeinsamer Zustand. Eine Hashtable, damit auch die Timer-Ereignisse sicher darauf zugreifen können.
$Zustand = @{
    Testmodus   = $false
    Fehler      = $false
    Fenster     = $null
    FensterEnde = [DateTime]::MinValue
    Timer       = $null
    Uhr         = $null
    Stopp       = $null
    Zufall      = $null
}

# ------------------------------------------------------------------------------
# Start und Beenden
# ------------------------------------------------------------------------------

function Test-SkipperLaeuft {
    # $true, wenn schon ein Skipper im Hintergrund läuft
    $vorhanden = $null
    if ([System.Threading.Mutex]::TryOpenExisting($MutexName, [ref]$vorhanden)) {
        $vorhanden.Dispose()
        return $true
    }
    return $false
}

function Start-Normal {
    # Nach dem Doppelklick: kurz prüfen, dann eine zweite PowerShell ganz ohne Fenster starten und selbst beenden.
    # Dadurch schließt sich das Konsolenfenster sofort wieder.
    if (Test-SkipperLaeuft) {
        Write-Host 'Skipper läuft bereits. Zum Beenden Skipper-Stopp.bat doppelklicken.'
        Start-Sleep -Seconds 4
        exit 0
    }
    $start = [System.Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'powershell.exe'))
    # Der Kommentar "Skipper-Gag" macht den Prozess im Task-Manager erkennbar (Reiter Details, Spalte Befehlszeile).
    $start.Arguments        = '-NoLogo -NoProfile -NonInteractive -Sta -Command "<# Skipper-Gag #> & ([scriptblock]::Create([IO.File]::ReadAllText($env:SKIPPER_DATEI, [Text.Encoding]::UTF8)))"'
    $start.UseShellExecute  = $false
    $start.CreateNoWindow   = $true             # kein Konsolenfenster, auch nicht kurz
    $start.WorkingDirectory = $env:SystemRoot   # damit der Skipper-Ordner nicht "in Benutzung" ist
    $start.EnvironmentVariables['SKIPPER_MODUS'] = 'hintergrund'
    [void][System.Diagnostics.Process]::Start($start)
    exit 0
}

function Start-Hintergrund {
    # Der eigentliche Skipper: läuft unsichtbar, bis Skipper-Stopp.bat das Signal gibt oder Windows sich abmeldet.
    $neu = $false
    $sperre = [System.Threading.Mutex]::new($true, $MutexName, [ref]$neu)
    if (-not $neu) {
        # Es läuft schon einer (z. B. doppelt angeklickt), also leise wieder gehen.
        $sperre.Dispose()
        exit 0
    }
    $Zustand.Stopp = [System.Threading.EventWaitHandle]::new($false, [System.Threading.EventResetMode]::ManualReset, $StoppName)
    [void]$Zustand.Stopp.Reset()
    try {
        Initialisiere-Wpf
        $Zustand.Uhr = [System.Diagnostics.Stopwatch]::StartNew()
        Starte-Schleife
    }
    finally {
        $Zustand.Stopp.Dispose()
        $sperre.ReleaseMutex()
        $sperre.Dispose()
    }
    exit 0
}

function Start-Test {
    # Testmodus: Skipper einmal sofort zeigen, danach beenden. Fehler werden hier sichtbar ausgegeben.
    Write-Host 'Testmodus: Skipper erscheint jetzt einmal und verschwindet wieder ...'
    $Zustand.Testmodus = $true
    Initialisiere-Wpf
    Zeige-Skipper
    Starte-Schleife
    if ($Zustand.Fehler) { exit 1 }
    Write-Host 'Test fertig. Wenn du ihn gesehen hast, passt alles.'
    exit 0
}

function Initialisiere-Wpf {
    # WPF und WinForms gehören zu Windows (.NET Framework), es wird nichts installiert.
    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Windows.Forms
    $Zustand.Zufall = [System.Random]::new()
}

function Starte-Schleife {
    # Ein Takt pro halbe Sekunde: Stopp-Signal prüfen, altes Fenster aufräumen, bei Bedarf Skipper zeigen.
    $takt = [System.Windows.Threading.DispatcherTimer]::new()
    $takt.Interval = [TimeSpan]::FromMilliseconds(500)
    $takt.add_Tick({ Pruefe-Takt })
    $Zustand.Timer = $takt
    $takt.Start()
    [System.Windows.Threading.Dispatcher]::Run()   # läuft, bis Beende-Schleife aufgerufen wird
}

function Pruefe-Takt {
    try {
        if ($Zustand.Stopp -and $Zustand.Stopp.WaitOne(0)) {
            Beende-Schleife
            return
        }
        if ($Zustand.Fenster) {
            if ([DateTime]::Now -ge $Zustand.FensterEnde) {
                Schliesse-Fenster
                if ($Zustand.Testmodus) { Beende-Schleife }
            }
            return
        }
        if (-not $Zustand.Testmodus -and $Zustand.Uhr.Elapsed.TotalMinutes -ge $IntervallMinuten) {
            $Zustand.Uhr.Restart()
            Zeige-Skipper
        }
    }
    catch {
        Schliesse-Fenster
        if ($Zustand.Testmodus) {
            Write-Host "Fehler: $($_.Exception.Message)"
            $Zustand.Fehler = $true
            Beende-Schleife
        }
        # Im Hintergrund wird ein Fehler still übergangen (kein Logging), beim nächsten Mal versucht er es neu.
    }
}

function Beende-Schleife {
    Schliesse-Fenster
    if ($Zustand.Timer) { $Zustand.Timer.Stop() }
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvokeShutdown([System.Windows.Threading.DispatcherPriority]::Normal)
}

function Schliesse-Fenster {
    $fenster = $Zustand.Fenster
    $Zustand.Fenster = $null
    if ($fenster) {
        try { $fenster.Dispose() } catch { }
    }
}

# ------------------------------------------------------------------------------
# Anzeige
# ------------------------------------------------------------------------------

function Get-DpiFaktor {
    # Fragt über ein unsichtbares Hilfsfenster ab, wie stark Windows skaliert (1.0 = 100 Prozent, 1.5 = 150 Prozent ...).
    $p = [System.Windows.Interop.HwndSourceParameters]::new('Skipper-Gag DPI', 1, 1)
    $p.WindowStyle         = $WS_POPUP                                # ohne WS_VISIBLE: wird nie angezeigt
    $p.ExtendedWindowStyle = $WS_EX_TOOLWINDOW -bor $WS_EX_NOACTIVATE
    $hilfe = [System.Windows.Interop.HwndSource]::new($p)
    try {
        $faktor = $hilfe.CompositionTarget.TransformToDevice.M11
        if ($faktor -gt 0) { return $faktor }
        return 1.0
    }
    catch { return 1.0 }
    finally { $hilfe.Dispose() }
}

function Lade-Bitmap([byte[]]$bytes, [int]$hoehePx) {
    # Lädt das PNG aus dem Speicher (die Datei bleibt dabei nicht gesperrt). Mit $hoehePx > 0 direkt in Zielgröße.
    $bmp = [System.Windows.Media.Imaging.BitmapImage]::new()
    $bmp.BeginInit()
    $bmp.CacheOption  = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bmp.StreamSource = [System.IO.MemoryStream]::new($bytes)
    if ($hoehePx -gt 0) { $bmp.DecodePixelHeight = $hoehePx }
    $bmp.EndInit()
    $bmp.Freeze()
    return $bmp
}

function Neues-Bild([double]$faktor, [double]$maxHoehePx) {
    # Skipper als Bild: höchstens $maxHoehePx hoch, nie größer als das Original, Seitenverhältnis bleibt.
    $bytes    = [System.IO.File]::ReadAllBytes($BildPfad)
    $original = Lade-Bitmap $bytes 0
    $hoehePx  = [int][Math]::Max(1, [Math]::Min($original.PixelHeight, [Math]::Floor($maxHoehePx)))
    $breitePx = [int][Math]::Max(1, [Math]::Round($hoehePx * $original.PixelWidth / $original.PixelHeight))

    $img = [System.Windows.Controls.Image]::new()
    $img.Source  = Lade-Bitmap $bytes $hoehePx
    $img.Stretch = [System.Windows.Media.Stretch]::Fill
    $img.Width   = $breitePx / $faktor   # WPF rechnet in skalierten Einheiten, daher durch den DPI-Faktor
    $img.Height  = $hoehePx / $faktor
    [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($img, [System.Windows.Media.BitmapScalingMode]::HighQuality)
    return $img
}

function Neuer-Text([double]$faktor, [double]$maxHoehePx, [double]$maxBreitePx) {
    # Ersatz, falls skipper.png fehlt: "Du Skipper!" in weißer Schrift mit schwarzem Rand (auf hell und dunkel lesbar)
    $schrift = [System.Windows.Media.Typeface]::new(
        [System.Windows.Media.FontFamily]::new('Segoe UI'),
        [System.Windows.FontStyles]::Normal,
        [System.Windows.FontWeights]::Black,
        [System.Windows.FontStretches]::Normal)
    $text = [System.Windows.Media.FormattedText]::new(
        'Du Skipper!',
        [System.Globalization.CultureInfo]::GetCultureInfo('de-DE'),
        [System.Windows.FlowDirection]::LeftToRight,
        $schrift,
        100.0,
        [System.Windows.Media.Brushes]::White)

    # Schrift in eine Form umwandeln, damit sie einen Umriss bekommen kann
    $rand   = 4.0
    $form   = $text.BuildGeometry([System.Windows.Point]::new(0, 0))
    $grenze = $form.Bounds
    $gruppe = [System.Windows.Media.GeometryGroup]::new()
    [void]$gruppe.Children.Add($form)
    $gruppe.Transform = [System.Windows.Media.TranslateTransform]::new($rand - $grenze.X, $rand - $grenze.Y)

    $pfad = [System.Windows.Shapes.Path]::new()
    $pfad.Data            = $gruppe
    $pfad.Fill            = [System.Windows.Media.Brushes]::White
    $pfad.Stroke          = [System.Windows.Media.Brushes]::Black
    $pfad.StrokeThickness = $rand
    $pfad.StrokeLineJoin  = [System.Windows.Media.PenLineJoin]::Round

    # Passend skalieren: höchstens $maxHoehePx hoch und $maxBreitePx breit
    $breite0  = $grenze.Width + 2 * $rand
    $hoehe0   = $grenze.Height + 2 * $rand
    $massstab = [Math]::Min($maxHoehePx / $hoehe0, $maxBreitePx / $breite0)
    $box = [System.Windows.Controls.Viewbox]::new()
    $box.Stretch = [System.Windows.Media.Stretch]::Uniform
    $box.Width   = $breite0 * $massstab / $faktor
    $box.Height  = $hoehe0 * $massstab / $faktor
    $box.Child   = $pfad
    return $box
}

function Zeige-Skipper {
    Schliesse-Fenster
    $faktor     = Get-DpiFaktor
    $arbeit     = [System.Windows.Forms.SystemInformation]::WorkingArea            # Hauptbildschirm ohne Taskleiste, in Pixeln
    $maxHoehePx = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height * $HoeheAnteil

    # Inhalt bauen: das Bild, oder ersatzweise den Text
    $inhalt = $null
    if (Test-Path -LiteralPath $BildPfad -PathType Leaf) {
        try {
            $inhalt = Neues-Bild $faktor $maxHoehePx
        }
        catch {
            $inhalt = $null
            if ($Zustand.Testmodus) { Write-Host "skipper.png ließ sich nicht laden ($($_.Exception.Message)), zeige den Text." }
        }
    }
    elseif ($Zustand.Testmodus) {
        Write-Host 'skipper.png nicht gefunden, zeige stattdessen den Text.'
    }
    if (-not $inhalt) {
        # Text: halb so hoch wie das Bild (1/8 der Bildschirmhöhe), höchstens 60 Prozent der Breite
        $inhalt = Neuer-Text $faktor ($maxHoehePx / 2) ($arbeit.Width * 0.6)
    }
    $inhalt.IsHitTestVisible  = $false
    $inhalt.UseLayoutRounding = $true
    $inhalt.Opacity           = 0

    # Zufällige Position, bei der Skipper komplett auf den Hauptbildschirm passt
    $breitePx = [int][Math]::Ceiling($inhalt.Width * $faktor)
    $hoehePx  = [int][Math]::Ceiling($inhalt.Height * $faktor)
    $rechts   = $arbeit.Right - $breitePx
    $unten    = $arbeit.Bottom - $hoehePx
    $x = $arbeit.Left
    $y = $arbeit.Top
    if ($rechts -gt $x) { $x = $Zustand.Zufall.Next($arbeit.Left, $rechts + 1) }
    if ($unten -gt $y)  { $y = $Zustand.Zufall.Next($arbeit.Top, $unten + 1) }
    if ($Zustand.Testmodus) {
        Write-Host ('Position {0},{1}  Größe {2}x{3} Pixel  Windows-Skalierung {4} Prozent' -f $x, $y, $breitePx, $hoehePx, [Math]::Round($faktor * 100))
    }

    # Das Fenster: randlos, durchklickbar, nie aktiv, immer oben, ohne Taskleisteneintrag
    $p = [System.Windows.Interop.HwndSourceParameters]::new('Skipper-Gag', $breitePx, $hoehePx)
    $p.PositionX           = $x
    $p.PositionY           = $y
    $p.WindowStyle         = $WS_POPUP -bor $WS_VISIBLE -bor $WS_DISABLED
    $p.ExtendedWindowStyle = $WS_EX_LAYERED -bor $WS_EX_TRANSPARENT -bor $WS_EX_NOACTIVATE -bor $WS_EX_TOPMOST -bor $WS_EX_TOOLWINDOW
    $p.UsesPerPixelOpacity = $true
    $fenster = [System.Windows.Interop.HwndSource]::new($p)
    $fenster.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
    $fenster.RootVisual    = $inhalt
    $Zustand.Fenster       = $fenster
    $Zustand.FensterEnde   = [DateTime]::Now.AddSeconds(2 * $BlendSekunden + $AnzeigeSekunden + 0.3)

    # Sanft ein- und ausblenden: 0 -> Zieldeckkraft, halten, -> 0
    $ziel  = 1.0 - $TransparenzProzent / 100.0
    $weich = [System.Windows.Media.Animation.SineEase]::new()
    $weich.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseInOut
    $verlauf = [System.Windows.Media.Animation.DoubleAnimationUsingKeyFrames]::new()
    $punkte = @(
        @{ Wert = 0.0;   Sekunde = 0.0 }
        @{ Wert = $ziel; Sekunde = $BlendSekunden }
        @{ Wert = $ziel; Sekunde = $BlendSekunden + $AnzeigeSekunden }
        @{ Wert = 0.0;   Sekunde = 2 * $BlendSekunden + $AnzeigeSekunden }
    )
    foreach ($punkt in $punkte) {
        $zeit = [System.Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::FromSeconds($punkt.Sekunde))
        [void]$verlauf.KeyFrames.Add([System.Windows.Media.Animation.EasingDoubleKeyFrame]::new([double]$punkt.Wert, $zeit, $weich))
    }
    $inhalt.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $verlauf)
}

# ------------------------------------------------------------------------------
# Los geht's
# ------------------------------------------------------------------------------
try {
    switch ($Modus) {
        ''            { Start-Normal }
        'test'        { Start-Test }
        'hintergrund' { Start-Hintergrund }
        default {
            Write-Host "Unbekannter Parameter '$Modus'. Erlaubt ist nur 'test' (oder gar nichts für den normalen Start)."
            exit 1
        }
    }
}
catch {
    # Im Hintergrund gibt es keine Ausgabe und kein Logging. Sichtbar wird ein Fehler nur beim Start und im Testmodus.
    if ($Modus -ne 'hintergrund') { Write-Host "Fehler: $($_.Exception.Message)" }
    exit 1
}
