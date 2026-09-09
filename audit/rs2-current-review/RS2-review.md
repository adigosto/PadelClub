**RS2 pregled trenutne radne kopije PadelClub — 8. septembar 2026.**

**Projekat ne zadovoljava dostavljena pravila: 32 nalaza — 7 P1, 19 P2 i 6 P3.** P1 označava visok poslovni rizik ili ključni nedostajući tok, P2 značajno funkcionalno/arhitektonsko odstupanje, P3 formalno odstupanje ili kvalitet. Nijedan novi P0 sigurnosni proboj nije potvrđen. Ovo nije brojčana fakultetska ocjena.

Pregledani su ASP.NET kontroleri i njihovo nasljeđivanje, ključni EF servisi/model, JWT konfiguracija, Stripe i refund tok, RabbitMQ subscriber/API workeri, online preporuke i zajednički Flutter kod. Mobile runner koristi desktop paket. Pregled obuhvata i postojeće necommitovane izmjene; aplikacijski izvorni kod nije mijenjan. Dodani su samo novi review artefakti; dotnet build/restore ažuriraju generisane bin/obj fajlove.

Dostavljeni tekst pravila korišten je kao ground truth. Aktuelni fakultetski silabus nije nezavisno provjeravan. Ovo je lokalni code review, bez napada na instalaciju, čitanja privatnog .env fajla, provider poziva ili pregleda Git historije tajni.

**Provjera.** Build kroz dotnet test uspijeva; 79 testova prolazi, 0 pada. Isključeno je šest klasa koje zahtijevaju SQL integracijski fixture: ApiIntegrationTests, MessagingReliabilityTests, ProviderRefundOperationIntegrationTests, ProspectiveEvidenceIntegrationTests, ReservationAvailabilityContractTests i RecommendationCohortReadinessApiTests. Zato rezultat ne potvrđuje SQL zaključavanja, FK ponašanje ili HTTP integraciju. Flutter build/test i uređajska naplata nisu izvršeni.

Nove probe pozivaju stvarne servise na izolovanom EF InMemory store-u: pet problematičnih ponašanja reprodukovano je, a jedna kontrola potvrđuje ispravljenu provjeru vlasništva. `observed=true` znači da je opisana pojava opažena; za pet bug-proba to nije prolaz sigurnosnog testa.

Dokazi: [audit/rs2-current-review/probe-results.txt](C:/Users/User/Desktop/PadelClub/audit/rs2-current-review/probe-results.txt), [audit/rs2-current-review/probes/Program.cs](C:/Users/User/Desktop/PadelClub/audit/rs2-current-review/probes/Program.cs), [audit/rs2-current-review/test-results/current-review.trx](C:/Users/User/Desktop/PadelClub/audit/rs2-current-review/test-results/current-review.trx).

**Raniji audit nije aktuelan za sve nalaze.** Pregled [audit/rs2-2026-09-08/RS2-review.md](C:/Users/User/Desktop/PadelClub/audit/rs2-2026-09-08/RS2-review.md) zadržan je kao historijski dokument. U sadašnjem kodu:
- Production demo seed je blokiran; development seed zahtijeva eksplicitnu konfiguraciju i lozinku iz konfiguracije. Poznati JWT fallback uklonjen je i startup odbija poznate placeholder ključeve.
- Reservations GET provjerava vlasništvo; probe vraćaju null za drugog korisnika. Generički Payment create/update/delete su blokirani.
- Hard delete rezervacija, narudžbi i članarina je blokiran. Update rezervacije sada koristi Serializable i zaključavanje, a lifecycle odbija proizvoljan status i budući no-show.
- Cancel rezervacije zahtijeva razlog, koristi transakciju i unique kredit ključ. Preostali problem je zajednički kredit/refund saldo, ne ranija nezaštićena provjera duplog kredita.
- PaymentIntent status ima zaštitu od regresije, a unmatched webhook više se ne označava uspješno obrađenim. Charge grana i dalje regresira refund saldo (R01).
- Withdraw bez TeamNumber sada mijenja samo vlastitu prijavu, a rezultat potvrđuje protivnički tim. ConfirmResult sada obuhvata i napredovanje u transakciji.
- BaseService sada ima maksimalno 100 zapisa, a checkout ima idempotency ključ. Override paginacije, posebne liste i UI navigacija i dalje imaju propuste.

**R01 · P1 · Plaćanje — Stariji charge događaj poništava dio evidentiranog refunda**

Charge grana bez provjere redoslijeda postavlja RefundedAmount = charge.AmountRefunded / 100m. Zaštita CanAdvanceStatus primjenjuje se samo na PaymentIntent granu.

**Posljedica:** Proba: nakon refunda 30, stariji događaj s refundom 10 vraća status iz Refunded u PartiallyRefunded i ponovo otvara lokalni refund kapacitet. Nije dokazano da Stripe stvarno isplaćuje više od naplaćenog iznosa.

**Ispravka:** Refund saldo usklađivati s aktuelnim provider stanjem i odbiti regresiju kumulativnog iznosa; zaštititi i konkurentne obrade događaja.

