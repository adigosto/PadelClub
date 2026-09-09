**RS2 pregled projekta PadelClub — 8. septembar 2026.**

**Zaključak: pregledani kod ne zadovoljava dostavljene kriterije.** Evidentirano je 37 nalaza: 2 P0, 16 P1, 15 P2 i 4 P3. P0 znači kritičan propust uz navedene konfiguracijske preduslove; P1 visok rizik ili ključan nedostajući tok; P2 značajno pravilo/arhitektonski propust; P3 formalno ili manje odstupanje. Formalna odstupanja nisu izjednačena sa sigurnosnim probojima.

Pregledana je trenutna radna kopija, uključujući postojeće necommitovane izmjene, a ne samo Git diff. Opseg: ASP.NET API/kontroleri, EF servisi i model, JWT, Stripe, RabbitMQ subscriber/workeri, preporuke i zajednički Flutter kod. Mobile runner koristi desktop paket, pa se zajednički lib odnosi na obje distribucije. Dostavljeni tekst pravila tretiran je kao ground truth; aktuelni fakultetski silabus nije nezavisno tražen niti verifikovan.

**Provjera i granice dokaza.** Build i 77 postojećih testova iz skupa bez SQL integration fixture-a prolaze. Dodatni lokalni program poziva stvarne kontrolere/servise i u izolovanoj EF InMemory bazi reprodukuje 11 problematičnih ponašanja. To nisu HTTP end-to-end, SQL race, uređajski niti stvarni provider testovi. Nisu pozivani produkcijski endpoint-i, Stripe, SMTP niti Firebase, niti je pregledan sadržaj privatnog .env fajla. Izvorne aplikacijske datoteke nisu mijenjane; dodani su samo audit artefakti. Build/restore su obnovili generisane bin/obj datoteke.

Dokazi: [izvršni rezultati proba](C:/Users/User/Desktop/PadelClub/audit/rs2-2026-09-08/probe-results.txt), [ponovljivi program proba](C:/Users/User/Desktop/PadelClub/audit/rs2-2026-09-08/probes/Program.cs), [77 testova — TRX](C:/Users/User/Desktop/PadelClub/audit/rs2-2026-09-08/test-results/rs2-audit-unit-tests.trx).

**F01 · P0 · Sigurnost — Production bootstrap kreira poznat administratorski račun**

BootstrapOnStartup podrazumijevano je true. SeedInitialData se poziva i u Production okruženju; ograničenje IsDevelopment odnosi se samo na dodatne demo podatke. Ako je tabela Users prazna, kreira se admin s lozinkom iz izvornog koda. Pri svakom bootstrapu račun nazvan admin ponovo dobija Administrator ulogu.

**Posljedica:** Napadaču koji može pristupiti novoj instalaciji s ovim bootstrapom dovoljni su javno poznati seed kredencijali za administrativni pristup. Ručno oduzeta admin uloga može se vratiti nakon restarta.

**Ispravka:** Demo korisnike ograničiti na eksplicitno razvojno okruženje. Prvog administratora kreirati zasebnim, jednokratnim postupkom s tajnom iz okruženja; ne dodjeljivati uloge na osnovu username-a.

**Dokaz:** Statički potvrđeno; nije testiran login na stvarnoj instalaciji. Lokacije: [PadelClub.WebAPI/Program.cs:213](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:213), [PadelClub.WebAPI/Program.cs:359](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:359), [PadelClub.WebAPI/Program.cs:404](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:404).

**F02 · P0 · Sigurnost — JWT ključ i infrastrukturne lozinke imaju javne, aktivne zadane vrijednosti**

appsettings.Development.json sadrži JWT signing key. docker-compose.yml pokreće API u Development okruženju i postavlja isti poznati ključ kao fallback, uz poznate SQL i RabbitMQ lozinke. Program provjerava samo minimalnu dužinu JWT ključa.

**Posljedica:** Instalacija koja ne zamijeni vrijednosti prihvata tokene potpisane javno poznatim ključem, uključujući proizvoljan identitet i Administrator claim. Ozbiljnost se odnosi na konfiguraciju sa zadanim ključem; vrijednosti stvarnog .env fajla nisu provjeravane.

**Ispravka:** Ukloniti tajne i tajne fallback vrijednosti iz koda, JSON-a i Compose-a. Zahtijevati .env vrijednosti pri pokretanju, odbiti poznati razvojni ključ i rotirati ključeve/kredencijale gdje su ove vrijednosti korištene.

**Dokaz:** Statički potvrđeno; nije tvrđeno da su Stripe ili PayPal produkcijske tajne procurile. Lokacije: [PadelClub.WebAPI/appsettings.Development.json:10](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/appsettings.Development.json:10), [docker-compose.yml:8](C:/Users/User/Desktop/PadelClub/docker-compose.yml:8), [docker-compose.yml:58](C:/Users/User/Desktop/PadelClub/docker-compose.yml:58), [PadelClub.WebAPI/Program.cs:126](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:126).

**F03 · P1 · Sigurnost — IDOR preko naslijeđenog GET /Reservations/{id}**

ReservationsController ograničava listu na administratore, ali ne override-a GetById. Naslijeđeni BaseController poziva GetByIdAsync(id), a BaseService radi FindAsync(id) bez poređenja vlasnika s JWT korisnikom.

**Posljedica:** Prijavljeni korisnik može enumerirati tuđe rezervacije i čitati UserId, termin, cijenu i Notes. Lokalna proba s caller=2 vratila je rezervaciju owner=1 i privatnu napomenu.

**Ispravka:** Implementirati zaseban servisni read s predikatom Id == id && UserId == currentUserId, uz eksplicitnu admin iznimku. Provjeravati i naslijeđene HTTP akcije u testovima.

**Dokaz:** Izvršno reprodukovano: IDOR. Proba poziva stvarnu akciju direktno; HTTP middleware nije pokrenut. Lokacije: [PadelClub.WebAPI/Controllers/BaseController.cs:26](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/BaseController.cs:26), [PadelClub.Services/BaseService.cs:64](C:/Users/User/Desktop/PadelClub/PadelClub.Services/BaseService.cs:64), [PadelClub.WebAPI/Controllers/ReservationsController.cs:12](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/ReservationsController.cs:12).

**F04 · P1 · Plaćanje — Generički admin CRUD zaobilazi server-side finalizaciju plaćanja**

PaymentsController izlaže POST, PUT i DELETE kroz generički servis. PaymentUpdateRequest prima Amount, Status i TransactionId; PaymentService.UpdateAsync prosljeđuje ih u base.UpdateAsync bez Stripe provjere i bez zabrane izmjena provider plaćanja.

**Posljedica:** Admin klijent može proglasiti Stripe uplatu Completed ili promijeniti obračunski iznos bez naplate. Proba je promijenila Amount sa 30 na 999 uz Completed; takvi podaci poslije ulaze u kredit/refund logiku. Ovo zahtijeva admin pristup, nije player eskalacija.

**Ispravka:** Onemogućiti generičke izmjene provider plaćanja. Naplaćeni iznos, provider ID i finalni status moraju biti nepromjenjivi servisni podaci potvrđeni kod providera; gotovinske uplate voditi odvojenim validiranim workflowom.

