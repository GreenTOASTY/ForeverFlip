# ForeverFlip

ForeverFlip begleitet Handelsrunden f�r h�ufig gehandelte Materialien in WoW Forever. Es verwendet die AH-Schnittstellen des Clients und die dokumentierte Ingame-API von AHledger f�r gesch�tzten Absatz und historische Preisvergleiche. ForeverFlip ist kostenlos.

## Installation

Kopiere den Ordner `ForeverFlip` mit der `ForeverFlip.toc` direkt nach `_forever_/Interface/AddOns`. Starte WoW neu oder gib `/reload` ein. Aktiviere [AHledger](https://ahledger.com/addon) zur Bewertung der Materialien. Die Suche l�uft direkt in ForeverFlip.

## Handelsrunde

1. Gib `/ff budget 4` ein und geh zum AH. W�hle die Materialien f�r die Suche. Das Budget gilt f�r alle Eink�ufe dieser Runde zusammen.
2. Klicke **Suchen**. Der Client erh�lt nacheinander je eine Abfrage f�r die ausgew�hlten Artikel. Sobald die Runde durch ist und das AH bereit ist, leuchtet **Erneut suchen** an derselben Stelle auf.
3. **Kauf pr�fen** fragt den Gesamtpreis f�r genau die angezeigte Menge ab. **Kauf best�tigen** erscheint nach der Antwort an derselben Stelle. �ndert sich der Preis, verf�llt die Best�tigung. Ausgaben z�hlen nach best�tigtem Kauf. Bei h�chstens 5 Silber Restbudget endet die Einkaufsphase.
4. Nach f�nf Minuten ab dem ersten Kauf erinnert **Zum Briefkasten?** ans Abholen. Du kannst die Einkaufsphase vorher beenden. Hole die AH-Post im Briefkasten selbst ab. Das Addon ordnet erkannte K�ufe bei der Abholung den Runden zu.
5. Geh zum AH zur�ck. **Verkauf vorbereiten** l�dt einen frischen Preis f�r die Ware. Standardm��ig erscheint der Preis mit Spielraum f�r Zwischenh�ndler, sofern er die Regeln erf�llt. Mit **Knapp unter Markt** wechselst du zum direkten Unterbieten. **Einstellen best�tigen** ver�ffentlicht die Auktion zu dem angezeigten Preis. Bei einer zus�tzlichen Blizzard-Preiswarnung ist eine weitere Best�tigung n�tig. Kann die Ware unter dem Tiefstpreis die Einkaufskosten nach Provision nicht decken, bleibt sie im Bestand.

Kaufvorschl�ge brauchen gesch�tzten Absatz, einen Sieben-Tage-Median und sichtbare Preisstufen. Die Rechnung pr�ft beide Handelsmargen nach Provision und der Bezugspreis bekommt 5 % Puffer f�r einen R�ckgang. Die Menge ist auf einen Viertelstundenanteil des gesch�tzten Marktabsatzes begrenzt. Verkaufsdauer und k�nftige Preise bleiben Sch�tzungen. Bei ungekl�rtem NPC-Preis pr�fe vor dem Kauf die H�ndlerquelle.

## Bestand und Export

**Bestand** zeigt offene Mengen aus allen Runden mit Einkaufskosten, Gewinnschwelle, 7- und 30-Tage-Median und einem Vergleich mit dem 30-Tage-Hoch. Fahre mit der Maus �ber eine Zeile f�r weitere Details. **Auktionen pr�fen** liest die eigenen Auktionen neu ein. Ein fehlender Eintrag bleibt ungekl�rt, bis du den Status pr�fst.

**Export** markiert tabulatorgetrennte Daten zum Kopieren mit **Strg+C**. Enthalten sind Runden, Ausgaben, Positionen, best�tigte Verkaufsmengen, rechnerische Nettoerl�se und beobachtete Auszahlungen aus dem Briefkasten. AH-Post kann Erl�se aus anderen Verk�ufen und zur�ckerstattete Kautionen enthalten. Sie bleibt deshalb getrennt von den ForeverFlip-Rundenerl�sen. Zur Analyse kannst du den kopierten Text direkt weitergeben. Er enth�lt keine Charakter- oder Spielernamen.

### Ausnahmen nachpr�fen

- Wenn du Ware schon abgeholt hast und die automatische Zuordnung fehlt, pr�fe die AH-Post und nutze `/ff collect RUNDE POSITION`. Derselbe Befehl ordnet eine vollst�ndig zur�ckgekommene Auktion neu zu, wenn ihre Auktion-ID im AH nicht mehr auftaucht. Die bisherige Kaution wird in diesem Fall als Verlust ber�cksichtigt.
- Ist eine Position vollst�ndig verkauft und du hast den Nettoerl�s laut Beleg gepr�ft, kannst du ihn als **Kupferbetrag abz�glich zur�ckerstatteter Kaution** mit `/ff receipt RUNDE POSITION KUPFER` nachtragen. Beispiel f�r R2.1 und 59 Silber netto: `/ff receipt 2 1 5900`.
- Bleibt eine Kaufantwort nach dem Best�tigungsklick aus, sperrt ForeverFlip weitere K�ufe bis zur Kl�rung. Pr�fe Gold und AH-Post. Verwende danach `/ff resolve bought` bei best�tigtem Kauf oder `/ff resolve failed` bei best�tigtem Fehlschlag. Pr�fe bei einer ungekl�rten Einstellung zuerst im AH, ob die Auktion existiert. Nur wenn sie nicht eingestellt wurde, verwende `/ff resolve unlisted`. Bei einer vorhandenen Auktion kannst du die best�tigte Auktion-ID mittels `/ff resolve listed ID` zuordnen.

0.2.0 ist eine Testversion. Die Handelsabl�ufe wurden mit simulierten WoW-Ereignissen gepr�ft. Suche, Kauf, Postabholung und Einstellen m�ssen noch im Forever-Client verifiziert werden.

Quellen: [Blizzards Addon-Richtlinie](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1) � [AHledger API](https://ahledger.com/developers) � [WoW AuctionHouse API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
