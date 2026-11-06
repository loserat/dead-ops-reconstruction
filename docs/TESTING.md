# Tests und nachgewiesener Stand

Stand: 06.11.2026, Quellstand 0.82. Der veröffentlichte Mac-Download bleibt auf 0.81. Getestet mit Xcode 27.0 auf einem Mac mit Apple-Chip.

## Version 0.82: Animation und Beleuchtung

Die [Prüfübersicht 0.82](verification-0.82.json) enthält die Zahlen und Grenzen dieser Fassung.

- Alle 55 Logikprogramme mit 6.163 PASS-Zeilen sowie drei normale und drei kooperative Acht-Runden-Simulationen erneut bestanden; ohne Godmode oder injizierte Ausrüstung.
- Direkter Mac-Build und tvOS-Geräte-SDK-Build bestanden. Beide Xcode-Ziele und `VERSION` stehen auf 0.82 / 82; dies ist kein neuer Apple-TV-Gerätetest.
- Native Mac-Paket-, Figuren- und Kameraprüfungen bestanden. Dazu zählen 24 echte Bewegungs-/Zielrichtungen, 576 Pickup-Pixelmasken, 42 Kamerabilder, 8.568 Geometrie- und 4.592 Karten-/Zugangsprojektionen. Die automatische ganze Kartenansicht bleibt erhalten.
- Die neue Animation wurde gegen die bisherige Funktion verglichen: 24.192 Gelenkmatrix-Komponenten stimmen innerhalb 0,00001 überein. Klone besitzen getrennte Gelenke. Entfernung, Reset, wiederverwendete Kennungen und gemischte Gegnermodelle sind geprüft.
- Sechs Vorher-/Nachher-Lichtszenen der Runden 1, 3, 4, 5, 7 und 8 geprüft. Unbewegte Bildpaare zeigen keine Änderungen über 8/255. Dies prüft statische Stabilität; es ist keine vollständige Abnahme jedes möglichen Flimmerns in Bewegung.

Der isolierte Animationsvergleich enthält jeweils 900 Messbilder mit 176 Gegnern, aufgewärmt und in wechselnder Reihenfolge. Er misst ausschließlich die Aktualisierung der Gelenke, nicht die gesamte Bildrate:

| Animationszeit für 176 Gegner | Vorher | 0.82 |
|---|---:|---:|
| Median | 0,644 ms | 0,310 ms |
| 95. Perzentil | 0,741 ms | 0,472 ms |
| Langsamstes Einzelbild | 1,007 ms | 8,490 ms |

Der Median sinkt um etwa 52 %. Ein größerer einzelner Ausreißer bleibt sichtbar; aus dem Median folgt keine garantierte Zeit für jedes Bild. Die Beleuchtungsvergleiche bei 2560 × 1440 verwenden einen gegen Szene und HUD kalibrierten Metal-Renderpfad. Die GPU-Zeiten liegen in derselben Größenordnung; daraus wird kein eigener Grafikgeschwindigkeitsgewinn abgeleitet.

Zusätzlich liefen je vier echte Spielfenster-Lastfälle für die alte und neue Fassung. Bei hoher Vier-Spieler-Last lag das 95. Perzentil der Spielaktualisierung bei etwa 4,07 ms vorher und 3,10 ms im neuen aktiven Lauf. Die Bildabstände lagen dort im 95. Perzentil bei 20,31 bzw. 18,41 ms; Bilder über 25 ms traten weiterhin auf (4 bzw. 6). Es sind kurze gestellte Lastläufe mit geschütztem Spieler, Fahrzeugen, 32 Funden und bis zu 176 dargestellten Gegnern. Die wechselnden Bewegungen und Effektzahlen erlauben keine genaue allgemeine Beschleunigungsangabe. Ein zusätzlicher neuer Lauf ohne Eingabefokus wurde getrennt erfasst; auch kurze Fokuswechsel im Wiederholungslauf sind separat gruppiert. Keine parallelen Builds oder anderen eigenen Grafikprüfungen während der akzeptierten Messungen.

**Stabile 60 FPS sind weiterhin nicht abgenommen.** Auch menschliches Spielgefühl, eine aktuelle physische Controller-/Hörprüfung und eine längere normale Spielrunde bleiben offen. Es wurden keine Bildschirmaufnahmen erstellt. Prüfberichte und die kleine Bildauswahl liegen lokal unter `work/maintenance/mac-render-2026-11-06` relativ zum Arbeitsordner oberhalb von `outputs/`.

Den unabhängigen nativen Vergleich erneut ausführen (benötigt einen verfügbaren Metal-Grafikprozessor; neues Ausgabeziel wählen):

```sh
python3 scripts/check_mac_render.py Build/RenderReport
```

Der Vergleich erzeugt zwölf eigene Szenenbilder und Messberichte. Rohbilder nach der Sichtprüfung auf eine kleine Auswahl begrenzen. Die Testanwendung pollt keine realen Eingaben und spielt keinen Ton.

## Veröffentlichter Stand 0.81

