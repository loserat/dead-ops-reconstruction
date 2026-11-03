<div align="center">
  <img src="Assets/AppIcon/DeadOps-Icon.png" alt="Dead Ops Reconstruction – App-Icon mit Helm und Totenschädel" width="112" height="112">
  <h1>Dead Ops Reconstruction</h1>
  <p><strong>Eine Arena. Zwei Sticks. Die nächste Welle.</strong></p>
  <p>Ein natives Arcade-Projekt für den Mac – inspiriert von Dead Ops Arcade.</p>
  <p><code>Version 0.81</code> · <code>1–4 Spieler lokal</code> · <code>Mac zuerst</code> · <code>tvOS in Entwicklung</code></p>
  <p><a href="https://github.com/loserat/dead-ops-reconstruction/releases/download/v0.81/DeadOps-Reconstruction-0.81-macOS-arm64.zip"><img src="docs/images/download-mac.svg" alt="Mac-App herunterladen – Apple Silicon, macOS 14 oder neuer" width="316" height="64"></a></p>
  <p>Fertige Mac-Vorabversion · Kein Xcode nötig · <a href="docs/INSTALLATION.md#erster-start">Hinweis zum ersten Start</a></p>
</div>

<p align="center">
  <a href="#losspielen">Losspielen</a> ·
  <a href="#spielprinzip">Spielprinzip</a> ·
  <a href="#einblicke">Bilder</a> ·
  <a href="#steuerung">Steuerung</a> ·
  <a href="#entwicklungsstand">Entwicklungsstand</a>
</p>

![Insel in Runde 1: Spieler, Gegner, Palmen und Stege in der automatischen Kartenansicht](docs/images/island-0.81.png)

*Insel · Runde 1 · Einzelspieler. Eigene In-Engine-Vorschau der Version 0.81.*

## Spielprinzip

Bewege dich durch die Arena, halte die Gegner auf Abstand und sammle Waffen, Schätze und Ausrüstung. Mit dem linken Stick steuerst du deine Figur, mit dem rechten bestimmst du die Schussrichtung. Bomben und Boosts helfen, wenn eine Welle den Weg versperrt.

Das Projekt soll das Gefühl des ursprünglichen **Dead Ops Arcade aus Call of Duty: Black Ops** auf den Mac bringen. Es ist eine spielbare Entwicklungsversion mit eigenen Grafiken, Modellen und synthetisierten Geräuschen. Originalwerte und Abläufe sind teilweise angenähert; ein vollständiger 1:1-Nachbau ist noch nicht erreicht.

| Bewegen und ausweichen | Sammeln und aufrüsten | Gemeinsam bestehen |
|---|---|---|
| Twin-Stick-Steuerung, Boosts und Gegner mit echten Anmarschwegen. | Sieben Waffen-Grundtypen, Panzer, Hubschrauber und Hilfsmittel. | Ein bis vier lokale Spieler mit eigenen Farben, Anzeigen und Vorräten. |

## Einblicke

### Insel: den Einstieg im Blick

Die ersten vier Runden spielen auf der Insel. Wasser, Strand und Stege bilden die Zugänge. Gegner folgen tatsächlichen Anmarschwegen auf die Karte. Die automatische Kamera zeigt den gesamten spielbaren Bereich und die nahen Eingänge; entfernte, nicht spielbare Außenbereiche bestimmen nicht mehr den Bildausschnitt.

Das Titelbild zeigt diese Standardansicht. Manuelle Zoomregler gibt es nicht. Zusätzliche Höhe oder Fahrzeuge dürfen die Ansicht erweitern, wenn das für die Sichtbarkeit nötig ist.

### Innenhof: Wege, Deckung und neue Angriffswinkel

![Innenhof in Runde 5 mit Brunnen, vier Zugängen und der Anzeige für Leben, Bomben und Boosts](docs/images/courtyard-0.81.png)

*Innenhof · Runde 5 · Einzelspieler.*

Ab Runde 5 wechselt das erste Gebiet in den Innenhof. Der Brunnen und die gekreuzten Wege prägen die Bewegung, während mehrere Zugänge Aufmerksamkeit in verschiedene Richtungen verlangen. Die ersten acht Runden verteilen sich damit auf **zwei Arenen**.

Oben links stehen Leben, Bomben, Boosts und die aktive Waffe. Punktestand und Multiplikator bleiben direkt daneben; die Anzeige nennt außerdem die Entfernung zur nächsten Lebensmarke.

