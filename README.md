# ForeverFlip

ForeverFlip begleitet Handelsrunden für häufig gehandelte Materialien in WoW Forever. Es verwendet die AH-Schnittstellen des Clients und die dokumentierte Ingame-API von AHledger für geschätzten Absatz und historische Preisvergleiche. ForeverFlip ist kostenlos.

## Installation

Kopiere den Ordner `ForeverFlip` mit der `ForeverFlip.toc` direkt nach `_forever_/Interface/AddOns`. Starte WoW neu oder gib `/reload` ein. Aktiviere [AHledger](https://ahledger.com/addon) zur Bewertung der Materialien. Die Suche läuft direkt in ForeverFlip.

## Handelsrunde

1. Geh zum AH und klicke **Neue Runde**. Gib das Budget in Gold ein und wähle die Materialien. Das Budget gilt für alle Einkäufe der Runde zusammen. Mit **Budget ändern** und **Items ändern** kannst du die laufende Einkaufsrunde anpassen. Bestätigte Käufe bleiben verbucht. `/ff budget 4` startet weiterhin eine neue Runde per Chat.
2. Klicke **Suchen** rechts in der ersten Zeile. Der Client erhält nacheinander je eine Abfrage für die ausgewählten Artikel. Kommt nach acht Sekunden keine passende AH-Antwort, überspringt ForeverFlip den Artikel für diesen Durchlauf. Die übrigen Abfragen laufen weiter, sobald das AH bereit ist. Am Ende siehst du die Zahl der übersprungenen Artikel. Der erste Treffer hat seinen Kaufbutton an derselben Stelle wie **Suchen**.
3. **Kauf prüfen** fragt den Gesamtpreis für genau die angezeigte Menge ab. **Kauf bestätigen** erscheint nach der Antwort an derselben Stelle. Ändert sich der Preis, verfällt die Bestätigung. Ausgaben zählen nach bestätigtem Kauf. Bei höchstens 5 Silber Restbudget endet die Einkaufsphase.
4. Nach fünf Minuten ab dem ersten Kauf erinnert **Zum Briefkasten?** ans Abholen. Du kannst die Einkaufsphase vorher beenden. Hole die AH-Post im Briefkasten selbst ab. Das Addon ordnet erkannte Käufe bei der Abholung den Runden zu.
5. Geh zum AH zurück. **Verkauf vorbereiten** lädt einen frischen Preis für die Ware. Standardmäßig erscheint der Preis mit Spielraum für Zwischenhändler, sofern er die Regeln erfüllt. Mit **Knapp unter Markt** wechselst du zum direkten Unterbieten. **Einstellen bestätigen** veröffentlicht die Auktion zu dem angezeigten Preis. Bei einer zusätzlichen Blizzard-Preiswarnung ist eine weitere Bestätigung nötig. Kann die Ware unter dem Tiefstpreis die Einkaufskosten nach Provision nicht decken, bleibt sie im Bestand.

Kaufvorschläge brauchen geschätzten Absatz, einen Sieben-Tage-Median und sichtbare Preisstufen. Die Rechnung prüft beide Handelsmargen nach Provision und der Bezugspreis bekommt 5 % Puffer für einen Rückgang. Die Menge ist auf einen Viertelstundenanteil des geschätzten Marktabsatzes begrenzt. Verkaufsdauer und künftige Preise bleiben Schätzungen. Bei ungeklärtem NPC-Preis prüfe vor dem Kauf die Händlerquelle.

Die Artikelauswahl enthält auch Tränke, Elixiere, Öle, Stoffballen und schwere Seidenverbände. Ein Artikel wird bei geschätzt mindestens 1.000 verkauften Stück pro Tag auf deinem Markt angezeigt. Taschen werden im AH als einzelne Auktionen gehandelt und haben in dieser Version keinen eigenen Kaufablauf.

## Bestand und Export

**Letzte Käufe** zeigt die vier jüngsten bestätigten Einkäufe, auch aus früheren Runden. Der Stückpreis ist bei gemischten Preisstufen der gerundete Durchschnitt.

**Verkäufe** zeigt die in ForeverFlip erfassten laufenden und vergangenen Auktionen. Mit **Offen** oder **Verkauft** filterst du die Liste. Bei bestätigten Teilverkäufen erscheinen die offene und verkaufte Menge. Ein ungeklärter Auktionsstatus bleibt markiert. **Auktionen prüfen** aktualisiert die Daten am AH.

Beim Vorbereiten eines Verkaufs zeigt die Kopfzeile den zuletzt abgefragten **Marktpreis** und den **gewählten Einstellpreis** je Stück sowie die gewählte Preisart. Ziehe das Fenster an der Ecke unten rechts größer oder kleiner. Die Zahl der Zeilen passt sich an und die Fenstergröße wird pro Charakter gespeichert.

**Bestand** zeigt offene Mengen aus allen Runden mit Einkaufskosten, Gewinnschwelle, 7- und 30-Tage-Median und einem Vergleich mit dem 30-Tage-Hoch. Fahre mit der Maus über eine Zeile für weitere Details. **Auktionen prüfen** liest die eigenen Auktionen neu ein. Ein fehlender Eintrag bleibt ungeklärt, bis du den Status prüfst.

**Export** markiert tabulatorgetrennte Daten zum Kopieren mit **Strg+C**. Enthalten sind Runden, Ausgaben, Positionen, bestätigte Verkaufsmengen, rechnerische Nettoerlöse und beobachtete Auszahlungen aus dem Briefkasten. AH-Post kann Erlöse aus anderen Verkäufen und zurückerstattete Kautionen enthalten. Sie bleibt deshalb getrennt von den ForeverFlip-Rundenerlösen. Zur Analyse kannst du den kopierten Text direkt weitergeben. Er enthält keine Charakter- oder Spielernamen.

### Ausnahmen nachprüfen

- Wenn du Ware schon abgeholt hast und die automatische Zuordnung fehlt, prüfe die AH-Post und nutze `/ff collect RUNDE POSITION`. Derselbe Befehl ordnet eine vollständig zurückgekommene Auktion neu zu, wenn ihre Auktion-ID im AH nicht mehr auftaucht. Die bisherige Kaution wird in diesem Fall als Verlust berücksichtigt.
- Ist eine Position vollständig verkauft und du hast den Nettoerlös laut Beleg geprüft, kannst du ihn als **Kupferbetrag abzüglich zurückerstatteter Kaution** mit `/ff receipt RUNDE POSITION KUPFER` nachtragen. Beispiel für R2.1 und 59 Silber netto: `/ff receipt 2 1 5900`.
- Bleibt eine Kaufantwort nach dem Bestätigungsklick aus, sperrt ForeverFlip weitere Käufe bis zur Klärung. Prüfe Gold und AH-Post. Verwende danach `/ff resolve bought` bei bestätigtem Kauf oder `/ff resolve failed` bei bestätigtem Fehlschlag. Prüfe bei einer ungeklärten Einstellung zuerst im AH, ob die Auktion existiert. Nur wenn sie nicht eingestellt wurde, verwende `/ff resolve unlisted`. Bei einer vorhandenen Auktion kannst du die bestätigte Auktion-ID mittels `/ff resolve listed ID` zuordnen.

0.2.5 ist eine Testversion. Die Handelsabläufe wurden mit simulierten WoW-Ereignissen geprüft.

Quellen: [Blizzards Addon-Richtlinie](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1) · [AHledger API](https://ahledger.com/developers) · [WoW AuctionHouse API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
