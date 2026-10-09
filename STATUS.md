# STATUS – Carrot Market

Senast uppdaterad: 8 okt 2026 (kväll). Aktuell fas: **Fas 5 – soft launch (förberedd, väntar på Philips steg nedan)**. Fas 1–4 publicerade.

## Fixar efter test (9 okt)

| Del | Status | Hur det testas |
|---|---|---|
| "Like"-prompten på egen farm | Fixad | Gilla-prompten vid din egen grind visas inte längre för dig, bara för andra spelare. Servern nekar fortfarande självgillning. |
| Legendary-räknaren | Omgjord | Ingen nedräkning på skärmen längre. Varje farm har en träskylt med tak till höger om grinden ("👑 LEGENDARY – in 123 plants" + gul stapel), läsbar från stigen och inifrån farmen, för alla spelare. Den ändras bara när du planterar (statisk skylt, ingen tickande timer). |
| HUD: korg + knappar | Fixat | Korgmätaren var extremt lång (den växte av sig själv). Nu ett litet fast kort (🧺 81/120 $13.9K) med en tjock stapel under. Knapparna Daily/Seeds/Index/Shop ligger direkt under korgkortet, högre upp, så de inte krockar med tumspaken. |
| Menyer såg konstiga ut | Fixat | Den mörka bakgrunden bakom menyer krympte med skärmskalan och täckte bara en ruta. Nu täcker den hela skärmen och bara själva menyrutan skalas. |
| För stor text i menyer | Fixat | Alla menyer (Upgrades, Seeds, Index, Shop, Daily, erbjudanden, Admin) ritas 20 % mindre (`UI.PANEL_SCALE`). |
| Admin-pratbubblan | Mindre | Bubblan med avatar är nu ca 60 % av förra storleken. |
| Färdiga morötter på nytt konto | Fixat | Efter "Reset account" sparades den gamla farmens morötter tillbaka in i det nya kontot (offline-sparningen). Nu töms farmen först, så ett nytt konto börjar med tomma plots: plantera → växa → skörda → tom plot. |
| Säljplatsen | Omgjord | Den stora gröna cirkeln runt marknaden (som sålde så fort man gick över torget) är borta. Nu finns fyra tydliga SELL-plattor, en framför varje disk: grön platta med guldkant, "💰 SELL" målat på och glittrande mynt, plus en grön "SELL HERE"-skylt ovanför disken. Ställ dig på plattan för att sälja. Guide-linjen leder till närmaste platta. |
| Frön med mer tur | Klar | Ny stege: Basic (gratis, oändligt) → Lucky $60 (2×) → Rare $250 (3×, aldrig Common) → Super $600 (5×) → Golden $2,000 (alltid Golden) → Mega $2,500 (8×, aldrig Common) → Ultra $15,000 (15×, Rare+) → Mystery $700 → Cosmic $90,000 (30×, Epic+). Priser skalar med Value-uppgraderingen. Bara cash. |
| Slå av/på köpta saker | Klar | Shop → "✅ My stuff" överst: varje gamepass du äger och varje aktiv boost har en knapp "ON ✔" / "OFF". Allt är PÅ som standard. Avstängt pass verkar inte (t.ex. Auto Harvest av = du skördar själv, VIP av = ingen VIP-skylt, Big Basket av = vanlig korg). En avstängd boost står på PAUSED – tiden räknas inte ner, så inget går förlorat. Valet sparas i profilen. |
| Admin-dashboard | Klar | Grå ⚙️-knapp uppe till höger (bredvid 🔍 och 🎵) – syns bara för admins (spelets ägare, `Config/Admin.UserIds`, alla i Studio). Allt kontrolleras på servern. |
| – Mål & räckvidd | Klar | "Target" växlar mellan dig och spelarna i servern. "Scope" väljer This server / ALL servers för events. |
| – Meddelande till alla servrar | Klar | Skriv text → "Send to ALL 💬": din avatars ansikte poppar upp överst hos alla spelare i alla servrar med en pratbubbla och klockljud. Texten filtreras av Roblox först (krav). |
| – Events | Klar | Starta valfri boom nu (3 min), avsluta boom, events av/på, välj dagens rarity, Server Luck ×2/×5 – i denna server eller alla. Prisbrädan, nedräkningen och musiken följer med. |
| – Spawns | Klar | Välj rarity/storlek/mutation → "Spawn now!" (färdig morot direkt på farmen med reveal), "Force next roll", "Instant grow", "Legendary next". |
| – Pengar & saker | Klar | Belopp (5000, 2.5M, 1B…) → Add/Set, +1K…+1T, Cash → 0, +10 av varje frö. |
| – Uppgraderingar | Klar | Max all, Reset all, +1 per spår. |
| – Pass & boosts | Klar | Ge/ta varje gamepass (som gåva), ge varje boost 15 min. |
| – Konto | Klar | "Complete Dex" och "Reset account" (tryck två gånger): profilen nollställs till en helt ny spelare (kvitton sparas så inget köp kan ges dubbelt) och du skickas automatiskt till en ny server – med tutorialen från början. I Studio kickas du i stället. |

