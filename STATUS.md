# STATUS – Carrot Market

Senast uppdaterad: 8 okt 2026. Aktuell fas: **Fas 3 – marknad och socialt (byggd, väntar på grind-test)**. Fas 1–2 publicerade.

## Fas 3 – marknad och socialt

| Del | Status | Hur det testas |
|---|---|---|
| EventSchedule (globala events) | Klar | Räknas från `os.time` – samma i alla servrar. Var 10:e minut kommer en boom på 3 min (Carrot Craze ×2 alla, Rare Rush ×3, Gold Rush ×3 muterade, Big Bonanza ×3 stora, Common Craze ×4). Daglig marknad: en rarity ×1,25 hela dagen, samma överallt. Lune-test bevisar att priser aldrig går under bas. |
| Boom bara vid marknaden | Klar | SELL var som helst = fullt baspris. Står du vid marknaden (inom 32 studs) under boom får du boompriset. SELL-rutan visar "$X at market!" under boom och "BOOM PRICE!" när du står där. |
| Prisbräda | Klar | Stor tavla ovanför marknaden: dagens pris per rarity med ▲ när det är förhöjt, nedräkning "Next boom in 4:12" / "Carrot Craze! 2:31 left" och vilken boom som kommer. |
| Lagerkorg | Klar | Korgen startar på 40 och uppgraderas med cash (Basket Size: 80 → 160 → 320 → 640 → 1 280). Full korg = siffran blir röd och nya skördar säljs direkt till baspris. |
| Marknadsklocka + pil | Klar (omgjord) | När boomen startar: klockljud och banner. En kompakt orange "MARKET BOOM! 45m"-pill under toppfältet där bara den lilla pilen i cirkeln roterar mot marknaden (texten står alltid rätt). Försvinner när du är framme. |
| 8 farms, tilldelning | Klar | (sedan fas 1) |
| Piedestal | Klar | Varje farm har en piedestal i främre hörnet där ägarens bästa morot någonsin svävar, stor och glödande, med namn och värde. |
| Utrop i tre nivåer | Klar | Epic: toast till dig. Legendary: banner till hela servern. Mythic/Secret: hela servern + alla andra servrar via MessagingService ("🌍 Anna found a MYTHIC … in another server!"). Fungerar inte i Studio (MessagingService). |
| Vattna en vän | Klar | Tryck på en annan spelares plots → +10 % växtfart för er båda i 2 min (💧-timer uppe till vänster), 2 min cooldown per farm. Skylt "💧 Tap plots to water!" syns över andras farms när du är nära. |
| Vänbonus | Klar | +10 % tur per Roblox-vän i servern, max 3 (👥 +20 % luck uppe till vänster). |
| Gilla en farm | Klar | Prompt "Like ❤" vid farmskylten, ett hjärta per farm och dag. Antal hjärtan syns på skylten. |
| Leaderboards | Klar | Tre tavlor runt torget: 🏆 Veckans bästa morot (nollställs måndagar 00:00 UTC), 💰 Största försäljning, 📖 CarrotDex. OrderedDataStore, uppdateras varje minut. Fungerar inte i Studio utan API-åtkomst. |

## Grind för fas 3 – be Philip testa (helst med 2–3 vänner i samma server)

1. Titta på prisbrädan ovanför marknaden. Vänta in en boom (max 10 min): hörs klockan, syns pilen?
2. Spara morötter i korgen, spring till marknaden under boom och sälj – kändes det som en jackpot?
3. Uppgradera Basket Size.
4. Med en vän: vattna varandras farms, gilla varandras farm, se vänbonusen.
5. Hitta en Epic/Legendary – syns piedestalen och utropen?
6. Kolla leaderboard-tavlorna efter några minuter.

## Fas 2 – progression

