/// Italian copy for the match write-up. See `lib/i18n/locale_copy.dart`.
///
/// Voice and conventions taken from `locales/it.g.dart`'s own `report.*` block:
/// the club takes an article and a singular verb — "Il {club} si è messo a
/// difendere" — and the minute is written "al {minute}'", which is why the
/// apostrophe is in the copy rather than in the value.
library;

/// Replaces the generated entry, or adds a key Italian did not have.
const Map<String, String> itCopy = <String, String>{
  'customise.item.face.bubblegum': 'Gomma',

  // Una terza riga accanto a Suono e Musica: il clic di ogni pulsante.
  'settings.ui_sounds': 'Interfaccia',

  // La scheda non è più solo audio: si aggiunge la vibrazione.
  'settings.tab.controls': 'Comandi',
  'settings.haptics': 'Vibrazione',
  'settings.haptics.hint': 'Una breve vibrazione a ogni tocco. Anche le '
      'impostazioni di vibrazione del telefono possono disattivarla.',
  'settings.tap_ripple': 'Onde al tocco',

  // ── Il titolo ────────────────────────────────────────────────────────────
  //
  // Sostituiti, non allargati: i testi generati aprono tutti con {score}.
  // `{minute}` arriva solo ai tre testi `.late`.
  'report.win.rout':
      'È finita, ed è stata una lezione: il {club} ne ha messi {ours} al {opp} '
          'senza scomporsi.|'
      'Fischio finale su una goleada. {ours} per il {club}, {theirs} per il '
          '{opp}, e il punteggio non fa sconti a nessuno tranne a chi ha '
          'vinto.|'
      'Finale, e il {club} ha smontato il {opp}: {ours} gol, e potevano essere '
          'di più.',
  'report.win.comfortable':
      'È arrivato il fischio e il {club} l\'ha vinta al piccolo trotto, tre gol '
          'sopra il {opp}.|'
      'È finita. Tre gol alla fine, e il {club} non ha mai rischiato di '
          'restituirli.|'
      'Finale. Il {club} vince di tre e fa il lavoro senza mai doverlo '
          'forzare.',
  'report.win.clear':
      'È arrivato il fischio e il {club} la vince di due. Il {opp} ha avuto i '
          'suoi momenti senza mai dare l\'idea di pareggiarla.|'
      'È finita, due gol di scarto, e il {club} ha gestito il pomeriggio dal '
          'momento in cui è entrato il secondo.|'
      'Finale, e una vittoria di due gol del {club} comoda quanto sembra.',
  'report.win.narrow':
      'È arrivato il fischio e c\'è stato un gol di scarto — ed era del '
          '{club}.|'
      'È finita. Un solo gol li separa alla fine, e i punti sono del {club}.|'
      'Finale, e il {club} l\'ha spuntata. Un gol, e poteva finire da '
          'entrambe le parti.',
  'report.win.late':
      'È arrivato il fischio e il {club} l\'ha vinta tardi: il gol che ha '
          'deciso è arrivato al {minute}\'.|'
      'È finita, e che finale: pari fino al {minute}\', e poi il {club} ha '
          'trovato quello a cui il {opp} non ha più avuto tempo di '
          'rispondere.|'
      'Finale. Il pari sembrava il risultato più probabile fino al {minute}\', '
          'quando il {club} l\'ha vinta.',
  'report.win.thriller':
      'È finita, e che partita: {total} gol tra le due, e se la prende il '
          '{club}.|'
      'Fischio finale su una partita da {total} gol, e il {club} ne esce con i '
          'punti.|'
      'Finale, e si respira. {total} gol, ed è caduta dalla parte del {club} '
          'per quello di scarto.',
  'report.draw.goalless':
      'È arrivato il fischio e non c\'è niente a dividerle: nessun gol, e '
          'nemmeno molte occasioni.|'
      'È finita, senza gol. I due portieri hanno passato un pomeriggio '
          'tranquillo.|'
      'Finale, e onori pari con il tabellone a zero.',
  'report.draw.shared':
      'È arrivato il fischio su un pari: {ours} a testa, e né il {club} né il '
          '{opp} hanno trovato quello che la decideva.|'
      'È finita, e si dividono i punti. {ours} ciascuna, in una partita che un '
          'vincitore da qualche parte ce l\'aveva.|'
      'Finale, e pari. Nessuno dei due spogliatoi ne sarà del tutto contento.',
  'report.draw.late':
      'È arrivato il fischio su un pari, e il gol del pareggio non è arrivato '
          'prima del {minute}\': un punto guadagnato per una e due persi per '
          'l\'altra.|'
      'È finita, pari, e c\'è voluto fino al {minute}\' per arrivarci.|'
      'Finale, con il gol del pareggio caduto al {minute}\'.',
  'report.draw.thriller':
      'È finita, e che partita: {total} gol e niente a dividerle.|'
      'Fischio finale su una partita da {total} gol che nessuna delle due è '
          'riuscita a vincere.|'
      'Finale, e un punto a testa dopo {total} gol tra le due.',
  'report.loss.narrow':
      'È arrivato il fischio e c\'è stato un gol di scarto — ed era del '
          '{opp}.|'
      'È finita. Il {opp} se la prende di un gol, e al {club} restano le '
          'domande.|'
      'Finale, e il {club} perde di misura. Dettagli, e sono caduti dalla parte '
          'del {opp}.',
  'report.loss.late':
      'È arrivato il fischio e il {club} l\'ha persa tardi: il gol del {opp} è '
          'arrivato al {minute}\'.|'
      'È finita, e un finale crudele: pari fino al {minute}\', e poi il {opp} '
          'ha segnato quello che contava.|'
      'Finale. Al {club} era bastato per il punto fino al {minute}\', e non un '
          'minuto di più.',
  'report.loss.thriller':
      'È finita, e che partita: {total} gol tra le due, ma se la prende il '
          '{opp}.|'
      'Fischio finale su una partita da {total} gol, e il {club} ne esce senza '
          'niente.|'
      'Finale, e si respira. {total} gol, ed è caduta dalla parte del {opp} per '
          'quello di scarto.',
  'report.loss.clear':
      'È arrivato il fischio e il {opp} la vince di due. Il {club} è stato '
          'secondo in entrambe le aree.|'
      'È finita, due gol di scarto, e il {club} non è mai rientrato davvero in '
          'partita dopo il secondo.|'
      'Finale, e una sconfitta di due gol del {club} contro un {opp} più '
          'affilato dove contava.',
  'report.loss.comfortable':
      'È arrivato il fischio e il {club} le ha prese: tre gol per il {opp} alla '
          'fine.|'
      'È finita. Tre di scarto, e il {club} conteneva e basta molto prima del '
          'fischio.|'
      'Finale, e un pomeriggio da dimenticare per il {club}, battuto di tre.',
  'report.loss.rout':
      'È finita, ed è stata una lezione: il {opp} ne ha messi {theirs} al '
          '{club}.|'
      'Fischio finale su una goleada. {theirs} per il {opp}, {ours} per il '
          '{club}, e nessuno ha niente da recriminare.|'
      'Finale, e il {club} è stato smontato: {theirs} subiti, e potevano '
          'essere di più.',

  // ── Come ha giocato l'avversario ─────────────────────────────────────────
  'report.opp.comeback':
      'Il {opp} sembrava battuto e non ha mai giocato come tale, e alla fine '
          'era la squadra su cui avresti puntato.|'
      'Merito al {opp}: è stato secondo per un tratto e ha ribaltato il '
          'pomeriggio.|'
      'Dice qualcosa del {opp} che andare sotto sembri tranquillizzarlo.',
  'report.opp.rampant':
      'Il {opp} è stato enorme, rapido in tutto e spietato su ogni errore che '
          'è capitato.|'
      'Questo era il {opp} nella sua versione migliore, e chi c\'era per loro '
          'ne parlerà tutta la settimana.|'
      'Al {opp} è riuscito tutto. Non sono molte le squadre che gli avrebbero '
          'tenuto testa oggi.',
  'report.opp.shut_us_out':
      'Il {opp} è stato bravo senza palla quanto con la palla, e il {club} non '
          'ha mai trovato il modo di passare.|'
      'Porta inviolata e punti per il {opp}, che ha difeso la propria area come '
          'si deve dal primo all\'ultimo minuto.|'
      'Il {opp} non ha dato niente al {club} su cui lavorare, e questo spiega '
          'la vittoria quanto quello che ha fatto davanti.',
  'report.opp.clinical':
      'Non c\'era molto tra le due; il {opp} è stato semplicemente più preciso '
          'quando sono arrivate le occasioni.|'
      'Il {opp} ha preso i suoi momenti e il {club} no, che di solito è tutto.|'
      'Al {opp} non serviva essere la squadra migliore per vincerla, e comunque '
          'non ci andava lontano.',
  'report.opp.fought_back':
      'Il {opp} era sotto e non ha smesso di venire, e in pochi allo stadio '
          'direbbero il punto immeritato.|'
      'Ci è voluto carattere dal {opp} per rientrare in questa partita.|'
      'Il {opp} si è rifiutato di accettarla e si è guadagnato la sua parte di '
          'pomeriggio nel modo difficile.',
  'report.opp.stalemate':
      'Il {opp} è stato ordinato quanto il {club}, e nessuna delle due ha '
          'trovato il varco.|'
      'Poco da scegliere tra le due — il {opp} era difficile da aprire quanto '
          'il {club}.|'
      'Il {opp} è venuto per un punto e ha difeso come una squadra che ci '
          'teneva davvero.',
  'report.opp.matched':
      'Il {opp} ha tenuto testa al {club} per lunghi tratti e sul risultato la '
          'penserà più o meno allo stesso modo.|'
      'Partita onesta ed equilibrata del {opp}, mai sotto e mai davvero '
          'davanti.|'
      'C\'era poco tra le due, e il {opp} non avrà la sensazione di aver perso '
          'qualcosa qui.',
  'report.opp.outclassed':
      'È stato un pomeriggio lungo per il {opp}, secondo su quasi tutto e mai '
          'in grado di prendere in mano la partita.|'
      'Il {opp} vorrà dimenticarla in fretta. Gli è andato bene pochissimo.|'
      'Al {opp} non ha funzionato granché, e la distanza tra le due squadre era '
          'evidente ben prima della fine.',
  'report.opp.pushed':
      'Il {opp} ha fatto lavorare il {club} e non era lontano nemmeno lui.|'
      'Il {opp} avrà la sensazione di aver avuto abbastanza di questa partita '
          'da portarsi via qualcosa.|'
      'C\'era qui più per il {opp} di quanto gli dia il risultato.',

  // ── I gol, come tema e non come cronologia ───────────────────────────────
  'report.goals.opened':
      '{player} ha messo in moto il {club}.|'
      'È stato {player} a cominciarla per il {club}.|'
      '{player} ha sbloccato il risultato, e il {club} ci ha costruito sopra il '
          'pomeriggio.',
  'report.goals.surge.ours':
      'Il secondo tempo è stato a senso unico. Il {club} ha segnato a piacere '
          'dopo l\'intervallo e il {opp} non aveva risposta per niente di '
          'tutto ciò.|'
      'Il {club} è uscito dagli spogliatoi un\'altra squadra, e i gol hanno '
          'continuato ad arrivare finché il {opp} ha smesso di contarli.|'
      'Qualunque cosa sia stata detta all\'intervallo ha funzionato: dopo, il '
          '{club} ha portato la partita lontano dal {opp}.',
  'report.goals.surge.theirs':
      'Il {opp} ha fatto a pezzi il secondo tempo. All\'intervallo il {club} '
          'era ancora in partita e alla fine non ci era neanche vicino.|'
      'L\'intervallo ha cambiato tutto in peggio: il {opp} ha segnato ancora e '
          'ancora dopo di esso e il {club} non è riuscito a fermare niente.|'
      'Il {club} è uscito dagli spogliatoi ed è stato travolto. Il {opp} non ha '
          'concesso tregua dopo l\'intervallo.',

  // ── Il bilancio della partita, senza una sola cifra ──────────────────────
  //
  // I primi due non possono rivendicare il possesso: scattano anche su un solo
  // asse, e il {club} può aver avuto la palla ed essere comunque stato secondo.
  'report.stats.on_top':
      'Il {club} ha avuto il meglio della partita ed è sembrato il più '
          'pericoloso quasi per tutto.|'
      'Era una partita da controllare per il {club}, e l\'ha controllata. Il '
          '{opp} ne ha passata buona parte a inseguire.|'
      'Il {club} ha comandato la maggior parte dei novanta e il {opp} ha '
          'raramente dato l\'idea di poterlo cambiare.',
  'report.stats.pinned_back':
      'Il {club} ne ha passata buona parte a difendere, e il {opp} era quello '
          'che sembrava poter segnare.|'
      'Il {opp} ha avuto il meglio della partita fin da presto e il {club} è '
          'uscito da sotto ben poche volte.|'
      'C\'era una squadra sopra qui e non era il {club}. Il {opp} gli ha '
          'portato la partita addosso.',
  'report.stats.ball_only':
      'Il {club} ha avuto palla in abbondanza e ben poco da mostrare. Il {opp} '
          'ha difeso la propria area e ne era contento.|'
      'Tutto il possesso del mondo per il {club}, e le occasioni che ne sono '
          'venute non valevano granché.|'
      'Il {club} ha tenuto la palla e il {opp} l\'ha tenuto lontano da dove '
          'faceva male.',
  'report.stats.counter':
      'Il {opp} ha avuto la palla e il {club} i momenti, che è tanto un modo di '
          'giocare quanto un caso.|'
      'Il {club} ha lasciato fare al {opp} e ha ricavato molto di più da quello '
          'che gli è capitato.|'
      'Il possesso è andato da una parte e le occasioni vere dall\'altra. Al '
          '{club} non dispiacerà per niente.',
  'report.stats.even':
      'C\'era pochissimo tra le due, con la palla e senza.|'
      'Il {club} e il {opp} si sono equivalsi quanto il pomeriggio lascia '
          'pensare.|'
      'Né il {club} né il {opp} hanno avuto abbastanza partita abbastanza a '
          'lungo da poterla chiamare loro.',

  // ── Il finale, dall'altra panchina ───────────────────────────────────────
  //
  // `{chaser}` è chi è arrivato al finale sotto e `{holder}` chi era avanti,
  // così la frase regge da entrambe le parti.
  'report.late.held_out':
      'Il {chaser} ha buttato tutto avanti nell\'ultimo tratto e non ha trovato '
          'il modo di passare.|'
      'Il finale è stato tutto del {chaser}, e il {holder} ha retto.|'
      'Il {chaser} ha insistito e insistito cercando il gol, e non è mai '
          'arrivato.',
  'report.late.consolation':
      'Il {chaser} ha spinto tutti avanti nel finale e ne ha cavato un gol, e '
          'poco altro.|'
      'Il gol tardivo ha dato al {chaser} qualcosa da mostrare per la pressione '
          'e non è mai sembrato poter bastare.|'
      'Il {chaser} ne ha trovato uno al termine di un lungo assedio, e a quel '
          'punto il {holder} aveva già fatto la parte difficile.',

  // ── La panchina ──────────────────────────────────────────────────────────
  'report.subs.impact':
      '{player} è entrato dalla panchina e ha fatto la differenza per il '
          '{club}.|'
      'Il cambio del {club} ha funzionato: {player} è entrato e ha segnato.|'
      'La panchina si è ripagata da sola: {player} è entrato ed è andato a '
          'segno per il {club}.',
  'report.subs.changes':
      'Il {club} ha consumato i cambi cercando qualcosa.|'
      'Il {club} ha svuotato la panchina per provare a entrare in partita.|'
      'I cambi si sono susseguiti nel {club}, senza che nessuno girasse '
          'davvero qualcosa.',

  // ── L'arbitro ────────────────────────────────────────────────────────────
  //
  // Senza minuto: quello che conta è che hanno finito in inferiorità.
  'report.cards.our_red_named':
      '{player} è stato espulso, e il {club} ha finito con meno uomini di '
          'quanti ne avesse iniziati.|'
      'Il rosso a {player} ha lasciato il {club} in inferiorità per il resto '
          'della partita.',
  'report.cards.our_booked_many':
      '{n} giocatori del {club} sono stati ammoniti: {names}.|'
      'L\'arbitro ha ammonito {names} nel {club}, {n} cartellini in tutto.',
  'report.cards.their_reds':
      'Il {opp} ha avuto {n} espulsi e ha chiuso la partita ben lontano da una '
          'squadra intera.|'
      '{n} rossi per il {opp}, che hanno condizionato tutto quello che è venuto '
          'dopo.',

  // ── I cambi di piano ─────────────────────────────────────────────────────
  //
  // Senza minuto e senza il nome del modulo: una decisione, non
  // un'impostazione. `{minute}` e `{tactic}` continuano ad arrivare e qui non
  // si usano.
  'report.tactic.shut_up_shop':
      'Il {club} si è abbassato per il finale e si è messo a proteggere quello '
          'che aveva.|'
      'Sul finire il {club} ha chiuso bottega, ha invitato il {opp} ad '
          'attaccare e si è fidato di sé per portarla a casa.|'
      'Il {club} ha portato tutti dietro la palla per quello che restava e ha '
          'chiuso così il pomeriggio.',
  'report.tactic.went_for_it':
      'Il {club} ha buttato gente avanti per il finale e ha accettato il '
          'rischio che ne veniva.|'
      'Sul finire il {club} ci ha provato, salendo sul {opp} invece di '
          'accontentarsi di quello che aveva.|'
      'Il {club} si è giocato quello che restava e ha mandato uomini avanti.',
  'report.tactic.settled':
      'Il {club} ha cambiato assetto per il finale e ha chiuso la partita '
          'così.|'
      'Una riorganizzazione del {club} sul finire ha deciso come è finito il '
          'pomeriggio.|'
      'Il {club} si è risistemato per quello che restava e ha portato a casa la '
          'partita in quel modo.',
  // ── La classifica, e l'accordo con il numero ─────────────────────────────
  //
  // "1 posizioni" e "1 punti", la stessa falla segnalata in inglese. In
  // italiano non basta una `s` finale: posto/posti e punto/punti cambiano la
  // desinenza. Quindi niente sostantivo contato accanto al numero — "sale di
  // {n} in classifica" regge per qualsiasi cifra, e "a quota {pts}" pure.
  'report.table.climbed':
      'Fa salire il {club} di {n} in classifica: {pos}, a quota {pts}.|'
      'Su di {n}, {pos}, a quota {pts}.|'
      'Ora {pos} il {club}, {n} meglio di prima, a quota {pts}.',
  'report.table.dropped':
      'Costa al {club} {n} in classifica — {pos}, a quota {pts}.|'
      'Giù di {n}, {pos}, a quota {pts}.|'
      '{pos} e in calo, {n} peggio di prima, a quota {pts}.',
  'report.table.held':
      'Sempre {pos}, ora a quota {pts}.|'
      '{pos}, invariato, a quota {pts}.|'
      'Nessun movimento — {pos}, a quota {pts}.',

  // The settings screen's small print — see `en_copy.dart`.
  'settings.cutaways.hint':
      'Quando capita un\'occasione a una squadra che hai attivato, la partita '
          'stacca sul campo e gioca il momento — e poi puoi rivederlo.',
  'settings.matchSpeed.auto': 'Auto',
  'settings.matchSpeed.hint':
      'Auto va a 2x e scende a metà velocità ogni volta che il mister ha '
          'qualcosa da dire, così hai il tempo di leggerlo e intervenire.',

  // The training list's ceiling — see `en_copy.dart`.
  'training.up_to': 'Fino a',

  // L'allenamento a riposo e il conto alla rovescia — vedi `en_copy.dart`.
  'training.resting': 'Cooldown {time}',
  'mg.countdown_go': 'VIA!',

  // Negozio: il ripiano non è più gratis, e le entrate escono dai bonus —
  // vedi `en_copy.dart`.
  'shop.lucky_boot_name': 'Scarpa fortunata',
  'shop.lucky_boot_desc': 'Prossimo avversario {pct}% più debole (una partita)',
  'shop.section.income': 'Entrate',
  'product.energy_director.desc': '+50 energia subito · Cap a 15 · ricarica {energyPct}% più rapida — per sempre, anche dopo i reset!',

  'shop.section.looks': 'Stile allenatore',

  // Colin relays an offer and calls it; then his tour after the tutorial.
  'coach.bid.relay': 'Ha chiamato il {club}, mister. Vogliono {player} e mettono {price} sul tavolo.',
  'coach.sponsor.relay': 'Si è fatta sentire {company}, mister. Vogliono {player} come volto del marchio: {n}% di entrate in più da quel giocatore finché dura l\'accordo.',
  'coach.verdict.accept': 'Il mio consiglio: accetta',
  'coach.verdict.decline': 'Il mio consiglio: rifiuta',
  'coach.verdict.your_call': 'Il mio consiglio: può andare in entrambi i modi',
  'manager.transfer.starter_short': '{player} è titolare ogni settimana e in panchina non c\'è nessuno a sostituirlo. Rifiuta, a meno che tu non ingaggi subito un rimpiazzo.',
  'manager.transfer.relegation': 'Siamo in zona retrocessione e {player} è nell\'undici. Vendere adesso ci indebolisce proprio quando non possiamo permettercelo.',
  'manager.transfer.flying': 'Siamo in testa e le casse sono piene. Non ci servono questi soldi: tieni unita la rosa.',
  'manager.transfer.need_money': 'Sinceramente, siamo al verde. Questa cifra paga un acquisto intero, e ci servono le monete più di {player}.',
  'manager.transfer.bench_warmer': '{player} non è nemmeno nel tuo undici, e il prezzo è giusto. Prendi i soldi e rinforza dove conta.',
  'manager.sponsor.clean': 'Questo non ha fregature. Firma: sono soldi gratis.',
  'manager.sponsor.relegation_starter': '{player} è nell\'undici e siamo in zona retrocessione. Un titolare più debole è l\'ultima cosa che ci serve: rifiuta.',
  'manager.sponsor.injury_prone': '{player} ha già {seasons} stagioni nelle gambe e questo accordo aumenta il rischio infortuni. Non ne vale la pena.',
  'manager.sponsor.poor_form': 'La forma di {player} è già scarsa e questo accordo la peggiora. Di\' di no.',
  'manager.sponsor.need_money': 'Siamo a corto di monete e questo paga ogni secondo. La fregatura vale la pena: firma.',
  'manager.sponsor.bench': '{player} non è nel tuo undici, quindi la fregatura non ci costa nulla in campo. Firma.',
  'manager.sponsor.rating_cost': 'Costa {n} di valutazione a {player}, ed è un titolare. Più entrate in cambio di una squadra più debole: decidi tu.',
  'manager.sponsor.fair': 'La fregatura è piccola e le entrate no. Io firmerei.',
  'guide.scout': 'Tocca Osserva per ingaggiare qualcuno di nuovo. Due dello stesso tipo trascinati insieme si fondono in un giocatore migliore.',
  'guide.squad_tab': 'Bene. Ora apri la scheda {tab} e metti in campo i tuoi migliori undici.',
  'guide.squad_fill': 'Tocca uno slot vuoto per scegliere chi gioca lì, oppure premi Auto e ti schiero io la squadra.',
  'guide.dugout': 'Vedi il Menu, in basso a destra? È il Dugout: allenamenti e classifica sono lì dentro.',
  'guide.club_tab': 'Anche lo stadio rende. Dai un\'occhiata alla scheda {tab}.',
  'guide.club_buy': 'Compra una struttura qui. Ognuna che possiedi si aggiunge a quanto il club guadagna ogni secondo.',
  'guide.shop_tab': 'A corto di energia o monete? La scheda {tab} ha pacchetti e bonus quando ti servono.',


  // ── Where it was won: the positional card and its write-up ─────────────
  'match.analysis.title':
      'Dove si è decisa',
  'match.analysis.hint':
      'Dove ogni squadra ha avuto il pallone, attaccando verso l\'alto. Le fasce sono quelle di ciascuna squadra.',
  'match.analysis.flanks':
      'Attacchi per fascia',
  'match.analysis.left':
      'Sinistra',
  'match.analysis.centre':
      'Centro',
  'match.analysis.right':
      'Destra',
  'match.analysis.shots':
      '{shots} tiri, {xg} xG',
  'match.analysis.duel_record':
      '{name} ha vinto {won} duelli su {total}.',
  'report.zone.down_right':
      '{club} ha attaccato a destra per tutto il pomeriggio, e quasi tutto il pericolo è nato lì.|Quasi tutto ciò che {club} ha costruito è passato dalla fascia destra.',
  'report.zone.down_left':
      '{club} ha attaccato a sinistra per tutto il pomeriggio, e quasi tutto il pericolo è nato lì.|Quasi tutto ciò che {club} ha costruito è passato dalla fascia sinistra.',
  'report.zone.through_middle':
      '{club} è passato dritto per il centro, senza quasi bisogno delle fasce.|Tutto per vie centrali per {club}, in linea retta verso la porta.',
  'report.zone.their_right':
      '{opp} ha insistito sulla propria destra, ed è da lì che è arrivato quasi tutto il pericolo.|Quasi tutto ciò che {opp} ha creato è passato dalla fascia destra.',
  'report.zone.their_left':
      '{opp} ha insistito sulla propria sinistra, ed è da lì che è arrivato quasi tutto il pericolo.|Quasi tutto ciò che {opp} ha creato è passato dalla fascia sinistra.',
  'report.zone.their_middle':
      '{opp} è venuto dritto per il centro contro {club}, quasi senza usare le fasce.|Tutto per vie centrali per {opp}.',
  'report.duel.dominant':
      '{name} ha vinto quasi tutto quello che gli è capitato davanti.|Nessuno di {opp} ha avuto la meglio su {name} per tutto il pomeriggio.',
  'report.duel.busy':
      '{name} è stato nel vivo del gioco dal primo all\'ultimo fischio.|Gran parte della partita è passata da {name}, nel bene e nel male.',
  'report.duel.struggled':
      '{name} ha avuto un pomeriggio difficile, battuto nella maggior parte dei duelli.|Non è andata a {name}, che ha perso più duelli di quanti ne abbia vinti.',

  // ── Strings the spec's own catalogues never translated ─────────────────
  //
  // Identical to English in all ten shipped locales — a gap in
  // `../merge-empire-fc`'s own catalogue, same shape as `champ.*` below.
  'match.subs': 'Cambi',
  'match.subs.bench': 'Panchina',
  'match.subs.empty_slot': 'Vuoto',
  'match.subs.done': 'Torna alla partita',
  'match.subs.on_pitch': 'In campo',
  'match.subs.empty_bench': 'Nessun giocatore in panchina.',
  'match.subs.pick_off': 'Tocca un giocatore da sostituire.',
  'match.subs.pick_on': 'Tocca una riserva da far entrare (verde = posizione migliore).',
  'match.subs.none_left': 'Cambi finiti.',
  'match.subs.feed': '{off} esce, {on} entra.',
  'match.subs.feed_on': '{on} entra.',
  'tut.loan_boost.title': '⭐ Arrivano stelle in prestito!',
  'tut.loan_boost.body': 'Ho chiesto qualche favore… dei <strong>top player</strong> hanno accettato di unirsi a noi per la tua prima partita! Se ne vanno subito dopo — ma sfruttiamolo al massimo!',
  'tut.loan_boost.btn': 'Vedi la mia rosa →',
  'tut.loan_depart.title': 'Ora costruiamo la nostra squadra',
  'tut.loan_depart.body': 'Le stelle in prestito se ne sono andate — ma hanno dimostrato che possiamo competere. Ora costruiamo qualcosa che è <strong>nostro</strong>. Ecco <strong>500 monete</strong> per iniziare. Sarò in basso a sinistra ogni volta che avrò un consiglio.',
  'tut.loan_depart.btn': 'Costruiamo! →',
  'difficulty.switch.confirm': 'Si parte',
  'difficulty.switch.toHard': 'Modalità Pro: ogni giocatore si stanca durante una partita — gestisci l\'energia della tua rosa e fai ruotare la panchina per tenere le gambe fresche. Posso aiutarti a scegliere il tuo undici più fresco, ma resterò in silenzio sulla tattica. Cambiare ti farà ricominciare da capo.',
  'difficulty.switch.toEasy': 'Modalità Casual: nessuna stanchezza dei giocatori, la panchina serve solo per cambi tattici e infortuni. Tornano la selezione automatica e i consigli del mister. Cambiare ti farà ricominciare da capo.',
  'coachtip.subs_bench.title': 'Hai una panchina',
  'coachtip.subs_bench.body': 'Tocca Cambi durante una partita per aprire la tua panchina — hai 5 cambi a partita, e il cronometro si ferma mentre scegli. Anche gli infortuni passano di lì ora: quando qualcuno si fa male, la sua maglia esce dal campo e il posto resta vuoto finché non fai entrare un sostituto, quindi non lasciarlo così.',
  'coachtip.try_hard_mode.title': 'Voglia di una sfida?',
  'coachtip.try_hard_mode.body': 'Hai fatto molta strada, capo. Pronto per la modalità Pro? I giocatori si stancano durante le partite, quindi ruotare la rosa e sfruttare la panchina conta davvero — tocca Auto e io scelgo il tuo undici legale più fresco — e resterò in silenzio sulla tattica. Fa partire una squadra nuova — solo se te la senti.',
  'coachtip.try_hard_mode.cta': 'Apri Impostazioni',
  'coach.match.tired': '{name} è esausto — fai entrare un giocatore fresco!',
  'coach.tactic_tip.open_dominant': 'Entrambe le squadre segneranno ma siamo chiaramente più forti. {tactic} — punta alla vittoria.',
  'coach.tactic_tip.open_favoured': 'Entrambe le squadre creeranno occasioni e dovremmo spuntarla. {tactic} per controllare la partita.',
  'coach.tactic_tip.open_even': 'Entrambe le squadre creeranno occasioni. {tactic} — colpisci {opp} in ripartenza.',
  'coach.tactic_tip.open_underdog': '{opp} è più forte ma sarà una partita aperta. {tactic} — sfrutta le occasioni quando arrivano.',
  'coach.tactic_tip.exploit_their_def': 'La difesa di {opp} è scoperta. {tactic} — punta alla vittoria.',
  'coach.tactic_tip.counter_their_atk': '{opp} è pericoloso in avanti. {tactic} — assorbi e riparti in contropiede.',
  'coach.tactic_tip.park_underdog': '{opp} è una minaccia reale e faremo fatica a segnare. {tactic} — limita i danni.',
  'coach.tactic_tip.tight_favoured': 'Una partita equilibrata ma siamo in vantaggio. {tactic} — costruisci l\'occasione.',
  'coach.tactic_tip.tight_underdog': 'Difficile segnare per entrambe le squadre. {tactic} — resta disciplinato.',
  'ach.cat.hardmode': 'Modalità Pro',
  'toast.energy_refilled': 'Energia della rosa ricaricata!',
  'toast.no_fit_players': 'Non ci sono abbastanza giocatori in forma — falli riposare o guarda un annuncio per ricaricare.',
  'trait.name.iron_lungs': 'Polmoni di ferro',
  'trait.desc.iron_lungs': 'Motore instancabile — l\'energia scende più lentamente durante le partite (modalità Pro)',
  'champ.title': 'CAMPIONI!',
  'champ.subtitle': 'Champions League conquistata',
  'champ.body': 'Hai conquistato ogni divisione e ti sei elevato sopra ogni rivale. Sei da solo in cima, il più grande allenatore del mondo.',
  'champ.prestige_teaser': 'Ricomincia e risali dalla Lega Domenicale con un <strong>bonus di reddito ×{mult}</strong> permanente. I risultati della tua carriera restano tuoi per sempre.',
  'champ.new_adventure': '🌟 Inizia una nuova avventura',
  'champ.defend': '⚽ Difendi il titolo',

  // ── The side dial on the squad tab ────────────────────────────────────
  'squad.side.label': 'Attaccare da',
  'squad.side.balanced': 'Equilibrato',
  'squad.side.balanced.hint': 'Gli attacchi partono dove li mette il modulo.',
  'squad.side.left': 'Sinistra',
  'squad.side.left.hint': 'La maggior parte degli attacchi parte dalla fascia sinistra.',
  'squad.side.centre': 'Centro',
  'squad.side.centre.hint': 'La maggior parte degli attacchi parte per vie centrali.',
  'squad.side.right': 'Destra',
  'squad.side.right.hint': 'La maggior parte degli attacchi parte dalla fascia destra.',

  // ── Roles on the wide slots ───────────────────────────────────────────
  'role.label': 'Ruolo',
  'role.natural': 'Naturale',
  'role.natural.hint': 'Gioca la posizione così come la disegna il modulo.',
  'role.winger': 'Ala',
  'role.winger.hint': 'Resta largo e arriva fino al fondo. Dove attacca, non quanto bene.',
  'role.winger.short': 'AL',
  'role.insideForward': 'Ala tagliente',
  'role.insideForward.hint': 'Rientra dalla fascia verso il mezzo spazio e l\'area.',
  'role.insideForward.short': 'AT',
  'role.widePlaymaker': 'Regista largo',
  'role.widePlaymaker.hint': 'Arretra per costruire, così più gioco passa da lui e prima.',
  'role.widePlaymaker.short': 'RL',

  // ── The match inspector ─────────────────────────────────
  //
  // `ui/screens/match/match_inspector.dart`. Same frame as `match.analysis.*`:
  // attacking upward, and each side's own left and right.
  'match.inspect.open':
      'Analizza',
  'match.inspect.title':
      'Analisi della partita',
  'match.inspect.touches':
      'Tocchi',
  'match.inspect.shots':
      'Tiri',
  'match.inspect.xg':
      'xG',
  'match.inspect.total':
      '{metric}: {ours} a {theirs}',
  'match.inspect.players':
      'Duelli per giocatore — tocca per vedere solo la sua mappa',
  'match.inspect.matchups':
      'Chi ha affrontato chi',
  'match.inspect.duel_line':
      '{won}-{lost} ({pct} %)',
  'match.inspect.shot_line_one':
      '{shots} tiro, {xg} xG',
  'match.inspect.shot_line':
      '{shots} tiri, {xg} xG',
  'match.inspect.versus':
      '{attacker} contro {defender}',
  'match.inspect.whole_team':
      'Tutta la squadra',
  'match.inspect.showing':
      'Viene mostrato solo {name}.',
  'match.inspect.hint':
      'La tua porta è in basso e attacchi verso l’alto, quindi la fascia in cima è la loro area. La tua fascia destra è a sinistra del campo, dove sta il tuo terzino destro.',
};