**Dokaz:** Izvršno reprodukovano: MANUAL_SETTLEMENT. Lokacije: [PadelClub.WebAPI/Controllers/PaymentsController.cs:26](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PaymentsController.cs:26), [PadelClub.Services/PaymentService.cs:30](C:/Users/User/Desktop/PadelClub/PadelClub.Services/PaymentService.cs:30), [PadelClub.Model/Requests/PaymentUpdateRequest.cs:12](C:/Users/User/Desktop/PadelClub/PadelClub.Model/Requests/PaymentUpdateRequest.cs:12).

**F05 · P1 · Plaćanje — Webhook može vratiti finalizirano plaćanje u stariji status**

ProcessWebhookAsync deduplicira samo po StripeEventId. Svaki novi PaymentIntent događaj direktno prepisuje Status; Charge događaj direktno prepisuje RefundedAmount. Nema provjere dozvoljenog prijelaza ni usklađivanja s aktuelnim provider stanjem.

**Posljedica:** Uspjeh praćen starijim processing događajem vraća lokalni status iz Completed u Pending. Zakašnjeli charge snapshot može smanjiti evidentirani refund; naknadni succeeded može prebrisati Refunded. Lokalna proba potvrđuje Completed -> Pending.

**Ispravka:** Uvesti monotone prijelaze plaćanja, odvojiti status naplate od refund stanja i vršiti server-side reconciliation prije primjene konfliktnog događaja. Testirati više različitih event ID-jeva u promijenjenom redoslijedu.

**Dokaz:** Izvršno reprodukovano: WEBHOOK_REGRESSION; vanjski Stripe nije pozivan. Lokacije: [PadelClub.WebAPI/Payments/StripePaymentService.cs:67](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/StripePaymentService.cs:67), [PadelClub.WebAPI/Payments/StripePaymentService.cs:80](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/StripePaymentService.cs:80), [PadelClub.WebAPI/Payments/StripePaymentService.cs:90](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/StripePaymentService.cs:90).

**F06 · P1 · Plaćanje — Nepovezan webhook označava se obrađenim i više se ne pokušava**

Ako za intent.Id još ne postoji Payment s odgovarajućim TransactionId, metoda preskače promjenu plaćanja, ali ipak snima StripeWebhookEvent.ProcessedAt. Svaki replay tog ID-ja završava na početnom return. CreateIntent povezuje TransactionId tek nakon vanjskog poziva.

**Posljedica:** Događaj koji stigne prije lokalnog povezivanja, nakon prekida inicijalizacije ili u toku oporavka može trajno ostati bez primjene. Proba je prvo dostavila događaj, zatim dodala odgovarajuće plaćanje i ponovila događaj: plaćanje je ostalo Pending.

**Ispravka:** Trajno primiti događaj u inbox sa statusom Pending/Unmatched; tek uspješnu obradu označiti Completed. Koristiti metadata payment_id za korelaciju, retry i reconciliation; ne poistovjećivati primljen s obrađenim.

**Dokaz:** Izvršno reprodukovano: EARLY_WEBHOOK_LOST. Stvarna mrežna utrka nije izvršena. Lokacije: [PadelClub.WebAPI/Payments/StripePaymentService.cs:51](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/StripePaymentService.cs:51), [PadelClub.WebAPI/Payments/StripePaymentService.cs:69](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/StripePaymentService.cs:69), [PadelClub.WebAPI/Payments/StripePaymentService.cs:100](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/StripePaymentService.cs:100).

**F07 · P1 · Plaćanje — Kredit nakon otkazivanja nije usklađen s refund saldom**

CancelAsync dodaje AccountCredit na osnovu Completed uplate, ali ne mijenja payment saldo/status. QueueDirectAsync računa preostali refund samo iz Amount, RefundedAmount i pending refund operacija. Provjera postojećeg kredita je AnyAsync izvan transakcije, bez unique ReservationId indeksa.

**Posljedica:** Ista uplata može ostati osnova za puni kredit i puni refund. Dvije istovremene obrade otkazivanja mogu upisati dva kredita. Proba potvrđuje kredit od 30 uz uplatu koja i dalje ima status Completed; vanjski refund i konkurentni SQL upisi nisu izvršeni.

**Ispravka:** Voditi jedinstven transakcijski saldo povrata s izborom kredit ili provider refund. Dodati unique poslovni ključ kredita i zaključavanje/idempotentnu obradu otkazivanja; kredit izdavati iz stvarnog preostalog naplaćenog iznosa.

**Dokaz:** Djelimično izvršno potvrđeno: CREDIT_PAYMENT_LEDGER; ostatak je analiza povezanih putanja. Lokacije: [PadelClub.Services/ReservationService.cs:178](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:178), [PadelClub.Services/Database/PadelClubContext.cs:604](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/PadelClubContext.cs:604), [PadelClub.WebAPI/Payments/ProviderRefundOperationService.cs:97](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/ProviderRefundOperationService.cs:97).

**F08 · P1 · Poslovna logika — Hard delete aktivnih rezervacija, narudžbi i članarina uništava poslovni trag**

ReservationService, OrderService i MembershipService nasljeđuju BaseCRUDService.DeleteAsync bez zabrane aktivnog stanja. Brisanje radi Remove. Veze Payment -> Reservation/Membership/Order koriste SetNull; OrderItems i MembershipEvents imaju Cascade.

**Posljedica:** Admin DELETE uklanja potvrđenu rezervaciju ili aktivnu narudžbu umjesto otkazivanja. Narudžba gubi stavke, članarina historiju, a uplata vezu s predmetom; brisanje narudžbe zaobilazi vraćanje zalihe. Proba je obrisala buduću Confirmed rezervaciju.

**Ispravka:** Ukloniti javni generički hard delete za poslovne entitete. Koristiti centralizovano otkazivanje/arhiviranje, Restrict za finansijske/audit veze i transakcijsko vraćanje zalihe.

**Dokaz:** Izvršno reprodukovano: HARD_DELETE. SQL kaskade potvrđene konfiguracijom modela, ne InMemory probom. Lokacije: [PadelClub.Services/BaseCRUDService.cs:78](C:/Users/User/Desktop/PadelClub/PadelClub.Services/BaseCRUDService.cs:78), [PadelClub.WebAPI/Controllers/ReservationsController.cs:47](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/ReservationsController.cs:47), [PadelClub.Services/Database/PadelClubContext.cs:917](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/PadelClubContext.cs:917), [PadelClub.Services/Database/PadelClubContext.cs:1149](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/PadelClubContext.cs:1149).

**F09 · P1 · Poslovna logika — Rezervacije nemaju centralizovane validirane prijelaze**

Generički Update mapira request.Status prije BeforeUpdate, koji provjerava samo termin, korisnika i cijenu. MarkNoShowAsync bezuslovno postavlja NoShow, bez kontrole prethodnog statusa i vremena završetka. CancelAsync ne provjerava izričito dozvoljeni prethodni status.