| Del | Status | Hur det testas |
|---|---|---|
| Alla 5 uppgraderingsspår | Klar | UPGRADES-rutan: Growth Speed, Luck, Value, Farm Size, Harvest Power. Varje rad visar nivå, "nu → nästa" och pris. Målbaren pekar alltid på billigaste köpet. |
| Plots 4 → 6 → 9 → 12 → 16 | Klar | Farm Size-spåret öppnar nya plots direkt (växande morötter behålls). Nya plots säger "TAP TO PLANT". |
| Frön | Klar | SEEDS-rutan: Rare ($250, aldrig Common, 3× tur), Golden ($2,000, alltid Golden ×3), Mystery ($700, blir Rare 60 % / Golden 37 % / Secret 3 % – oddsen visas), Secret (bara från CarrotDex-belöningar, alltid Legendary+). Köp ×1/×10, USE väljer frö. Priser skalar med Value-uppgraderingen. Bara cash, aldrig Robux. Valt frö används för varje plantering (även auto-omplantering) tills det tar slut. |
| CarrotDex, två lager | Klar | INDEX-rutan: 24 morotstyper (4 Common, 4 Uncommon, 4 Rare, 4 Epic, 3 Legendary, 3 Mythic, 2 Secret) i 3D. Ej hittade visas som siluett med "???", odds "1 in X" syns alltid. Lager 2: tre mutationsprickar per typ (72 stämplar). Röd "!" på Index när du hittat något nytt. Milstolpar ger frön automatiskt (4 hittade → 5 Rare, 8 → 3 Golden, 12 → 5 Mystery, 16/20/24 → Secret; stämplar 5/15/30/50/72). |
| Synlig pity-mätare | Klar | 👑-baren uppe till vänster: "Legendary in 123" – garanterad Legendary inom 250 planteringar. |
| Offline-tillväxt + korg | Klar | Lämna i minst 1 minut och kom tillbaka: "While you were away…" avslöjar morötterna en i taget, snabbare och snabbare, bästa sist. Tak 8 h / 100 morötter. Morötterna ligger i korgen (full korg → säljs automatiskt). Offline används bara Basic-frön. |
| tools/simulate.luau | Klar | `lune run tools/simulate` → `tools/simulation-report.md`. 24 körningar × 4 h. |

### Simulering (sammanfattning, se tools/simulation-report.md)

| Fönster | Median tid till nästa köp | Mål |
|---|---|---|
| 0–10 min | 25 s | 30–90 s |
| 10–30 min | 1:20 | – |
| 30–60 min | 2:56 | 2–3 min |
| 1–2 h | 5:16 | 3–5 min |
| 2–4 h | 12:23 | mjuk vägg (prestige tar över) |

Första Legendary ~6 min, första Mythic ~19 min, Secret i ~40 % av körningarna inom 4 h. 16 plots nås efter ~2 h 40 min. En gratisspelare når max plots och Mythic utan Robux.

## Grind för fas 2 – be Philip testa

1. Köp några uppgraderingar av olika slag. Känns nästa köp lagom nära?
2. Köp Farm Size och se nya plots dyka upp.
3. Öppna SEEDS, köp Rare Seeds, tryck USE och plantera. Pröva Mystery Seed.
4. Öppna INDEX – syns hittade morötter i färg och oupptäckta som siluetter? Får du frön vid 4 hittade?
5. Följ pity-mätaren.
6. Lämna spelet i några minuter, kom tillbaka och se avslöjandet "While you were away…".

## Fas 1 – tickets

| Ticket | Status | Hur det testas |
|---|---|---|
| F1.1 Skelett och CI | Klar | Push till `main` → Actions-jobbet `deploy` kör StyLua, Selene, Lune-tester, Rojo-build och publicerar. Andra grenar kör bara kontrollerna. |
| F1.2 WorldBuilder | Klar | Allt byggs i kod: gräsmark, torg, marknadskiosk med randigt tak och jättemorot, 8 farmer (16 plot-platser var, 4 upplåsta), stängsel, skyltar, stigar, träd, stenar, belysning, himmel, atmosfär. |
| F1.3 Config och RollService | Klar | `lune run tests`: 1 000 000 slag. Utfall med ≥ 2 000 förväntade träffar ligger inom ±5 %, sällsyntare (Mythic, Secret, Giant…) inom 5 standardavvikelser. |
| F1.4 Farm-loop | Klar | Tryck på en plot → planteras. Fyra växtfaser (blast växer, morotstopp syns från 50 %). Tryck när den är klar → skörd + automatisk omplantering. Servern validerar plotindex, ägare och tid, och rate-limitar. |
| F1.5 Reveal och skördeögonblick | Klar | Skimmer (Rare+/mutation) från 25 %, gnistor (Epic+) från 50 %, ljuspelare (Legendary+) från 75 % – syns för alla. Skörd: pop, partiklar, värdetext i rarity-färg, morötter flyger till SELL. Legendary+: långsam snurr, kamerazoom, blixt, banner till hela servern. |
| F1.6 Ekonomi | Klar | Skördade morötter hamnar i korgen. SELL-knappen (var som helst) eller "Sell All"-prompten vid marknaden säljer allt; pengar flyger till plånboken och räknas upp. Talformat 1,600 / 12.3K / 4.56M. |
| F1.7 Första uppgraderingen + målbar | Klar | Startcash $20 + fyra skördar räcker till Growth Speed 1 ($50). Målbaren under cash visar "Growth Speed 1 – $X left", "sell carrots to afford!" eller "TAP TO BUY!". |
| F1.8 Sparning | Klar | ProfileStore med session locking, versionsnummer och migreringar. Sparar cash, uppgraderingar, hittade typer, mutationsstämplar, korgen, pity och statistik. DataStore: `CM_Dev_v1`. |
| F1.9 Mobil-HUD | Klar (omgjord) | Stil från dagens toppspel (se nedan). UIScale efter skärmhöjd, inget kräver hover/tangentbord. Plot-etiketterna ("TAP TO PLANT", nedräkning, "TAP TO HARVEST!") är också tryckbara. |

