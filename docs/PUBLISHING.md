# Dateien vor einer Veröffentlichung prüfen

Im Repository liegen Spielquellen, Tests, eigene Grafiken und aktuelle Dokumentation. Die fertige Mac-App wird separat als GitHub-Release veröffentlicht. Lokale Arbeitsprotokolle und Referenzsammlungen bleiben außerhalb der Git-Historie.

## Vor dem Hochladen

Die Dateiprüfung liest den **Git-Index**, also genau die zum Commit vorgemerkten Dateien. Deshalb zuerst die beabsichtigten Änderungen vormerken und danach prüfen:

```sh
git add README.md
python3 scripts/check_docs.py
python3 scripts/check_publication.py --history
git diff --cached --check
git diff --cached --stat
```

Die zweite Prüfung kontrolliert Dateipfade und Formate, auffällige Zugangsdatenmuster, persönliche Rechnerpfade, Links statt normaler Dateien sowie persönliche Bildmetadaten. Mit `--history` werden außerdem alle lokal vorhandenen Commits untersucht. Ausgaben nennen nur Dateinamen und Fundkategorien, keine erkannten Geheimwerte.

Die `.gitignore` lässt für Dokumentation nur Markdown, JSON sowie PNG-/SVG-Bilder zu. Zertifikate, Schlüssel, Datenbanken, Rohprotokolle und App-/ZIP-Builds bleiben ausgeschlossen. Bereits getrackte Dateien werden durch eine neue Ignore-Regel nicht entfernt; dafür dient die Prüfung des Git-Index.

## Xcode und Downloadpaket

Die Xcode-Projektdatei wird im Prüfsystem absichtlich nicht als Text ausgewertet. Persönliche Entwicklerteam- und Profilzuordnungen zusätzlich über Xcode prüfen. Historische identische Projektdateien lassen sich über ihre Git-Prüfsumme zuordnen.

Bei einem neuen App-Paket ZIP-Inhalt, Ressourcen, Signatur und native Paketprüfung prüfen. Nach dem Upload das ZIP erneut herunterladen und mit `SHA256SUMS.txt` vergleichen. Anleitung und wiederholbare Paketierung stehen im [Workflow](WORKFLOW.md#mac-download-erstellen).

## Überprüfung vom 06.11.2026

Zu Beginn wurden alle 223 Dateien auf GitHub mit dem lokalen Stand verglichen: Dateinamen, Dateimodi und Git-Objektkennungen stimmen überein. Die drei bisherigen Commits enthalten 232 unterschiedliche Dateirevisionen. Die Musterprüfung hat darin keine Zugangsdaten oder persönlichen Rechnerpfade gefunden. Alle drei Commit-Adressen sind GitHub-Noreply-Adressen.

Die einzige Xcode-Projektdateiversion wurde über die aktuellen Ziel-Einstellungen geprüft: kein persönliches Entwicklerteam und keine Profilzuordnung. Die Bildmetadaten enthalten Größen-/Farbinformationen sowie zwei benötigte Kennungen für vorbereitete Bodenflächen; keine gefundenen Besitzer-, Seriennummer- oder Standortfelder. Diese Bodenkennungen werden von der App zur Wiedererkennung vorbereiteter Grafiken verwendet und bleiben erhalten.

Das öffentliche Repository hat einen Hauptbranch und die Mac-Vorabversion 0.81 mit App-ZIP und Prüfsumme. Die Abschlussprüfung des ZIPs und der aktualisierten Veröffentlichung wird lokal mit Datum und Prüfsummen protokolliert.

## Quellstand 0.82 veröffentlichen

Die Weiterentwicklung von Figurenanimation und Beleuchtung enthält die Spieländerungen, einen separaten nativen Vergleich sowie die dokumentierten Messwerte in [verification-0.82.json](verification-0.82.json). README, Changelog und Prüfanleitung unterscheiden den Quellstand 0.82 vom weiterhin verfügbaren App-Download 0.81.

Die vorhandenen lokalen Commits werden als normale Fortschreibung von `main` übertragen. Fertige Apps, Compilerdateien, private Arbeitsprotokolle und Originalreferenzen werden nicht in den Commit aufgenommen. Die erneute Prüfung umfasst den Git-Index und die gesamte lokale Historie; beide Xcode-Ziele werden separat auf Versionsnummer und persönliche Team-/Profilzuordnungen geprüft. Nach dem Push werden der GitHub-Branchstand und ausgewählte Dokumente zurückgelesen. Ein Push des Quellcodes erstellt keine neue herunterladbare App-Version.

## Grenzen

Die Prüfung erkennt konkrete Dateitypen und Muster. Sie garantiert weder die Abwesenheit jedes denkbaren Geheimnisses noch Malwarefreiheit oder sämtliche Nutzungsrechte. Bei einem Fund zuerst die betreffende Datei prüfen; veröffentlichte Zugangsdaten müssten außerdem widerrufen werden. Eine Änderung der öffentlichen Git-Historie erfolgt gezielt nach einem konkreten Befund.
