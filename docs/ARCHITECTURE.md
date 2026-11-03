# Architektur

## Eine Quelle für den aktuellen Stand

Seit der Zusammenführung von 0.81 liegen die produktiven Quellen gemeinsam in `Sources/`. Der frühere Aufbau mit Basisstand 0.79 und separaten 0.80-/0.81-Ergänzungen ist für einen frischen Checkout nicht erforderlich. Die acht geprüften Grafik-, HUD- und Kamera-Ergänzungen wurden unverändert übernommen. Der normale App-Einstieg ist `Sources/App.swift`; historische Diagnose-Wrapper gehören nicht zum veröffentlichten Spiel.

| Bereich | Einstiegspunkte | Aufgabe |
|---|---|---|
| Simulation | `GameCore.swift`, `TeamSimulation.swift`, `CombatRules.swift` | Spielzustand, Spieler und Kampfschritte |
| Arenen und Zugänge | `ArenaLayout.swift`, `OpeningMapDesign.swift`, `EnemyEntrances.swift` | Begehbarkeit, Hindernisse und echte Gegnerwege |
| Kamera | `TeamCamera.swift`, `TeamArt.swift` | Feste Kartenansicht, nahe Eingänge, Höhenreserve und Nebel |
| Darstellung | `GameScene.swift`, `CharacterArt.swift`, `OpeningTerrainArt.swift`, `MapLandmarkArt.swift` | SceneKit-Szene, Figuren, Boden und Kartenobjekte |
| Anzeigen und Menüs | `GameHUD.swift`, `GameMenus.swift` | SpriteKit-Anzeigen und Bedienung |
| Eingabe | `NativeInput.swift`, `ControllerRouting.swift`, `FrameInput.swift` | Tastatur, Controllerrollen und Übergabe an die Simulation |
| Waffen und Fahrzeuge | `Weapons.swift`, `WeaponProjectiles.swift`, `Vehicles.swift` | Wirkung, Laufzeiten und Bewegung |
| Punkte und Leben | `ScoreAwards.swift`, `PlayerDamage.swift`, `LifeTransfers.swift` | Punktschwellen, Lebensfunde, Schäden und Koop |
| Ton | `AudioCore.swift`, `AudioPlayback.swift`, `MusicPlayback.swift` | Synthetisierte Effekte und optionale Musik |

## Verzeichnisstruktur

```text
Sources/                        Gemeinsame Swift-Quellen für Mac und tvOS
Tests/                          Logikprüfungen und automatisierte Spielpiloten
Assets/                         Projektgrafiken und Icon
Config/                         Plattformbezogene Info.plist-Vorlagen
DeadOpsReconstruction.xcodeproj/ Xcode-Projekt und geteilte Schemata
docs/                           Aktuelle Projektdokumentation
scripts/                        Prüfungen der Dokumentation
VERSION                         Versionsnummer des direkten Builds
build.sh                        Direkter Mac-/tvOS-Build
```

`Build/`, `Reference/`, `Project/`, lokale Textprotokolle und historische Arbeitsverzeichnisse werden nicht veröffentlicht. Der frühere Projektgenerator ist für einen Checkout nicht nötig. Änderungen an Xcode-Zielen oder Zielmitgliedschaften erfolgen in Xcode; das Projekt wird nicht im Build neu erzeugt.

## Wichtige Regeln

- Gegner werden entlang ihrer realen Anmarschwege bewegt. Die engere Kamera verändert weder Startorte noch Kollisionen.
- Der gesamte spielbare Kartenbereich und die nahen Zugänge bestimmen die Standardansicht. Entfernte, nicht spielbare Schutzdächer müssen nicht im Bild liegen.
- Zusätzliche Höhe oder Fahrzeuge dürfen eine nötige Erweiterung der Ansicht auslösen. Bodenbewegung allein soll keinen nachlaufenden Zoom verursachen.
- Bildberechnung, Simulation und Eingabe sind verschiedene Teile der Laufzeit. Viele gezeichnete Bilder beweisen noch keine ebenso häufig aktualisierte Simulation.
- Plattformcode ist durch Swift-Plattformbedingungen getrennt. Ein erfolgreicher Mac-Build belegt keinen tvOS-Gerätelauf.
