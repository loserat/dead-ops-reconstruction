# Tests und nachgewiesener Stand

Stand: 03.11.2026, zusammengeführte Entwicklungsversion 0.81. Getestet mit Xcode 27.0 auf einem Mac mit Apple-Chip. Die maschinenlesbare [Prüfübersicht](verification-0.81.json) dokumentiert die Ergebnisse dieses Veröffentlichungsstands.

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