## HUD-layout (inspirerad av populära simulatorer, mobil först)

- **Målbar i Robloxs toppfält** (via `GuiService.TopbarInset`): gul progress-bar med ⬆️-ikon, "Growth Speed 2 … $34/$58". Blir grön och pulserar med "TAP TO BUY!" – tryck köper direkt. Får den inte plats hamnar den strax under toppfältet.
- **Vänster stapel:** chunkiga kvadratiska knappar med gradient, tjock kontur och etikett över nederkanten. Nu bara "Upgrades" (röd "!"-badge som vickar när du har råd). Index/Shop läggs här i fas 2/4.
- **Höger:** stor grön SELL-ruta med korg-ikon och grön antal-badge, korgens värde i stor text under. Sitter ovanför hoppknappen, nära tummen.
- **Nere till vänster:** valutastapel med stora konturerade siffror: 🥕 korg (12/200) och 💵 cash.
- **Toasts:** stor konturerad text ovanför mitten nertill (som "Cannot use items in the safe zone!").
- **Sälj:** stor "+$1,234"-popup mitt på skärmen som krymper in i plånboken medan pengar flyger dit.
- **Typsnitt:** Luckiest Guy för siffror och rubriker, Fredoka One för småtext.
- **Ikoner:** emoji-fallback (🥕 💵 🧺 ⬆️) tills riktiga ikoner laddas upp i `Config/Assets.Images` (Cash, Carrot, Basket, Upgrade).

## Grind för fas 1 – be Philip testa (på iPhone)

1. Öppna spelet. Du teleporteras till din farm (skylten har ditt namn).
2. Tryck på de fyra jordplättarna → de planteras. Etiketten visar nedräkning.
3. Tryck när det står "TAP TO HARVEST!" → moroten poppar, värdet syns, moroten flyger till SELL.
4. Tryck SELL → pengarna flyger upp till plånboken.
5. Tryck på den gula målbaren uppe i toppfältet ("TAP TO BUY!") → Growth Speed 1 köps. Mål: inom 60 sekunder.
6. Spela några minuter: du ska få din första mutation (Golden) senast vid plantering nr 18.
7. Lämna och kom tillbaka: cash, uppgraderingar och korgen ska finnas kvar.
8. Klart-kriterier i designplanen: minst fem personer testar och de flesta fortsätter spela utan att bli ombedda.

Bra att veta vid test: du kan trycka på dina plots (eller etiketten ovanför) så länge de syns på skärmen. SELL och UPGRADES funkar överallt.

## Beslut tagna under bygget (regel 10)

Fas 3:
- **Boompriset betalas bara vid marknaden** (designplan §2: sälj på plats till fullt pris, marknaden ger bonus under boom). Det gör korgen och marknaden till ett riktigt beslut.
- **Boom i slutet av varje 10-minuterscykel** (7 min väntan, 3 min boom) så nedräkningen alltid pekar framåt. Boomtypen väljs med en deterministisk hash av cykelnumret.
- **Daglig marknad** (en rarity ×1,25 hela dagen, alla servrar) gäller överallt, inte bara vid marknaden.
- **Korgen startar på 40** (var 200) så att lagerbeslutet märks; Basket Size-spåret köps med cash. Gamepasset Big Basket kommer i fas 4.
- **Vattning** ger båda spelarna bonus, räknas bara i servern, cooldown 2 min per farm.
- **Piedestalen** jämför bästa morot på basvärde (utan event-bonus) så ingen "fuskar till sig" en topp under boom.
- **Rikast-listan** väntar till prestige (Update 1), enligt designplanen.
- **Profilversion 3** (pedestal, likes, största försäljning) med migrering.


Fas 2:
- **Balans efter simulering:** startvärdena gav 117 köp på 10 min och Mythic efter 11 min (Luck kunde nå ×7). Ny kurva: Growth ×1,65/nivå (max 25), Luck +5 %/nivå ×1,65 (max 40 → ×3), Value +10 %/nivå ×1,38, Harvest Power +8 %/nivå ×1,6, Farm Size $1,500 / $20K / $200K / $1,5M.
- **Fler morotstyper:** fas 1 hade 8, nu 24 (målet ~30) för att Dex ska ha en riktig samlarsvans redan nu.
- **Fröpriser skalar med Value-uppgraderingen** så frön förblir intressanta hela spelet.
- **Mystery Seed** är slumpad men köps bara med cash, och oddsen visas (§11).
- **Offline använder bara Basic-frön** så att ingen förlorar köpta frön medan de är borta.
- **Profilversion 2** med migrering från v1 (inga data förloras).
- **UI-fix efter test 2:** boom-pilen var en roterande jättepil där texten följde med upp och ner; nu en liten pill med upprätt text och avstånd. Knapparna Upgrades/Seeds/Index ligger nu i en rad under valutorna så Index inte hamnar på tumspaken.
- **UI-fix efter test:** målbaren centreras i toppfältet med säkerhetsmarginal mot Robloxs knappar, valutor uppe till vänster (tumspaken äger nere till vänster), toasts smalare, ljusare barnvänlig palett, partikel-aura på alla morötter som växer med rarity.

