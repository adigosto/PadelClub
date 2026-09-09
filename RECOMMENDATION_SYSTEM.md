# Sistem preporuke proizvoda

## Veza sa prijavljenom temom

Prijavljena tema obećava preporuku proizvoda na osnovu ranijih kupovina kupaca
(*collaborative filtering*). Implementacija to radi nad stvarnim podacima:

`Orders -> OrderItems -> Products`

Nije riječ o statičnoj listi niti o preporuci po nazivu proizvoda.

## Šta je implementirano

- Autentificirani endpoint: `GET /Recommendations/products?limit=6`.
- Shared Flutter shop prikazuje sekciju **Recommended for you** sa objašnjenjem za svaku stavku.
- Već kupljeni, deaktivirani i proizvodi bez zalihe se nikada ne preporučuju.
- U obzir ulaze samo isporučene narudžbe aktivnih korisnika. Otkazane narudžbe nisu signal, a odobreni/refundirani povrati se oduzimaju od količine.
- Nema lažnog "AI score-a": API jasno vraća `strategy`, `isFallback` i verziju algoritma `item-cf-cosine-v1`.

## Algoritam

Ovo je deterministički **item-to-item collaborative filtering** za implicitne povratne informacije iz kupovina.

1. Za svakog korisnika i proizvod pravi se težina kupovine:

   `w(u,i) = Σ log(1 + neto_količina) × 2^(-starost_dana / 180)`

   Novije i veće, stvarno zadržane kupovine imaju veću težinu.

2. Za svaki par proizvoda porede se vektori kupovina drugih kupaca pomoću kosinusne sličnosti.

3. Sličnost se smanjuje kada je podržana sa premalo kupaca:

   `sim(i,j) = cosine(i,j) × support / (support + 3)`

4. Kandidat dobija zbir doprinosa proizvoda koje je trenutni korisnik ranije kupio. Najveći doprinos daje objašnjenje, na primjer: *"Players who bought PadelClub Control Racket also bought this item."*

`score` je vrijednost za rangiranje, a ne vjerovatnoća da će korisnik kupiti proizvod.

## Rijetki podaci i cold start

Kada nema dovoljno zajedničkih kupovina, aplikacija ne glumi da postoji personalizovani rezultat. Umjesto toga prikazuje označeni fallback:

- `popular-fallback` — popularan proizvod prema broju različitih kupaca;
- `new-arrivals-fallback` — novi raspoloživ proizvod kada nema historije kupovina.

Nakon što administrator označi narudžbu kao `Delivered`, naredno učitavanje shopa automatski koristi tu kupovinu kao signal.

## Demonstracija na development bazi

Seeding dodaje idempotentne, jasno označene demo korpe za `player2`, `player3` i `player4`. Uz postojeću kupovinu `player1`, to daje vidljiv primjer:

- `player1` je kupio Control Racket;
- ostali demo igrači su kupovali Control Racket zajedno s lopticama ili patikama;
- zbog jače zajedničke kupovine, loptice se rangiraju ispred patika za `player1`.

Podaci služe samo za lokalnu demonstraciju i ne predstavljaju stvarne korisničke podatke.
Narudžbe imaju oznaku `IsSeededForDemo`; ostaju dostupne za prikaz preporuka u
development okruženju, ali se isključuju iz historijske evaluacije i ne mogu biti
prikazane kao metrika kvaliteta.

## Provjera

```powershell
dotnet test PadelClub.WebAPI.Tests\PadelClub.WebAPI.Tests.csproj --configuration Release --no-restore
cd UI\padelclub_desktop
flutter analyze
flutter test --no-pub
```

## Historijska evaluacija

Administrator moĹľe pokrenuti reproducibilni temporalni backtest preko
`GET /Operations/recommendations/evaluation` sa eksplicitnim `cutoffUtc`,
`endUtc` i `k`. Trening koristi samo kupovine prije cut-off-a, a evaluacija
poredi isti item-to-item ranker sa popularity baseline-om. Metodologija,
metrike i ograniÄŤenja su u
[docs/RECOMMENDATION_EVALUATION.md](docs/RECOMMENDATION_EVALUATION.md).

Backend testovi pokrivaju jačinu zajedničke kupovine, isključivanje već posjedovanih proizvoda, ignorisanje potpuno vraćenog proizvoda i zaštitu endpointa autentifikacijom.