**Posljedica:** Prihvaćen je proizvoljan status ArbitraryState i no-show za budući termin. Admin može preko PUT zaobići CancelAsync, a time kredit, CancelledAt i notifikaciju, ili reaktivirati otkazanu buduću rezervaciju.

**Ispravka:** Uvesti jednu state machine za kreiranje, potvrdu, otkazivanje, završetak i no-show. Generički update ne smije direktno mapirati Status; prijelazi trebaju validirati vrijeme i izvršiti sve vezane efekte.

**Dokaz:** Izvršno reprodukovano: STATE i FUTURE_NO_SHOW. Lokacije: [PadelClub.Services/BaseCRUDService.cs:61](C:/Users/User/Desktop/PadelClub/PadelClub.Services/BaseCRUDService.cs:61), [PadelClub.Services/ReservationService.cs:113](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:113), [PadelClub.Services/ReservationService.cs:295](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:295).

**F10 · P1 · Baza i konkurentnost — Izmjena rezervacije nema zaštitu provjere preklapanja**

CreateAsync koristi Serializable transakciju. UpdateAsync je naslijeđen: učitavanje, BeforeUpdate/AnyAsync provjera preklapanja i SaveChanges nisu u istoj eksplicitnoj transakciji. Indeks CourtId/StartTime/EndTime nije ograničenje koje zabranjuje presijecanje intervala.

**Posljedica:** Dvije paralelne admin izmjene mogu obje provjeriti slobodan isti termin i zatim obje snimiti rezervacije. Postojanje provjere na backendu nije dovoljno kada provjera i upis nisu atomarni.

**Ispravka:** Provjeru i izmjenu objediniti pod istim zaključavanjem po terenu/terminu ili Serializable transakcijom sa smislenim retry postupkom; dodati SQL konkurentni test update-update i create-update.

**Dokaz:** Statički potvrđena nezaštićena putanja; konkurentnost nije reprodukovana na SQL Serveru. Lokacije: [PadelClub.Services/ReservationService.cs:82](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:82), [PadelClub.Services/ReservationService.cs:113](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:113), [PadelClub.Services/BaseCRUDService.cs:55](C:/Users/User/Desktop/PadelClub/PadelClub.Services/BaseCRUDService.cs:55).

**F11 · P1 · Poslovna logika — Turnirski mečevi i održavanje ne dijele provjeru zauzetosti s rezervacijama**

BracketService.GenerateAsync bira prvi aktivni teren i dodjeljuje ScheduledTime bez provjere Reservations/MaintenanceBlocks. ValidateReservationAsync provjerava samo rezervacije i održavanje, ne Matches. AddMaintenanceBlockAsync samo snima blok i ne rješava postojeće rezervacije.

**Posljedica:** Turnir može biti zakazan preko potvrđene rezervacije; korisnik može rezervisati teren na kojem je već meč. Održavanje može blokirati već obećan termin bez otkazivanja i obavijesti.

**Ispravka:** Uvesti zajednički servis kalendara s intervalima za mečeve, rezervacije i održavanje. Sve izvore zauzetosti provjeravati atomarno; održavanje koje zahvata rezervacije mora imati eksplicitno rješavanje pogođenih rezervacija.

**Dokaz:** Statički potvrđeno. Lokacije: [PadelClub.WebAPI/Tournaments/BracketService.cs:25](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Tournaments/BracketService.cs:25), [PadelClub.WebAPI/Tournaments/BracketService.cs:37](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Tournaments/BracketService.cs:37), [PadelClub.Services/ReservationService.cs:236](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:236), [PadelClub.Services/ReservationService.cs:286](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:286).

**F12 · P1 · Pouzdanost — Poslovni commit prije obavezne notifikacije ostavlja nepovratan parcijalni uspjeh**

CheckoutAsync prvo commit-a narudžbu i umanjenje zalihe, zatim kreira notifikaciju. CancelAsync snima otkazivanje prije kreiranja notifikacije i ponovljeni zahtjev odmah vraća već Cancelled rezervaciju. Sličan obrazac postoji kod turnirskih operacija.

**Posljedica:** Ako kreiranje notifikacije zakaže, checkout klijentu može vratiti grešku iako je narudžba već snimljena. Retry bez checkout idempotency ključa pravi novu narudžbu i ponovno umanjuje zalihu. Retry otkazivanja ne obnavlja izgubljenu notifikaciju.

**Ispravka:** U istoj transakciji snimiti poslovnu promjenu i notification/outbox namjeru; dostavu izvršavati naknadno. Dodati stabilan idempotency ključ checkouta i vraćati već kreirani rezultat pri ponavljanju.

**Dokaz:** Statički potvrđeno; kvar notifikacijskog upisa nije injektovan. Lokacije: [PadelClub.Services/OrderService.cs:169](C:/Users/User/Desktop/PadelClub/PadelClub.Services/OrderService.cs:169), [PadelClub.Services/ReservationService.cs:170](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:170), [PadelClub.Services/ReservationService.cs:181](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:181), [UI/padelclub_desktop/lib/features/product/presentation/providers/cart_provider.dart:100](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/product/presentation/providers/cart_provider.dart:100).

**F13 · P1 · Poslovna logika — Generički CRUD narudžbi i stavki zaobilazi obračun i state machine**

OrderService.BeforeInsert postavlja samo porijeklo; OrderInsertRequest prima Status i TotalAmount. UpdateAsync provjerava prijelaz, ali MapUpdateToEntity i dalje mapira TotalAmount i UserId. OrderItemService nema insert/update/delete validaciju poslovnog stanja ni preračun narudžbe.

**Posljedica:** Admin može kreirati odmah Delivered narudžbu, mijenjati stavke/iznose nakon isporuke ili premjestiti vlasništvo bez usklađenja s uplatom. To kvari zalihu, refund raspodjelu i preporuke. Provjera prijelaza u UpdateAsync pokriva samo jednu ulaznu putanju.

**Ispravka:** Zamijeniti široke CRUD DTO-e komandama za kreiranje, ispunjenje i otkazivanje. Zaključati cijene i stavke nakon zaključivanja; ukupan iznos i zalihu računati na backendu kroz isti servis za sve ulaze.

**Dokaz:** Statički potvrđeno; admin privilegija je preduslov. Lokacije: [PadelClub.Services/OrderService.cs:49](C:/Users/User/Desktop/PadelClub/PadelClub.Services/OrderService.cs:49), [PadelClub.Services/OrderService.cs:217](C:/Users/User/Desktop/PadelClub/PadelClub.Services/OrderService.cs:217), [PadelClub.Model/Requests/OrderInsertRequest.cs:7](C:/Users/User/Desktop/PadelClub/PadelClub.Model/Requests/OrderInsertRequest.cs:7), [PadelClub.Services/OrderItemService.cs:10](C:/Users/User/Desktop/PadelClub/PadelClub.Services/OrderItemService.cs:10).

**F14 · P1 · Sigurnost — Povlačenje s turnira povlači i nepovezane igrače bez broja tima**

Withdraw pronalazi korisnikovu prijavu, a zatim povlači sve učesnike čiji je TeamNumber jednak njenom. TeamNumber je nullable. Za legacy/generičke prijave null == null obuhvata sve takve prijave na turniru.