**Dokaz:** Izvršno potvrđeno: REFUND_REGRESSION, 30 → 10. Stvarni servis, EF InMemory, bez Stripe poziva. Lokacije: [PadelClub.WebAPI/Payments/StripePaymentService.cs:93](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/StripePaymentService.cs:93), [PadelClub.WebAPI/Payments/ProviderRefundOperationService.cs:88](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/ProviderRefundOperationService.cs:88).

**R02 · P1 · Plaćanje — Ista uplata daje puni kredit i puni refund**

CancelAsync izdaje AccountCredit, ali payment saldo ne evidentira izdati kredit. QueueDirectAsync računa kapacitet samo iz Amount, RefundedAmount i pending refund operacija.

**Posljedica:** Proba je za uplatu 30 kreirala kredit 30 i prihvatila refund operaciju 30. Otkazivanje traži vlasnika/admina, direktan refund admina. Unique indeks kredita i transakcija sada postoje, pa raniju tvrdnju o duplom kreditu ne ponavljam.

**Ispravka:** U istoj transakciji rezervisati jedinstven raspoloživi saldo, uz međusobno isključive kredit/refund kompenzacije.

**Dokaz:** Izvršno potvrđeno: CREDIT_AND_REFUND. Refund je lokalno zakazan; novac nije isplaćen. Lokacije: [PadelClub.Services/ReservationService.cs:216](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:216), [PadelClub.WebAPI/Payments/ProviderRefundOperationService.cs:88](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/ProviderRefundOperationService.cs:88), [PadelClub.Services/Database/PadelClubContext.cs:612](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/PadelClubContext.cs:612).

**R03 · P1 · Poslovna logika — Admin CRUD narudžbi i stavki zaobilazi obračun i lifecycle**

OrderService.CreateAsync koristi generičko mapiranje Status/TotalAmount; BeforeInsert određuje samo porijeklo. Update mapira i ostala DTO polja nakon provjere statusa. OrderItemService nasljeđuje insert/update/delete bez provjere stanja narudžbe i preračuna zalihe/ukupnog iznosa.

**Posljedica:** Proba kreira Delivered narudžbu iznosa 999 bez ijedne stavke. Admin može mijenjati finansijske podatke izvan checkout workflowa. Admin privilegija je preduslov, ovo nije player eskalacija.

**Ispravka:** Zamijeniti generički CRUD poslovnim komandama; zaključati vlasništvo i stavke nakon obračuna, cijenu i zalihu računati isključivo na backendu.

**Dokaz:** Kreiranje izvršno potvrđeno: ORDER_CRUD_BYPASS. Ostale putanje potvrđene kodom. Lokacije: [PadelClub.Services/OrderService.cs:36](C:/Users/User/Desktop/PadelClub/PadelClub.Services/OrderService.cs:36), [PadelClub.Services/OrderService.cs:231](C:/Users/User/Desktop/PadelClub/PadelClub.Services/OrderService.cs:231), [PadelClub.Services/OrderItemService.cs:10](C:/Users/User/Desktop/PadelClub/PadelClub.Services/OrderItemService.cs:10), [PadelClub.Model/Requests/OrderInsertRequest.cs:7](C:/Users/User/Desktop/PadelClub/PadelClub.Model/Requests/OrderInsertRequest.cs:7).

**R04 · P1 · Poslovna logika — Članarine imaju nezaštićen update i neusaglašene putanje statusa/obnove**

MembershipService validira Create, ali nasljeđuje Update bez istih provjera. ChangeStatus ne provjerava prethodni status. Renew direktno produžava i aktivira bez potvrđene nove naplate; worker postavlja RenewalDue uz IsActive=false, a ResolvePayableAsync prihvata samo IsActive članarine.

**Posljedica:** Proba upisuje cijenu -25, EndDate prije StartDate i Status=Active uz IsActive=false. Obnova nema zatvoren tok naplate, a jedinstvena veza Membership–Payment dodatno traži model pojedinačnih obračunskih perioda.

**Ispravka:** Centralizovati članarinski lifecycle i sve validacije; obnovu predstavljati zasebnim naplativim periodom koji postaje aktivan tek nakon propisane potvrde.

**Dokaz:** Update izvršno potvrđen: MEMBERSHIP_UPDATE_BYPASS. Lifecycle/obnova statički analizirani. Lokacije: [PadelClub.Services/MembershipService.cs:17](C:/Users/User/Desktop/PadelClub/PadelClub.Services/MembershipService.cs:17), [PadelClub.Services/BaseCRUDService.cs:55](C:/Users/User/Desktop/PadelClub/PadelClub.Services/BaseCRUDService.cs:55), [PadelClub.WebAPI/Controllers/MembershipsController.cs:71](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/MembershipsController.cs:71), [PadelClub.WebAPI/Controllers/MembershipsController.cs:89](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/MembershipsController.cs:89), [PadelClub.WebAPI/Memberships/MembershipLifecycleWorker.cs:21](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Memberships/MembershipLifecycleWorker.cs:21), [PadelClub.WebAPI/Payments/StripePaymentService.cs:137](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/StripePaymentService.cs:137).

**R05 · P1 · Rezervacije — Rezervacije, turnirski mečevi i održavanje ne dijele kalendar zauzetosti**