**Ser du inte ⚙️?** Ägaren av upplevelsen är admin automatiskt (grupp: rank ≥ 254). Annars: skicka ditt Roblox user id så läggs det i `Config/Admin.luau`.

## Ny spelloop 8 okt (kväll): sälj och uppgradera på fasta platser i världen

Philips feedback: "inga knappar för att sälja eller uppgradera, det ska vara fasta platser i världen". Byggt:

| Del | Status | Hur det testas |
|---|---|---|
| Sälj vid marknaden | Klar | SELL-knappen är borta. Gå in i den **gröna cirkeln runt marknaden** så säljs hela korgen direkt (marknadspris +20 %, plus boom-pris under en boom). |
| Full korg | Klar | När korgen är full går det inte att skörda. Morötterna står kvar klara på ploten (inget försvinner) tills du har sålt. Korg-pillret blinkar rött och en linje visar vägen till marknaden. |
| Upgrade Shop | Klar | Uppgraderingsknappen är borta. Två stånd med turkost tak och skylten "⬆ UPGRADES" står på torget, mellan stigarna. Ställ dig på den turkosa plattan framför ståndet så öppnas uppgraderingspanelen. Den stängs när du går därifrån. Servern godkänner bara köp på plattan. |
| Guidelinje | Klar | En lysande linje från fötterna till nästa plats, med en studsande skylt där ("SELL HERE 🧺" eller "UPGRADES ⬆"). Den visas när korgen är full, vid boom med morötter i korgen, när nästa uppgradering är köpbar, och 12 s efter tryck på målbaren. Döljs när du är framme. |
| Snabbare gång | Klar | WalkSpeed 22 (Roblox standard 16), så en tur till marknaden tar cirka 5 s åt varje håll. Värdet finns i `Config/World.luau`. |
| Tutorial | Klar | Plantera → skörda → följ linjen till marknaden och sälj → följ linjen till Upgrade Shop och köp → klart. |
| Ekonomi | Simulerad | Ny modell med korg och 14 s marknadstur. Tid till nästa köp: 29 s, 1:02, 2:50, 4:59 (alla inom mål). Cirka 26 marknadsturer i timmen. Rapport: `tools/simulation-report.md`. |

**HUD (ombyggd):**
- Uppe till vänster: pengar (ritat mynt i stället för sedel-emoji), korg ("9/40" plus vad den säljs för) och Legendary-mätaren. Pillren växer med texten, så ingenting klipps längre ("Legendary in 202" blev avklippt förut). Korgen och mätaren har en tunn fyllnadsstapel i botten.
- Vänster kant: 2x2 rutor, Daily (🎁), Seeds, Index och Shop.
- Uppe till höger: runda knappar för 🔍 odds och 🎵 musik, nu tillräckligt stora för tummen.
- Målbaren överst visar "Luck 2  $26/$825". Ikonen ligger på mörk botten så att emojin syns. När målet är köpbart står det "GO UPGRADE! ⬆", och ett tryck visar vägen.

