# Dead Ops Reconstruction

Ein natives Twin-Stick-Arcadespiel für den Mac, inspiriert von **Dead Ops Arcade** aus *Call of Duty: Black Ops*. Swift, SceneKit, SpriteKit und GameController; ein zusätzliches Ziel für Apple TV ist vorhanden.

**Stand: 0.81 · Entwicklungsversion · Mac zuerst.** Eine spielbare Annäherung mit eigenen Grafiken und synthetisierten Geräuschen. Kein offizielles Call-of-Duty-Spiel und kein vollständiger 1:1-Nachbau. Das ursprüngliche Dead Ops Arcade ist die Referenz dieses Projekts; spätere Serienteile sind nicht der verbindliche Maßstab.

![Innenhof der Version 0.81, lokal gerendert](docs/images/courtyard-0.81.png)

*Eigenes gerendertes Prüfbild; kein Bildschirmfoto eines laufenden Spieltests.*

## Spielen und bauen

Benötigt werden ein Mac mit Apple-Chip, macOS 14 oder neuer und eine vollständige Xcode-Installation. Aktuelle lokale Prüfungen verwenden Xcode 27.0. Der Kommandozeilen-Build ist derzeit auf `arm64` eingestellt; Intel-Macs sind nicht verifiziert.

```sh
git clone https://github.com/loserat/dead-ops-reconstruction.git
cd dead-ops-reconstruction
./build.sh mac
open Build/Mac/DeadOpsReconstruction.app
```

Alternativ `DeadOpsReconstruction.xcodeproj` in Xcode öffnen, **Dead Ops Mac** und **My Mac** auswählen und starten. Beide Wege verwenden die Quellen in `Sources/` und den Stand 0.81. Keine zusätzlichen Swift-Pakete, REA-Installation oder API-Schlüssel erforderlich. Die Mac-App wird lokal signiert; es liegt kein notarisiertes Installationspaket vor.

## Steuerung

| Aktion | Tastatur | PS5-/kompatibler Controller |
|---|---|---|
| Bewegen | WASD | Linker Stick |
| Zielen und schießen | Pfeiltasten | Rechter Stick |
| Boost | Leertaste | R1 oder R2 |
| Bombe | B | L1 oder L2 |
| Bestätigen | Eingabe | Kreuz / untere Aktionstaste |
| Pause | Escape | Options / Menü |
| Zurück im Menü | Menüführung | Kreis / rechte Aktionstaste |

Ein bis vier lokale Spieler sind vorgesehen. Der Mac kann die Tastatur für den ersten Spieler verwenden. Die aktuelle physische Abnahme mit mehreren Controllern steht noch aus.

## Enthalten

- Insel und Innenhof für die ersten acht Runden sowie weitere Arenen und spätere Spielabläufe.
- Gegner mit tatsächlichen Anmarschwegen, Waffenfunde, Panzer, Hubschrauber, Begleiter und Hilfsmittel.
- Punkte, Multiplikator, Lebensfunde, Schicksale, Nebenräume und lokale Koop-Regeln.
- Automatische Übersicht über die gesamte spielbare Karte und nahe Zugänge; keine manuellen Zoomregler.
- Einstellungen für Ton, Helligkeit, Spielerfarben und Godmode mit gezählten virtuellen Lebensverlusten.
- Ein persönlicher Lebensfund wird beim Erreichen der nächsten 200.000-Punkte-Marke ausgelöst; er muss eingesammelt werden.

## Grenzen des aktuellen Stands

Stabile 60 FPS bei hoher Last sind **noch nicht nachgewiesen**. Originalwerte, Kartenoptik, Animationen und Spielgefühl sind teilweise angenähert. Das vollständige Referenzvideo wurde noch nicht durchgehend in Bewegung und mit Ton ausgewertet. Originalmusik ist nicht enthalten. Der aktuelle Stand wurde noch nicht vollständig mit PS5-Controller oder auf physischem Apple TV abgenommen.

## Dokumentation

- [Installation und Apple TV](docs/INSTALLATION.md)
- [Architektur und Projektaufbau](docs/ARCHITECTURE.md)
- [Entwicklungsablauf und Speicherpflege](docs/WORKFLOW.md)
- [Tests und nachgewiesener Stand](docs/TESTING.md)
- [Offene Aufgaben](docs/ROADMAP.md)
- [Quellen, Grafiken und Musik](docs/REFERENCES.md)
- [Änderungen](CHANGELOG.md) · [Mitwirken](CONTRIBUTING.md) · [Lizenzstatus](LICENSE.md)

Lokale Entwicklungsprotokolle, Videoeinzelbilder, Wiki-Kopien, Einstellungen, Build-Ausgaben und alte Apps gehören nicht zum Repository. Die Quellen und Spielgrafiken zum eigenständigen Bauen sind enthalten.
