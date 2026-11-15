# ForeverFlip

ForeverFlip wertet bereits geladene AH-Preisstufen in WoW Forever aus. Es zeigt Flip-Kandidaten mit Kaufmenge, St�ck- und Gesamtlimit, Einstellpreis und der rechnerischen Marge f�r den n�chsten K�ufer. Das Addon ist kostenlos und der vollst�ndige Lua-Quellcode liegt im Ordner `ForeverFlip`.

## Installation

Kopiere den inneren Ordner `ForeverFlip`, der die `ForeverFlip.toc` enth�lt, in `_forever_/Interface/AddOns`. Starte WoW neu oder verwende bei laufendem WoW `/reload`. Aktiviere [AHledger](https://ahledger.com/addon) f�r den gesch�tzten Absatz und den Sieben-Tage-Median. F�r wiederholte Suchen kannst du zus�tzlich [auxForever](https://www.curseforge.com/wow/addons/auxforever) installieren.

## Benutzung

1. �ffne das AH. Das Fenster erscheint rechts und l�sst sich verschieben. Mit `/ff` kannst du es bei ge�ffnetem AH erneut zeigen.
2. Gib beispielsweise `/ff budget 4` ein. Das Limit gilt pro Vorschlag. Pr�fe bei mehreren K�ufen den verbleibenden Einsatz.
3. Suche im Blizzard-AH manuell nach einem Material oder kopiere �ber **Suchliste** den Text in die Suche von auxForever. Speichere ihn dort als Favorit und probiere **Full** und **Live**. Hier bezeichnet **Full** die Detailansicht f�r die gezielte Suche. Sobald WoW die Preisstufen eines Artikels liefert, berechnet ForeverFlip den Vorschlag. Klicke in der schnellen Suche auf das Material, um seine Preisstufen zu laden.
4. Pr�fe Menge, St�cklimit und Gesamtpreis beim Kauf. Stelle die Ware zum angezeigten Preis ein, solange die Preisstufen noch plausibel sind. Pr�fe bei einem Kandidaten mit ungekl�rtem NPC-Preis vor dem Kauf die H�ndlerquelle.

## Berechnung

- Startliste aus Stoffen, Erzen, Barren, Leder, Kr�utern, Staub und Stein. Der gesch�tzte Tagesabsatz von AHledger muss mindestens 1.000 St�ck betragen. Die H�chstmenge pro Angebot entspricht einem Viertelstundenanteil des gesch�tzten Marktabsatzes.
- Ein Kandidat r�umt die g�nstigen Preisstufen f�r das Item innerhalb des Budgets ab. Als Bezugspreis f�r den n�chsten H�ndler gilt der niedrigere Wert aus der verbleibenden Preisstufe minus einem Kupfer und dem Sieben-Tage-Median. Bekannte g�nstigere NPC-Preise begrenzen den Bezugspreis zus�tzlich. Der H�ndlerbestand ist in dieser Version nicht live verf�gbar.
- Beide Handelsstufen m�ssen nach jeweils 5 % AH-Geb�hr mindestens 5 % Rendite auf den jeweiligen Einkauf erreichen. Die Anzeige setzt einen vollst�ndigen Verkauf voraus. Eine verlorene Einstellgeb�hr bei Ablauf oder Abbruch ist separat zu ber�cksichtigen.
- Empfehlungen laufen nach 20 Sekunden ab. F�r aktualisierte Ergebnisse muss der Client wieder Preisstufen liefern.

ForeverFlip verwendet die AH-Lesefunktionen, die auch AHledger verwendet. Die Suchabfragen kommen aus der normalen AH-Oberfl�che oder auxForever. Kauf und Verkauf best�tigst du dort selbst. Die erste Version wurde mit simulierten WoW-Ereignissen gepr�ft. Die Kombination aus auxForever Full und Live muss im Forever-Client verifiziert werden.

Quellen: [Blizzards Addon-Richtlinie](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1) � [AHledger API](https://ahledger.com/developers) � [auxForever](https://github.com/TylerHampton/aux-forever)