**Titel över huvudet:** storleken sätts nu i studs i stället för pixlar, så den följer avatarens storlek ("HARVESTER" var jättestor när kameran var långt bort). Den är liten och har "⭐ VIP" på samma skylt.

**Världen:**
- Farmskylten är nu en entréport över stigen med en målad skylt i farmens färg, läsbar från torget.
- VIP-loungen har en riktig skylt över dörren i stället för en svävande text.
- Pokalen på piedestalen har en lutande skylt utanför staketet i stället för en svävande text.
- Topplistorna har träram och litet tak.
- Stenarna är runda stenblock i par i stället för grå kuber. Blommorna är buskar med blommor i stället för lösa kulor.

## Helhetsgenomgång 8 okt – retention, FTUE, status, liv

| Del | Status | Hur det testas |
|---|---|---|
| Daglig belöning (7 dagar) | Klar | Ny 📅 Daily-ruta (först i menyn, "!" när något väntar). Öppnas av sig själv när dagens belöning väntar. Dag 1: 3 Rare Seeds, 2: 2 Golden, 3: Luck ×2 15 min, 4: 3 Mystery, 5: Value ×2 15 min, 6: 5 Golden, 7: Secret Seed + 3 Golden, sedan loop. **Streaken pausas, nollställs aldrig.** UTC-dagar. |
| Dagliga uppdrag | Klar | Tre om dagen, samma för alla (t.ex. "Harvest 60 carrots", "Find 5 Rare-or-better", "Sell during a market boom"). Belöning i frön + bonus (3 Golden + 2 Mystery) när alla tre är klara. Alla går att klara solo. Toast när ett uppdrag blir klart. |
| Guidad första minut | Klar | Bara för helt nya spelare: studsande pil över ploten ("TAP!"), sedan "HARVEST!", pil på SELL, pil på uppgraderingsbaren, firande. Reagerar på vad spelaren gör, aldrig på timers. Visas aldrig igen. Test: nytt konto eller ny DataStore. |
| Titlar över huvudet | Klar | Rarast hittade morot ger titel i raritetens färg: Sprout, Gardener, Farmer, Harvester, Legendary Farmer, Mythic Hunter, Cosmic Grower, Keeper of Secrets, Divine Farmer (regnbåge). Syns för alla inom 80 studs. |
| Fjärilar | Klar | 10 fjärilar som fladdrar runt kameran. Bara klient, kostar nästan inget. |

## Fas 5 – soft launch

| Del | Status | Hur det testas |
|---|---|---|
| Koder | Klar | Shop → överst "🎟️ Codes": skriv kod, REDEEM. Koderna finns i `Config/Launch.luau`: **CARROTS** (5 Rare Seeds), **LAUNCH** (3 Golden), **MARKETBOOM** (3 Mystery). En gång per spelare, okänslig för versaler. Belöningar är bara frön (aldrig Robux-saker). Lune-test vaktar konfigurationen. |
| Group-belöning | Klar (väntar på grupp) | När `GroupId` sätts: medlemmar får 3 Golden + 5 Rare Seeds en gång. Icke-medlemmar får efter 20 s en vänlig påminnelse. |
| Favorit-prompt | Klar | Första gången en spelare skördar Legendary eller bättre visas Robloxs "favorite"-prompt 4 s efter avslöjandet (det gladaste ögonblicket), en gång per spelare. |
| Live-data | Redo | Byt `DataStoreName` i `Config/Economy.luau` från `CM_Dev_v2` till `CM_Live_v1` samma dag som lanseringen. Alla börjar då om rent. |