BracketService bira prvi aktivni teren i dodjeljuje ScheduledTime bez provjere rezervacija/održavanja. ValidateReservationAsync ne provjerava Matches. AddMaintenanceBlockAsync samo snima blok.

**Posljedica:** Moguće je rezervisati termin već dodijeljen meču, napraviti meč preko rezervacije ili dodati održavanje preko obećanog termina bez rješavanja pogođenih korisnika.

**Ispravka:** Uvesti zajedničku backend provjeru intervala za sve izvore zauzetosti i atomarnu rezervaciju termina.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/Tournaments/BracketService.cs:24](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Tournaments/BracketService.cs:24), [PadelClub.WebAPI/Tournaments/BracketService.cs:35](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Tournaments/BracketService.cs:35), [PadelClub.Services/ReservationService.cs:275](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:275), [PadelClub.Services/ReservationService.cs:325](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:325).

**R06 · P1 · Pouzdanost — Generisanje bracket-a ostavlja djelimično snimljen turnir**

GenerateAsync snima prazne mečeve, potom veze/učesnike, potom bye napredovanje/status kroz više SaveChangesAsync. Ni servis ni Generate akcija ne otvaraju zajedničku transakciju. Prvi guard odbija ponavljanje čim postoji bracket meč.

**Posljedica:** Kvar nakon prvog upisa ostavlja nepotpun bracket koji običan retry više ne može dovršiti. Ovo se ne odnosi na ConfirmResult, koji sada ima transakciju.

**Ispravka:** Sve generisanje obuhvatiti transakcijom i zaključavanjem turnira; dodati test prekida nakon prvog SaveChanges.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/Tournaments/BracketService.cs:18](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Tournaments/BracketService.cs:18), [PadelClub.WebAPI/Tournaments/BracketService.cs:40](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Tournaments/BracketService.cs:40), [PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs:115](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs:115).

**R07 · P1 · Flutter / plaćanje — Mobilna aplikacija nema povezan tok Stripe plaćanja**

Mobilni runner koristi desktop paket. U lib/pubspec oba projekta nema PaymentSheet/Stripe SDK integracije niti poziva payment-intents endpointa. Checkout šalje Orders/checkout i zatvara formu; launchUrl u toj formi otvara Google Maps.

**Posljedica:** Korisnik može poslati narudžbu, ali prikazani mobilni tok ne završava in-app naplatu. Backend webhook sam ne ispunjava pravilo mobilnog plaćanja.

**Ispravka:** Povezati kreiranje intent-a, mobilni SDK/deep-link povrat i prikaz backend potvrđenog statusa, uz confirmation korak.

**Dokaz:** Statički pregled Flutter koda i zavisnosti. Nije pokretano plaćanje na uređaju. Lokacije: [UI/padelclub_mobile/lib/main.dart:4](C:/Users/User/Desktop/PadelClub/UI/padelclub_mobile/lib/main.dart:4), [UI/padelclub_desktop/lib/features/product/presentation/widgets/checkout_sheet.dart:60](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/product/presentation/widgets/checkout_sheet.dart:60), [UI/padelclub_desktop/lib/features/product/presentation/providers/cart_provider.dart:101](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/product/presentation/providers/cart_provider.dart:101).

**R08 · P2 · Pouzdanost — Checkout i ponavljajuće rezervacije commitaju prije obavezne notifikacije**

OrderService.CheckoutAsync commit-a prije CreateAsync notifikacije; ponavljanje istog idempotency ključa odmah vraća narudžbu bez popravke notifikacije. CreateRecurringAsync također commit-a prije obavijesti.

**Posljedica:** Kvar notifikacije daje parcijalni uspjeh; potvrđena narudžba može ostati bez obavijesti. Kod serije klijent može dobiti grešku iako rezervacije postoje. Ranija tvrdnja da svaki checkout retry pravi duplu narudžbu više nije tačna jer postoji idempotency ključ.

**Ispravka:** Poslovnu promjenu i notification/outbox namjeru snimiti u istoj transakciji; dostavu obaviti naknadno.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.Services/OrderService.cs:71](C:/Users/User/Desktop/PadelClub/PadelClub.Services/OrderService.cs:71), [PadelClub.Services/OrderService.cs:183](C:/Users/User/Desktop/PadelClub/PadelClub.Services/OrderService.cs:183), [PadelClub.Services/ReservationService.cs:303](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:303), [PadelClub.WebAPI/Memberships/MembershipLifecycleWorker.cs:28](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Memberships/MembershipLifecycleWorker.cs:28).

**R09 · P2 · Poslovna logika — Dio otkazivanja nema obavezan razlog i notifikaciju**

Withdraw turnirske prijave prima samo tournamentId i snima Withdrawn bez razloga ili notifikacije. Članarinski CancelAtPeriodEnd nema razlog; ChangeStatus prihvata prazne Notes. OrderUpdateRequest nema obavezan razlog otkazivanja.

**Posljedica:** Nedostaje propisani poslovni trag za otkazivanje i obavijest saigraču. Rezervacijski CancelAsync sada zahtijeva razlog, pa se nalaz ne odnosi na taj popravljeni tok.