Fas 1:

- **Auto-omplantering:** skörd planterar direkt ett nytt Basic-frö, så plots aldrig står tomma (`Economy.AutoReplant`). Färre tryck, samma loop.
- **Korg redan i fas 1:** skördar går till en korg (tak 200) och säljs med SELL var som helst till fullt pris. Är korgen full säljs moroten direkt. Lagerbeslutet (boom) kommer i fas 3.
- **8 farmer redan nu:** fas 1 säger "en farm", men flera testare i samma server behöver var sin. Varje spelare får en egen farm vid join (fas 3-tilldelningen är alltså redan gjord i enkel form). **Sätt Max Players = 8 i Creator Hub** så att ingen blir utan farm.
- **Förskjuten skörd:** varje plot har en egen tidsfaktor (0,85–1,5 × 12 s) plus ±8 % slump → 10–18 s i början.
- **Pity:** Legendary garanteras efter 250 planteringar; mätaren syns i HUD sedan fas 2.
- **Första mutationen:** skriptad Golden på plantering nr 18 om spelaren aldrig fått en (~1–2 min in).
- **Growth Speed:** −5 % per nivå multiplikativt (0,95^nivå), golv 3 s, kostnad $50 × 1,15^nivå.
- **Ljud:** inga uppladdade ljud än. Platshållare använder Robloxs inbyggda `rbxasset://sounds/...` (kräver ingen uppladdning); saknas en fil blir det bara tyst.
- **Verktyg i CI:** i stället för `setup-rokit` laddar `tools/install-tools.sh` ned samma versioner som `rokit.toml` direkt från GitHub Releases (ingen beroende på API-rate-limits). Lokalt funkar `rokit install`.
- **Publicering bara från `main`:** workflowen körs på alla grenar men publicerar bara på `main`.

## Saknade assets (Config/Assets.luau)

| Asset | Används till | Nu |
|---|---|---|
| Sounds.Plant | Plantering | Tyst |
| Sounds.Pop / Harvest / Sell / Purchase | Skörd, sälj, köp | Platshållare `electronicpingshort.wav` |
| Sounds.RareHarvest | Rare-skörd | Tyst (använder Harvest med högre tonhöjd) |
| Sounds.Legendary | Legendary+ fanfar | Platshållare `victory.wav` |
| Sounds.Shimmer / Pillar | Reveal steg 1 och 3 | Tyst |
| Sounds.Discover / Click | Ny morot, knappar | Tyst |
| Meshes.Carrot | Morotsmodell | Byggd av primitiva delar |
| Images.Cash / Carrot / Basket / Upgrade | HUD-ikoner | Emoji-fallback (💵 🥕 🧺 ⬆️) |
| Images.Seeds / Index / Crown | HUD-ikoner (fas 2) | Emoji-fallback (🌱 📖 👑) |
| Sounds.Bell | Marknadsklocka | Platshållare `electronicpingshort.wav` |
| Sounds.Water | Vattning | Tyst |
| Images.Icon | Spelikon | Saknas |

## Kvar / kända begränsningar

- Morötter som växer när man lämnar räknas inte (offline-skörden räknar från noll med Basic-frön).
- Fler mutationer (mål 8) och dubbelmutationer kommer med säsonger.
- Inga marknadsevents/boom (fas 3). Utrop till alla servrar (MessagingService) kommer i fas 3; Mythic/Secret ropas nu bara ut i den egna servern.
- MessagingService och OrderedDataStore fungerar bara i publicerade servrar (inte i Studio).
- Upplevelsen bör vara **privat/endast vänner** fram till soft launch – varje push till `main` publicerar.
- Publiceringsnyckeln behöver Open Cloud-behörigheten `universe-places:write` för universe 10769879996 och en IP-tillåtelse för GitHubs runners (t.ex. `0.0.0.0/0`). 401/403 = nästan alltid något av de två.

## Lokala kontroller

```
./tools/install-tools.sh            # eller: rokit install
stylua --check src && selene src && lune run tests && rojo build default.project.json -o cm.rbxl
```