### Philip: inför soft launch
1. ~~Game passes och developer products~~ **Klart (8 okt, via API).** 5 game passes, 5 gåvoprodukter och 10 developer products är skapade och ID:na ligger i `Config/Products.luau`. Butiken säljer på riktigt nu. Logg: `tools/ops/ops-log.md`. Ikonerna är Robloxs standardbild, byt gärna i Creator Hub (Monetization) när du har bilder.
2. **Roblox-grupp:** skapa gruppen och skicka grupp-ID:t. Grupper går inte att skapa via API.
3. ~~Max Players = 8~~ **Klart (8 okt, via API).**
4. **Ikon och thumbnails:** ladda upp (designerna finns). Roblox API:t kan inte ladda upp spelikon eller thumbnails, så det här måste göras i Creator Hub. Slå på thumbnail-A/B-test.
5. **Frågeformuläret för innehållsmognad** i Creator Hub.
6. **Lyssna igenom ljuden** och säg till om något ska bytas.
7. **Speltesta grinden:** plantera, skörda, uppgradera mot 9 plots, vänta in en boom och sälj vid marknaden, lämna 5 min och kom tillbaka (dina planterade morötter ska stå klara, inget extra).
8. **Lanseringsdagen:** jag byter till live-data, du gör upplevelsen publik och startar en liten annonskampanj. Mät D1 och sessionstid en vecka innan mer budget.

## Ljud – brief (ljuddesign 8 okt)

**Identitet: "solig folk-pop på bondens marknad".** Akustiskt och varmt: ukulele, marimba, lätt handslagverk, visslingar. Musiken ligger *under* spelet. Stjärnorna är morots-avslöjandena, så musiken duckar (sänks) vid stora ögonblick. Mixen och beteendet finns i `src/shared/Config/Audio.luau`, ID:na i `src/shared/Config/Assets.luau`.

**Vad som är byggt:**
- **Bussar:** Music, Ambience, SFX och UI (SoundGroups) med egna nivåer. Musiken duckar till 25 % vid Legendary, Mythic, boom-försäljning och marknadsklockan.
- **Musikregissör** (`Controllers/Music`): lugn farm-loop som standard. När en boom startar tonar den över (2,5 s) till ett upbeat boom-spår i alla servrar samtidigt, sedan tillbaka.
- **Ambience:** äng (fåglar och vind) överallt, plus marknadssorl som hörs vid marknaden.
- **Skörde-kombo:** snabba skördar i rad stiger en halvton per skörd, max 8 steg. Det känns som att plocka mynt.
- **Avslöjandet hörs:** skimmer, gnistor och ljuspelare har egna 3D-ljud från ploten, så man *hör* en bra morot komma.
- **Ljud per raritet:** Common, Rare, Epic, Legendary och Mythic/Secret har var sin skördeljud. Mutation har ett eget ljud.
- **Övriga ljud:** "Denied" när du inte har råd, "GoalReady" när nästa uppgradering blir köpbar, "Open" för paneler, "BoomEnd" när boomen slutar och "Announce" för andras fynd.
- **Variation:** slumpad tonhöjd på upprepade ljud, plus cooldowns så att inget smattrar.
- **🎵-knapp** vid 🔍 slår av eller på musiken och sparas i profilen.
- **Placeholders:** ljud utan ID lånar ett närliggande ljud i en annan tonhöjd, så spelet aldrig är tyst. Det är bara tillfälliga ljud från Roblox-klienten.

**Ljud och musik är valda (8 okt, andra versionen).** Alla ID:n kommer från Robloxs licensierade partner i Creator Store (APMOfficial, ProSoundEffects, DistroKid/TooLost official) och är gratis att använda i vilken upplevelse som helst. Namnen står som kommentarer i `Config/Assets.luau`, så att man kan provlyssna i Creator Store.

| Roll | Ljud |
|---|---|
| Farm-musik (spellista) | Cheery Ukulele A + C (APM, John Epping), Ukulele Sunshine, Hawaiian Breeze Peaceful Chords |
| Boom-musik (spellista) | Lively Country + Energetic Folk (APM, Lionel Wendling) |
| Skörd | Fem varianter av ett litet bubbel-"plopp", stiger i ton vid snabba serier |
| Plantera | Spade i jord |
| Sälja | Riktiga mynt som faller |
| Raritet-stings | Korta APM-folk-stings: Straw Hat Boy (Rare), Good Good Times (Epic), Winning Spirit (Legendary), Magical (Mythic) |
| Ny morot / mutation | Whistle Along / Fairy Dust |
| Marknadsklocka | Butiksdörrklocka (koskälla) |
| Boom slut | Goodnight Mr Uke |
| Ambience | Fågelsång (äng) + utomhussorl vid marknaden |