**Ispravka:** Dodati namjenske cancel DTO-e sa validiranim razlogom i trajnu obavijest svim pogođenim korisnicima.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs:97](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs:97), [PadelClub.WebAPI/Controllers/MembershipsController.cs:44](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/MembershipsController.cs:44), [PadelClub.WebAPI/Controllers/MembershipsController.cs:81](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/MembershipsController.cs:81), [PadelClub.Model/Requests/OrderUpdateRequest.cs:3](C:/Users/User/Desktop/PadelClub/PadelClub.Model/Requests/OrderUpdateRequest.cs:3).

**R10 · P2 · Performanse — Notifikacije zaobilaze maksimalnu paginaciju**

NotificationService override-i GetAsync i GetForUserAsync koriste Take samo kada je PageSize > 0 i nemaju max clamp. Popravka BaseService se ne primjenjuje na ove override-e.

**Posljedica:** PageSize=0 ili negativan vraća sve dostupne notifikacije, a proizvoljno veliki pozitivan limit također prolazi.

**Ispravka:** Primijeniti obavezni zajednički page-size clamp i na override-e; provjeriti admin i mine endpoint.

**Dokaz:** Izvršno potvrđeno: NOTIFICATIONS_UNBOUNDED, PageSize=0 vratio 121 zapis. Lokacije: [PadelClub.Services/NotificationService.cs:29](C:/Users/User/Desktop/PadelClub/PadelClub.Services/NotificationService.cs:29), [PadelClub.Services/NotificationService.cs:140](C:/Users/User/Desktop/PadelClub/PadelClub.Services/NotificationService.cs:140).

**R11 · P2 · Performanse — Posebni list endpoint-i nemaju paginaciju**

Waitlist/credits mine vraćaju ToListAsync bez limita; membership history i returns mine također. Discovery koristi fiksni Take(30/50), ali nema sljedeće stranice; commerce liste s Take(500) imaju isti formalni nedostatak.

**Posljedica:** Neograničene liste rastu s historijom, a fiksno odrezane liste ne daju pristup starijim zapisima. Fiksni limit nije dokaz N+1 niti neograničenog učitavanja.

**Ispravka:** Dodati page/cursor i max limit svakom list endpointu, uz stabilno sortiranje i continuation podatke.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.Services/ReservationService.cs:319](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:319), [PadelClub.WebAPI/Controllers/MembershipsController.cs:108](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/MembershipsController.cs:108), [PadelClub.WebAPI/Controllers/CommerceOperationsController.cs:284](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/CommerceOperationsController.cs:284), [PadelClub.WebAPI/Controllers/DiscoveryController.cs:39](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/DiscoveryController.cs:39).

**R12 · P2 · Arhitektura — Osam kontrolera direktno koristi DbContext i poslovnu logiku**

CommerceOperations, PlayerExperience, Privacy, Discovery, Operations, NotificationSettings, TournamentLifecycle i Memberships zavise od PadelClubContext. Npr. ConfirmResult računa rating i upisuje stanje meča u kontroleru.

**Posljedica:** Krši Controller → Service → DbContext; lifecycle, transakcije i pravila teško se ponovo koriste kroz druge ulaze.

**Ispravka:** Premjestiti use-case logiku i transakcije u scoped servise; kontrolere svesti na HTTP ugovor i autorizaciju.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/Controllers/CommerceOperationsController.cs:18](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/CommerceOperationsController.cs:18), [PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:16](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:16), [PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:142](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:142), [PadelClub.WebAPI/Controllers/MembershipsController.cs:16](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/MembershipsController.cs:16).

**R13 · P2 · Arhitektura — Pet poslovnih workera pokreće se u API hostu**

Program registruje ProviderRefundOperationWorker, NotificationDeliveryWorker, MembershipLifecycleWorker, PrivacyDeletionWorker i OutboxPublisherWorker preko AddHostedService unutar API-ja. Odvojeni product subscriber kontejner postoji.

**Posljedica:** Krši izričito pravilo odvojenog worker kontejnera; broj API replika utiče na broj pokrenutih background petlji. Postojeći lease mehanizmi ne zamjenjuju traženu deployment granicu.

**Ispravka:** Poslovne workere premjestiti u zaseban worker host/kontejner uz zadržavanje lease/idempotency zaštita.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/Program.cs:65](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:65), [PadelClub.WebAPI/Program.cs:80](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:80), [PadelClub.WebAPI/Program.cs:123](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:123).

**R14 · P2 · DI — DbContext-zavisni servisi registrovani su kao Transient**

ITournamentParticipantService/TournamentParticipantService i pet product-state klasa registrovani su kao transient; koriste DbContext direktno ili kroz baznu klasu.

**Posljedica:** Krši zahtjev Scoped. Transient servis koji prima scoped DbContext nije automatski dokaz nove konekcije ili thread-safety proboja.

**Ispravka:** Registracije ovih kontekst-zavisnih servisa uskladiti na Scoped.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/Program.cs:92](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:92), [PadelClub.WebAPI/Program.cs:111](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:111), [PadelClub.Services/TournamentParticipantService.cs:12](C:/Users/User/Desktop/PadelClub/PadelClub.Services/TournamentParticipantService.cs:12), [PadelClub.Services/ProductStateMachine/BaseProductState.cs:13](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ProductStateMachine/BaseProductState.cs:13).