**Posljedica:** Jedan igrač može povući druge igrače koji nisu njegovi saigrači. Proba s dvije nepovezane null-team prijave potvrdila je da caller=2 povlači i owner=1.

**Ispravka:** Ako TeamNumber nije postavljen, izmijeniti samo trenutnu prijavu. Tim modelirati zasebnim FK entitetom i provjeriti granice ovlaštenja za timsko povlačenje.

**Dokaz:** Izvršno reprodukovano: NULL_TEAM_WITHDRAWAL. Lokacije: [PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs:101](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs:101), [PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs:105](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs:105).

**F15 · P1 · Poslovna logika — Saigrač može potvrditi rezultat bez protivničkog tima**

ConfirmResult zabranjuje potvrdu samo istom ReportedByUserId i ne provjerava pripadnost suprotnoj ekipi. CanConfirmResult koristi isti uslov. Potvrda mijenja rejtinge i pokreće napredovanje kroz bracket.

**Posljedica:** Dva igrača iste ekipe mogu prijaviti i potvrditi pobjedu bez saglasnosti protivnika. Proba s reporter=1 i confirmer=2 iz tima 1 finalizirala je rezultat protiv igrača 3.

**Ispravka:** Za potvrdu zahtijevati igrača iz protivničkog tima ili eksplicitnu admin arbitražu. Sačuvati ConfirmedByUserId i provjeriti da je meč vremenski spreman za unos rezultata.

**Dokaz:** Izvršno reprodukovano: TEAMMATE_CONFIRMS. Lokacije: [PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:113](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:113), [PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:144](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:144).

**F16 · P1 · Pouzdanost — Generisanje i napredovanje bracket-a nisu atomarni**

GenerateAsync prvo snima Matches, pa veze sljedećih mečeva i učesnike kroz dodatne SaveChanges pozive bez zajedničke transakcije. Svaki postojeći BracketRound blokira ponovni Generate. ConfirmResult commit-a konačan rezultat prije AdvanceWinnerAsync.

**Posljedica:** Kvar između upisa ostavlja djelimičan bracket koji nije moguće ponovo generisati. Kvar napredovanja poslije potvrde ostavlja pobjednika izvan sljedećeg meča, a ponovna potvrda odbija već Confirmed rezultat.

**Ispravka:** Generisanje objediniti u jednu transakciju. Potvrdu i napredovanje izvršiti zajedno ili kroz idempotentnu trajnu operaciju koja se može ponoviti poslije prekida.

**Dokaz:** Statički potvrđeno; proces nije nasilno prekidan. Lokacije: [PadelClub.WebAPI/Tournaments/BracketService.cs:18](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Tournaments/BracketService.cs:18), [PadelClub.WebAPI/Tournaments/BracketService.cs:43](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Tournaments/BracketService.cs:43), [PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:161](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:161).

**F17 · P2 · Poslovna logika — Članarine imaju više neusaglašenih putanja promjene stanja**

MembershipService validira datum, cijenu i preklapanje samo pri CreateAsync. Generički PUT ostaje naslijeđen, dok ChangeStatus i Renew u kontroleru direktno mijenjaju stanje. ChangeStatus dopušta Active i za isteklu članarinu, bez provjere EndDate ili preklapanja.

**Posljedica:** Moguće je snimiti neispravan raspon/cijenu na update-u ili imati Status i IsActive koji se ne slažu. RenewalDue postaje IsActive=false, a ResolvePayableAsync prima samo aktivne članarine, pa taj payment ulaz ne može platiti nastalu obnovu.

**Ispravka:** Centralizovati lifecycle članarine i validaciju intervala za sve izmjene. Obnovu modelirati kao zaseban period s vlastitom obavezom plaćanja; aktivirati je tek po potvrđenoj uplati.

**Dokaz:** Statički potvrđeno. Lokacije: [PadelClub.Services/MembershipService.cs:18](C:/Users/User/Desktop/PadelClub/PadelClub.Services/MembershipService.cs:18), [PadelClub.WebAPI/Controllers/MembershipsController.cs:70](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/MembershipsController.cs:70), [PadelClub.WebAPI/Memberships/MembershipLifecycleWorker.cs:19](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Memberships/MembershipLifecycleWorker.cs:19), [PadelClub.WebAPI/Payments/StripePaymentService.cs:119](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Payments/StripePaymentService.cs:119).

**F18 · P2 · Poslovna logika — Otkazivanje ne zahtijeva korisnički razlog**

ReservationsController.Cancel ne prima request body, a CancelAsync nema argument razloga. AccountCredit.Reason je fiksna poruka sistema, ne razlog otkazivanja. OrderUpdateRequest.Notes je opcionalan; otkazivanje narudžbe ne zahtijeva objašnjenje. Turnirsko Withdraw također nema razlog ni notifikaciju.

**Posljedica:** Ne može se objasniti zašto je korisnik ili administrator otkazao poslovnu stavku, što izričito krši zadani kriterij. Postojanje reservation notification poruke ne nadomješta razlog.

**Ispravka:** Uvesti CancelRequest s obaveznim validiranim razlogom i snimiti ga uz actor/time u istoj transakciji; obavijestiti sve pogođene korisnike.

**Dokaz:** Statički potvrđeno; Flutter potvrda otkazivanja postoji, ali nema unos razloga. Lokacije: [PadelClub.WebAPI/Controllers/ReservationsController.cs:52](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/ReservationsController.cs:52), [PadelClub.Services/ReservationService.cs:164](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:164), [PadelClub.Model/Requests/OrderUpdateRequest.cs:10](C:/Users/User/Desktop/PadelClub/PadelClub.Model/Requests/OrderUpdateRequest.cs:10), [PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs:98](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/TournamentLifecycleController.cs:98).

**F19 · P1 · Performanse — Paginacija se može isključiti, a brojne liste nemaju stranice**

BaseService i NotificationService izvršavaju Skip/Take samo za PageSize > 0, bez max limita. PageSize=0 ili negativan broj vraća cijeli skup. Waitlist/credits, historija članarine, moje prijave na turnire i moji return zahtjevi nemaju paginaciju. Discovery, partners, deliveries, coupons i admin returns imaju samo fiksni Take.

**Posljedica:** Jedan autentificiran zahtjev može izazvati neograničeno učitavanje i serijalizaciju. Fiksni Take ograničava veličinu, ali stariji zapisi nakon limita nisu dostupni jer nema sljedeće stranice. Proba PageSize=0 vratila je svih 15 upisanih rezervacija.

**Ispravka:** Centralno zahtijevati Page >= 1 i PageSize u rasponu 1..100 ili cursor s hard limitom. Primijeniti isti ugovor i stabilan redoslijed na sve list endpoint-e; agregatne izvještaje tretirati zasebno.

**Dokaz:** Izvršno reprodukovano: PAGINATION; ostale liste potvrđene pregledom. Lokacije: [PadelClub.Services/BaseService.cs:33](C:/Users/User/Desktop/PadelClub/PadelClub.Services/BaseService.cs:33), [PadelClub.Services/NotificationService.cs:26](C:/Users/User/Desktop/PadelClub/PadelClub.Services/NotificationService.cs:26), [PadelClub.Services/ReservationService.cs:280](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:280), [PadelClub.WebAPI/Controllers/CommerceOperationsController.cs:283](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/CommerceOperationsController.cs:283), [PadelClub.WebAPI/Controllers/DiscoveryController.cs:36](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/DiscoveryController.cs:36).

