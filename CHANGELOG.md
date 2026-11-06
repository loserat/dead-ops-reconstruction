# Änderungen

## 0.82 – 06.11.2026: Figurenanimation und Licht für den Mac

- Lebende menschliche Gegner behalten eigene Gelenkverweise. Wiederholte Knotensuchen und doppelte Beinbewegungen entfallen; besiegte Gegner geben die Verweise wieder frei.
- Tages- und Abendlicht auf Insel und Innenhof erhalten deutlichere Schatten. Die kühle Nachtbeleuchtung wurde separat auf Lesbarkeit abgestimmt.
- Das Inselwasser ist dunkler, die Normalenstruktur und Glanzspitzen sind zurückgenommen. Zusätzliche Texturen, Geometrie und Renderdurchläufe sind dafür nicht nötig.
- Separaten nativen Vergleich für Gelenkbewegungen, Lebensdauer der Figurenverweise, sechs Lichtszenen und Renderzeiten ergänzt. Die ganze spielbare Karte bleibt in der bisherigen automatischen Ansicht.

Quellstand 0.82; der veröffentlichte Mac-Download bleibt 0.81. Ergebnisse und Grenzen stehen in [TESTING](docs/TESTING.md).

## GitHub-Auftritt und Dateiprüfung – 06.11.2026

- README kürzer und einladender gestaltet: Download, erste Schritte und Bilder stehen vor den Entwicklerdetails.
- Öffentliche Dateien, bisherige Git-Historie, Bildmetadaten und Xcode-Signierungszuordnungen überprüft.
- Dokumentationspfade und ausgeschlossene sensible Dateitypen enger begrenzt.
- Wiederverwendbare Prüfung des Git-Index und der Historie ergänzt. Spielquellen, Grafikdateien und Mac-Download bleiben auf Stand 0.81.

## Mac-Download 0.81 – 03.11.2026

- Fertige Mac-Vorabversion für Apple Silicon und macOS 14+ als GitHub-Release vorbereitet.
- Download-Button und einfache Installationsanleitung ergänzt; zum Spielen ist Xcode nicht erforderlich.
- Wiederholbare Paketierung mit Ressourcenprüfung, App-Signatur, Paketmanifest und ZIP-Prüfsumme hinzugefügt.
- Lokale Signierung und fehlende Apple-Notarisierung ausdrücklich dokumentiert. Spielquellen bleiben unverändert.

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