**R15 · P2 · RabbitMQ — Consumer ne demonstrira traženi tip listenera ni exponential retry obrade**

Subscriber koristi EasyNetQ PubSub.SubscribeAsync i IBus. Exponential retry postoji za uspostavljanje pretplate; HandleAsync nema vlastiti retry/backoff oko DB inbox obrade. Nema eksplicitnog AsyncEventingBasicConsumer.

**Posljedica:** Prema dostavljenim pravilima listener nije usaglašen. Iz ovoga ne zaključujem da EasyNetQ otvara konekciju za svaku poruku niti da biblioteka nema internu obradu grešaka.

**Ispravka:** Implementirati traženi consumer/retry ugovor ili dokumentovati dokazanu ekvivalentnost biblioteke; greške obrade odvojiti od retry-a povezivanja.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/PadelClub.Subscriber/ProductUpdatedSubscriber.cs:43](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/PadelClub.Subscriber/ProductUpdatedSubscriber.cs:43), [PadelClub.WebAPI/PadelClub.Subscriber/ProductUpdatedSubscriber.cs:104](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/PadelClub.Subscriber/ProductUpdatedSubscriber.cs:104), [PadelClub.WebAPI/PadelClub.Subscriber/Program.cs:16](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/PadelClub.Subscriber/Program.cs:16).

**R16 · P2 · Performanse — Ponavljani DB upiti unutar petlji**

CreateRecurringAsync za svaku sedmicu poziva ValidateReservationAsync koji ponavlja provjere terena, korisnika, rezervacija i održavanja te radi SaveChanges. MembershipLifecycleWorker pojedinačno poziva NotificationService za svaku istek­lu članarinu, ponavljajući recipient/preference upite.

**Posljedica:** Broj DB round-tripova raste s brojem sedmica/članarina; krši zabranu upita u petlji. NotificationService sam ne radi recipient upit za svakog usera, pa taj stari navod nije ponovljen.

**Ispravka:** Zajedničke podatke i intervale učitati grupno, validirati kolekciju i batchirati upise/notifikacije uz zadržavanje atomarnosti.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.Services/ReservationService.cs:294](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:294), [PadelClub.Services/ReservationService.cs:268](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:268), [PadelClub.WebAPI/Memberships/MembershipLifecycleWorker.cs:30](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Memberships/MembershipLifecycleWorker.cs:30).

**R17 · P2 · Preporuke — Serving model uključuje seed/admin historiju**

Upit rawPurchaseLines filtrira samo Delivered i aktivnog korisnika. Ne filtrira OrderOrigin ni IsSeededForDemo. Strožiji filter niže u ResolveTelemetrySourceAsync određuje izvor telemetrije, ne trening skup ovog rankera.

**Posljedica:** Demo/admin kupovine mogu uticati na online preporuke iako analitička evidencija odvojeno razlikuje porijeklo. Ne tvrdim da stvarna historija ne postoji: checkout je upisuje.

**Ispravka:** Za online učenje koristiti dokazano stvarne kupovine i isključiti demo/admin evidenciju ili model jasno označiti kao demonstracijski.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.Services/Recommendations/ProductRecommendationService.cs:77](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Recommendations/ProductRecommendationService.cs:77), [PadelClub.Services/Recommendations/ProductRecommendationService.cs:367](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Recommendations/ProductRecommendationService.cs:367), [PadelClub.Services/OrderService.cs:58](C:/Users/User/Desktop/PadelClub/PadelClub.Services/OrderService.cs:58).

**R18 · P2 · Performanse — Svaka preporuka materijalizira globalnu historiju**

GetForUserAsync učitava sve eligible proizvode, sve Delivered stavke svih aktivnih korisnika i sve odobrene/refundirane return stavke. Dio product filtriranja radi poslije ToListAsync; odgovor je ograničen na 12 tek nakon obrade.

**Posljedica:** Mali odgovor skriva rast memorije i CPU-a po zahtjevu. Ovo je učitavanje globalnog skupa, ne N+1 dokaz.

**Ispravka:** Agregirati u bazi, precompute/cache model ili statistike i koristiti kontrolisan vremenski prozor; product filter izvršiti u bazi.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.Services/Recommendations/ProductRecommendationService.cs:42](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Recommendations/ProductRecommendationService.cs:42), [PadelClub.Services/Recommendations/ProductRecommendationService.cs:56](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Recommendations/ProductRecommendationService.cs:56), [PadelClub.Services/Recommendations/ProductRecommendationService.cs:77](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Recommendations/ProductRecommendationService.cs:77).

**R19 · P2 · Audit — HTTP audit ne garantuje poslovni trag odobrenja**

AuditMiddleware upisuje u drugom scope-u nakon akcije, koristi RequestAborted i samo logira neuspjeh. Reservation nema ConfirmedBy/CancelledBy; ConfirmResult postavlja vrijeme potvrde bez identiteta potvrđivača.

**Posljedica:** Poslovna promjena može ostati bez audita pri prekidu zahtjeva ili grešci upisa. HTTP putanja ne dokazuje staro/novo stanje ili razlog odluke.