**F20 · P2 · Arhitektura — Osam kontrolera direktno zavisi od DbContext-a**

CommerceOperationsController, DiscoveryController, MembershipsController, NotificationSettingsController, OperationsController, PlayerExperienceController, PrivacyController i TournamentLifecycleController direktno koriste PadelClubContext. U kontrolerima su SQL upiti, transakcije, refund raspodjela, rejting i promjene stanja.

**Posljedica:** Krši se Controller -> Service -> DbContext. Poslovna pravila se razilaze između generičkih servisa, kontrolera i workera, što je vidljivo u konkretnim lifecycle propustima.

**Ispravka:** Kontrolere svesti na vezivanje zahtjeva, identitet/autorizaciju i HTTP odgovor. Poslovne transakcije i pravila premjestiti u Scoped aplikacijske servise s jasnim komandama.

**Dokaz:** Statički potvrđeno u osam kontrolera. Lokacije: [PadelClub.WebAPI/Controllers/CommerceOperationsController.cs:18](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/CommerceOperationsController.cs:18), [PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:16](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:16), [PadelClub.WebAPI/Controllers/PrivacyController.cs:12](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PrivacyController.cs:12), [PadelClub.WebAPI/Controllers/MembershipsController.cs:16](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/MembershipsController.cs:16).

**F21 · P2 · Arhitektura — Servisi koji koriste DbContext registrovani su kao Transient**

Program registruje ProductService, UserService, CourtService, ReservationService, OrderService, PaymentService, MembershipService, NotificationService i druge CRUD servise kroz AddTransient. Njihove baze/injektovani konstruktori koriste Scoped PadelClubContext.

**Posljedica:** Ovo izričito krši zahtjev predmeta da takvi servisi budu Scoped. Sam Transient u request scope-u nije automatski dokaz paralelnog korištenja DbContext-a niti opravdava tvrdnju o sigurnosnom proboju.

**Ispravka:** Promijeniti registracije DbContext-zavisnih servisa i stanja na Scoped; zadržati Singleton samo za prikladne thread-safe infrastrukturne objekte.

**Dokaz:** Formalno odstupanje i arhitektonska nedosljednost; nije dokaz runtime race-a. Lokacije: [PadelClub.WebAPI/Program.cs:80](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:80), [PadelClub.WebAPI/Program.cs:98](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:98), [PadelClub.Services/BaseCRUDService.cs:25](C:/Users/User/Desktop/PadelClub/PadelClub.Services/BaseCRUDService.cs:25).

**F22 · P2 · Arhitektura — Pet workera izvršava se unutar API procesa**

Program dodaje ProviderRefundOperationWorker, NotificationDeliveryWorker, MembershipLifecycleWorker, PrivacyDeletionWorker i OutboxPublisherWorker kao hosted servise API-ja. Compose ima zaseban subscriber, ali on obrađuje ProductUpdated i ne premješta ove poslove iz API-ja.

**Posljedica:** Refund, dostava, lifecycle, privatnost i outbox zavise od životnog ciklusa API-ja. To krši navedeno pravilo o odvojenom worker kontejneru; skaliranje API-ja također multiplicira poslove koji nemaju svi lease/dedup zaštitu.

**Ispravka:** Premjestiti hosted poslove u zaseban worker host/kontejner, s odgovarajućim lease-ovima i idempotentnim izvršavanjem. API treba samo trajno upisati namjeru.

**Dokaz:** Statički potvrđeno. Nije tvrđeno da zaseban subscriber nedostaje. Lokacije: [PadelClub.WebAPI/Program.cs:64](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:64), [PadelClub.WebAPI/Program.cs:71](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:71), [PadelClub.WebAPI/Program.cs:115](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:115), [docker-compose.yml:101](C:/Users/User/Desktop/PadelClub/docker-compose.yml:101).

**F23 · P2 · Pravila predmeta — RabbitMQ consumer ne demonstrira traženi AsyncEventingBasicConsumer i retry handlera**

Subscriber koristi EasyNetQ PubSub.SubscribeAsync i exponential backoff oko uspostavljanja pretplate. HandleAsync nema vlastiti retry/backoff za grešku obrade; u aplikacijskom kodu nije pronađen AsyncEventingBasicConsumer.

**Posljedica:** Prema doslovnom zadatku nije demonstrisana tražena implementacija. EasyNetQ apstrakcija sama po sebi nije dokaz da je potrošnja sinhrona ili da biblioteka nema recovery/error mehanizme; subscriber već ima zaseban kontejner i zajednički IBus.

**Ispravka:** Ako je AsyncEventingBasicConsumer obavezan, implementirati traženi consumer s retry/dead-letter politikom. Ako je EasyNetQ dozvoljen na predmetu, dokumentovati i testirati ekvivalentnu politiku za grešku handlera, ne samo povezivanje.

**Dokaz:** Formalna neusaglašenost s dostavljenim pravilom; internals biblioteke nisu auditirani. Lokacije: [PadelClub.WebAPI/PadelClub.Subscriber/ProductUpdatedSubscriber.cs:43](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/PadelClub.Subscriber/ProductUpdatedSubscriber.cs:43), [PadelClub.WebAPI/PadelClub.Subscriber/ProductUpdatedSubscriber.cs:106](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/PadelClub.Subscriber/ProductUpdatedSubscriber.cs:106), [PadelClub.WebAPI/PadelClub.Subscriber/Program.cs:18](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/PadelClub.Subscriber/Program.cs:18).

**F24 · P2 · Performanse — Ponavljani DB upiti unutar petlji**

CreateRecurringAsync za svaku sedmicu poziva ValidateReservationAsync, koji ponavlja court/user existence i overlap/maintenance upite, te svaki put SaveChangesAsync. MembershipLifecycleWorker prolazi istekle članarine i za svaku poziva NotificationService, koji ponovo učitava korisnika/preference.

**Posljedica:** Broj DB round-tripova raste s brojem sedmica ili članarina. Recurring je ograničen na MaxRecurringWeeks, pa nije neograničen DoS, ali i dalje krši izričitu zabranu N+1.

**Ispravka:** Jednom učitati korisnika/teren i sve relevantne intervale za seriju, grupisati konflikte i upisati stavke u batch-u unutar transakcije. Notifikacije pripremati batch operacijom.

**Dokaz:** Statički potvrđeno; SQL broj upita nije mjeren. Lokacije: [PadelClub.Services/ReservationService.cs:255](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:255), [PadelClub.Services/ReservationService.cs:229](C:/Users/User/Desktop/PadelClub/PadelClub.Services/ReservationService.cs:229), [PadelClub.WebAPI/Memberships/MembershipLifecycleWorker.cs:27](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Memberships/MembershipLifecycleWorker.cs:27), [PadelClub.Services/NotificationService.cs:75](C:/Users/User/Desktop/PadelClub/PadelClub.Services/NotificationService.cs:75).

