# Entwicklungsablauf

## Ein überprüfbares Ergebnis pro Schritt

1. Eine konkrete Änderung mit einem sichtbaren Erfolgskriterium auswählen.
2. Quellen in `Sources/` ändern; keine neuen dauerhaften Versions-Arbeitsordner aufbauen.
3. Betroffene Logikprüfungen ausführen. Vor einem neuen spielbaren Stand die vollständigen Prüfungen und einen normalen Acht-Runden-Lauf ausführen.
4. Den Mac bauen. Grafikänderungen zusätzlich mit eigenen gerenderten Szenen prüfen; Leistung im echten Spielfenster messen.
5. Ergebnis und Grenzen in `docs/TESTING.md` und `CHANGELOG.md` festhalten. Erst dann als geprüften Stand markieren.

Keine Spielregeln vereinfachen oder Godmode einschalten, um einen normalen Durchlauf bestehen zu lassen. Gestellte Lasttests zusätzlich und ausdrücklich als solche ausweisen. Menschliches Spielgefühl und physische Controller benötigen eigene Abnahme.

## Git und Versionen

`main` enthält den nachvollziehbaren Entwicklungsstand. Größere Änderungen auf einem kurzen Arbeitsbranch vorbereiten. Ein Commit beschreibt einen zusammengehörigen Schritt und nennt passende Prüfungen. Zusätzlich zum Quellcode gibt es ein Mac-Downloadpaket unter GitHub Releases. Es ist eine lokal signierte, nicht notarisierte Vorabversion; keine App-Store-Veröffentlichung.

Vor dem Hochladen:

```sh
python3 scripts/check_docs.py
git status --short
git diff --cached --stat
```

`VERSION`, die Versionsangaben beider Xcode-Ziele und die Dokumentation bei einem Versionswechsel gemeinsam anpassen. Persönliche Signierungseinstellungen nicht committen. Ein Tag kennzeichnet einen konkreten Quellstand; er ersetzt keine Hardwareprüfung.

## Mac-Download erstellen

Mit Python 3.11 oder neuer und dem gebauten Mac-Paket:

```sh
./build.sh mac
python3 scripts/package_mac.py
```

Das Skript erstellt unter `Build/Downloads/` ein ZIP mit App, kurzer Anleitung und Paketmanifest sowie `SHA256SUMS.txt`. Es prüft Architektur, Versionsnummer, lokale Signatur und die 15 erwarteten Ressourcen. Zusätzliche Benutzer-Musik wird nicht veröffentlicht. Bestehende Pakete werden nicht überschrieben.

Vor einer Veröffentlichung das ZIP erneut entpacken, App-Signatur und Ressourcen vergleichen und die native Paketprüfung ausführen. Anschließend als GitHub-Vorabversion hochladen und den Download wieder abrufen und per Prüfsumme vergleichen. Die fertige App gehört zu den Release-Dateien, nicht in die Git-Historie. Die aktuelle Verpackung ist ausdrücklich für die ad-hoc-signierte Vorabversion gedacht; Developer-ID-Signierung und Notarisierung erfordern einen eigenen geprüften Ablauf.

## Speicherpflege

- Lokal nur die aktuelle spielbare App und ihren direkten Vorgänger behalten.
- Build-Ergebnisse und Caches bleiben außerhalb der Git-Historie.
- Neue Prüfbilder nach der Auswertung auf eine kleine Auswahl begrenzen.
- Originale Arbeitsreferenzen bleiben lokal und müssen nicht in jeden Checkout kopiert werden.
- Vor dem Löschen Quellen und benötigte Inhalte prüfen. Laufende Apps und Partien nicht entfernen oder beenden.
- Keine pauschale automatische Löschung des gesamten Projekt- oder Arbeitsordners.

Die `.gitignore` lässt nur die vorgesehenen Veröffentlichungspfade zu. Das verhindert die versehentliche Aufnahme vieler lokaler Altbestände. Neue Dateikategorien müssen bewusst freigegeben werden. Es ist keine Hintergrund-Löschautomation eingerichtet.

## Gemeinsame Spieltests

Prüfungen ohne Fenster bündeln. Danach eine kurze zusammenhängende Sitzung für Spielgefühl, Ton und Controller planen. Gesperrte Rechner nicht bedienen. Bildschirmaufnahmen sind für die bestehenden Tests nicht erforderlich; eigene Renderbilder und Laufzeitmessungen sind getrennte Nachweise.