Musiken spelar spellistorna i tur och ordning. Under boom tonar den över till boom-listan, sedan fortsätter farm-musiken där den slutade. Stings duckar musiken så att tonarterna inte krockar.

**Philip, lyssna och säg till:** jag har valt ljuden från namn och metadata och har inte kunnat höra dem. Om något låter fel säger du bara vilken roll ("Legendary-ljudet"), så byter jag.

## Fas 4 – robust och monetiserat

| Del | Status | Hur det testas |
|---|---|---|
| RemoteEvent-validering överallt | Klar | Alla klient→server-remotes (PlotAction, SellAll, BuyUpgrade, BuySeed, SelectSeed, WaterFarm, SetGiftTarget, Track) typkontrolleras och rate-limitas per spelare. Klienten skickar bara avsikter. |
| ProcessReceipt med kvittologg | Klar | Varje PurchaseId sparas i köparens profil och profilen sparas (väntar på bekräftelse) innan Roblox får "granted". Misslyckas sparningen svarar vi NotProcessedYet och Roblox försöker igen – kvittologgen hindrar dubbelutdelning. |
| Gamepasses | Klar (ID:n saknas) | 2x Growth, Auto Harvest (bara i servern), Market VIP (VIP-skylt över huvudet, VIP-lounge vid torget, 3 Golden Seeds per dag), Big Basket (3× korg, 16 h/300 morötter offline), Carrot Scanner (🔍 visar exakta odds). |
| Developer products | Klar (ID:n saknas) | Luck Boost, Value Boost, Instant Grow, Super Luck, Server Luck (hela servern + namn i utrop), Mega Luck (aura), Golden Seed Pack. Boosts räknar bara speltid och syns som timers uppe till vänster. |
| Bundles | Klar (ID:n saknas) | Starter Bundle (en gång, visas efter första Rare – aldrig vid inloggning), Lucky Farmer, Market Tycoon. Allt med känt innehåll. |
| Kontextuella erbjudanden | Klar | Under boom vid marknaden: "💰 x2 Value"-knapp vid SELL. Döljs när pity-mätaren är ≥ 90 % full. |
| Gåvor | Klar (ID:n saknas) | Varje pass har "🎁 Gift" → välj en spelare i servern → köp gåvoprodukten → "Philip gave Anna Auto Harvest!". Om mottagaren lämnat levereras gåvan via ProfileStore-meddelande nästa gång de spelar. |
| Telemetry (AnalyticsService) | Klar | Onboarding-funnel (Join → FirstPlant → FirstHarvest → FirstSell → FirstUpgrade → FirstRare → FirstMutation → OpenedDex), ekonomi (cash in per källa, cash ut per sänka), Rare+-skördar, visningar/klick på erbjudanden. |
| Butik i spelet | Klar | Ny rosa "Shop"-ruta: Boosts, Bundles, Game Passes med riktiga Robux-priser (hämtas från Roblox när ID:t finns). Utan ID står det "Soon!". |

### Philip: skapa detta i Creator Hub och skicka mig ID:na

Game passes (Creator Hub → Monetization → Passes): 2x Growth (399), Auto Harvest (349), Market VIP (499), Big Basket (299), Carrot Scanner (199).

Developer products (Monetization → Developer Products): Luck Boost (49), Value Boost (79), Instant Grow (29), Super Luck (149), Server Luck (199), Mega Luck (249), Golden Seed Pack (99), Starter Bundle (99), Lucky Farmer (299), Market Tycoon (799), samt en gåvoprodukt per pass: Gift 2x Growth (399), Gift Auto Harvest (349), Gift Market VIP (499), Gift Big Basket (299), Gift Carrot Scanner (199).

ID:na läggs i `src/shared/Config/Products.luau` (`passId`, `productId`, `giftProductId`). Inget annat behöver ändras.

## Grind för fas 4 – be Philip testa