**F25 · P2 · Preporuke — Online preporuke uče i iz seed/admin historije**

Online ProductRecommendationService uzima sve OrderItems gdje je Order.Status == Delivered i korisnik aktivan. Ne filtrira IsSeededForDemo ni Order.Origin u tom trening skupu. Program namjerno kreira korelirane demo narudžbe. Provjere porijekla niže u servisu odnose se na atribuciju, ne na rawPurchaseLines.

**Posljedica:** Demo i administrativno unesene isporuke utiču na preporuke prikazane kao kupovine drugih korisnika. Time online trening ne zadovoljava zahtjev stvarne historije, iako sistem odvojeno prati operativnu telemetriju i ima tekstualno objašnjenje preporuke.

**Ispravka:** Trening podatke ograničiti na stvarne customer checkout/verifikovane importe, isključiti demo naloge i seed narudžbe; demonstracioni model jasno odvojiti od operativnog.

**Dokaz:** Statički potvrđeno. Upis stvarnih checkout stavki i objašnjenja preporuka postoje. Lokacije: [PadelClub.Services/Recommendations/ProductRecommendationService.cs:77](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Recommendations/ProductRecommendationService.cs:77), [PadelClub.Services/Recommendations/ProductRecommendationService.cs:367](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Recommendations/ProductRecommendationService.cs:367), [PadelClub.WebAPI/Program.cs:872](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:872).

**F26 · P2 · Performanse — Svaki zahtjev preporuka materijalizira historiju svih korisnika**

GetForUserAsync prije rangiranja učitava sve aktivne proizvode, sve delivered purchase lines i sve odobrene/refundirane return lines. Dio ProductState filtriranja i agregacije rade se nakon ToListAsync; izlazni limit 12 primjenjuje se tek poslije tog rada.

**Posljedica:** Veličina izlaza skriva neograničen trošak ulaza. Kako historija raste, svaki korisnički zahtjev ponavlja alokaciju i izgradnju item-item vektora na API thread poolu.

**Ispravka:** SQL-om filtrirati i agregirati dozvoljeni vremenski prozor, unaprijed pripremati/cachirati model u workeru i ograničiti online učitavanje na potrebne kandidate i historiju ciljnog korisnika.

**Dokaz:** Statički potvrđeno; nije izvršen load test. Lokacije: [PadelClub.Services/Recommendations/ProductRecommendationService.cs:42](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Recommendations/ProductRecommendationService.cs:42), [PadelClub.Services/Recommendations/ProductRecommendationService.cs:77](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Recommendations/ProductRecommendationService.cs:77), [PadelClub.Services/Recommendations/ItemBasedCollaborativeRanker.cs:40](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Recommendations/ItemBasedCollaborativeRanker.cs:40).

**F27 · P2 · Poslovna logika — Audit je best-effort HTTP zapis, bez garantovanog traga poslovnog odobrenja**

AuditMiddleware snima UserId, HTTP metod, putanju i vrijeme poslije izvršene akcije, u zasebnom scope-u i s RequestAborted tokenom; grešku samo logira. Ne snima staro/novo stanje ni razlog. Reservation nema ConfirmedBy/CancelledBy, a match potvrda nema ConfirmedByUserId.

**Posljedica:** Commit poslovne promjene može uspjeti bez audita ako se klijent odspoji ili audit upis zakaže. PUT na generičku putanju sam ne otkriva da je izvršeno odobrenje, niti koje stanje je promijenjeno.

**Ispravka:** U istoj poslovnoj transakciji snimati nepromjenjiv lifecycle događaj: entitet, akcija, prethodno/novo stanje, actor, vrijeme i razlog. HTTP audit zadržati kao dodatni operativni trag.

**Dokaz:** Statički potvrđeno. Audit sistem postoji; nalaz se odnosi na njegovu dovoljnost i pouzdanost. Lokacije: [PadelClub.WebAPI/Auditing/AuditMiddleware.cs:20](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Auditing/AuditMiddleware.cs:20), [PadelClub.Services/Database/AuditLog.cs:3](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/AuditLog.cs:3), [PadelClub.Services/Database/Reservation.cs:17](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/Reservation.cs:17), [PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:159](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:159).

**F28 · P2 · Kvalitet koda — Blokirajući startup retry i sync-over-async u mrtvom helperu**

ApplyMigrationsWithRetry koristi sinhroni Migrate i Thread.Sleep(3000). RunCrudSmokeTestsIfNeeded sadrži 20 GetAwaiter().GetResult() poziva; pretragom nije nađen poziv tog helpera.

**Posljedica:** Thread.Sleep stvarno blokira startup pri nedostupnoj bazi. GetResult pozivi krše doslovno pravilo, ali su u trenutno nepozvanom kodu: nije opravdano predstavljati ih kao dokaz aktivnog request deadlock-a.

**Ispravka:** Startup učiniti async uz MigrateAsync i Task.Delay. Nepozvani CRUD smoke helper ukloniti iz aplikacije ili premjestiti u zasebne testove.

**Dokaz:** Statički potvrđeno uz razlikovanje aktivnog i mrtvog koda. Lokacije: [PadelClub.WebAPI/Program.cs:1001](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:1001), [PadelClub.WebAPI/Program.cs:1024](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:1024), [PadelClub.WebAPI/Program.cs:1189](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:1189).

**F29 · P3 · Kvalitet koda — Zakomentarisane CRUD implementacije i nedovršen hash interfejs**

ReservationsController sadrži blok zakomentarisanih Create/Update/Delete akcija. PasswordHasher.GenerateSalt implementiran je samo kao throw new NotImplementedException; stvarni put hashiranja već sam generiše salt.

**Posljedica:** Krši se zabrana mrtvog/zakomentarisanog koda. Nedovršen javni ugovor može izazvati runtime grešku ako bude upotrijebljen, ali takav aktivni poziv nije pronađen.

**Ispravka:** Ukloniti stare blokove i nepotreban GenerateSalt iz interfejsa/implementacije ili ga smisleno implementirati ako postoji stvarni potrošač.

**Dokaz:** Statički potvrđeno; nije nalaz nesigurnog hashiranja. Lokacije: [PadelClub.WebAPI/Controllers/ReservationsController.cs:93](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/ReservationsController.cs:93), [PadelClub.Services/PasswordHasher.cs:110](C:/Users/User/Desktop/PadelClub/PadelClub.Services/PasswordHasher.cs:110).

**F30 · P2 · Baza i UI — Grad igrača je slobodan string umjesto referentnog FK-a**

PlayerProfile.City je string; SaveProfile samo trimuje vrijednost i provjerava dužinu. Flutter profil koristi tekstualno polje za City. MembershipType je također slobodan string umjesto referentnog tipa.

**Posljedica:** Gradovi se mogu unositi u različitim zapisima i nema referentnog integriteta, što direktno krši dostavljeni primjer CityId umjesto City. Adresni tekst dostave može imati drugi poslovni smisao; glavni nalaz je strukturirani profil igrača.

