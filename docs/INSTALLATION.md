# Installation

## Mac

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