1. Öppna Shop-rutan: syns allt tydligt med priser/"Soon!"?
2. När ID:na finns: köp en Luck Boost (testköp i Studio är gratis) – syns timern och räknar den bara ner när du spelar?
3. Köp Carrot Scanner och tryck 🔍 vid pity-mätaren.
4. Hitta din första Rare på ett nytt konto – kommer Starter Bundle-erbjudandet (en gång)?
5. Gåva: med en vän i servern, tryck 🎁 Gift på ett pass.
6. Kolla Creator Hub → Analytics efter ett dygn: onboarding-funneln och ekonomin ska fyllas på.

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
| Plots 4 → 36 | Klar (utökad 8 okt) | Farm Size i 8 steg: 6, 9, 12, 16, 20, 25, 30, 36 plots (6×6). Farmen växer utåt från mitten. Simulering: 16 plots efter ~3 h, därefter långsiktigt mål (prestige tar över). Farmerna ligger nu på radie 150 så att 6×6-farmer får plats med luft emellan. |
| Frön | Klar | SEEDS-rutan: Rare ($250, aldrig Common, 3× tur), Golden ($2,000, alltid Golden ×3), Mystery ($700, blir Rare 60 % / Golden 37 % / Secret 3 % – oddsen visas), Secret (bara från CarrotDex-belöningar, alltid Legendary+). Köp ×1/×10, USE väljer frö. Priser skalar med Value-uppgraderingen. Bara cash, aldrig Robux. Valt frö används för varje plantering (även auto-omplantering) tills det tar slut. |
| CarrotDex, två lager | Klar | INDEX-rutan: 24 morotstyper (4 Common, 4 Uncommon, 4 Rare, 4 Epic, 3 Legendary, 3 Mythic, 2 Secret) i 3D. Ej hittade visas som siluett med "???", odds "1 in X" syns alltid. Lager 2: tre mutationsprickar per typ (72 stämplar). Röd "!" på Index när du hittat något nytt. Milstolpar ger frön automatiskt (4 hittade → 5 Rare, 8 → 3 Golden, 12 → 5 Mystery, 16/20/24 → Secret; stämplar 5/15/30/50/72). |
| Synlig pity-mätare | Klar | 👑-baren uppe till vänster: "Legendary in 123" – garanterad Legendary inom 250 planteringar. |
| Offline | Klar (slutlig regel 8 okt) | Det du planterat fortsätter växa medan du är borta, inget mer. När du kommer tillbaka står samma morötter i sina plots, färdiga är redo att skörda, och du skördar själv. Aldrig fler morötter än du planterade, tomma plots förblir tomma. "Welcome back! 4 carrots are ready to harvest". Test: plantera, lämna 2 min, kom tillbaka – morötterna står klara i plots. |
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

- **Av/på för köp:** avstängd boost pausas (tiden sparas) i stället för att brinna upp; VIP-loungens dörr följer ägarskap, inte av/på. Profilversion 6.

Nio rariteter 8 okt (Philips lista):
- **Common** grön, **Uncommon** ljusgrön, **Rare** blå, **Epic** lila, **Legendary** guld, **Mythic** röd, **Cosmic** cyan/elektrisk blå (ny), **Secret** svart + vit (pulserar), **Divine** regnbåge (ny, cyklar alla färger).
- **Odds (1 på X, före tur):** 1,4 / 5 / 14 / 40 / 222 / 2 500 / 11 111 / 111 111 / 1 000 000. **Basvärde:** $10 / $30 / $120 / $600 / $5K / $60K / $400K / $2,5M / $20M. Varje steg är sällsyntare och värt mer (testat).
- **Nya morötter:** Comet (Cosmic), Shadow och Yin-Yang (Secret, svart/vita), Prism (Divine, regnbågskropp). Cosmic Carrot flyttad till Cosmic och Carrot King till Divine. Totalt 28 typer och 84 stämplar, med nya Dex-milstolpar (28 typer, 84 stämplar → 10 Secret Seeds).
- **Ekonomin omsimulerad** med manuell plantering (0,6 s per plantering), 36-plots-banan och nya rariteter: tid till nästa köp 27 s / 1:12 / 2:54 / 5:20 (inom målen). Första Legendary ~7 min, Mythic ~25 min, Cosmic ~1 h, Secret ~3 h (4 av 10 spelare), Divine 0 av 24 på 4 h (avsiktligt: en nyhet över alla servrar).

