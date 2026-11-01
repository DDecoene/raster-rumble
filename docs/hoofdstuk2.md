# Hoofdstuk 2: de tweede vijand

Notities uit de brainstorm. Doel: jij schrijft de code, Claude legt uit en reviewt.

## Wat we willen

- Bij de **tiende ontweken vijand** klinkt een speciaal "ting ting" in plaats van het gewone dodge-geluid.
- Vanaf dan komt er een **tweede vijandtype** bij met een **ander model**.
- Type 2 zakt eerst **langzaam**, en na een **vaste tijd** versnelt hij plotseling. Het moment is elke keer hetzelfde en er is **geen waarschuwing**.
- Type 1 blijft zoals nu. Hits, levens en game over blijven ook zoals ze zijn.
- Later (idee): per leven meer vijanden, bijvoorbeeld 2x type 1 en 1x type 2, daarna 2 van elk.

## Hoe het nu werkt

| Onderdeel | Waar |
|---|---|
| Dodge tellen en versnellen elke 10 dodges | `count_dodge` in `src/actors.asm`, aangeroepen op `main.asm:263` |
| Dodge-geluid (SID voice 3) | `main.asm` rond regel 244-258 |
| Spawnen met 9-bit X | `spawn_enemy` in `src/actors.asm` |
| Botsing | `SPR_COLL` ($d01e), alleen bit 0 en 1 getest |
| Explosiedeeltjes | `src/effects.asm`, gebruiken sprite 2 t/m 7 |
| Instellingen | `src/config.asm` (`DODGES_PER_LEVEL`, `ENEMY_SPEED`, `MAX_SPEED`) |

Let op: de vijand wordt nu al sneller bij elke 10 dodges. Beslis of de nieuwe vijand **één keer** (bij de eerste tien, aanbevolen) of bij **elke tien** verschijnt.

## Het sprite-probleem

De C64 heeft 8 hardware-sprites: 0 is het schip, 1 de vijand, 2 t/m 7 zijn nu voor de explosie. Een nieuwe vijand moet dus een sprite krijgen (bijvoorbeeld sprite 7) en de explosie moet daarop aangepast worden.

- De **shape** (64 bytes) kan door meerdere sprites gedeeld worden: pointers `$07f8-$07ff` mogen naar hetzelfde blok wijzen.
- Een **hardware-sprite** heeft maar één X, Y en kleur. Meer kopieën op het scherm kan alleen met **sprite-multiplexing** (raster-interrupt die de Y halverwege verandert). Dat werkt alleen goed als de kopieën in verschillende hoogtebanden zitten. Een idee voor hoofdstuk 3.

## Stappenplan voor één extra vijand

1. Variabele `enemy2_active` (0/1) in `config.asm`, op 0 zetten in `reset_difficulty`.
2. Tweede shape tekenen in `sprites.asm` (nieuw blok van 64 bytes), pointer in `$07ff`.
3. Bij de tiende dodge (in `count_dodge`): activeren, bit in `SPR_ENABLE` ($d015) aanzetten, spawnen.
4. Beweging met een fasetimer: `e2_timer` telt op; onder de drempel valt hij 1 pixel per frame, erboven 5.
5. Onderaan (`MAX_Y`) opnieuw spawnen en de timer resetten.
6. Botsing: `SPR_COLL` testen op bit 0 en het bit van de nieuwe sprite.
7. "Ting ting": twee noten kort na elkaar op voice 3, met een kleine teller voor de tweede noot.

Aandachtspunten: het 9e X-bit zit in `$d010` (`SPR_XHI`), per sprite een eigen bit. Op game over moet alles teruggezet worden.

## Voor later: meerdere vijanden (data-gedreven)

Maak van de losse vijandvariabelen **tabellen** met vijandnummer als index X: type, X laag, X hoog, Y, timer, actief. Eén lus doet het werk voor alle vijanden. Sprite n staat op `$d000 + 2n` (X en Y), de bit voor het 9e X-bit staat in `bit_tab` (`data.asm`). Gedrag per type via `cmp type` of een sprongtabel.

**Sprite-budget**

- Schip + 2 + 2 vijanden = 5 sprites, dus 3 over voor de explosie.
- Schip + 3 + 3 = 7 sprites, dus niets over voor de explosie.

Opties: de explosie hergebruikt de sprites van weggeraakte vijanden, de explosie wordt kleiner, of multiplexen.

**Aanbevolen volgorde:** eerst refactoren naar een tabel met één rij (alles werkt nog hetzelfde), dan rij 2, dan type 2. Elke stap is testbaar.

## Open vragen

- Maximaal aantal vijanden in hoofdstuk 2?
- Nieuwe vijand één keer of bij elke tiende dodge?
- Welke sprites gebruikt de explosie precies? (kijk in `effects.asm`)