### Lokaler Koop: vier Farben, eine gemeinsame Ansicht

![Vier-Spieler-Ansicht im Innenhof: grüne, blaue, orange und pinke Spielfigur mit jeweils eigener Statusanzeige](docs/images/coop-0.81.png)

*Innenhof · Runde 8 · vier Spieler in einer gestellten Koop-Szene.*

Alle Spieler teilen sich die Arena und die Kamera. Eigene Farben und Statuskarten machen die Rollen unterscheidbar. Controller werden einzelnen Spielerplätzen zugeordnet; auf dem Mac kann der erste Spieler auch die Tastatur verwenden. Die aktuelle physische Mehrcontroller-Abnahme steht noch aus.

<details>
<summary><strong>Woher stammen die Bilder?</strong></summary>

Die drei Bilder stammen aus dem eigenen nativen Renderer und zeigen kontrolliert aufgebaute Testszenen der Version 0.81. Es sind keine Aufnahmen aus dem Originalspiel und keine Bildschirmfotos einer laufenden menschlichen Partie. Die [Bildliste mit Prüfsummen](docs/SCREENSHOTS.json) dokumentiert ihre Herkunft.

</details>

## Waffen, Fahrzeuge und Fortschritt

### Dein Arsenal

| Waffe | Rolle im aktuellen Spiel |
|---|---|
| **M60** | Grundwaffe für den Einstieg. |
| **Death Machine** | Sehr hohe Schussfolge. |
| **SPAS-12** | Mehrere Projektile in einem breiten Fächer. |
| **RPG** | Explosive Raketenangriffe. |
| **Ray Gun** | Energieprojektile mit eigener Trefferlogik. |
| **China Lake** | Granaten mit Flugbahn und Explosion. |
| **M2-Flammenwerfer** | Ein Feuerkegel für Gegner auf kurze Entfernung. |

Zusätzlich sind **Panzer und Hubschrauber**, Begleiter, Hilfsmittel, Nebenräume, Schicksale sowie spätere Arenen und Sonderabläufe funktional vorhanden. Schaden, Reichweiten, Animationen und Fahrzeuggefühl werden weiter mit der Referenz abgeglichen.

### Punkte sammeln, Lebensfunde sichern

Schätze und Gegnerabschüsse erhöhen deinen Punktestand. Beim Erreichen der nächsten **200.000-Punkte-Marke** wird ein persönlicher Lebensfund ausgelöst. Die Lebensstatue muss eingesammelt werden; die Punkte allein erhöhen den Lebenszähler noch nicht.

Wer Abläufe in Ruhe kennenlernen möchte, kann in den Einstellungen **Godmode** einschalten. Virtuelle Lebensverluste werden dabei weiter gezählt. Außerdem lassen sich Helligkeit, Spielerfarben und Ton anpassen.

## Losspielen

### Fertige Mac-App herunterladen