Plantering, offline, stora farmer och HD-morötter 8 okt:
- **Ingen auto-omplantering.** Skörd lämnar ploten tom och du trycker för att plantera, så valt frö spelar roll på varje plot. Auto Harvest-passet skördar och planterar om (bara när du är i spelet), vilket gör passet värt något.
- **Offline: "du kan inte skörda mer än du planterade".** Det sparade växer klart i realtid och står redo i plots när du kommer tillbaka. Ingen popup, inga extra morötter, ingen korg fylls. All gammal offline-belöningskod (avslöjandet, takt, tak, Big Basket-offline) är borttagen. Big Basket = 3× korg.
- **Farm Size till 36 plots** (8 steg, sista 1,5 miljarder).
- **HD-morötter:** 11 segment med organisk avsmalning, skuggning från axel till spets, tillväxtringar, solgrön axel, rotsvans och rothår, stjälkhals med böjda fjäderblad i två gröna. Full detalj på din farm, i skördeeffekter och Index; lättare version på andras farmer (prestanda med 8 × 36 plots på mobil).

Sälja och uppgraderingsbaren 8 okt:
- **SELL-knappen stannar.** På mobil skulle en promenad per korg döda 30-sekundersloopen. Marknaden ska vara en belöning, inte en tull: sälj var som helst = baspris, vid marknaden alltid +20 % (`Events.MarketBonus`), plus boom-multiplikatorn under boom. SELL-rutan visar "MARKET PRICE!" när du står där. Tidigare gav marknaden bara något under boom, så den var meningslös 7 av 10 minuter.
- **Uppgraderingsbaren:** mörkt glas som valutapillren. Ikonen och fyllningen får uppgraderingens egen färg och emoji (⏩ 🍀 💰 🌱 💪 🧺) med nivåmärke. Har du råd blir den grön med svepande glans, guppande ikon och "UPGRADE! $375". Köp ger blixt och studs.

Ljuddesign 8 okt:
- **Mixhierarki:** avslöjanden och fanfarer > skörd och sälj > UI > musik > ambience. Musiken duckar i stället för att tävla.
- **Boom-musik** följer det globala schemat, så klockan och musikbytet säger "spring och sälj" till alla samtidigt.
- **Musik av** sänker även ambience till 40 %, så att "av" faktiskt är tyst.

Offline, andra fixen 8 okt:
- **Problemet:** offline gick i 25 % av spelarens växtfart. Med Growth-uppgraderingar (6 s) blev det 1 morot per plot var 24:e sekund, så 5–6 min borta fyllde korgen. Offline skalade med uppgraderingar, vilket var fel.
- **Nu:** golv på 4 min per offline-morot och plot (`OfflineMinCycle`) och tak på 30 extra per timme borta (`OfflinePerHour`). Regressionstest i `tests/OfflinePlan.spec.luau` återskapar Philips fall.
- **Ny dev-data:** `CM_Dev_v2`. Profiler i `CM_Dev_v1` var fulla av morötter från buggarna; alla testkonton börjar om rent. (Gamla datan finns kvar i v1 om vi skulle behöva den.)

