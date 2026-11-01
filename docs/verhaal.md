# De Nacht van de Rasterstraal

Een voorstel voor het verhaal achter Raster Rumble. Dit is mijn eerste versie: schrap, wijzig en vul aan.

## Het verhaal

Het is 1986. Een kind gaat naar bed en vergeet de Commodore 64 uit te zetten. De computer staat nog aan en de monitor gloeit in het donker.

Binnen in die machine leeft **Pixel**, een klein schip, een sprite die al jaren op dezelfde plek hangt. Vannacht gebeurt er iets: de **Rasterstraal**, de lichtbundel die 50 keer per seconde het scherm van boven naar beneden tekent, begint te haperen. Als hij stilvalt, valt de wereld uit elkaar. Alles wat in het geheugen leeft verdwijnt, ook Pixel.

Pixel heeft tot de ochtend. Rond 07:00 komt iemand de kamer in en zet de stekker eruit. Om dan nog te bestaan, moet Pixel zijn naam wegschrijven op de **diskette**: de enige plek die de stroom overleeft.

De reis gaat door de machine, van de bovenkant van het scherm naar de diepste lagen van het geheugen. Elk uur van de nacht is een hoofdstuk.

## De hoofdstukken

| Uur | Hoofdstuk | Wat er in het verhaal gebeurt | Wat het in de game betekent |
|---|---|---|---|
| 23:00 | **Opstarten** | Pixel merkt dat er iets mis is. De eerste *bugs* vallen uit het scherm. | Wat het spel nu is: één vijand, leren sturen. Na 10 ontwijkers klinkt een "ting ting": de eerste echte storing. |
| 01:00 | **De Glitch** | Een nieuw soort fout. Hij lijkt traag en onschuldig, tot hij ineens schiet. | De tweede vijand uit hoofdstuk 2: valt langzaam, versnelt na een vaste tijd, zonder waarschuwing. Ander model. |
| 03:00 | **Het Randgebied** | Pixel vliegt tot aan de rand van het scherm, waar de kleuren van de border beginnen. Daar is de wereld dun. | Vijanden komen schuin of van de zijkant. Border en achtergrond knipperen mee met de storing. Nieuwe kleuren en een andere bas. |
| 04:30 | **Het Geheugen** | Pixel zakt door de geheugenbanken. Oude programma's slapen daar en worden wakker. | Twee vijanden tegelijk. Parallax-banden schuiven met verschillende snelheid. De explosie hergebruikt sprites van vernietigde vijanden. |
| 06:00 | **De Rasterstraal** | De straal zelf is het gevaar geworden. Hij veegt over het scherm. | Eindbaas: een horizontale balk die van boven naar beneden zakt met één of twee gaten. Pixel moet in het gat zitten. De balk past bij de naam van de game en bij onze raster-effecten. |
| 07:00 | **De Diskette** | Voetstappen op de gang. De deur gaat open. Pixel schrijft zijn naam weg en het scherm gaat zwart. | Eindscherm waarin je je initialen invoert en de hoogste score op disk wordt bewaard. De scroller vertelt het slot. |

## Hoe het verteld wordt

Geen lange teksten. Het verhaal komt via dingen die we al hebben of makkelijk kunnen bouwen:

- **Titelscherm-scroller**: de lopende tekst vertelt de aanleiding ("Het is 1986. Iemand vergat de stekker...").
- **Tussenscherm bij elk hoofdstuk**: zwart scherm, tijdstip groot, twee of drie regels tekst die letter voor letter verschijnen. Eén sleutelzin per hoofdstuk.
- **Game over per hoofdstuk**: een andere zin, afhankelijk van waar je viel. Bijvoorbeeld in Het Geheugen: "Pixel werd vergeten."
- **Levens** zijn de herinneringen van Pixel. Een leven kwijt is een herinnering kwijt.
- **Muziek en kleur** veranderen per hoofdstuk, zodat je hoort en ziet dat je verder bent.

## Hoe voortgang werkt

- Elk hoofdstuk duurt een vast aantal ontweken vijanden (bijvoorbeeld 25) en eindigt met het tussenscherm.
- Je begint na game over opnieuw bij hoofdstuk 1. Het hoogste hoofdstuk dat je haalde blijft staan naast de score. Een eventuele checkpoint-regel is een latere keuze.
- Per hoofdstuk één nieuw ding om te leren, nooit twee tegelijk.

## Wat dit vraagt van de code

| Wat | Idee |
|---|---|
| Hoofdstukteller | Eén byte `chapter` in `config.asm`, op 0 in `reset_difficulty`. |
| Tabellen per hoofdstuk | Kleuren, snelheid, aantal vijanden, muziekdeel, dodges om te halen: één rij per hoofdstuk in `data.asm`. |
| Tussenscherm | Hergebruik de tekstroutines en de raster-effecten uit `title.asm` en `demo.asm`. |
| Meer vijanden | De tabel-refactor uit `docs/hoofdstuk2.md`, dan het sprite-budget. |
| Eindbaas | Raster-interrupt voor de balk; botsing op Y-bereik in plaats van sprite-botsing. |
| Disk opslaan | KERNAL SAVE/LOAD, staat al op de lijst. |

## Voorstel voor de volgorde

1. **Hoofdstukteller en tussenscherm** met alleen wat er nu is. Het verhaal is meteen zichtbaar.
2. **De Glitch** (hoofdstuk 2 uit de notities).
3. **Het Randgebied**: kleuren, schuine vijanden.
4. **Het Geheugen**: meerdere vijanden.
5. **De Rasterstraal**: eindbaas.
6. **De Diskette**: einde en opslaan.

Elke stap is los te spelen en te testen.

## Open punten

- Passen de naam Pixel en de nacht van 1986 bij jou? Zo niet, wat dan wel?
- Zes hoofdstukken of korter?
- Wil je dat de game in het Nederlands of in het Engels verteld wordt? (Mijn gok: Engels op het scherm, want het is een C64-spel dat vreemden moeten kunnen lezen.)
