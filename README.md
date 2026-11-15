# ForeverFlip

ForeverFlip begleitet Handelsrunden für häufig gehandelte Materialien in WoW Forever. Es verwendet die AH-Schnittstellen des Clients und die dokumentierte Ingame-API von AHledger für geschätzten Absatz und historische Preisvergleiche. ForeverFlip ist kostenlos.

## Installation

Kopiere den Ordner `ForeverFlip` mit der `ForeverFlip.toc` direkt nach `_forever_/Interface/AddOns`. Starte WoW neu oder gib `/reload` ein. Aktiviere [AHledger](https://ahledger.com/addon) zur Bewertung der Materialien. Die Suche läuft direkt in ForeverFlip.

## Handelsrunde

1. Geh zum AH und klicke **Neue Runde**. Gib das Budget in Gold ein und wähle die Materialien. Das Budget gilt für alle Einkäufe der Runde zusammen. Mit **Budget ändern** und **Items ändern** kannst du die laufende Einkaufsrunde anpassen. Bestätigte Käufe bleiben verbucht. `/ff budget 4` startet weiterhin eine neue Runde per Chat.
2. Klicke **Suchen** rechts in der ersten Zeile. Der Client erhält nacheinander je eine Abfrage für die ausgewählten Artikel. Kommt nach einer Sekunde keine passende AH-Antwort, überspringt ForeverFlip den Artikel für diesen Durchlauf. Die übrigen Abfragen laufen weiter, sobald das AH bereit ist. Am Ende siehst du die Zahl der übersprungenen Artikel. Der erste Treffer hat seinen Kaufbutton an derselben Stelle wie **Suchen**.
3. **Kauf prüfen** fragt den Gesamtpreis für genau die angezeigte Menge ab. **Kauf bestätigen** erscheint nach der Antwort an derselben Stelle. Ändert sich der Preis, verfällt die Bestätigung. Ausgaben zählen nach bestätigtem Kauf. Bei höchstens 5 Silber Restbudget endet die Einkaufsphase.

4. Nach fünf Minuten ab dem ersten Kauf erinnert **Zum Briefkasten?** ans Abholen. Du kannst die Einkaufsphase vorher beenden. Hole die AH-Post im Briefkasten selbst ab. Das Addon ordnet erkannte Käufe bei der Abholung den Runden zu.
5. Geh zum AH zurück. **Verkauf vorbereiten** lädt einen frischen Preis für die Ware. **Einstellen bestätigen** erscheint am selben Button. Bei einer zusätzlichen AH-Preiswarnung folgt an derselben Stelle eine weitere Bestätigung. Sobald die Auktion bestätigt ist, rückt die nächste offene Position nach. Reicht der Marktpreis für die erforderliche Marge nicht aus, bleibt die Zeile als **Halten** stehen. Klicke dann eine Zeile tiefer. Die eingestellten Auktionen findest du unter **Verkäufe**.

Mit **Live: aus/an** wechselst du zwischen manueller und wiederholter Suche. Nach einem normalen Durchlauf startet Live frühestens fünf Sekunden nach dessen Start den nächsten. Bei fehlenden AH-Antworten versucht Live es eine Sekunde nach Ende des Durchlaufs erneut. Jede Abfrage wartet darauf, dass der AH-Client wieder bereit ist. Beide Modi pausieren am ersten Treffer und setzen den Durchlauf nach Kauf, Überspringen oder Ablauf fort. Live endet beim Schließen des Fensters oder des AH, beim Tabwechsel und bei Änderungen an Budget oder Auswahl. **Ton: aus/an** schaltet den eingebauten WoW-Trefferton pro Charakter um.

**Kauf prüfen** und **Kauf bestätigen** reagieren schon beim Drücken der linken Maustaste. Der Bestätigungsbutton wird nach der AH-Preisantwort sofort aktualisiert. Der Kauf erfordert zwei getrennte Mausklicks.

Kaufvorschläge brauchen geschätzten Absatz, einen Sieben-Tage-Median und sichtbare Preisstufen. In der Handelsrunde schaltest du zwischen **Direktverkauf** und **Zwischenhändler** um:

- **Direktverkauf** ist der Standard. ForeverFlip prüft günstige Preisstufen zusammen. Der Zielpreis liegt unter dem ersten Angebot, das nach dem vollständigen Kauf noch übrig wäre, und berücksichtigt den Sieben-Tage-Median sowie bekannte NPC-Preise. Davon gehen 2 % Preispuffer ab. Der geschätzte Gewinn nach AH-Provision muss mindestens 5 % der Einkaufskosten betragen. Vor dem Einstellen berechnet ForeverFlip den Preis mit dem dann aktuellen Markt neu.
- **Zwischenhändler** reserviert bei Stapelware weiterhin eine zweite Marge von 5 % neben deiner eigenen Marge von 5 %. Die historische Preisgrenze erhält in diesem Modus 5 % Puffer.

Mit **Limit** wählst du 15 Minuten, 1 Stunde oder 4 Stunden geschätzten Tagesabsatz als Mengenlimit pro Artikel. Bei 960 Verkäufen am Tag sind das zum Beispiel 10 Stück in 15 Minuten. Im Direktmodus zählt bereits erfasster offener Bestand desselben Artikels mit. Einzelauktionen werden im Zwischenhändlermodus einzeln bewertet. Das Budget begrenzt den Gesamtkauf. Für jeden Kandidaten muss eine weitere sichtbare Preisstufe übrig bleiben. Der Treffer zeigt den Zielpreis und geschätzten Gewinn, seine Preisstufen stehen im Tooltip und im Export. Verkaufsdauer und künftige Preise bleiben Schätzungen. Bei ungeklärtem NPC-Preis prüfe vor dem Kauf die Händlerquelle.

Die **Watchlist** lässt sich nach Name oder Item-ID filtern und mit Mausrad oder Scrollleiste durchgehen. **Alle markieren** wählt sämtliche scanbaren Items aus, **Treffer markieren** beschränkt das bei aktiver Namenssuche auf den Filter. **Alle abwählen** leert die Auswahl. **Letzte Suche** stellt die Auswahl des letzten gestarteten Durchlaufs wieder her. Der Mindestabsatz steht standardmäßig auf **100 Stück pro Tag** und lässt sich direkt in der Watchlist ändern. Eigene Items fügst du per Item-ID oder eingefügtem Itemlink hinzu. Für einen Treffer braucht ForeverFlip weiterhin AHledger-Absatzdaten und einen Sieben-Tage-Median.

**AH-Katalog laden** lädt am geöffneten AH die regulären Browse-Ergebnisse seitenweise und merkt sich die gefundenen Artikel für die Watchlist. Der Kategoriefilter verwendet die lokalen WoW-Klassen und Unterklassen. **Treffer markieren** gilt bei aktivem Kategorien- oder Namensfilter. Pro Item siehst du den Schätzabsatz je Tag und den zuletzt von AHledger erfassten niedrigsten Sofortkaufpreis je Stück. Aktuell unangebotene und bisher unbekannte Items kannst du weiterhin per ID oder Link hinzufügen. Beim Live-Scan werden die markierten und scanbaren Artikel nacheinander abgefragt.

Taschen und gezielt ausgewählte Waffen oder Rüstung können als Einzelauktionen durchsucht werden. Der Direktmodus kann mehrere einzelne Auktionen als zusammenhängenden Treffer anzeigen. Im Zwischenhändlermodus gilt für Einzelauktionen die bisherige Schwelle von 20 % Nettomarge nach einem 15-%-Abschlag. Zufällige Itemzusätze fallen aus dem Vergleich. Klicke in ForeverFlip auf **Sofortkauf prüfen** und danach auf den angezeigten Einzelpreis. Bei einem Paket wiederholst du das am gleichen Button für jede Auktion. ForeverFlip prüft die verbleibende Menge und verbucht bestätigte Käufe einzeln im Rundenbudget. Der prognostizierte Preis setzt den vollständigen Kauf voraus. Nach der Abholung kannst du die Einzelauktionen aus der Handelsrunde heraus wieder einstellen.

## Bestand und Export

**Käufe** zeigt sämtliche bestätigten Einkäufe über alle Runden, neueste zuerst. Jede Zeile enthält Menge, Gesamtpreis und Stückpreis. Bei gemischten Preisstufen ist der Stückpreis der gerundete Durchschnitt. Weitere Details stehen im Tooltip.

**Verkäufe** zeigt die in ForeverFlip erfassten laufenden und vergangenen Auktionen. Mit **Offen** oder **Verkauft** filterst du die Liste. Bei bestätigten Teilverkäufen erscheinen die offene und verkaufte Menge. Ein ungeklärter Auktionsstatus bleibt markiert. **Auktionen prüfen** aktualisiert die Daten am AH.

**Scan-Stats** vergleicht Treffer und Gewinn je 100 beantwortete AH-Abfragen pro Item. Der Gewinn berücksichtigt die seit Version 0.2.7 erfassten, vollständig verkauften Käufe. Im Tooltip stehen Serverzeiten, Fehler und Ergebnisse für Käufe ab zwei Stück. Der Export enthält dieselben Rohzähler. Ein AH-Fehler allein verrät nicht, ob ein anderer Käufer schneller war.

Beim Vorbereiten eines Verkaufs zeigt die Kopfzeile den zuletzt abgefragten **Marktpreis** und den **gewählten Einstellpreis** je Stück sowie die gewählte Preisart. Ziehe das Fenster an der Ecke unten rechts größer oder kleiner. Die Zahl der Zeilen passt sich an und die Fenstergröße wird pro Charakter gespeichert.

**Bestand** zeigt offene Mengen aus allen Runden mit Einkaufskosten, Gewinnschwelle, 7- und 30-Tage-Median und einem Vergleich mit dem 30-Tage-Hoch. Fahre mit der Maus über eine Zeile für weitere Details. **Auktionen prüfen** liest die eigenen Auktionen neu ein. Ein fehlender Eintrag bleibt ungeklärt, bis du den Status prüfst.

**Export** markiert tabulatorgetrennte Daten zum Kopieren mit **Strg+C**. Enthalten sind Runden, Ausgaben, Positionen, bestätigte Verkaufsmengen, rechnerische Nettoerlöse und beobachtete Auszahlungen aus dem Briefkasten. AH-Post kann Erlöse aus anderen Verkäufen und zurückerstattete Kautionen enthalten. Sie bleibt deshalb getrennt von den ForeverFlip-Rundenerlösen. Zur Analyse kannst du den kopierten Text direkt weitergeben. Er enthält keine Charakter- oder Spielernamen.

**Bilanz** zeigt standardmäßig alle bestätigten Käufe und den Nettoerlös bestätigter Verkäufe. Wählbar sind zusätzlich die letzten 1, 7, 30 und 90 Tage. Die Bilanz zieht Ausgaben und erkannte verlorene Kautionen ab. Verkäufe zählen bei ihrer Erkennung, auch bei Teilerlösen. Auszahlungen werden weiterhin separat erfasst. Altdaten ohne Zeitstempel erscheinen unter Gesamt.

Der Export enthält ab 0.4.0 eine Zeile je gefundenem Angebot, auch bei Ablauf, Überspringen oder fehlgeschlagenem Kauf. Bei Kaufversuchen trennt er Antwortzeiten des AH und die Wartezeit bis zum nächsten Klick. Der gemeldete AH-Fehlercode und das endgültige Ergebnis stehen in eigenen Spalten. **DatabaseError** entspricht **Internal auction error**. Der Code allein verrät nicht, warum der Kauf scheiterte. Die Bilanz verwendet den zuletzt gewählten Zeitraum. Große Exporte kopierst du mit **Weiter** in der angezeigten Reihenfolge.

### Ausnahmen nachprüfen

- Wenn du Ware schon abgeholt hast und die automatische Zuordnung fehlt, prüfe die AH-Post und nutze `/ff collect RUNDE POSITION`. Derselbe Befehl ordnet eine vollständig zurückgekommene Auktion neu zu, wenn ihre Auktion-ID im AH nicht mehr auftaucht. Die bisherige Kaution wird in diesem Fall als Verlust berücksichtigt.
- Ist eine Position vollständig verkauft und du hast den Nettoerlös laut Beleg geprüft, kannst du ihn als **Kupferbetrag abzüglich zurückerstatteter Kaution** mit `/ff receipt RUNDE POSITION KUPFER` nachtragen. Beispiel für R2.1 und 59 Silber netto: `/ff receipt 2 1 5900`.
- Bleibt eine Kaufantwort nach dem Bestätigungsklick aus, sperrt ForeverFlip weitere Käufe bis zur Klärung. Prüfe Gold und AH-Post. Verwende danach `/ff resolve bought` bei bestätigtem Kauf oder `/ff resolve failed` bei bestätigtem Fehlschlag. Prüfe bei einer ungeklärten Einstellung zuerst im AH, ob die Auktion existiert. Nur wenn sie nicht eingestellt wurde, verwende `/ff resolve unlisted`. Bei einer vorhandenen Auktion kannst du die bestätigte Auktion-ID mittels `/ff resolve listed ID` zuordnen.

0.5.0 behebt den Startfehler von 0.4.0 durch die Aufteilung der Anzeigenfunktion. Slash-Befehl, Katalog, Bilanz, Kaufprotokoll und Preisstufenrechnung wurden mit simulierten WoW-Ereignissen geprüft.

0.5.1 berücksichtigt gruppierte AH-Zeilen für Einzelauktionen bei der Preisermittlung.

0.6.0 ergänzt den Sofortkauf und die Einstellung von Einzelauktionen sowie das Nachrücken im Verkaufsfenster. Diese Abläufe wurden mit simulierten AH-Ereignissen getestet.

0.6.1 zeigt während der Suche unten in der Handelsrunde die scrollbare Kaufhistorie. Bestätigte Käufe stehen oben. Du siehst Menge, tatsächliche Ausgaben, den letzten verfügbaren Marktpreis aus dem AH-Scan oder AHledger und die beim Kauf errechneten Stückpreise für beide Verkaufsvarianten. AH-Abzug und erwarteter Gewinn gelten jeweils für die gesamte gekaufte Menge. Der Gewinn berücksichtigt die tatsächlichen Einkaufskosten und bereits verlorene Kautionen. Bei älteren Käufen erscheint der damals gespeicherte Zielpreis. Den Zeitpunkt und die Quelle des Marktpreises findest du im Tooltip.

Quellen: [Blizzards Addon-Richtlinie](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1) · [AHledger API](https://ahledger.com/developers) · [WoW AuctionHouse API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
