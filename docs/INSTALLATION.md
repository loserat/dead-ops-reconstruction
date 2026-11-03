# Installation

## Mac

### Fertige App

**[Mac-Vorabversion 0.81 herunterladen](https://github.com/loserat/dead-ops-reconstruction/releases/download/v0.81/DeadOps-Reconstruction-0.81-macOS-arm64.zip)**

Benötigt werden ein Mac mit Apple-Chip (M1 oder neuer) und macOS 14+. Zum Spielen ist keine Entwicklungssoftware nötig. Intel-Macs, Windows und Apple TV verwenden dieses Mac-Paket nicht.

1. Das ZIP entpacken.
2. **Dead Ops Reconstruction.app** aus dem entpackten Ordner nach **Programme** ziehen.
3. Die App öffnen. Im gleichen Ordner liegen eine kurze Anleitung und `Release-Info.json` mit Versions-, Signatur- und Ressourcenangaben.

Im [Release](https://github.com/loserat/dead-ops-reconstruction/releases/tag/v0.81) enthält `SHA256SUMS.txt` die Prüfsumme des ZIPs. Die zusätzlich von GitHub angebotenen „Source code“-Archive sind zum Weiterentwickeln gedacht; zum Spielen die oben verlinkte Mac-App verwenden.

### Erster Start

Das Paket ist lokal signiert, aber nicht mit Developer ID signiert oder von Apple notarisiert. Auf einem anderen Mac kann Gatekeeper den ersten Start blockieren. Bei einer entsprechenden Meldung und wenn du diesem Download vertraust: **Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen** für diese App wählen. [Apples Erklärung](https://support.apple.com/de-de/102445).

Ein Developer-ID-Zertifikat und die Apple-Notarisierung fehlen für die normale bestätigte Weitergabe. Eine Prüfung auf einem fremden Mac und eine aktuelle physische Controller-Abnahme stehen noch aus; lokale Paket- und Signaturprüfungen sind davon getrennt.

### Selbst bauen

Der unterstützte Kommandozeilen-Build richtet sich an Apple Silicon und macOS 14+. Xcode muss unter `/Applications/Xcode.app` installiert sein oder über `DEVELOPER_DIR` angegeben werden. Python 3 wird für das Lesen der Versionsdatei benötigt; es werden keine Python-Pakete installiert.

```sh
./build.sh mac
open Build/Mac/DeadOpsReconstruction.app
```

Bei einer anders benannten Xcode-Installation:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./build.sh mac
```

Das Build-Verzeichnis lässt sich über `DEADOPS_BUILD_ROOT` ändern. Es enthält erzeugte Daten und wird von Git ignoriert. Die vorhandenen Projektquellen oder andere Spielversionen müssen zum Bauen nicht gelöscht werden.

Im Xcode-Projekt sind **Dead Ops Mac** und **Dead Ops Apple TV** als geteilte Schemata vorhanden. Für den Mac **My Mac** wählen. Die Prüfharnesse unter `Tests/` sind keine XCTest-Ziele; Cmd-U führt sie nicht automatisch aus.

## Apple TV

Das tvOS-Ziel setzt tvOS 18 oder neuer voraus. Ein SDK-Build ist möglich:

```sh
./build.sh tv-simulator
./build.sh tv-device
```

Diese Befehle erstellen die App-Struktur und das Programm. Der Geräte-Build ist kein fertig signiertes Installationspaket. Zur Installation auf einem echten Apple TV das Xcode-Schema **Dead Ops Apple TV** verwenden, das eigene Entwicklerteam unter **Signing & Capabilities** auswählen, Apple TV mit Xcode koppeln und als Ziel auswählen. Das Repository enthält kein persönliches Entwicklerteam, keine Zertifikate und keine Bereitstellungsprofile.

Der aktuelle Quellstand hat keine physische tvOS-Abnahme. Beim früheren Apple-TV-HD-Test wurden Ruckler und Darstellungsprobleme gemeldet. Der Mac bleibt die vorrangige Zielplattform.

## Controller und Musik

Den Controller vor dem Spielstart über macOS beziehungsweise tvOS verbinden. Das Spiel verwendet das Extended-Gamepad-Profil; die konkrete Tastenbelegung steht in der [README](../README.md).

Optional können eigene Audiodateien unter `Assets/Music/` liegen. Unterstützte Formate kopiert der Build ins Paket. Dieser Ordner enthält im Repository nur die Anleitung; persönliche oder fremde Musikdateien bleiben ausgeschlossen. Originalmusik wird nicht heruntergeladen. Ein Musikimport aus dem Mac-Spiel liegt im Benutzerbereich und wird nicht automatisch auf Apple TV übertragen.
