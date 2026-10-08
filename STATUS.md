# STATUS – Carrot Market

Senast uppdaterad: 8 okt 2026. Aktuell fas: **Fas 1 – spelbar version (byggd, väntar på grind-test)**.

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

- **Auto-omplantering:** skörd planterar direkt ett nytt Basic-frö, så plots aldrig står tomma (`Economy.AutoReplant`). Färre tryck, samma loop.
- **Korg redan i fas 1:** skördar går till en korg (tak 200) och säljs med SELL var som helst till fullt pris. Är korgen full säljs moroten direkt. Lagerbeslutet (boom) kommer i fas 3.
- **8 farmer redan nu:** fas 1 säger "en farm", men flera testare i samma server behöver var sin. Varje spelare får en egen farm vid join (fas 3-tilldelningen är alltså redan gjord i enkel form). **Sätt Max Players = 8 i Creator Hub** så att ingen blir utan farm.
- **Förskjuten skörd:** varje plot har en egen tidsfaktor (0,85–1,5 × 12 s) plus ±8 % slump → 10–18 s i början.
- **Pity räknas redan:** Legendary garanteras efter 250 planteringar (osynligt nu, mätaren kommer i fas 2).
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
| Images.Icon | Spelikon | Saknas |

## Kvar / kända begränsningar

- Plot-tillstånd sparas inte: växande morötter försvinner när man lämnar (offline-tillväxt + skördekorg kommer i fas 2).
- Ingen CarrotDex-skärm, pity-mätare eller fler uppgraderingsspår än Growth Speed (fas 2).
- Inga marknadsevents/boom (fas 3). Utrop till alla servrar (MessagingService) kommer i fas 3; Mythic/Secret ropas nu bara ut i den egna servern.
- Upplevelsen bör vara **privat/endast vänner** fram till soft launch – varje push till `main` publicerar.
- Publiceringsnyckeln behöver Open Cloud-behörigheten `universe-places:write` för universe 10769879996 och en IP-tillåtelse för GitHubs runners (t.ex. `0.0.0.0/0`). 401/403 = nästan alltid något av de två.

## Lokala kontroller

```
./tools/install-tools.sh            # eller: rokit install
stylua --check src && selene src && lune run tests && rojo build default.project.json -o cm.rbxl
```