Design-pass 8 okt (HUD, marknad, värld):
- **HUD-buggen:** HUD hade en egen kopia av skalfunktionen med den gamla formeln, så förra krympningen nådde aldrig HUD:en. Kopian är borta; allt skalar via `UI.screenScale` (telefon ~0,8).
- **HUD-layout:** mitten av skärmen tillhör farmen. Valutor som mörka glas-piller uppe till vänster (cash, korg, pity + 🔍). Meny 2×2 vid vänsterkanten. SELL mindre, vid högerkanten ovanför hoppknappen.
- **Marknadsskylt:** den svävande pristabellen är borta. En griffeltavla på ett staffli framför marknaden (spawn-sidan) visar det spelaren vill veta: nästa boom och nedräkning, vad som boomar, dagens heta raritet. Ovanför marknaden svävar bara en liten timer "BOOM 4:38" (orange "BOOM! 2:31" under boom) som syns från alla farmer.
- **Värld:** djupare grönt gräs och dämpad mättnad (inte neon), varma jordstigar med kant, torg i kräm/terrakotta med åtta orange ekrar som pekar mot farmerna, kullar runt kanten som ramar in dalen, lager-träd.
- **Marknaden** är kartans landmärke: trädäck, röda stolpar, våningstält i orange/kräm med girlang-kant, namnskylt på alla fyra sidor, jättemorot på taket.
- **Farmer:** mörka jordbäddar med träram (morötterna syns bättre), klippta gräsränder, en lada bakom varje farm i farmens egen färg (åtta färger) + färgad kant på skylten. Piedestalen i guld/marmor i stället för neon.
- **VIP-loungen:** häckar med guldkant och lila matta i stället för en neon-gul låda.
- Art direction finns nu kort i CLAUDE.md så att framtida sessioner håller stilen.

UI-storlek 8 okt (efter Philips iPhone-skärmdump):
- **HUD-skalan** räknas nu mot 520 pt höjd (var 400): en liggande telefon hamnar runt 0,8 i stället för ~1,15. Surfplatta/dator max 1,25.
- **Målbaren** i toppfältet max 300 pt bred och 32 pt hög. Bannern mindre.
- **Plot-etiketterna** är små piller (3,2 × 0,8 studs, syns inom 60 studs) med kort text: PLANT, nedräkning, HARVEST! eller raritetens namn ("RARE!").
- **Prisbrädan** över marknaden är 12 × 8 studs (var 22 × 15) och syns inom 140 studs (var 260). Boom-pillret under toppfältet är mindre.

Buggfix 8 okt (offline):
- **Buggen:** offline-koden räknade skördar för alla upplåsta plots oavsett om något var planterat, så en inloggning utan att spela gav en full korg gratis. Den gjorde också att man kunde lämna och gå med igen för gratis morötter, och växande morötter (även en glödande Legendary) försvann när man lämnade.
- **Fixen:** plots sparas när du lämnar (och var 30:e sekund), med morot och återstående tid. Offline färdigställer bara det som sparades. Logiken ligger i `src/shared/OfflinePlan.luau` med Lune-tester.
- **Offline-fart 25 %** (`OfflineRate`) så att lämna och gå med igen aldrig lönar sig mer än att spela. Kortaste offline-avslöjande är 5 min (`OfflineMinSeconds`).
- **Profilversion 5:** gamla profiler startar utan något i jorden. Morötter som redan hamnat i korgen av buggen ligger kvar i dev-datan (`CM_Dev_v1`), som ändå byts vid soft launch.
- **UX:** toast när korgen blir full, tydligare text i avslöjandet och ett tips om man kommer tillbaka till en tom farm.

Fas 4:
- **Luck-boosts staplas inte:** den starkaste aktiva personliga luck-boosten gäller (×2/×4/×8), gånger Server Luck och vänbonus. Annars blir tur orimlig. Value-boosts multipliceras men taket ×6 gäller.
- **Samma boost köpt igen lägger till tid** i stället för att nollställa.
- **2x Growth** halverar växttiden även under golvet 3 s, men aldrig under 1,5 s.
- **Auto Harvest** väntar 0,8 s efter att moroten blivit klar så att pop-ögonblicket syns.
- **Gåvor** kräver en egen developer product per pass (Roblox kan inte köpa ett pass åt någon annan). Om mottagaren redan äger passet när köpet går igenom får köparen passet, eller 20 Golden Seeds om även köparen äger det.
- **Starter Bundle** visas bara om dess produkt-ID finns, en gång per spelare, 1,5 s efter första Rare.
- **Mystery Seeds säljs aldrig för Robux** – ett Lune-test (`tests/Products.spec.luau`) stoppar bygget om någon lägger till dem i en Robux-produkt.
- **Profilversion 4** (kvitton, boosts, gåvor) med migrering.


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
| Images.Shop / Scanner | HUD-ikoner (fas 4) | Emoji-fallback (🛒 🔍) |
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