Die maschinenlesbare [Prüfübersicht](verification-0.81.json) dokumentiert den bisherigen Veröffentlichungsstand. Die folgenden Angaben beziehen sich auf 0.81:

## Reproduzierbare Befehle

```sh
./Tests/check.sh all
./Tests/check.sh opening
./build.sh mac
./build.sh tv-device
python3 scripts/check_docs.py
```

`all` führt die 55 reinen Swift-Prüfprogramme gemeinsam aus. `opening` prüft normale erste acht Runden und einen kooperativen Durchlauf mit automatisierten Piloten. Die Piloten verwenden die Spielsimulation; sie sind keine Menschen mit physischen Controllern und kein Bildratenbeweis.

Zusätzlich kann das tatsächlich gebaute Mac-Paket ohne Spielfenster geprüft werden:

```sh
Build/Mac/DeadOpsReconstruction.app/Contents/MacOS/DeadOpsReconstruction --verify-package /tmp/deadops-package-check
Build/Mac/DeadOpsReconstruction.app/Contents/MacOS/DeadOpsReconstruction --verify-camera-art /tmp/deadops-camera-check
```

Für jede Prüfung ein neues, leeres Ausgabeziel verwenden. Die Grafikprüfungen benötigen einen verfügbaren Metal-Grafikprozessor. Sie erzeugen eigene Szenenbilder und nehmen keinen Bildschirm auf. Die entstandenen Bilder gehören nicht in die Git-Historie.

## Für diesen Quellstand erneut geprüft

- Normale und kooperative Acht-Runden-Simulationen erfolgreich: 6 automatische Durchläufe.
- Frischer Export ausschließlich der 217 veröffentlichten Dateien erfolgreich gebaut und nativ als Paket geprüft; historische lokale Ordner waren dabei nicht vorhanden. Die temporäre Kopie wurde anschließend entfernt.
- Mac-Kommandozeilen-Build und Xcode-Release-Build erfolgreich; beide melden Version 0.81 / Build 81.
- tvOS-Geräte-SDK-Build erfolgreich; keine Installation oder Hardwareprüfung daraus abgeleitet.
- Alle 55 Logik-Prüfprogramme erfolgreich, mit 6.163 protokollierten Einzelbestätigungen.
- Ganze spielbare Karte und nahe Zugänge über 40 Rundenlayouts, zwei Orientierungen und fünf Seitenverhältnisse geprüft. Die ersten acht Runden behalten beim geprüften Bodenlauf ihren festen Bildausschnitt. Spätere Karten dürfen die bestehende nötige Höhen-/Körpersicherheit verwenden.
- Mac-Paketprüfung mit Ressourcenprüfung sowie Pause-, Eingabe- und Lebensabläufen erfolgreich.
- Native Kameraprüfung: 42 eigene Renderbilder, 8.568 Geometrieprojektionen und 4.592 Karten-/Zugangsprojektionen erfolgreich, einschließlich tatsächlicher Pixelkalibrierung.

Die alte Kameraprüfung erwartete vollständig sichtbare entfernte Außenwege. Sie wurde an die neuere Vorgabe angepasst. Unabhängige Proben laufen weiterhin auf tatsächlichen Gegnerwegen; die Kamera verändert keine Spawnpositionen. Für spätere Karten verwenden die Bewegungstests begehbare Positionen und die reale Bodenhöhe.

## Frühere Nachweise und offene Grenzen

Für den früheren 0.81-Kandidaten existiert ein kurzer nativer Lasttest im Fenster. Dabei blieben unter hoher Last langsamere Einzelbilder vorhanden; stabile 60 FPS wurden nicht abgenommen. Der neue zusammengeführte Quellstand hat durch die Veröffentlichung keine zusätzliche Echtfenster-Leistungsabnahme erhalten.

Weiter offen: längerer normaler Lauf im echten 0.81-Spielfenster, menschliche Bewertung von Perspektive und Balance, aktuelle physische PS5-/Mehrcontroller-Prüfung, Hörabnahme und Apple-TV-Gerätelauf. Einzelbilder, Compiler-Erfolg und automatisierte Piloten ersetzen diese Prüfungen nicht.


## Mac-Download 0.81

Das fertige ZIP wurde aus dem veröffentlichten Quellstand `5306b6a` gebaut;
die Spielquellen blieben danach unverändert. Es wurde erneut entpackt:
Ausführbarkeit, strenge lokale App-Signatur, alle 15 Ressourcen und die
native Paketprüfung bestanden. Es werden nur Systembibliotheken benötigt.
Die [Download-Prüfübersicht](download-0.81.json) enthält Größe und Prüfsumme.

Die lokale Gatekeeper-Standardbewertung wurde abgewiesen: Das Paket ist
ad-hoc-signiert und nicht von Apple notarisiert. Dies ist ausdrücklich keine
bestandene normale Weitergabeprüfung. Hinweise zum ersten Start stehen in
der [Installation](INSTALLATION.md#erster-start). Ein Fremd-Mac- oder neuer
physischer Controller-Test ist damit nicht ersetzt.
