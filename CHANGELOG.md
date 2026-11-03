# Änderungen

## README-Ausbau – 03.11.2026

- Startseite mit App-Icon, Sprungnavigation und drei eigenen In-Engine-Vorschauen gestaltet.
- Spielprinzip, Arenen, Koop, Waffen, Lebensfunde und Steuerung verständlicher erklärt.
- Bildherkunft dokumentiert und Dokumentationsprüfung auf HTML-Bildverweise erweitert.
- Nur Dokumentation und Bildauswahl geändert; Spielquellen und Version bleiben 0.81.

## 0.81 – 03.11.2026: nachvollziehbarer Quellstand für GitHub

- Die acht bereits geprüften Kamera-, Boden-, Kartenobjekt- und HUD-Ergänzungen von 0.80/0.81 im gemeinsamen Hauptprojekt zusammengeführt.
- Xcode-Ziele und direkter Build auf denselben Versionsstand gebracht. Der direkte Build liest nun `VERSION` und benötigt den historischen Projektgenerator nicht.
- Die Kameraprüfung an die aktuelle Vorgabe angepasst: ganze spielbare Karte und nahe Zugänge; entfernte nicht spielbare Anmarschbereiche bestimmen nicht mehr den Bildausschnitt.
- Installation, Steuerung, Architektur, Tests, Quellen, offene Arbeit und Speicherpflege dokumentiert.
- Veröffentlichung auf Quellen, Spielgrafiken und aktuelle Dokumentation begrenzt. Persönliche Signierungszuordnung aus den Xcode-Zielen entfernt.

Die Zusammenführung verändert keine Spielregeln. Sie ersetzt keine neue menschliche Spielgefühl-, Controller-, Audio- oder Apple-TV-Abnahme. Aktuelle Prüfergebnisse stehen in [TESTING](docs/TESTING.md).

## Vorherige Entwicklung

0.81 führte die engere automatische Übersicht ein. 0.80 verbesserte unter anderem Nebel, Boden, Brunnenmaterialien und die Verarbeitung der Anzeigen. Die umfangreiche ältere lokale Entwicklungshistorie wird nicht als Git-Historie nachträglich importiert. Der erste öffentliche Commit ist ein dokumentierter Ausgangsstand.
