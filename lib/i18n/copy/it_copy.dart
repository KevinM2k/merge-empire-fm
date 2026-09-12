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

  // ── Commentary pools the spec's own catalogues never widened ───────────
  //
  // English grew these `commentary.*` pools over time; the translated
  // locales stayed at the original length. Existing lines are kept
  // verbatim; new lines fill the gap so every locale draws from the same
  // number of variants. `commentary.opp_sub`'s original single variant was
  // itself untranslated English in every locale — replaced here too.
  'commentary.blocked': '{who} si vedono murare il tiro!|{who} calciano dal limite e un corpo si butta davanti — così un difensore si guadagna lo stipendio.|Tre maglie del {who} si mettono in fila sulla respinta, e vengono murate una dopo l\'altra.|Tiro del {who} da dodici metri, murato da una gamba spuntata dal nulla.|{who} recuperano palla e tirano di nuovo — e ancora una volta c\'è un corpo in mezzo.|Murata sul nascere, e {who} devono ripartire l\'azione da capo.|La difesa si getta davanti a tutto quello che {who} riescono a costruire.',
  'commentary.booking.opp_red': 'Rosso diretto per il {opp}, e nessuno allo stadio protesta: il {opp} resta in dieci.|Un intervento terribile da una maglia del {opp}, e l\'arbitro va dritto al rosso. Ospiti in dieci.|Un giocatore del {opp} viene espulso. L\'arbitro non poteva dare altro.|Rosso per il {opp}, e dalla panchina non arriva nessuna protesta. Ora sono in dieci.',
  'commentary.booking.opp_second_yellow': 'Secondo giallo per il {opp}, e fuori: si sono complicati il pomeriggio da soli.|Due ammonizioni per lo stesso giocatore del {opp}, e l\'arbitro deve espellerlo. Il {opp} resta in dieci.|Due ammonizioni per lo stesso giocatore del {opp}, e l\'arbitro lo manda negli spogliatoi. Il {opp} gioca il resto in dieci.|Secondo giallo per il {opp}, ed è rosso. Si sono complicati la vita da soli.',
  'commentary.booking.opp_yellow': 'Una maglia del {opp} finisce sul taccuino per uno sgambetto cinico: l\'arbitro ne aveva viste abbastanza.|Il {opp} regala una punizione inutile e si prende pure il giallo.|Ammonizione per il {opp}, e la loro panchina non la prende bene.|Un giocatore del {opp} viene ammonito per aver trattenuto l\'avversario in corsa — l\'arbitro non aveva scelta.|Intervento in ritardo e scomposto del {opp}, e il giallo è la parte meno grave.',
  'commentary.booking.red': 'Rosso diretto per {player}, e non c\'è nulla da discutere — ultimo uomo, e gli prende le gambe. {us} finiscono in dieci.|{player} perde completamente la testa e l\'arbitro non esita. Fuori. Mezz\'ora lunga davanti a {us}.|{player} viene espulso. Un intervento senza alcun tentativo di giocare il pallone, e {us} finiscono in dieci.|L\'arbitro va dritto in tasca per {player}, ed è rosso. {us} restano in dieci.',
  'commentary.booking.second_yellow': 'Ed è la seconda ammonizione per {player} — niente di cattivo, ma era già ammonito e lo sapeva. {us} in dieci.|{player} entra di nuovo, e l\'arbitro non ha scelta: due gialli, fuori. {us} giocano il resto in inferiorità.|Due gialli per {player}, ed è una camminata lunga verso gli spogliatoi. {us} restano in dieci per il resto della partita.|{player} viene ammonito di nuovo, e il rosso è la conseguenza automatica. {us} restano in inferiorità numerica.',
  'commentary.booking.yellow': '{player} viene ammonito per perdita di tempo — la prima del pomeriggio, ora dovrà stare attento.|Entrata in ritardo di {player}, e l\'arbitro tira fuori il giallo prima che si rialzi.|{player} trattiene la maglia per fermare la ripartenza. C\'è un solo esito: ammonito.|Proteste di {player} — fra tutti i modi stupidi per finire sul taccuino.|{player} arriva in ritardo sul contrasto e all\'arbitro non resta altra scelta — giallo.|Sgambetto di {player} a centrocampo, ed esce il cartellino.|{player} finisce sul taccuino per un fallo che non valeva la pena commettere.',
  'commentary.demolition': '{us}–{them} — che prestazione! Abbiamo demolito {opp}. I ragazzi saranno gasati per giorni.|{us}–{them}. Ci è riuscito tutto quello che abbiamo provato, e il {opp} non ha avuto risposte.|Non abbiamo mai giocato meglio di così. {us}–{them} contro il {opp} — godetevela.|{us}–{them}! Non potevo chiedere di più ai ragazzi oggi.|Siamo stati spietati. {us}–{them}, e il {opp} ha accolto il fischio finale con sollievo.',
  'commentary.dispossessed': '{who} perdono palla — che intervento!|{who} fanno un tocco di troppo in area, e l\'intervento è pulitissimo.|{who} alzano la testa per il passaggio che c\'era un attimo fa — e gliel\'hanno soffiata dal piede.|Un contrasto tempestivo chiude l\'azione del {who}.|{who} si fanno rubare palla al limite dell\'area da un intervento spuntato dal nulla.|Il pallone viene sfilato a {who} proprio mentre stava per partire il tiro.|{who} perdono tempo sul pallone e pagano quel secondo di troppo.',
  'commentary.drubbing': 'Brutta serata. {us}–{them} a {opp}. Rialzatevi — ogni squadra ha la sua giornata storta.|{us}–{them} a {opp}. Non è andata bene niente e non ho intenzione di far finta di nulla.|Una lezione, senza tanti giri di parole. {us}–{them}. Ce la lasciamo alle spalle e ripartiamo.|{us}–{them}. Il {opp} è stato migliore di noi in ogni zona del campo. Capita.|Non c\'è molto da dire su {us}–{them}. Giornata storta, memoria corta, si va avanti.',
  'commentary.flow.addedtime.0': 'Dramma nel recupero!|Recupero, e non è ancora finita.|Dramma all\'ultimissimo respiro.|Succede di tutto in questi ultimi secondi.',
  'commentary.flow.addedtime.1': 'Resistono fino in fondo al recupero.|Recupero avanzato, e si resiste con le unghie.|Ogni secondo viene portato via, e dalla panchina nessuno protesta.|Qui dentro conta solo l\'orologio.',
  'commentary.flow.addedtime.2': 'Il cartello del quarto uomo si alza — recupero in corso.|Il cartello è alzato, e c\'è ancora da giocare.|Il quarto uomo segnala i minuti di recupero, e sono più del previsto.|Recupero confermato, e su quel numero nessuna panchina sembra contenta.',
  'commentary.flow.addedtime.3': 'C\'è ancora tempo per un\'ultima occasione.|C\'è tempo per un ultimo affondo.|Un ultimo pallone in area, di sicuro.|Non è ancora finita — c\'è ancora spazio per un\'altra occasione.',
  'commentary.flow.closing.0': 'Ultimo tratto!|Dieci minuti alla fine, ed è qui che si deciderà tutto.|L\'orologio corre e la tensione sale.|Ultimi dieci minuti, ed entrambe le panchine sono in piedi.',
  'commentary.flow.closing.1': 'Ogni intervento conta ora.|Ogni contrasto viene giocato come fosse l\'ultimo della stagione.|Nessuno regala niente, in nessuna zona del campo.|Corpi buttati in ogni angolo del campo.',
  'commentary.flow.closing.2': 'Riusciranno a reggere?|La domanda ora è se riusciranno a portarla a casa.|Le gambe iniziano a mancare, e c\'è ancora tempo sull\'orologio.|Si difende con tutto quello che resta, e i minuti non sono ancora finiti.',
  'commentary.flow.closing.3': 'Ultimo tentativo dell\'avversario.|Arriva l\'ultimo cambio — da qui in poi si spinge tutti avanti.|Un difensore centrale è salito in attacco. Dice tutto sulla situazione.|È l\'ultimo assalto, e non si tiene indietro più niente.',
  'commentary.flow.closing.4': 'Tensione altissima in tutto lo stadio.|Si sente la tensione, qui dentro.|Ogni passaggio sbagliato viene accolto da un lamento degli spalti.|Il pubblico fischia, vuole solo che finisca.',
  'commentary.flow.firstA.0': 'La tua squadra prende fiducia.|La fiducia cresce, e i passaggi si fanno più rapidi.|Una fase di controllo — una squadra ha preso in mano il centrocampo.|Il giro palla ha trovato un ritmo.',
  'commentary.flow.firstA.1': 'Conclusione ravvicinata — fuori di un soffio!|Conclusione secca da otto metri, e sfiora il palo sul lato sbagliato.|Mischia nell\'area piccola, e il pallone scivola largo su un difensore.|Colpo di testa ravvicinato, e finisce di un soffio a lato del palo.',
  'commentary.flow.firstA.2': 'Bell\'intesa sulla fascia sinistra.|Tre passaggi sulla fascia sinistra, tutti di prima, e il cross è quasi perfetto.|Bel calcio sulla fascia destra, e il terzino salta l\'uomo sull\'esterno.|Un uno-due sulla linea laterale apre il campo per un attimo.',
  'commentary.flow.firstA.3': 'Il portiere respinge di pugni un corner.|Il corner viene battuto, e il portiere esce e la prende sopra la testa di tutti.|Un calcio piazzato profondo semina il panico per un attimo, prima di essere spazzato via.|Corner su corner, e la difesa continua a metterci la testa.',
  'commentary.flow.firstB.0': 'Punizione pericolosa in arrivo...|Punizione in una zona pericolosissima, venti metri e centrale.|Si misura la barriera, ed è un\'occasione vera.|Fallo al limite dell\'area, e qui c\'è davvero da segnare.',
  'commentary.flow.firstB.1': 'Portiere chiamato in causa — bella parata!|Tiro potente dalla distanza, e il portiere la blocca al secondo tentativo.|Gran parata, bassa sulla sua sinistra, e la respinta viene spazzata via in angolo.|Il portiere esce rapido dai pali e chiude lo specchio ai piedi dell\'attaccante.',
  'commentary.flow.firstB.3': 'Tiro bloccato sulla linea!|Spazzata via sulla linea, e allo stadio nessuno capisce come.|Un corpo si getta davanti al tiro, e la respinta finisce in corner.|Murato, e murato di nuovo sulla ribattuta — difesa disperata.',
  'commentary.flow.open.0': 'Calcio d\'inizio! Entrambe le squadre si sistemano.|Si comincia. Entrambe le squadre prendono le misure.|L\'arbitro dà il via, e i primi passaggi sono cauti.|Si parte. Nessuna delle due squadre vuole concedere niente in questi primi minuti.',
  'commentary.flow.open.1': 'Pressing precoce del centrocampo.|Finora è a centrocampo che si decide la partita.|Un primo possesso prolungato, e il primo vero predominio territoriale del pomeriggio.|Entrambe le squadre pressano alte, e nessuno riesce ancora a impostare il gioco.',
  'commentary.flow.open.2': 'Il pubblico è già rumoroso.|Lo stadio è già in piedi, e non sono ancora passati dieci minuti.|Un boato ogni volta che il pallone va in avanti.|L\'atmosfera qui dentro cresce fin dal riscaldamento.',
  'commentary.flow.secondA.0': 'Secondo tempo al via — la tua squadra spinge in avanti.|Si torna in campo per il secondo tempo, e si sente già più urgenza.|La ripresa porta un cambio di ritmo — più veloce del primo tempo.|Secondo tempo, e quello che è stato detto all\'intervallo si vede in campo.',
  'commentary.flow.secondA.1': 'Il cambio tattico sembra funzionare.|Il modulo è cambiato, e lo spazio si è aperto di conseguenza.|Un rimescolamento dalla panchina, e si vede l\'effetto.|Qualcuno si è accentrato, e il campo sembra più grande.',
  'commentary.flow.secondA.2': 'Adesso è botta e risposta.|La partita si è aperta del tutto — è tutta un\'azione da una parte all\'altra.|Nessuna delle due squadre vuole più tenere il pallone.|Ogni rinvio torna subito indietro, e nessuno riesce a controllare il ritmo.',
  'commentary.flow.secondA.3': 'Fisio chiamato per una botta.|Il fisioterapista entra in campo, c\'è un giocatore a terra da soccorrere.|Gioco fermo mentre si controlla un infortunio a bordo campo.|Cure sul terreno di gioco, e questi minuti verranno recuperati alla fine.',
  'commentary.flow.secondB.0': 'Battaglia a centrocampo che si infiamma.|I contrasti volano a centrocampo, uno dopo l\'altro.|Nessuno riesce a controllare il centrocampo, ma ci provano tutti.|È diventata una battaglia nella zona centrale del campo.',
  'commentary.flow.secondB.1': 'Tiro da fuori — dritto sul portiere.|Trenta metri e si scatenano — il portiere blocca senza problemi.|C\'è effetto sul tiro dalla distanza, ma finisce dritto tra le braccia del portiere.|Tentativo ambizioso dalla distanza, che non impensierisce mai la porta.',
  'commentary.flow.secondB.2': 'Splendido uno-due in area, allontanato per poco!|Un uno-due apre la difesa, e l\'ultimo tocco è di uno stivale avversario.|Lavorata benissimo dentro l\'area, e spazzata via all\'ultimo istante.|Due passaggi e la difesa era saltata — ma arriva comunque il rinvio.',
  'commentary.forces_save': '{who} costringe a una parata!|{who} allargano e crossano — il portiere ci arriva in tuffo.|Uno-due rapido di {who} al limite, e il tiro viene respinto basso sul primo palo.|{who} ripartono tre contro due, e solo un\'uscita bassa la tiene fuori.|La palla arriva comoda a {who} da otto metri — e il portiere, chissà come, c\'è.|{who} calciano da posizione defilata, e il portiere devia in angolo.|Un colpo di testa su corner del {who} viene salvato sulla linea, chissà come.|{who} mettono un pallone basso sullo specchio, e il portiere ci arriva con una manona forte.',
  'commentary.goal.equalise.no_scorer': '{us} pareggiano!|{us} agguantano il pari!|{us} pari — partita aperta!|Partita aperta! {us} pareggiano!|{us} trovano il pareggio!|{us} tornano in parità!|Tutto pari — è {us}!|{us} riequilibrano il match!',
  'commentary.goal.equalise.with_scorer': '{scorer} pareggia per {us}!|Tornati in partita — {scorer} la mette per {us}!|{scorer} risponde — {us} pari!|Partita aperta! {us} pareggiano con {scorer}.|{scorer} trova il varco giusto — {us} tornano in parità!|Tutto pari! {scorer} firma il gol per {us}!|{scorer} non sbaglia — {us} hanno pareggiato!|Dritto nel mezzo della porta con {scorer}, e {us} sono di nuovo in parità!',
  'commentary.goal.extend.no_scorer': '{us} ne mettono un altro!|{us} allungano!|{us} dilagano!|{us} prendono il largo!|{us} segnano ancora!|{us} volano via!|Gli sta sfuggendo di mano — ancora {us}!|{us} stringono ancora di più!',
  'commentary.goal.extend.with_scorer': '{scorer} ne aggiunge un altro per {us}!|Conclusione in due tocchi di {scorer} — {us} allungano!|{scorer} raddoppia — {us} dilagano!|Cinico {scorer} — {us} prendono il largo!|{scorer} mette questa fuori portata per {us}!|Un altro per {us}, ed è di {scorer}!|Ancora {scorer} — {us} stringono la morsa!|{us} sono scatenati, e {scorer} è al centro di tutto!',
  'commentary.goal.lead.no_scorer': '{us} passano in vantaggio!|{us} prendono il largo!|{us} rompono l\'equilibrio!|{us} davanti!|{us} sono avanti!|Lo sblocco — {us} in vantaggio!|{us} trovano il gol del vantaggio!|Primi a colpire — {us}!',
  'commentary.goal.lead.with_scorer': '{scorer} porta avanti {us}!|Che tiro di {scorer}! {us} in vantaggio!|{scorer} rompe l\'equilibrio per {us}!|Sistemato da {scorer} — {us} avanti!|{scorer} sblocca il match — {us} sono avanti!|{us} in vantaggio, ed è merito di {scorer}!|Un gol dal nulla di {scorer}, e {us} passano in vantaggio!|{scorer} gonfia la rete — vantaggio {us}!',
  'commentary.goal.pullback.no_scorer': '{us} accorciano!|{us} trovano una boccata d\'ossigeno!|{us} di nuovo in partita!|{us} riprendono terreno!|{us} accorciano le distanze!|Gol per {us} — la partita è riaperta!|{us} riducono lo svantaggio!|Non è ancora finita — segnano {us}!',
  'commentary.goal.pullback.with_scorer': '{scorer} accorcia per {us}!|Speranza! {scorer} va a segno per {us}!|{scorer} tiene {us} in vita!|{scorer} converte per {us}!|{scorer} regala a {us} qualcosa a cui aggrapparsi!|Un gol per {us} con {scorer} — la partita è riaperta!|{scorer} colpisce, e {us} non sono ancora fuori!|Un filo di speranza per {us}, e arriva da {scorer}!',
  'commentary.halftime_ahead': '{us} sono avanti all\'intervallo!|{us} portano il vantaggio negli spogliatoi.|Intervallo, e {us} sono avanti.|{us} vanno al riposo in vantaggio — nella ripresa si tratta di difenderlo.',
  'commentary.halftime_behind': '{us} sono sotto — bisogna reagire.|Intervallo, e per {us} c\'è del lavoro da fare.|{us} sono sotto al riposo, e qualcosa deve cambiare.|Un primo tempo da dimenticare per {us}, e quarantacinque minuti per rimediare.',
  'commentary.halftime_level': 'Pari all\'intervallo.|Niente da dividerle al riposo.|Tutto pari all\'intervallo.|In parità dopo quarantacinque minuti, può succedere di tutto.',
  'commentary.high_scoring_loss': 'Partita aperta. {us}–{them} a {opp}. Abbiamo segnato tanto — solo subito uno di troppo.|{us}–{them} a {opp}. Tanta roba da una parte, troppa dall\'altra.|Non siamo mai stati fuori da quella partita, ma non ci siamo mai sentiti al sicuro. {us}–{them}.|{us}–{them}. Segnare non è il nostro problema. Fermarli, sì.|Divertente per tutti tranne che per me. {us}–{them}, e la prossima settimana difendiamo meglio.',
  'commentary.high_scoring_win': 'Gran partita. {us}–{them} contro {opp} — gol ovunque ma portiamo a casa il risultato. Concretizzare così merita una chiamata da uno sponsor.|{us}–{them} contro il {opp}. Partita apertissima, col fiato sospeso, e tre punti.|Abbiamo segnato tanto e concesso qualcosa. {us}–{them}, e me lo tengo stretto.|{us}–{them}! L\'attacco era imprendibile. Della difesa ne parliamo con calma.|Una sfida a viso aperto con il {opp}, {us}–{them}, e l\'ultima parola l\'abbiamo avuta noi.',
  'commentary.hit_post': '{who} colpiscono il palo!|{who} calciano con tutto quello che hanno, e tutto lo stadio sente il palo.|Carambola su un difensore e scende sotto la traversa per {who} — ed esce sbattendo sul legno.|{who} scuotono il palo lontano da venti metri, e resta fuori.|Ci pensa la traversa a salvarli — {who} erano a un centimetro dal gol.|Un colpo di testa del {who} scheggia la traversa e rimbalza fuori dalla porta.|Sull\'interno del palo e lungo la linea di porta — {who} non ci credono.',
  'commentary.injury': '{player} esce per infortunio!|{player} non può continuare — brutta tegola.|{player} si ferma e fa segno alla panchina. Il pomeriggio finisce qui.|{player} è a terra, e non sembra il tipo di infortunio da cui si torna in piedi da soli.',
  'commentary.nervy_one_nil': 'Un 1–0 contro {opp}. Non bellissimo, ma tre punti sono tre punti. Porta inviolata, in cassaforte, avanti.|1–0. Non c\'era bisogno di renderla così difficile, ma una vittoria contro il {opp} resta una vittoria.|Porta inviolata e tre punti contro il {opp}. Ad aprile nessuno si ricorderà come.|Un 1–0 sporco. Le grandi squadre le vincono anche così, quindi non mi lamento.|Un gol è bastato contro il {opp}. Se lo è meritato la difesa.',
  'commentary.nil_nil': 'Zero a zero con {opp}. Pomeriggio piatto — prendiamo il punto e ne cerchiamo di più la prossima.|Zero a zero contro il {opp}. Nessuno ne parlerà, ma un punto è un punto.|Almeno la porta inviolata. Il {opp} non ci ha portato via niente e noi non abbiamo preso niente da loro.|Senza gol con il {opp}. Potevamo giocare fino a mezzanotte senza segnare.|Un punto, una porta inviolata, e novanta minuti lunghissimi contro il {opp}.',
  'commentary.opp_goal': '{them} segnano!|Che gol di {them}!|Combinazione pulita di {them} — dritta dentro.|{them} puniscono una sbavatura difensiva.|{them} infilano un passaggio — finalizzazione cinica.|Difesa addormentata — {them} colpiscono.|Bomba di {them}, il portiere non poteva farci nulla.|Sporca per {them}, ma vale.|{them} trovano l\'angolo — classe pura.|Un corner che nessuno attacca, un colpo di testa che nessuno contrasta, e {them} lo prendono gratis.|{them} lavorano la sovrapposizione e la infilano sul primo palo.|Una deviazione spiazza tutti, e {them} ne approfittano.|Un solo passaggio taglia fuori la difesa, e {them} fanno il resto.|{them} colpiscono di testa su un cross che non doveva arrivare.|Lancio lungo, sponda, e {them} sono soli davanti al portiere: gol.',
  'commentary.opp_sub': 'Il {opp} fa un cambio — gambe fresche dalla panchina.|Cambio per il {opp} — gambe fresche in campo.|Il {opp} attinge alla panchina.|Il {opp} fa un cambio, e il nuovo entrato va subito in attacco.|Esce una maglia stanca del {opp}, ed entra una fresca.',
  'commentary.shot_over': '{who} la mandano alta!|{who} la rimettono in area e ci si appoggiano sopra — e la spediscono in curva.|A {who} bastava un metro, e da dodici la manda alle stelle.|{who} hanno tutta la porta a disposizione e la spediscono sopra la traversa.|Colpo di testa libero per {who} da sei metri, e finisce sugli spalti.|Il tiro al volo di {who} è calciato bene, ma troppo alto.|Tiro in girata di {who}, e supera la traversa di parecchio.',
  'commentary.shot_wide': '{who} la mandano larga!|{who} provano a girarla sul secondo palo e la vedono uscire di un soffio.|Il pallone si alza perfetto per {who} — e attraversa tutto lo specchio senza nessuno.|{who} rientrano sul destro e la curvano di poco fuori dal palo.|Conclusione di prima di {who} che non ha mai impensierito la porta.|Azione ben costruita da {who}, e il tiro dal limite finisce largo.|L\'assist rasoterra trova una maglia del {who}, e il tiro attraversa tutto lo specchio e finisce fuori.',
  'commentary.snub': '{opp} sembra furiosi dopo lo schiaffo — aspettati una partita ostile.|C\'è una storia tra queste due squadre, e il {opp} non l\'ha dimenticata.|Il {opp} è sceso in campo con qualcosa da dimostrare.',
  'commentary.thriller_draw': '{us}–{them}! Botta e risposta con {opp}. I neutrali si sono divertiti anche se torniamo con un solo punto.|{us}–{them} con il {opp}, e nessuna delle due meritava di perderla. Prendiamoci il punto.|Aveva tutto tranne il gol vittoria. {us}–{them}, e dividiamo la posta con il {opp}.|Un punto da {us}–{them}. Divertente, sfiancante, e non del tutto sufficiente.|{us}–{them} contro il {opp}. Se fosse così ogni settimana non avrei più voce.',
  'commentary.thriller_loss': 'Cocente delusione in un thriller {us}–{them} contro {opp}. Abbiamo dato tutto — mancava solo il gol vittoria.|{us}–{them} contro il {opp}. Ce l\'abbiamo giocata fino all\'ultimo pallone, e ci è comunque sfuggita.|Niente di cui vergognarsi in {us}–{them}. Abbiamo fatto la nostra parte in una bella partita, e l\'abbiamo persa.|Questa farà male. {us}–{them}, e un solo episodio ha deciso l\'intero pomeriggio.|Abbiamo tenuto testa al {opp} ovunque tranne che sul risultato. {us}–{them}, e si torna al lavoro.',
  'commentary.thriller_win': 'Che partita! {us}–{them} contro {opp} — abbiamo vinto un classico per un soffio. Gare così riempiono gli stadi.|{us}–{them}. Ho invecchiato di dieci anni a guardarla, e la rifarei la settimana prossima.|Abbiamo vinto una vera partita di calcio, {us}–{them}. Il {opp} ci ha messo in difficoltà fino alla fine.|Valeva da sola il prezzo del biglietto. {us}–{them} contro il {opp}, e siamo usciti dalla parte giusta.|{us}–{them}! Non chiedetemi come, ma abbiamo trovato quello che contava.',

  // ── Copy the generated catalogue never caught up on ──────────────────────
  //
  // Reported from a live save in Italian: whole screens still in English. The
  // subs panel, the difficulty switch, the tutorial's loan spell, two coach
  // tips, the champions card and the Iron Lungs trait were added to `en.js`
  // and never translated, so `locales/*.g.dart` carries the ENGLISH sentence
  // in all nine — which `t()` cannot detect, because the key resolves.
  //
  // And `game.training.intro` called the ball a BUBBLE. It is a football in
  // `keeper_view.dart` and has been since the scene was ported; every locale
  // translated the word faithfully, so the Italian read "bolle" over a picture
  // of a ball. Fixed in `en_copy.dart` first, then here.
  'match.subs': 'Cambi',
  'match.subs.done': 'Torna alla partita',
  'match.subs.on_pitch': 'In campo',
  'match.subs.bench': 'Panchina',
  'match.subs.empty_bench': 'Nessun giocatore in panchina.',
  'match.subs.empty_slot': 'Vuoto',
  'match.subs.pick_off': 'Tocca un giocatore da sostituire.',
  'match.subs.pick_on':
      'Tocca un giocatore in panchina da far entrare (verde = ruolo migliore).',
  'match.subs.none_left': 'Non hai più sostituzioni.',
  'match.subs.feed': 'Esce {off}, entra {on}.',
  'match.subs.feed_on': 'Entra {on}.',
  'difficulty.switch.toHard':
      'Modalità Pro: ogni giocatore si stanca durante la partita — gestisci '
      'l\'energia della rosa e ruota la panchina per tenere le gambe fresche. '
      'Posso aiutarti a scegliere gli undici più freschi, ma sulle tattiche '
      'resterò in silenzio. Cambiare modalità fa ripartire tutto da capo.',
  'difficulty.switch.toEasy':
      'Modalità Casual: nessuna fatica per i giocatori, quindi la panchina '
      'serve solo per cambi tattici e infortuni. Tornano la scelta automatica e '
      'i consigli del mister. Cambiare modalità fa ripartire tutto da capo.',
  'tut.loan_boost.title': '⭐ Arrivano le stelle in prestito!',
  'tut.loan_boost.body':
      'Ho chiesto qualche favore… dei <strong>giocatori top</strong> hanno '
      'accettato di unirsi a noi per la tua prima partita! Se ne andranno '
      'subito dopo, ma tanto vale sfruttarli al massimo!',
  'tut.loan_boost.btn': 'Vedi la mia rosa →',
  'tut.loan_depart.title': 'Ora costruiamo la nostra squadra',
  'tut.loan_depart.body':
      'Le stelle in prestito se ne sono andate, ma hanno dimostrato che '
      'possiamo competere. Ora costruiamo qualcosa di <strong>nostro</strong>. '
      'Ecco <strong>500 monete</strong> per iniziare. Mi trovi in basso a '
      'sinistra ogni volta che ho un consiglio.',
  'tut.loan_depart.btn': 'Costruiamo! →',
  'ach.cat.hardmode': 'Modalità Pro',
  'coachtip.subs_bench.title': 'Hai una panchina',
  'coachtip.subs_bench.body':
      'Tocca Cambi durante la partita per aprire la panchina: hai 5 '
      'sostituzioni a match e il cronometro si ferma mentre scegli. Ora ci '
      'passano anche gli infortuni: quando qualcuno cade, la sua maglia esce '
      'dal campo e il posto resta vuoto finché non fai entrare un sostituto, '
      'quindi non lasciarlo lì.',
  'coachtip.try_hard_mode.title': 'Ti va una sfida?',
  'coachtip.try_hard_mode.body':
      'Hai fatto tanta strada, mister. Pronto per la Modalità Pro? I giocatori '
      'si stancano durante la partita, quindi ruotare la rosa e usare la '
      'panchina conta davvero — tocca Auto e ti schiero gli undici regolari più '
      'freschi — e sulle tattiche resterò in silenzio. Si riparte con una '
      'squadra nuova: solo se te la senti.',
  'coachtip.try_hard_mode.cta': 'Apri Impostazioni',
  'coach.match.tired': '{name} è esausto — fai entrare un giocatore fresco!',
  'toast.energy_refilled': 'Energia della rosa ricaricata!',
  'toast.no_fit_players':
      'Non ci sono abbastanza giocatori in condizione — falli riposare o guarda '
      'un annuncio per ricaricare.',
  'trait.name.iron_lungs': 'Polmoni d\'acciaio',
  'trait.desc.iron_lungs':
      'Motore instancabile — consuma energia più lentamente durante le partite '
      '(Modalità Pro)',
  'champ.title': 'CAMPIONI!',
  'champ.subtitle': 'Champions League conquistata',
  'champ.body':
      'Hai conquistato ogni divisione e superato tutti i rivali. Sei da solo in '
      'cima: il più grande allenatore del mondo.',
  'champ.prestige_teaser':
      'Azzera tutto e risali dalla Lega Domenicale con un <strong>bonus '
      'permanente ×{mult} sulle entrate</strong>. I traguardi della tua '
      'carriera restano tuoi per sempre.',
  'champ.new_adventure': '🌟 Inizia una nuova avventura',
  'champ.defend': '⚽ Difendi il titolo',
  'game.training.intro':
      'Tocca {n} tiri mentre arrivano. Hai {secs}s per esercizio.',
};