**Ispravka:** Actor ID, vrijeme, razlog i prijelaz upisati u istoj transakciji s poslovnom promjenom; HTTP audit ostaviti dodatnim slojem.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/Auditing/AuditMiddleware.cs:24](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Auditing/AuditMiddleware.cs:24), [PadelClub.Services/Database/Reservation.cs:18](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/Reservation.cs:18), [PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:164](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:164).

**R20 · P2 · Flutter — Notifikacije zavise od početnog učitavanja i ručnog refresha**

NotificationProvider učitava na eksplicitni poziv; home poziva loadMine pri učitavanju, a admin ekran ima refresh dugme. U pregledanom Flutter lib nema SignalR-a, periodičnog pollinga ili push listenera koji ažurira listu.

**Posljedica:** Nova backend notifikacija ne osvježava otvoreni ekran automatski; backend push worker sam to ne rješava.

**Ispravka:** Dodati lifecycle-aware polling ili SignalR, uz zaustavljanje pri logoutu/dispose i bez preklapanja zahtjeva.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [UI/padelclub_desktop/lib/features/notifications/presentation/providers/notification_provider.dart:17](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/notifications/presentation/providers/notification_provider.dart:17), [UI/padelclub_desktop/lib/features/home/presentation/screens/mobile_home_screen.dart:37](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/home/presentation/screens/mobile_home_screen.dart:37), [UI/padelclub_desktop/lib/features/notifications/presentation/screens/notification_management_screen.dart:130](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/notifications/presentation/screens/notification_management_screen.dart:130).

**R21 · P2 · Flutter / paginacija — Popravka backend limita skriva korisnike iza prve stranice**

BaseService sada ograničava PageSize na 100. UserProvider traži 200, uzima samo items i odbacuje TotalCount; UserManagement filtrira samo lokalni users i nema page navigaciju.

**Posljedica:** Od 101. korisnika nadalje zapisi nisu dostupni na ovom ekranu; lokalna pretraga ih ne pronalazi. Slične jednokratne zahtjeve treba pregledati na orders/courts/product ekranima.

**Ispravka:** UI vezati za stvarnu server paginaciju i backend pretragu; ne tretirati prvu stranicu kao cijelu tabelu.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.Services/BaseService.cs:33](C:/Users/User/Desktop/PadelClub/PadelClub.Services/BaseService.cs:33), [UI/padelclub_desktop/lib/features/users/presentation/providers/user_provider.dart:24](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/users/presentation/providers/user_provider.dart:24), [UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:271](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:271).

**R22 · P2 · Baza / UI — Grad i tip članarine koriste slobodan tekst umjesto referentnih FK-ova**

PlayerProfile.City i Membership.MembershipType su stringovi; profil prima City kroz request. Model nema odgovarajuće CityId/MembershipTypeId reference za ove vrijednosti.

**Posljedica:** Krši dostavljeno pravilo referentnih tabela; pravopisne varijante otežavaju filtriranje i dosljedan prikaz.

**Ispravka:** Uvesti referentne tabele/FK i Dropdown selekcije. Migraciju postojećih tekstualnih vrijednosti napraviti eksplicitno.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.Services/Database/PlayerProfile.cs:9](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/PlayerProfile.cs:9), [PadelClub.Services/Database/Membership.cs:9](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/Membership.cs:9), [PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:177](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:177).

**R23 · P2 · Flutter — UI prikazuje PK i traži unos User ID-a**

Audit filter je tekstualno polje User ID, payment history naslov prikazuje payment.id, a reservation red prikazuje reservation.id i userId.

**Posljedica:** Krši zabranu prikazivanja PK i pravilo referentnog izbora kroz Dropdown; korisnik mora znati interne identifikatore.

**Ispravka:** Prikazati naziv korisnika i poslovni broj dokumenta; filter korisnika zamijeniti pretraživim Dropdown-om.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [UI/padelclub_desktop/lib/features/operations/presentation/screens/audit_trail_screen.dart:123](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/operations/presentation/screens/audit_trail_screen.dart:123), [UI/padelclub_desktop/lib/features/payment_history/presentation/screens/payment_history_screen.dart:169](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/payment_history/presentation/screens/payment_history_screen.dart:169), [UI/padelclub_desktop/lib/features/reservations/presentation/screens/reservation_screens.dart:1733](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/reservations/presentation/screens/reservation_screens.dart:1733).

**R24 · P2 · Flutter — Nedostupne admin akcije ostaju klikabilne**

Add User i activate/deactivate imaju aktivan onPressed, ali samo otvaraju obavijest da će funkcionalnost biti povezana u kasnijoj fazi.

**Posljedica:** UI obećava akciju koju ne može izvršiti; krši disabled + objašnjenje zahtjev i zadržava implementacijske poruke u korisničkom toku.

**Ispravka:** Akcije implementirati ili prikazati disabled uz konkretan korisnički razlog.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:57](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:57), [UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:261](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:261), [UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:312](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:312).

**R25 · P2 · State machine — Completed prijelaz rezervacije postoji samo u helperu**

ReservationLifecycle dopušta Confirmed → Completed nakon završetka, ali ReservationService/Controller nude samo cancel i no-show. Update izričito zabranjuje promjenu statusa; create direktno kreira Confirmed.

**Posljedica:** Normalno odigrana rezervacija nema dostupan tok prelaska u Completed. Postojanje helpera nije dovršen centralni lifecycle.