**Ispravka:** Uvesti Cities i MembershipTypes referentne tabele/FK-e, migrirati postojeće vrijednosti i koristiti Dropdown s nazivima.

**Dokaz:** Statički potvrđeno. Lokacije: [PadelClub.Services/Database/PlayerProfile.cs:9](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/PlayerProfile.cs:9), [PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:45](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PlayerExperienceController.cs:45), [UI/padelclub_desktop/lib/features/player_experience/presentation/screens/player_hub_screen.dart:128](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/player_experience/presentation/screens/player_hub_screen.dart:128), [PadelClub.Services/Database/Membership.cs:9](C:/Users/User/Desktop/PadelClub/PadelClub.Services/Database/Membership.cs:9).

**F31 · P1 · Flutter Mobile — Stripe backend nema povezan mobilni tok plaćanja**

Mobile main.dart koristi PadelClubBootstrap iz desktop paketa. Zajednički pubspec nema Stripe SDK; u Flutter lib kodu nema poziva StripePayments/intent, PaymentSheet-a ni payment deep-link toka. CheckoutSheet poziva CartProvider.checkout, koji samo kreira Orders/checkout.

**Posljedica:** Postojanje API PaymentIntent endpointa i ekrana historije ne omogućava korisniku in-app naplatu rezervacije, članarine ili narudžbe. Trenutni launchUrl u checkoutu otvara Google Maps, ne plaćanje.

**Ispravka:** Povezati backend intent sa mobilnim SDK-om ili podržanim deep-link tokom; prikazati potvrdu iznosa i završni status čitati s backenda nakon webhook-a. Ne proglašavati uspjeh na osnovu klijentskog callback-a.

**Dokaz:** Statički potvrđena nedostajuća veza; uređaj i stvarno plaćanje nisu pokretani. Lokacije: [UI/padelclub_mobile/lib/main.dart:4](C:/Users/User/Desktop/PadelClub/UI/padelclub_mobile/lib/main.dart:4), [UI/padelclub_desktop/pubspec.yaml:32](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/pubspec.yaml:32), [UI/padelclub_desktop/lib/features/product/presentation/widgets/checkout_sheet.dart:77](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/product/presentation/widgets/checkout_sheet.dart:77), [UI/padelclub_desktop/lib/features/product/presentation/providers/cart_provider.dart:100](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/product/presentation/providers/cart_provider.dart:100).

**F32 · P2 · Flutter — Notifikacije zavise od početnog učitavanja i manuelnog refresh-a**

NotificationProvider.loadMine/loadAdminNotifications učitavaju na poziv. MobileHome poziva loadMine u inicijalnom refresh-u; admin ekrani imaju refresh dugmad. Pretraga zajedničkog lib-a nije pronašla SignalR ni polling za notifikacije; jedini Timer pripada auth refresh-u.

**Posljedica:** Nova notifikacija se ne pojavljuje sama na otvorenom ekranu. Backend worker za email/push nije zamjena za obavezni SignalR ili polling u Flutteru.

**Ispravka:** Uvesti lifecycle-aware polling ili SignalR pretplatu, ažuriranje liste/badge-a i prekid pretplate pri logout-u; testirati novu obavijest bez korisničkog refresh-a.

**Dokaz:** Statički potvrđeno u zajedničkom Flutter kodu. Lokacije: [UI/padelclub_desktop/lib/features/notifications/presentation/providers/notification_provider.dart:17](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/notifications/presentation/providers/notification_provider.dart:17), [UI/padelclub_desktop/lib/features/home/presentation/screens/mobile_home_screen.dart:31](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/home/presentation/screens/mobile_home_screen.dart:31), [UI/padelclub_desktop/lib/features/notifications/presentation/screens/notification_management_screen.dart:131](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/notifications/presentation/screens/notification_management_screen.dart:131).

**F33 · P2 · Flutter — UI prikazuje PK-e i zahtijeva ručni unos referentnog ID-a**

Maintenance dijalog traži Court ID kao numerički unos. Audit filter traži User ID. Liste rezervacija prikazuju CourtId, Reservation.Id i UserId; historija plaćanja i članarina također prikazuje interne ID-eve.

**Posljedica:** Korisnik mora znati interne ključeve i može pogrešno odabrati teren. Ovo izričito krši zabranu PK prikaza i zahtjev Dropdown-a za referentne podatke.

**Ispravka:** API projekcije trebaju vratiti imena terena/korisnika i poslovne oznake. Court/User selekcije prikazati pretraživim Dropdown-om, uz posebnu opciju svi tereni umjesto praznog ID-a.

**Dokaz:** Statički potvrđeno; ID u internom API DTO-u sam po sebi nije ovaj UI propust. Lokacije: [UI/padelclub_desktop/lib/features/reservations/presentation/screens/reservation_screens.dart:834](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/reservations/presentation/screens/reservation_screens.dart:834), [UI/padelclub_desktop/lib/features/reservations/presentation/screens/reservation_screens.dart:1678](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/reservations/presentation/screens/reservation_screens.dart:1678), [UI/padelclub_desktop/lib/features/operations/presentation/screens/audit_trail_screen.dart:123](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/operations/presentation/screens/audit_trail_screen.dart:123), [UI/padelclub_desktop/lib/features/payment_history/presentation/screens/payment_history_screen.dart:169](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/payment_history/presentation/screens/payment_history_screen.dart:169).

**F34 · P2 · Flutter — Nedostupne akcije ostaju aktivne ili bez razloga blokade**

Add user i activation/deactivation imaju aktivan onPressed koji prikazuje poruku da će povezivanje biti urađeno u kasnijoj fazi. No-show dugme se ispravno disable-a za budući termin, ali tooltip i dalje samo govori Mark player as no-show, bez objašnjenja zašto nije dostupno.

**Posljedica:** UI nudi akciju koja ne može biti izvršena i otkriva implementacijske bilješke korisniku; disabled akcija ne objašnjava preduslov. To krši zadani UX kriterij.

**Ispravka:** Implementirati funkciju ili postaviti onPressed=null s jasnim poslovnim razlogom. Za no-show prikazati da je dostupan tek nakon završetka termina, odnosno navesti razlog za otkazane/već označene stavke.

**Dokaz:** Statički potvrđeno. Lokacije: [UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:57](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:57), [UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:261](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:261), [UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:312](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/users/presentation/screens/user_management_screen.dart:312), [UI/padelclub_desktop/lib/features/reservations/presentation/screens/reservation_screens.dart:1715](C:/Users/User/Desktop/PadelClub/UI/padelclub_desktop/lib/features/reservations/presentation/screens/reservation_screens.dart:1715).

**F35 · P3 · Pravila predmeta — Anonimni endpoint-i postoje i izvan login/register**

Users refresh, forgot-password, reset-password i verify-email imaju AllowAnonymous; Stripe webhook također. /health/live i /health/ready nisu zaštićeni RequireAuthorization, a fallback policy nije postavljen.

**Posljedica:** Prema doslovnom dostavljenom pravilu ovo je odstupanje. To nije automatski ranjivost: auth recovery koristi opaque tokene i rate limiting, a webhook provjerava Stripe-Signature. Slijepo dodavanje korisničkog JWT-a webhooku prekinulo bi provider integraciju.