1. **[Mac-App 0.81 herunterladen](https://github.com/loserat/dead-ops-reconstruction/releases/download/v0.81/DeadOps-Reconstruction-0.81-macOS-arm64.zip)** und das ZIP entpacken.
2. **Dead Ops Reconstruction.app** in den Ordner **Programme** ziehen.
3. Die App öffnen und mit Tastatur oder Controller spielen.

Du brauchst einen **Mac mit Apple-Chip (M1 oder neuer) und macOS 14+**. Xcode und Python sind zum Spielen nicht erforderlich.

**Erster Start:** Diese Vorabversion ist lokal signiert und noch nicht von Apple notarisiert. macOS kann deshalb eine zusätzliche Freigabe verlangen. Die [Installationsanleitung](docs/INSTALLATION.md#erster-start) erklärt den vorgesehenen Weg. Weitere Dateiinformationen und die Prüfsumme stehen im [GitHub-Release](https://github.com/loserat/dead-ops-reconstruction/releases/tag/v0.81).

### Selbst bauen

**Du brauchst:** einen Mac mit Apple-Chip, macOS 14 oder neuer, eine vollständige Xcode-Installation und Python 3. Der direkte Build richtet sich derzeit an `arm64`; Intel-Macs sind nicht verifiziert.

```sh
git clone https://github.com/loserat/dead-ops-reconstruction.git
cd dead-ops-reconstruction
./build.sh mac
open Build/Mac/DeadOpsReconstruction.app
```

**Lieber mit Xcode?** `DeadOpsReconstruction.xcodeproj` öffnen, **Dead Ops Mac** und **My Mac** auswählen und starten. Xcode und der direkte Build verwenden denselben Quellstand 0.81.

Die App verwendet Swift, SceneKit, SpriteKit und GameController. Zusätzliche Swift-Pakete, eine REA-Installation oder API-Schlüssel sind nicht erforderlich. Die Mac-App wird beim direkten Build lokal signiert. Ein von Apple notarisiertes Paket ist noch nicht vorhanden.

Für Apple TV gibt es ein tvOS-Ziel. SDK-Build, Signierung und Installation beschreibt die [Installationsanleitung](docs/INSTALLATION.md).

## Steuerung

| Aktion | Tastatur | PS5-/kompatibler Controller |
|---|---|---|
| **Bewegen** | WASD | Linker Stick |
| **Zielen und schießen** | Pfeiltasten | Rechter Stick |
| **Boost** | Leertaste | R1 oder R2 |
| **Bombe** | B | L1 oder L2 |
| **Bestätigen** | Eingabe | Kreuz / untere Aktionstaste |
| **Pause** | Escape | Options / Menü |
| **Zurück im Menü** | Menüführung | Kreis / rechte Aktionstaste |

## Entwicklungsstand

**0.81 ist ein spielbarer Zwischenstand.** Vorrang haben ein angenehmes Spielgefühl, eine gut lesbare Karte und flüssiger Betrieb auf dem Mac.

| Bereich | Aktueller Nachweis |
|---|---|
| **Mac** | Direkter Build, Xcode-Release-Build und native Paketprüfung bestanden. |
| **Spiellogik** | 55 Prüfprogramme mit 6.163 protokollierten Einzelbestätigungen bestanden. |
| **Erste acht Runden** | Sechs automatische Solo-/Koop-Durchläufe bestanden. |
| **Kamera** | 42 native Renderbilder und geometrische Sichtprüfungen bestanden. |
| **Frische Quellkopie** | Ohne die alten lokalen Arbeitsordner gebaut und als Paket geprüft. |
| **Apple TV** | Geräte-SDK-Build bestanden; aktuelle physische Abnahme offen. |

Diese Ergebnisse beziehen sich auf den zuletzt geprüften Spielquellstand. Automatische Piloten und Renderbilder ersetzen keine menschliche Spielrunde oder Hardwareprüfung. Einzelheiten und Befehle stehen unter [Tests und Nachweise](docs/TESTING.md).

### Woran wir als Nächstes arbeiten

- **Flüssigkeit:** stabile 60 FPS unter hoher Last nachweisen und unnötige Hintergrundlast senken.
- **Spielgefühl:** Bewegung, Gegnerdruck, Waffenwirkung und Fahrzeuge gezielter abstimmen.
- **Lesbarkeit:** Perspektive, Figuren, Funde und Effekte beim normalen Spielen bewerten.
- **Geräte und Ton:** aktuelle PS5-, Mehrcontroller-, Hör- und Apple-TV-Tests durchführen.
- **Originalabgleich:** das gesamte Referenzvideo in Bewegung und mit Ton auswerten; Originalmusik liegt weiterhin nicht als Projektdatei vor.

Die [Roadmap](docs/ROADMAP.md) enthält die Prioritäten und konkrete Erfolgskriterien. Online-Mehrspieler und eine Browserfassung sind derzeit nicht umgesetzt.

## Dokumentation

| Du möchtest … | Hier geht es weiter |
|---|---|
| Das Spiel bauen oder auf Apple TV installieren | [Installation](docs/INSTALLATION.md) |
| Den Aufbau des Codes verstehen | [Architektur](docs/ARCHITECTURE.md) |
| Weiterentwickeln und den Speicher schlank halten | [Workflow](docs/WORKFLOW.md) |
| Prüfungen nachvollziehen oder wiederholen | [Tests und Nachweise](docs/TESTING.md) |
| Die nächsten Aufgaben sehen | [Roadmap](docs/ROADMAP.md) |
| Referenzen und Grafiken nachvollziehen | [Quellen und Inhalte](docs/REFERENCES.md) |
| Änderungen verfolgen oder mitwirken | [Changelog](CHANGELOG.md) · [Mitwirken](CONTRIBUTING.md) |

---

*Inoffizielles Entwicklungsprojekt, inspiriert von Dead Ops Arcade. Kein offizielles Call-of-Duty-Produkt. Der [Lizenzstatus](LICENSE.md) ist dokumentiert; eine Open-Source-Lizenz wurde noch nicht ausgewählt.*