**Ispravka:** Dodati autorizovanu complete komandu ili worker koji koristi isti lifecycle i zapisuje actor/vrijeme; definisati i Pending potvrdu ako se zadržava to stanje.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.Services/ReservationLifecycle.cs:11](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationLifecycle.cs:11), [PadelClub.Services/ReservationService.cs:128](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:128), [PadelClub.WebAPI/Controllers/ReservationsController.cs:88](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/ReservationsController.cs:88).

**R26 · P2 · Baza — Cascade/SetNull veze ostaju na poslovnoj historiji**

OrderItems i MembershipEvents koriste Cascade; Payment veze prema Reservation/Membership/Order koriste SetNull.

**Posljedica:** Doslovno krši dostavljeno pravilo očuvanja povezanih podataka. Generički DELETE rezervacija/narudžbi/članarina sada je blokiran, pa ovo nije dokaz da te HTTP akcije i dalje brišu historiju; rizik ostaje na DB/novim servisnim ulazima.

**Ispravka:** Za finansijske i audit veze koristiti Restrict/NoAction i domensko arhiviranje, uz provjeru migracija.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.Services/Database/PadelClubContext.cs:471](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/PadelClubContext.cs:471), [PadelClub.Services/Database/PadelClubContext.cs:927](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/PadelClubContext.cs:927), [PadelClub.Services/Database/PadelClubContext.cs:1156](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/PadelClubContext.cs:1156).

**R27 · P3 · Kvalitet / async — Mrtvi helper, blokirajući pozivi i neimplementirani metod ostaju u kodu**

RunCrudSmokeTestsIfNeeded nema pozivalaca, ali sadrži brojne GetAwaiter().GetResult(). ReservationsController zadržava zakomentarisane CRUD metode. PasswordHasher.GenerateSalt baca NotImplementedException.

**Posljedica:** Krši zabranu mrtvog/zakomentarisanog koda i sync-over-async. Ne tvrdim da mrtvi helper sada blokira produkcijske zahtjeve; startup migration retry je već prebačen na Task.Delay.

**Ispravka:** Ukloniti neaktivni helper i zakomentarisane implementacije; suziti ili implementirati hash interfejs.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/Program.cs:1017](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:1017), [PadelClub.WebAPI/Program.cs:1041](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:1041), [PadelClub.WebAPI/Controllers/ReservationsController.cs:101](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/ReservationsController.cs:101), [PadelClub.Services/PasswordHasher.cs:108](C:/Users/User/Desktop/PadelClub/PadelClub.Services/PasswordHasher.cs:108).

**R28 · P3 · Pravila / autorizacija — AllowAnonymous postoji izvan login/register**

refresh, forgot-password, reset-password, verify-email i Stripe webhook imaju AllowAnonymous. Webhook provjerava Stripe potpis.

**Posljedica:** Formalno kršenje dostavljenog pravila. Sama anonimnost potpisanog webhooka nije potvrđen sigurnosni proboj. Dodavanje običnog korisničkog JWT zahtjeva onemogućilo bi predviđeni vanjski callback.

**Ispravka:** Uskladiti pravila za auth recovery i potpisane integracijske callback-e ili odvojiti integracijski ulaz s odgovarajućom autentikacijom; ne uklanjati provjeru potpisa.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/Controllers/UsersController.cs:59](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/UsersController.cs:59), [PadelClub.WebAPI/Controllers/UsersController.cs:72](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/UsersController.cs:72), [PadelClub.WebAPI/Controllers/UsersController.cs:81](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/UsersController.cs:81), [PadelClub.WebAPI/Controllers/StripePaymentsController.cs:43](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/StripePaymentsController.cs:43).

**R29 · P3 · Pravila / autorizacija — Admin policy koristi Administrator umjesto Roles=Admin**

AdminOnly zahtijeva RequireRole("Administrator"), a kontroleri koriste Authorize(Policy="AdminOnly").

**Posljedica:** Formalna razlika u nazivu/atributu prema ground truth-u; policy ipak vrši server-side provjeru uloge. Nije dokaz player pristupa admin operacijama.

**Ispravka:** Uskladiti naziv uloge, seed, JWT claim i atribute ako se traži doslovno Admin, ili dokumentovati policy ekvivalentnost.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/Program.cs:149](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:149), [PadelClub.WebAPI/Controllers/PaymentsController.cs:19](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PaymentsController.cs:19).

**R30 · P3 · Pravila / identitet — Self-service DTO prima UserId i nema current-user accessor servisa**

ReservationInsertRequest izlaže UserId, Status i TotalPrice; controller prepisuje identitet i servis računa cijenu. Kontroleri ponavljaju čitanje ClaimsPrincipal-a; IHttpContextAccessor/current-user servis nije pronađen.

**Posljedica:** Formalno krši zabranu primanja UserId za trenutnog korisnika i traženu injekciju. Ovaj POST nije potvrđena impersonacija; FindFirstValue nije ručno dekodiranje JWT-a.

