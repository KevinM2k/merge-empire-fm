/// Italian copy for the match write-up. See `lib/i18n/locale_copy.dart`.
///
/// Voice and conventions taken from `locales/it.g.dart`'s own `report.*` block:
/// the club takes an article and a singular verb — "Il {club} si è messo a
/// difendere" — and the minute is written "al {minute}'", which is why the
/// apostrophe is in the copy rather than in the value.
library;

/// Replaces the generated entry, or adds a key Italian did not have.
const Map<String, String> itCopy = <String, String>{
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
};