**Ispravka:** Odvojeno usaglasiti silabusni zahtjev za token-protected recovery, webhook i health iznimke ili koristiti dozvoljenu server-side verifikacionu arhitekturu. Zadržati validaciju Stripe potpisa; osjetljivi readiness endpoint ograničiti infrastrukturnom autorizacijom.

**Dokaz:** Formalna neusaglašenost; nije nalaz nezaštićenog Stripe potpisa. Lokacije: [PadelClub.WebAPI/Controllers/UsersController.cs:59](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/UsersController.cs:59), [PadelClub.WebAPI/Controllers/UsersController.cs:72](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/UsersController.cs:72), [PadelClub.WebAPI/Controllers/StripePaymentsController.cs:43](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/StripePaymentsController.cs:43), [PadelClub.WebAPI/Program.cs:277](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:277).

**F36 · P3 · Pravila predmeta — Admin zaštita koristi Administrator policy umjesto propisanog Roles=Admin**

Admin akcije koriste Authorize(Policy = AdminOnly), a Program definiše RequireRole(Administrator). Ne koriste doslovni Authorize(Roles = Admin) iz zadatka.

**Posljedica:** Razlikuju se naziv uloge i forma atributa. Policy je stvarna server-side role zaštita; ne postoji osnova da se samo zbog ovog zapisa tvrdi da player ima admin pristup.

**Ispravka:** Ako se doslovno provjerava Roles=Admin, uskladiti naziv uloge, seed, claimove, UI i atribute. Inače dokumentovati ekvivalentnost postojeće policy zaštite prema pravilima predmeta.

**Dokaz:** Isključivo formalno odstupanje prema dostavljenom ground truth-u. Lokacije: [PadelClub.WebAPI/Program.cs:140](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Program.cs:140), [PadelClub.WebAPI/Controllers/PaymentsController.cs:19](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/PaymentsController.cs:19).

**F37 · P3 · Pravila predmeta — DTO trenutnog korisnika prima UserId; nema zajedničkog current-user servisa**

ReservationInsertRequest javno izlaže UserId, Status i TotalPrice, a akcija ih prepisuje vrijednostima s backenda. Identitet se ponavlja kroz User.FindFirstValue i int.Parse/TryParse u kontrolerima; nije pronađen injektovani IHttpContextAccessor/current-user servis.

**Posljedica:** DTO ne poštuje doslovnu zabranu primanja UserId za self-service. U ovoj POST putanji UserId se ipak prepisuje iz JWT claim-a, pa to nije potvrđena impersonacija. Čitanje ClaimsPrincipal-a nije manuelno dekodiranje sirovog JWT-a.

**Ispravka:** Uvesti self-service DTO samo s dozvoljenim poljima i ICurrentUser servis zasnovan na IHttpContextAccessor. Admin komande za rad s drugim korisnicima ostaviti zasebne.

**Dokaz:** Formalna/strukturna neusaglašenost; razlikovati od stvarnog IDOR-a F03. Lokacije: [PadelClub.Model/Requests/ReservationInsertRequest.cs:1](C:/Users/User/Desktop/PadelClub/PadelClub.Model/Requests/ReservationInsertRequest.cs:1), [PadelClub.WebAPI/Controllers/ReservationsController.cs:35](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/ReservationsController.cs:35), [PadelClub.WebAPI/Controllers/ReservationsController.cs:84](C:/Users/User/Desktop/PadelClub/PadelClub.WebAPI/Controllers/ReservationsController.cs:84).

**Provjere bez potvrđenog kršenja**

- Lozinke se obrađuju PBKDF2-om; SHA256 unutar PBKDF2 ili hashiranja nasumičnog reset tokena nije plain SHA256 hash lozinke. Reset/refresh tokeni koriste RandomNumberGenerator.
- POST rezervacije i Orders/checkout uzimaju identitet s backenda i računaju cijenu iz baze. Njihove create transakcije koriste Serializable. To ne otklanja zasebne propuste na GET/UPDATE/DELETE i admin CRUD putanjama.
- Stripe webhook provjerava potpis. Plaćanja imaju unique idempotency ključ i one-to-one FK prema predmetu plaćanja: nije potvrđena tvrdnja da novi idempotency ključ sam omogućava drugu uplatu za isti predmet. Refund operacije imaju trajne zapise, saldo pending operacija i retry/lease mehanizam.
- RabbitMQ subscriber jeste zaseban Compose servis i koristi injektovani IBus. Nije pronađeno eksplicitno otvaranje nove konekcije za svaki publish. Interna implementacija EasyNetQ-a nije predstavljena kao pregledana.
- Globalni ExceptionFilter i custom UserException postoje. Nije utvrđen konkretan put vraćanja stack trace-a iz pregledanih MVC akcija. Filter ipak široko vraća ArgumentException/InvalidOperationException.Message; ne treba koristiti sistemske exceptione kao opći ugovor domenskih grešaka.
- Nije pronađen binary file-upload endpoint koji prima IFormFile ili raw upload. Proizvodi koriste ImageUrl; zato MIME/magic-byte provjera nije označena kao dokazan propust postojećeg uploada. Eventualni planirani upload zahtijeva zasebnu implementaciju i pregled.
- Nije pronađeno Base64 dekodiranje slika u Flutter build metodama. Produkt liste imaju Image.network thumbnail. Court model nema slikovno polje, pa nije prijavljen izmišljeni propust njegove slike. Na pregledanim ekranima postoje date pickeri i confirmation dijalozi za više destruktivnih akcija; nije tvrđeno da nedostaju globalno.
- Future.wait se već koristi u home/discovery/player/returns tokovima. Nije pronađena eksplicitna konstrukcija C# HttpClient-a izvan fabrike; Stripe/Firebase SDK klijenti nisu automatski isto kršenje.

**Redoslijed ispravki**

1. Ukloniti poznati admin bootstrap i ključeve; zatvoriti IDOR i cross-user povlačenje prijava.
2. Zaključati provider plaćanja, obraditi webhook redoslijed/unmatched događaje i objediniti kredit/refund saldo.
3. Ukloniti aktivni hard delete, objediniti state machine i sve izvore zauzetosti, povezati audit/notifikaciju s poslovnom transakcijom.
4. Uvesti obaveznu paginaciju; razdvojiti kontrolere, servise i worker host te izolovati trening podatke.
5. Dovršiti mobilno plaćanje, automatske notifikacije, Dropdown selekcije i objašnjenja nedostupnih akcija.

**Ponovno pokretanje izolovanih proba**

Iz korijena projekta pokrenuti `dotnet run --project audit/rs2-2026-09-08/probes/AuditProbes.csproj --no-restore`. Pri prvoj pripremi koristiti priloženi NuGet.Config bez mrežnih izvora i lokalno keširane pakete. Polje `reproduced: true` označava potvrđeno postojeće loše ponašanje, a ne prolaz sigurnosnog testa. Proba ne dokazuje ponašanje EF relacijskih FK-ova, zaključavanja ni middleware-a. Za ispravke treba dodati odvojene regresijske testove koji zahtijevaju siguran ishod.

