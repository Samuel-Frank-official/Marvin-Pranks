# Marvin-Pranks

## Skipper-Gag (`skipper/`)

Alle 10 Minuten taucht Skipper halbtransparent an einer zufälligen Stelle des Bildschirms auf (Standardhöhe die Hälfte des Bildschirms), bleibt 1 Sekunde und blendet sich wieder aus. Das Fenster ist komplett durchklickbar, stiehlt nie den Fokus und hat keinen Taskleisteneintrag.

| Datei | Zweck |
| --- | --- |
| `Skipper.bat` | Startet den Gag (Doppelklick) |
| `Skipper.ps1` | Gleiche Funktion als reine PowerShell-Datei (Alternative zur `.bat`) |
| `Skipper-Stopp.bat` | Beendet ihn (Doppelklick), stoppt beide Varianten |
| `skipper.png` | Das Bild. Fehlt es, erscheint stattdessen "Du Skipper!" als Text |

### Benutzung

1. Den Ordner `skipper` auf den PC kopieren, alle Dateien zusammen lassen.
2. **Testen:** Im Ordner in die Adresszeile des Explorers `cmd` tippen, Enter, dann `Skipper.bat test`. Skipper erscheint sofort einmal, Fehler werden im Fenster angezeigt.
3. **Starten:** `Skipper.bat` doppelklicken. Ein Konsolenfenster blitzt ca. 1 Sekunde auf, danach läuft er unsichtbar. Der erste Auftritt kommt nach 10 Minuten.
4. **Beenden:** `Skipper-Stopp.bat` doppelklicken. Abmelden oder Neustart beendet ihn auch, es gibt keinen Autostart.

### Anpassen

Oben in `Skipper.bat` im Abschnitt `EINSTELLUNGEN`:

- `$IntervallMinuten` (Standard 10, Kommazahlen mit Punkt, z. B. `0.5` zum Ausprobieren)
- `$AnzeigeSekunden` (Standard 1)
- `$TransparenzProzent` (Standard 50, 0 = deckend, 100 = unsichtbar)
- `$HoeheAnteil` (Standard 0.5 = halbe Bildschirmhöhe; 0.25 = ein Viertel, 1.0 = volle Höhe. Breite ergibt sich aus dem Seitenverhältnis)

### PowerShell-Variante (`Skipper.ps1`)

Gleiche Funktion und dieselben Einstellungen wie die `.bat`, nur als reine `.ps1`. Sie startet sich selbst einmal ohne Fenster neu, zeigt also **kein** dauerhaftes Konsolenfenster.

- Starten ohne Fenster (z. B. als Ziel einer Verknüpfung im Autostart):
  `powershell -NoProfile -WindowStyle Hidden -File "C:\Pfad\zu\Skipper.ps1"`
- Testen (zeigt ihn sofort einmal, mit Meldungen):
  `powershell -NoProfile -File "C:\Pfad\zu\Skipper.ps1" test`
- Beenden: `Skipper-Stopp.bat` (nutzt dieselben Namen, beendet auch die `.ps1`).
- Falls beim Start eine Meldung zur ExecutionPolicy kommt: einmalig und ohne Admin
  `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` setzen. Das betrifft nur das Starten von `.ps1`-Dateien.

### Gut zu wissen

- Läuft nur mit Bordmitteln (Windows PowerShell 5.1 und WPF): keine Installation, keine Adminrechte, kein Netzwerk, kein Logging, schreibt keine Dateien.
- Im Task-Manager heißt der Prozess "Windows PowerShell". Im Reiter "Details" mit eingeblendeter Spalte "Befehlszeile" steht "Skipper-Gag" drin.
- Bei Bildschirmfreigaben (Teams, Zoom) ist Skipper für alle sichtbar. Vor wichtigen Calls besser kurz stoppen.
- Wenn die Firmen-IT PowerShell einschränkt, startet er nicht. Der Testmodus zeigt das sofort an.
- Falls Windows beim ersten Start warnt (Datei aus dem Internet): Rechtsklick auf die Datei, Eigenschaften, unten "Zulassen" anhaken.