**Ispravka:** Odvojiti self-service DTO od admin DTO-a i koristiti ICurrentUser zasnovan na IHttpContextAccessor.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.Model/Requests/ReservationInsertRequest.cs:8](C:/Users/User/Desktop/PadelClub/PadelClub.Model/Requests/ReservationInsertRequest.cs:8), [PadelClub.WebAPI/Controllers/ReservationsController.cs:44](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/ReservationsController.cs:44), [PadelClub.WebAPI/Controllers/ReservationsController.cs:91](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/ReservationsController.cs:91).

**R31 · P3 · Konfiguracija — Development connection string ostaje u JSON-u**

appsettings.Development.json sadrži aktivni DefaultConnection za localhost s Trusted_Connection. Compose connection string sastavlja iz interpoliranih env vrijednosti.

**Posljedica:** Krši isključivo .env pravilo za connection string. U ovoj vrijednosti nema SQL lozinke; raniji nalaz javnog JWT ključa/fallback lozinki nije više važeći.

**Ispravka:** Sve connection string vrijednosti premjestiti u propisani env mehanizam, bez tajnih fallback-a.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/appsettings.Development.json:24](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/appsettings.Development.json:24), [docker-compose.yml:59](C:/Users/User/Desktop/PadelClub/docker-compose.yml:59).

**R32 · P3 · Exception ugovor — Domenske greške široko koriste sistemske exceptione**

Globalni ExceptionFilter i UserException postoje, ali servisi dominantno bacaju InvalidOperationException/KeyNotFoundException; filter prosljeđuje njihove Message vrijednosti.

**Posljedica:** Nedovoljno precizan domenski ugovor prema zahtjevu custom exceptiona; sistemska InvalidOperationException može sadržavati implementacijske detalje. Nije potvrđen izlaz stack trace-a.

**Ispravka:** Koristiti konkretne domenske exceptione i whitelisted poruke; neočekivane sistemske izuzetke logirati i vratiti generički problem.

**Dokaz:** Statička analiza trenutnog koda; nije izvršen HTTP/SQL/provider test. Lokacije: [PadelClub.WebAPI/Filters/ExceptionFilter.cs:23](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Filters/ExceptionFilter.cs:23), [PadelClub.Services/ReservationService.cs:129](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:129), [PadelClub.WebAPI/Payments/StripePaymentService.cs:83](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/StripePaymentService.cs:83).

**Provjere bez potvrđenog kršenja**

- Lozinke koriste PBKDF2. SHA256 kao PRF unutar PBKDF2 i hash nasumičnog reset tokena nisu zabranjeni plain SHA256 hash lozinke. Tokeni/salt koriste RandomNumberGenerator.
- Kontroleri imaju vlastitu ili naslijeđenu autorizaciju; AdminOnly provjerava ulogu. Iz UserId u admin DTO-u samog po sebi nije izveden IDOR nalaz. PartnerUserId označava drugog učesnika, ne identitet pozivaoca.
- Rezervacijski create i checkout računaju iznos na backendu; Stripe webhook provjerava potpis. Postoje unique payment idempotency/reference veze. Nije dokazano proizvoljno višestruko terećenje istog predmeta.
- Zaseban RabbitMQ subscriber i injektovani IBus postoje. Nije pronađena konstrukcija konekcije za svaki publish; interna implementacija EasyNetQ nije ovdje auditirana.
- Globalni exception filter i UserException postoje; izlaz stack trace-a iz pregledanih MVC akcija nije potvrđen. R32 se odnosi na preširok ugovor poruka.
- U pregledanim endpointima nema binary file uploada: proizvodi primaju ImageUrl, ne IFormFile/raw sadržaj. Zato nedostatak magic-byte provjere nije prijavljen kao propust postojećeg uploada. Model Asset s Base64Image nije sam po sebi javni upload endpoint.
- U Flutter build metodama nije pronađeno base64Decode. Produkt liste imaju Image.network, a pregledani rezervacijski tokovi imaju date pickere i confirmation dijaloge. Nedostatak potvrde nije generalizovan na sve ekrane.
- Future.wait postoji u home/discovery/player/returns tokovima. Nije pronađeno eksplicitno new HttpClient u aplikacijskom C# kodu; SDK klijent nije automatski isti prekršaj.

**Prioritet ispravki**

1. R01–R04: jedinstveni refund/kredit saldo i zatvaranje generičkih finansijskih/lifecycle zaobilaznica.
2. R05–R09 i R19/R25: zajednički kalendar, atomarne poslovne operacije, razlozi, audit i kompletan lifecycle.
3. R07/R20/R21: naplata u mobilnoj aplikaciji, automatske notifikacije i stvarna navigacija kroz stranice.
4. Preostala arhitektonska, performansna i formalna odstupanja; ne predstavljati policy naziv ili anonimni potpisani webhook kao dokazan sigurnosni proboj.

Za ponavljanje proba iz korijena projekta: `dotnet restore audit/rs2-current-review/probes/AuditProbes.csproj --configfile audit/rs2-current-review/probes/NuGet.Config`, zatim `dotnet run --project audit/rs2-current-review/probes/AuditProbes.csproj --no-restore`. Restore koristi samo lokalno keširane pakete. Za odobrenje ispravki potrebni su zasebni regresijski testovi sa sigurnim očekivanim ishodom i SQL/provider/uređajske provjere gdje su ovdje navedene granice.

