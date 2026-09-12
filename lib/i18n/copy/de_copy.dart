/// German copy for the match write-up. See `lib/i18n/locale_copy.dart`.
///
/// Voice and conventions taken from `locales/de.g.dart`'s own `report.*` block,
/// including its agreement: the club takes a SINGULAR verb — "{club} stellte
/// defensiv um" — and the opponent a PLURAL one — "{opp} hatten einen
/// Platzverweis". That split is the generated catalogue's, not a choice made
/// here, and matching it is what keeps a paragraph reading as one voice.
/// Clauses that would have to conjugate both are written around instead.
library;

/// Replaces the generated entry, or adds a key German did not have.
const Map<String, String> deCopy = <String, String>{
  'customise.item.face.bubblegum': 'Kaugummi',

  // Eine dritte Zeile neben Sound und Musik: der Klick jeder Schaltfläche.
  'settings.ui_sounds': 'Oberfläche',

  // Der Tab ist nicht mehr nur Ton: die Vibration kommt dazu.
  'settings.tab.controls': 'Steuerung',
  'settings.haptics': 'Vibration',
  'settings.haptics.hint': 'Ein kurzes Vibrieren bei jedem Tippen. Die '
      'Vibrationseinstellungen deines Telefons können es ebenfalls '
      'abschalten.',
  'settings.tap_ripple': 'Tipp-Wellen',

  // ── Die Schlagzeile ──────────────────────────────────────────────────────
  //
  // Ersetzt statt erweitert: die generierten Texte öffnen alle mit {score}.
  // `{minute}` erreicht nur die drei `.late`-Texte.
  'report.win.rout':
      'Abpfiff, und es war eine Demontage: {club} legte {ours} gegen {opp} auf '
          'und kam dabei kaum ins Schwitzen.|'
      'Schlusspfiff über einem Schützenfest. {ours} für {club}, {theirs} für '
          '{opp}, und das Ergebnis schmeichelt niemandem außer dem Sieger.|'
      'Spielende, und {club} hat {opp} auseinandergenommen — {ours} Tore, und '
          'es hätten mehr sein können.',
  'report.win.comfortable':
      'Der Schlusspfiff ist gefallen, und {club} hat das im Spaziergang '
          'gewonnen, drei Tore vor {opp}.|'
      'Vorbei. Drei Tore Abstand am Ende, und {club} war nie in Gefahr, sie '
          'wieder herzugeben.|'
      'Spielende. {club} gewinnt mit drei und macht die Arbeit, ohne je '
          'forcieren zu müssen.',
  'report.win.clear':
      'Der Schlusspfiff ist gefallen, und {club} gewinnt mit zwei. {opp} hatten '
          'ihre Phasen, ohne je nach Ausgleich auszusehen.|'
      'Vorbei, zwei Tore Abstand, und {club} verwaltete den Nachmittag ab dem '
          'Moment, als das zweite fiel.|'
      'Spielende, und ein Zwei-Tore-Sieg für {club}, so souverän, wie er '
          'klingt.',
  'report.win.narrow':
      'Der Schlusspfiff ist gefallen, und es war ein Tor Unterschied — und es '
          'gehörte {club}.|'
      'Vorbei. Ein einziges Tor trennt sie am Ende, und die Punkte gehen an '
          '{club}.|'
      'Spielende, und {club} hat es erzwungen. Ein Tor, und es hätte in beide '
          'Richtungen kippen können.',
  'report.win.late':
      'Der Schlusspfiff ist gefallen, und {club} hat es spät gewonnen — das '
          'entscheidende Tor fiel in der {minute}. Minute.|'
      'Vorbei, und was für ein Finale: bis zur {minute}. Minute ausgeglichen, '
          'dann fand {club} das eine, auf das {opp} keine Zeit mehr hatten.|'
      'Spielende. Ein Punkt sah bis zur {minute}. Minute nach dem '
          'wahrscheinlichsten Ausgang aus, dann gewann {club}.',
  'report.win.thriller':
      'Vorbei, und was für ein Spiel — {total} Tore zwischen beiden, und es '
          'geht an {club}.|'
      'Schlusspfiff über einem Spiel mit {total} Toren, und {club} nimmt die '
          'Punkte mit.|'
      'Spielende, und durchatmen. {total} Tore, und es fiel um das eine zu '
          'Gunsten von {club}.',
  'report.draw.goalless':
      'Der Schlusspfiff ist gefallen, und nichts trennt sie — keine Tore, und '
          'auch nicht viele Chancen.|'
      'Vorbei, torlos. Die beiden Torhüter hatten einen ruhigen Nachmittag.|'
      'Spielende, und geteilte Ehren bei leerer Anzeigetafel.',
  'report.draw.shared':
      'Der Schlusspfiff ist über einem Remis gefallen — {ours} auf jeder Seite, '
          'und weder {club} noch {opp} fanden das eine, das entscheidet.|'
      'Vorbei, und die Punkte werden geteilt. {ours} für jeden, in einem Spiel, '
          'in dem irgendwo ein Sieger steckte.|'
      'Spielende, und unentschieden. Keine der beiden Kabinen wird damit ganz '
          'zufrieden sein.',
  'report.draw.late':
      'Der Schlusspfiff ist über einem Remis gefallen, und der Ausgleich kam '
          'erst in der {minute}. Minute — ein gewonnener Punkt für die einen '
          'und zwei verlorene für die anderen.|'
      'Vorbei, ausgeglichen, und es hat bis zur {minute}. Minute gedauert.|'
      'Spielende, mit dem Ausgleichstor in der {minute}. Minute.',
  'report.draw.thriller':
      'Vorbei, und was für ein Spiel — {total} Tore, und nichts trennt sie.|'
      'Schlusspfiff über einem Spiel mit {total} Toren, das keiner von beiden '
          'gewinnen konnte.|'
      'Spielende, und je ein Punkt nach {total} Toren zwischen ihnen.',
  'report.loss.narrow':
      'Der Schlusspfiff ist gefallen, und es war ein Tor Unterschied — und es '
          'gehörte {opp}.|'
      'Vorbei. {opp} nehmen es mit einem Tor, und {club} bleiben die Fragen.|'
      'Spielende, und {club} verliert denkbar knapp. Kleinigkeiten, und sie '
          'fielen für {opp}.',
  'report.loss.late':
      'Der Schlusspfiff ist gefallen, und {club} hat es spät verloren — das Tor '
          'von {opp} fiel in der {minute}. Minute.|'
      'Vorbei, und ein bitteres Ende: bis zur {minute}. Minute ausgeglichen, '
          'dann trafen {opp} zum entscheidenden Tor.|'
      'Spielende. Für {club} hätte es bis zur {minute}. Minute zum Punkt '
          'gereicht, und keine Minute länger.',
  'report.loss.thriller':
      'Vorbei, und was für ein Spiel — {total} Tore zwischen beiden, aber es '
          'geht an {opp}.|'
      'Schlusspfiff über einem Spiel mit {total} Toren, und {club} geht leer '
          'aus.|'
      'Spielende, und durchatmen. {total} Tore, und es fiel um das eine zu '
          'Gunsten von {opp}.',
  'report.loss.clear':
      'Der Schlusspfiff ist gefallen, und {opp} gewinnen mit zwei. {club} war '
          'in beiden Strafräumen zweiter Sieger.|'
      'Vorbei, zwei Tore Abstand, und {club} kam nach dem zweiten nie wirklich '
          'zurück.|'
      'Spielende, und eine Zwei-Tore-Niederlage für {club} gegen ein {opp}, das '
          'dort schärfer war, wo es zählte.',
  'report.loss.comfortable':
      'Der Schlusspfiff ist gefallen, und {club} ist deutlich geschlagen — drei '
          'Tore Abstand für {opp} am Ende.|'
      'Vorbei. Drei Tore Unterschied, und {club} verwaltete lange vor dem Ende '
          'nur noch.|'
      'Spielende, und ein ernüchternder Nachmittag für {club}, mit drei Toren '
          'geschlagen.',
  'report.loss.rout':
      'Vorbei, und es war eine Lehrstunde: {opp} legten {theirs} gegen {club} '
          'auf.|'
      'Schlusspfiff über einer Demontage. {theirs} für {opp}, {ours} für '
          '{club}, und niemand hat etwas zu beanstanden.|'
      'Spielende, und {club} ist auseinandergenommen worden — {theirs} '
          'kassiert, und es hätten mehr sein können.',

  // ── Wie der Gegner gespielt hat ──────────────────────────────────────────
  'report.opp.comeback':
      '{opp} sahen geschlagen aus und spielten nie so, und am Ende waren sie '
          'die Mannschaft, auf die man gesetzt hätte.|'
      'Respekt an {opp} — eine Zeit lang zweiter Sieger, und dann haben sie den '
          'Nachmittag gedreht.|'
      'Es sagt etwas über {opp}, dass ein Rückstand sie offenbar beruhigt hat.',
  'report.opp.rampant':
      '{opp} waren überragend, schnell in allem und gnadenlos bei jedem Fehler, '
          'der kam.|'
      'Das waren {opp} in Bestform, und wer für sie da war, wird die ganze '
          'Woche darüber reden.|'
      'Bei {opp} ging alles auf. Nicht viele Mannschaften hätten heute '
          'mitgehalten.',
  'report.opp.shut_us_out':
      '{opp} waren ohne Ball so gut wie mit ihm, und {club} fand nie einen Weg '
          'vorbei.|'
      'Zu null und die Punkte für {opp}, die ihren Strafraum von der ersten bis '
          'zur letzten Minute richtig verteidigt haben.|'
      '{opp} gaben {club} nichts zu arbeiten, und das erklärt den Sieg genauso '
          'wie alles, was vorne passierte.',
  'report.opp.clinical':
      'Es lag nicht viel zwischen den beiden; {opp} waren schlicht schärfer, '
          'als die Chancen kamen.|'
      '{opp} nahmen ihre Momente mit und {club} nicht, und das ist meistens '
          'schon alles.|'
      '{opp} mussten nicht die bessere Mannschaft sein, um das zu gewinnen — '
          'und weit davon entfernt waren sie ohnehin nicht.',
  'report.opp.fought_back':
      '{opp} lagen zurück und kamen immer wieder, und kaum jemand im Stadion '
          'würde den Punkt unverdient nennen.|'
      'Es brauchte Charakter von {opp}, um in dieses Spiel zurückzufinden.|'
      '{opp} wollten es nicht hinnehmen und haben sich ihren Anteil am '
          'Nachmittag hart erarbeitet.',
  'report.opp.stalemate':
      '{opp} standen genauso geordnet wie {club}, und keiner von beiden fand '
          'die Lücke.|'
      'Wenig zu unterscheiden — {opp} waren so schwer zu knacken wie {club}.|'
      '{opp} kamen für einen Punkt und verteidigten wie eine Mannschaft, die es '
          'ernst meinte.',
  'report.opp.matched':
      '{opp} hielten über lange Strecken mit {club} mit und werden das Ergebnis '
          'ganz ähnlich sehen.|'
      'Ehrliche, ausgeglichene Sache von {opp}, nie hinten und nie ganz '
          'vorne.|'
      'Es lag wenig zwischen ihnen, und {opp} werden nicht das Gefühl haben, '
          'hier etwas verloren zu haben.',
  'report.opp.outclassed':
      'Es war ein langer Nachmittag für {opp}, bei fast allem zweiter Sieger '
          'und nie in der Lage, ins Spiel zu finden.|'
      '{opp} werden das hier schnell vergessen wollen. Sehr wenig lief für '
          'sie.|'
      'Bei {opp} funktionierte kaum etwas, und der Abstand zwischen den beiden '
          'Mannschaften war lange vor dem Ende offensichtlich.',
  'report.opp.pushed':
      '{opp} ließen {club} dafür arbeiten und waren selbst nicht weit weg.|'
      '{opp} werden das Gefühl haben, genug von diesem Spiel gehabt zu haben, '
          'um etwas mitzunehmen.|'
      'Für {opp} lag hier mehr drin, als das Ergebnis ihnen gibt.',

  // ── Die Tore, als Thema statt als Chronik ────────────────────────────────
  'report.goals.opened':
      '{player} brachte {club} ins Rollen.|'
      'Es war {player}, der es für {club} eröffnete.|'
      '{player} erzielte die Führung, und {club} baute den Nachmittag darauf '
          'auf.',
  'report.goals.surge.ours':
      'Die zweite Halbzeit lief nur in eine Richtung. {club} traf nach der '
          'Pause nach Belieben, und {opp} hatten darauf keine Antwort.|'
      '{club} kam als andere Mannschaft aus der Kabine, und die Tore kamen so '
          'lange, bis {opp} aufhörten mitzuzählen.|'
      'Was in der Pause gesagt wurde, hat gewirkt: danach nahm {club} das Spiel '
          'weit weg von {opp}.',
  'report.goals.surge.theirs':
      '{opp} nahmen die zweite Halbzeit auseinander. Zur Pause war {club} noch '
          'drin und am Ende nicht einmal in der Nähe.|'
      'Die Pause änderte alles zum Schlechteren: {opp} trafen danach wieder und '
          'wieder, und {club} konnte nichts davon aufhalten.|'
      '{club} kam aus der Kabine und wurde überrollt. {opp} kannten nach dem '
          'Seitenwechsel keine Gnade.',

  // ── Die Bilanz des Spiels, ohne eine einzige Zahl ────────────────────────
  //
  // Die ersten beiden dürfen den Ballbesitz nicht behaupten: sie greifen auch
  // über eine einzige Achse, und {club} kann den Ball gehabt haben und trotzdem
  // zweiter Sieger gewesen sein.
  'report.stats.on_top':
      '{club} hatte das Bessere an diesem Spiel und sah fast durchgehend nach '
          'der gefährlicheren Mannschaft aus.|'
      'Das war ein Spiel zum Kontrollieren für {club}, und {club} kontrollierte '
          'es. {opp} liefen einen großen Teil hinterher.|'
      '{club} bestimmte den größten Teil der neunzig Minuten, und {opp} sahen '
          'selten so aus, als könnten sie daran etwas ändern.',
  'report.stats.pinned_back':
      '{club} verteidigte einen großen Teil des Spiels, und {opp} waren die, '
          'die nach einem Tor aussahen.|'
      '{opp} hatten das Bessere daran schon früh, und {club} kam kaum darunter '
          'hervor.|'
      'Eine Mannschaft war hier oben auf, und es war nicht {club}. {opp} trugen '
          'ihnen das Spiel entgegen.',
  'report.stats.ball_only':
      '{club} hatte reichlich Ball und herzlich wenig davon zu zeigen. {opp} '
          'verteidigten ihren Strafraum und waren damit zufrieden.|'
      'Aller Ballbesitz der Welt für {club}, und die Chancen, die damit kamen, '
          'waren nicht viel wert.|'
      '{club} hielt den Ball, und {opp} hielten {club} von allem fern, wo er '
          'wehgetan hätte.',
  'report.stats.counter':
      '{opp} hatten den Ball und {club} die Momente, was ebenso eine Spielweise '
          'wie ein Zufall ist.|'
      '{club} ließ {opp} kommen und machte weit mehr aus dem, was sich bot.|'
      'Der Ballbesitz ging in die eine Richtung und die klaren Chancen in die '
          'andere. {club} wird das überhaupt nicht stören.',
  'report.stats.even':
      'Es lag sehr wenig zwischen ihnen, mit Ball wie ohne.|'
      '{club} und {opp} waren so ebenbürtig, wie der Nachmittag vermuten '
          'lässt.|'
      'Weder {club} noch {opp} hatten lange genug genug vom Spiel, um es ihr '
          'eigenes zu nennen.',

  // ── Die Schlussphase, von der anderen Bank aus ───────────────────────────
  //
  // `{chaser}` ging als Verfolger in die Schlussphase und `{holder}` in Führung,
  // damit der Satz von beiden Seiten aus trägt.
  'report.late.held_out':
      '{chaser} warf in der Schlussphase alles nach vorn und fand keinen Weg '
          'durch.|'
      'Die Schlussphase gehörte ganz {chaser}, und {holder} hielt stand.|'
      '{chaser} drückte und drückte auf den Treffer, und er kam nie.',
  'report.late.consolation':
      '{chaser} schob spät alles nach vorn und holte ein Tor heraus, und viel '
          'mehr nicht.|'
      'Das späte Tor gab {chaser} etwas für den Aufwand und sah nie danach aus, '
          'zu reichen.|'
      '{chaser} traf am Ende einer langen Druckphase, und {holder} hatte da das '
          'Schwerste längst erledigt.',

  // ── Die Bank ─────────────────────────────────────────────────────────────
  'report.subs.impact':
      '{player} kam von der Bank und machte für {club} den Unterschied.|'
      'Der Wechsel von {club} hat gewirkt: {player} kam und traf.|'
      'Die Bank hat sich selbst bezahlt gemacht — {player} kam und traf für '
          '{club}.',
  'report.subs.changes':
      '{club} spielte die Wechsel durch, auf der Suche nach irgendetwas.|'
      '{club} leerte die Bank, um ins Spiel zu finden.|'
      'Bei {club} kam Wechsel auf Wechsel, ohne dass sich an einem davon viel '
          'gedreht hätte.',

  // ── Der Schiedsrichter ───────────────────────────────────────────────────
  //
  // Ohne Minute: was zählt, ist dass sie mit einem Mann weniger zu Ende
  // gespielt haben.
  'report.cards.our_red_named':
      '{player} sah Rot, und {club} beendete das Spiel mit weniger Leuten, als '
          'es begonnen hatte.|'
      'Die Rote Karte für {player} ließ {club} den Rest des Spiels in '
          'Unterzahl.',
  'report.cards.our_booked_many':
      '{n} Spieler von {club} sahen Gelb: {names}.|'
      'Der Schiedsrichter verwarnte {names} bei {club}, {n} Karten insgesamt.',
  'report.cards.their_reds':
      '{opp} hatten {n} Platzverweise und beendeten das Spiel weit von einer '
          'kompletten Mannschaft entfernt.|'
      '{n} Rote Karten für {opp}, die alles danach geprägt haben.',

  // ── Die Planänderungen ───────────────────────────────────────────────────
  //
  // Ohne Minute und ohne den Namen der Ausrichtung: eine Entscheidung, keine
  // Einstellung. `{minute}` und `{tactic}` kommen weiter an und bleiben hier
  // ungenutzt.
  'report.tactic.shut_up_shop':
      '{club} ließ sich für die Schlussphase fallen und machte sich daran, das '
          'Erreichte zu schützen.|'
      'Spät machte {club} hinten dicht, lud {opp} ein und traute sich zu, es '
          'nach Hause zu bringen.|'
      '{club} zog für den Rest alles hinter den Ball und spielte den Nachmittag '
          'so zu Ende.',
  'report.tactic.went_for_it':
      '{club} schob für die Schlussphase Leute nach vorn und nahm das Risiko in '
          'Kauf, das damit kam.|'
      'Spät ging {club} ins Risiko und rückte gegen {opp} auf, statt sich mit '
          'dem Erreichten zufriedenzugeben.|'
      '{club} setzte auf den Rest alles und schickte Körper nach vorn.',
  'report.tactic.settled':
      '{club} stellte für die Schlussphase um und beendete das Spiel in dieser '
          'Ordnung.|'
      'Eine späte Umstellung von {club} prägte, wie der Nachmittag zu Ende '
          'ging.|'
      '{club} ordnete sich für den Rest neu und brachte das Spiel so zu Ende.',
  // ── Die Tabelle, und die Übereinstimmung mit der Zahl ────────────────────
  //
  // "1 Plätze" und "1 Punkten", dieselbe Falte, die auf Englisch gemeldet
  // wurde. Im Deutschen hilft kein angehängtes `s`: Platz/Plätze und
  // Punkt/Punkte ändern den Stamm. Also ist beides so umformuliert, dass gar
  // kein gezähltes Substantiv mehr danebensteht — "um {n} auf Rang {pos}"
  // stimmt für jede Zahl, und der Punktestand wird genannt statt gezählt.
  'report.table.climbed':
      'Das hebt {club} um {n} auf Rang {pos}, Punktestand {pts}.|'
      'Um {n} hoch auf Rang {pos}, mit einem Punktestand von {pts}.|'
      'Jetzt Rang {pos} für {club}, um {n} besser als vorher, Punktestand '
          '{pts}.',
  'report.table.dropped':
      'Es kostet {club} {n} Ränge — Rang {pos}, Punktestand {pts}.|'
      'Um {n} runter auf Rang {pos}, mit einem Punktestand von {pts}.|'
      'Rang {pos} und fallend, um {n} schlechter, Punktestand {pts}.',
  'report.table.held':
      'Weiter Rang {pos}, jetzt mit einem Punktestand von {pts}.|'
      'Rang {pos}, unverändert, Punktestand {pts}.|'
      'Keine Bewegung — Rang {pos}, Punktestand {pts}.',

  // The settings screen's small print — see `en_copy.dart`.
  'settings.cutaways.hint':
      'Fällt eine Chance an eine eingeschaltete Seite, blendet das Spiel auf '
          'den Platz um und spielt den Moment aus — danach kannst du ihn '
          'wiederholen.',
  'settings.matchSpeed.auto': 'Auto',
  'settings.matchSpeed.hint':
      'Auto läuft mit 2x und fällt auf halbe Geschwindigkeit, sobald der Trainer '
          'etwas zu sagen hat — Zeit genug, es zu lesen und zu reagieren.',

  // The training list's ceiling — see `en_copy.dart`.
  'training.up_to': 'Bis zu',

  // Die pausierende Einheit und der Anstoß-Countdown — siehe `en_copy.dart`.
  'training.resting': 'Abklingzeit {time}',
  'mg.countdown_go': 'LOS!',

  // Shop: das Regal ist nicht mehr gratis, und die Einnahmen ziehen aus den
  // Boosts aus — siehe `en_copy.dart`.
  'shop.lucky_boot_name': 'Glücksschuh',
  'shop.lucky_boot_desc': 'Nächster Gegner ein Spiel lang {pct}% schwächer',
  'shop.section.income': 'Einnahmen',
  'product.energy_director.desc': '+50 Energie sofort · Cap auf 15 · Aufladung {energyPct}% schneller — für immer, auch nach Resets!',

  'shop.section.looks': 'Manager-Stil',

  // Colin relays an offer and calls it; then his tour after the tutorial.
  'coach.bid.relay': '{club} haben angerufen, Chef. Sie wollen {player} und legen {price} auf den Tisch.',
  'coach.sponsor.relay': '{company} haben sich gemeldet, Chef. Sie wollen {player} als Gesicht ihrer Marke: {n}% mehr Einnahmen durch diesen Spieler, solange der Deal läuft.',
  'coach.verdict.accept': 'Mein Rat: annehmen',
  'coach.verdict.decline': 'Mein Rat: ablehnen',
  'coach.verdict.your_call': 'Mein Rat: kann so oder so ausgehen',
  'manager.transfer.starter_short': '{player} steht jede Woche in der Startelf und auf der Bank sitzt niemand, der einspringen könnte. Lehn ab, es sei denn, du scoutest direkt danach Ersatz.',
  'manager.transfer.relegation': 'Wir stehen in der Abstiegszone und {player} steht in der Elf. Jetzt zu verkaufen schwächt uns genau dann, wenn wir es uns nicht leisten können.',
  'manager.transfer.flying': 'Wir sind Tabellenführer und die Kasse ist voll. Wir brauchen dieses Geld nicht: Halt den Kader zusammen.',
  'manager.transfer.need_money': 'Ehrlich gesagt sind wir pleite. Diese Summe zahlt einen kompletten Neuzugang, und wir brauchen die Münzen mehr als {player}.',
  'manager.transfer.bench_warmer': '{player} steht nicht mal in deiner Elf, und der Preis ist fair. Nimm das Geld und verstärke dich, wo es zählt.',
  'manager.sponsor.clean': 'Kein Haken bei diesem hier. Unterschreib: Das ist geschenktes Geld.',
  'manager.sponsor.relegation_starter': '{player} steht in der Elf und wir sind in der Abstiegszone. Ein schwächerer Stammspieler ist das Letzte, was wir brauchen: Lehn ab.',
  'manager.sponsor.injury_prone': '{player} hat schon {seasons} Saisons in den Beinen und dieser Deal erhöht das Verletzungsrisiko. Nicht wert.',
  'manager.sponsor.poor_form': 'Die Form von {player} ist schon schlecht und dieser Deal drückt sie weiter. Sag nein.',
  'manager.sponsor.need_money': 'Uns fehlen Münzen und das hier zahlt jede Sekunde. Den Haken ist es wert: Unterschreib.',
  'manager.sponsor.bench': '{player} steht nicht in deiner Elf, also kostet uns der Haken auf dem Platz nichts. Unterschreib.',
  'manager.sponsor.rating_cost': 'Es kostet {player} {n} Bewertung, und das ist ein Stammspieler. Mehr Einnahmen gegen eine schwächere Elf: deine Entscheidung.',
  'manager.sponsor.fair': 'Der Haken ist klein, die Einnahmen nicht. Ich würde unterschreiben.',
  'guide.scout': 'Tipp auf Scouten, um jemand Neues zu holen. Zwei vom gleichen Typ, zusammengezogen, fusionieren zu einem besseren Spieler.',
  'guide.squad_tab': 'Gut. Öffne jetzt den Tab {tab} und stell deine beste Elf auf den Platz.',
  'guide.squad_fill': 'Tipp auf einen leeren Platz, um auszuwählen, wer dort spielt, oder drück Auto und ich stelle die Elf für dich auf.',
  'guide.dugout': 'Siehst du das Menü unten rechts? Das ist der Dugout: Training und Tabelle sind da drin.',
  'guide.club_tab': 'Das Stadion verdient auch Geld. Schau mal in den Tab {tab}.',
  'guide.club_buy': 'Kauf hier eine Einrichtung. Jede, die du besitzt, erhöht, was der Verein jede Sekunde verdient.',
  'guide.shop_tab': 'Knapp an Energie oder Münzen? Der Tab {tab} hat Packs und Boosts, wenn du sie brauchst.',

  // ── Commentary pools the spec's own catalogues never widened ───────────
  //
  // English grew these `commentary.*` pools over time; the translated
  // locales stayed at the original length. Existing lines are kept
  // verbatim; new lines fill the gap so every locale draws from the same
  // number of variants. `commentary.opp_sub`'s original single variant was
  // itself untranslated English in every locale — replaced here too.
  'commentary.blocked': '{who} sehen den Schuss geblockt!|{who} ziehen von der Strafraumkante ab, und ein Körper wirft sich dazwischen — so verdient ein Verteidiger sein Geld.|Drei Trikots von {who} stehen für den Nachschuss bereit — und einer nach dem anderen wird geblockt.|Ein Schuss von {who} aus zwölf Metern wird von einem Bein geblockt, das aus dem Nichts kam.|{who} kommen wieder ran und schießen erneut — und wieder steht ein Körper im Weg.|Direkt im Ansatz geblockt, {who} müssen den Angriff neu aufziehen.|Die Abwehr wirft sich vor alles, was {who} finden.',
  'commentary.booking.opp_red': 'Glatt Rot für {opp}, und niemand im Stadion widerspricht — {opp} sind nur noch zu zehnt.|Ein furchtbares Foul eines {opp}-Spielers, und der Schiedsrichter greift direkt zu Rot. {opp} sind einen Mann weniger.|Ein {opp}-Spieler muss vom Platz. Da gab es für den Schiedsrichter keine andere Entscheidung.|Rote Karte für {opp}, und ihre Bank hat dazu nichts zu sagen. Nur noch zu zehnt.',
  'commentary.booking.opp_second_yellow': 'Gelb-Rot für {opp}, und der Spieler muss runter — sie haben sich den Nachmittag selbst schwer gemacht.|Das ist die zweite Verwarnung für denselben {opp}-Spieler, der Schiedsrichter muss ihn vom Platz stellen. {opp} nur noch zu zehnt.|Zwei Verwarnungen für denselben {opp}-Spieler, der Schiedsrichter stellt ihn vom Platz. {opp} spielen den Rest zu zehnt.|Die zweite Verwarnung für {opp}, das bedeutet Rot. Sie haben sich das selbst schwer gemacht.',
  'commentary.booking.opp_yellow': 'Ein {opp}-Trikot geht wegen eines zynischen Beinstellers ins Buch — der Schiedsrichter hatte genug davon gesehen.|{opp} verschenken einen unnötigen Freistoß und kassieren dazu Gelb.|Verwarnung für {opp}, und ihre Bank ist damit gar nicht einverstanden.|Ein {opp}-Spieler sieht Gelb, weil er einen Läufer zurückreißt — der Schiedsrichter hatte keine Wahl.|Zu spät und ungestüm von {opp}, die Gelbe Karte ist da noch das Wenigste.',
  'commentary.booking.red': 'Glatt Rot für {player}, und da gibt es nichts zu diskutieren — letzter Mann, und er räumt ihn ab. {us} beenden das Spiel zu zehnt.|{player} verliert völlig die Nerven, und der Schiedsrichter zögert keine Sekunde. Runter. {us} müssen den Rest zu zehnt überstehen.|{player} muss runter. Ein Einsteigen ohne jeden Versuch, den Ball zu spielen — {us} beenden das Spiel zu zehnt.|Der Schiedsrichter greift bei {player} direkt in die Tasche — Rot. {us} sind nur noch zu zehnt.',
  'commentary.booking.second_yellow': 'Und das ist Gelb-Rot für {player} — nichts Böses dabei, aber er war schon verwarnt und wusste es. {us} sind nur noch zu zehnt.|{player} steigt noch einmal ein, und dem Schiedsrichter bleibt nichts übrig: zwei Verwarnungen, runter. {us} spielen den Rest in Unterzahl.|Zwei Gelbe für {player}, und das ist ein langer Weg zurück in die Kabine. {us} spielen den Rest zu zehnt.|{player} sieht erneut Gelb, und Rot folgt zwingend. {us} sind einen Mann weniger.',
  'commentary.booking.yellow': '{player} sieht Gelb wegen Zeitspiels — die erste an diesem Nachmittag, jetzt muss er aufpassen.|Ein zu spätes Einsteigen von {player}, und der Schiedsrichter hat die Karte draußen, ehe er wieder steht.|{player} hält das Trikot, um den Konter zu stoppen. Da gibt es nur eine Entscheidung: Gelb.|Meckern von {player} — von allen dummen Arten, ins Buch zu kommen.|{player} kommt zu spät ins Tackling, dem Schiedsrichter bleibt keine Wahl — Gelb.|Ein Beinstellen von {player} auf der Mittellinie, und die Karte kommt raus.|{player} kommt ins Buch für ein Foul, das die Sache nicht wert war.',
  'commentary.demolition': '{us}–{them} — was für eine Vorstellung! Wir haben {opp} zerlegt. Die Jungs werden tagelang strahlen.|{us}–{them}. Alles, was wir versucht haben, ist aufgegangen, und {opp} hatten darauf keine Antwort.|Besser haben wir noch nie gespielt. {us}–{them} gegen {opp} — genießt den Moment.|{us}–{them}! Mehr konnte ich heute von ihnen nicht verlangen.|Wir waren gnadenlos. {us}–{them}, und {opp} waren froh, als der Schlusspfiff kam.',
  'commentary.dispossessed': '{who} werden abgegrätscht — starke Grätsche!|{who} machen im Strafraum einen Kontakt zu viel, und der Tackling ist blitzsauber.|{who} suchen den Pass, den es vor einer Sekunde noch gab — und die Kugel ist ihnen vom Fuß gestochen worden.|Ein perfekt getimtes Tackling beendet den Angriff von {who}.|{who} werden am Strafraumrand von einem Tackling aus dem Nichts beraubt.|Der Ball wird {who} genau in dem Moment abgeluchst, in dem der Schuss kommen sollte.|{who} trödeln am Ball und bezahlen für die eine Sekunde zu viel.',
  'commentary.drubbing': 'Hässliche Geschichte. {us}–{them} bei {opp}. Schüttelt es ab — jede Mannschaft hat mal einen schlechten Tag.|{us}–{them} bei {opp}. Nichts ist gelaufen, und ich tue nicht so, als wäre es anders gewesen.|Das war eine klare Abreibung, ganz einfach. {us}–{them}. Wir haken das ab und machen weiter.|{us}–{them}. {opp} waren uns in jeder Phase überlegen. Sowas passiert.|Zu {us}–{them} gibt\'s nicht viel zu sagen. Schlechter Tag, kurzes Gedächtnis, nächstes Spiel.',
  'commentary.flow.addedtime.0': 'Drama in der Nachspielzeit!|Nachspielzeit, und hier ist noch nichts entschieden.|Ganz späte Dramatik zum Ende dieser Partie.|In diesen letzten Sekunden passiert einfach alles.',
  'commentary.flow.addedtime.1': 'Halten bis tief in die Nachspielzeit.|Tief in der Nachspielzeit, und hier wird sich mit allem festgeklammert.|Jetzt wird jede Sekunde mitgenommen, und auf der Bank beschwert sich niemand.|Hier zählt nur noch die Uhr.',
  'commentary.flow.addedtime.2': 'Die Tafel des vierten Offiziellen geht hoch — Nachspielzeit läuft.|Die Tafel geht hoch, und es wird noch weitergespielt.|Der vierte Offizielle zeigt die Nachspielzeit an, und es sind mehr Minuten als erwartet.|Die Nachspielzeit steht fest, und keine der beiden Bänke ist von der Zahl begeistert.',
  'commentary.flow.addedtime.3': 'Noch Zeit für eine letzte Chance.|Es bleibt Zeit für einen letzten Angriff.|Noch ein letzter Ball in den Strafraum, das muss doch drin sein.|Vorbei ist es noch nicht — da geht noch was.',
  'commentary.flow.closing.0': 'In die Schlussphase!|Noch zehn Minuten, und hier wird es entschieden.|Die Uhr läuft runter, und die Nervosität steigt.|Rein in die letzten zehn Minuten, und beide Bänke stehen.',
  'commentary.flow.closing.1': 'Jeder Zweikampf zählt jetzt.|Jeder Zweikampf wird geführt, als wäre es der letzte der Saison.|Hier wird auf dem ganzen Feld nichts mehr geschenkt.|Auf beiden Seiten wird sich mit allem reingeworfen.',
  'commentary.flow.closing.2': 'Halten sie das?|Die Frage ist jetzt, ob sich das über die Zeit bringen lässt.|Die Beine werden schwer, und auf der Uhr steht noch Zeit.|Hier wird mit allem verteidigt, und es bleiben noch Minuten.',
  'commentary.flow.closing.3': 'Letzter Versuch des Gegners.|Der letzte Wechsel ist gemacht — von hier an geht alles nach vorn.|Ein Innenverteidiger steht jetzt vorn. So steht es um die Lage.|Es ist der letzte Sturmlauf, und da wird nichts mehr zurückgehalten.',
  'commentary.flow.closing.4': 'Nervosität rund um den Platz.|Die Nervosität ist hier deutlich zu spüren.|Jeder Fehlpass wird mit einem Stöhnen quittiert.|Die Fans pfeifen schon aufs Ende.',
  'commentary.flow.firstA.0': 'Dein Team gewinnt an Selbstvertrauen.|Das Selbstvertrauen wächst, und die Pässe kommen dadurch schneller.|Eine ruhige Phase — eine Mannschaft hat das Mittelfeld übernommen.|Das Passspiel hat jetzt einen richtigen Rhythmus.',
  'commentary.flow.firstA.1': 'Kurzdistanz-Schuss — knapp daneben!|Ein schneller Abschluss aus acht Metern, und der geht nur um Zentimeter am Pfosten vorbei.|Ein Gewühl im Fünfer, und der Ball rutscht über einen Verteidiger knapp vorbei.|Ein Kopfball aus kurzer Distanz, und der fällt knapp am Pfosten vorbei.',
  'commentary.flow.firstA.2': 'Schöne Kombi auf der linken Seite.|Drei Pässe über links, alle direkt gespielt, und die Flanke ist fast perfekt.|Schönes Spiel über rechts, und der Außenverteidiger kommt außen durch.|Ein Doppelpass an der Seitenlinie öffnet für einen Moment das ganze Feld.',
  'commentary.flow.firstA.3': 'Keeper faustet eine Ecke weg.|Die Ecke kommt scharf rein, und der Keeper kommt raus und pflückt sie über allen anderen runter.|Ein langer Standard sorgt kurz für Panik, ehe geklärt wird.|Ecke um Ecke jetzt, und die Abwehr bekommt immer wieder den Kopf dran.',
  'commentary.flow.firstB.0': 'Gefährlicher Freistoß steht an...|Ein Freistoß aus übler Position, zweiundzwanzig Meter zentral vor dem Tor.|Die Mauer wird aufgestellt, und das ist eine echte Chance.|Ein Foul am Strafraumrand, und hier bietet sich eine richtige Möglichkeit.',
  'commentary.flow.firstB.1': 'Keeper gefordert — starke Parade!|Ein satter Schuss aus der Distanz, und der Keeper hält ihn erst im zweiten Versuch fest.|Starke Parade, flach nach links, und der Abpraller wird gerade noch geklärt.|Der Keeper kommt schnell aus dem Tor und erstickt den Ball am Fuß des Stürmers.',
  'commentary.flow.firstB.3': 'Schuss auf der Linie geblockt!|Auf der Linie geklärt, und im ganzen Stadion weiß keiner, wie.|Ein Körper wirft sich vor den Schuss, und der Block lenkt ihn zur Ecke ab.|Geblockt, und beim Abpraller nochmal geblockt — das ist verzweifelte Abwehrarbeit.',
  'commentary.flow.open.0': 'Anpfiff! Beide Teams tasten sich ab.|Und los geht\'s. Beide Mannschaften finden erst ins Spiel.|Der Schiedsrichter gibt den Anstoß frei, und die ersten Pässe kommen vorsichtig.|Los geht\'s. Keine der beiden Mannschaften will in den ersten Minuten etwas herschenken.',
  'commentary.flow.open.1': 'Frühe Pressing aus dem Mittelfeld.|Bislang wird das Spiel im Mittelfeld entschieden.|Die erste Ballbesitzphase, und das erste echte Terrain des Nachmittags.|Beide Mannschaften pressen hoch, und noch hat sich keiner am Ball beruhigt.',
  'commentary.flow.open.2': 'Die Fans sind schon laut.|Das Stadion ist schon wach, und es sind noch keine zehn Minuten gespielt.|Ein großer Lärm im Rund, sobald der Ball nach vorne geht.|Die Stimmung hier baut sich schon seit dem Aufwärmen auf.',
  'commentary.flow.secondA.0': 'Zweite Halbzeit läuft — dein Team drückt nach vorn.|Zurück aus der Kabine, und schon jetzt ist mehr Dringlichkeit im Spiel.|Der Wiederanpfiff bringt ein anderes Tempo — schneller als in der ersten Halbzeit.|Zweite Halbzeit, und was in der Pause gesagt wurde, ist offensichtlich angekommen.',
  'commentary.flow.secondA.1': 'Die taktische Umstellung scheint zu greifen.|Die Formation hat sich verändert, und dadurch öffnen sich Räume.|Eine Umstellung von der Bank, und die zeigt Wirkung.|Jemand ist nach innen gerückt, und das Feld wirkt dadurch größer.',
  'commentary.flow.secondA.2': 'Jetzt geht es hin und her.|Das Spiel ist komplett offen — es geht nur noch hin und her.|Keine der beiden Mannschaften will den Ball noch lange behalten.|Jede Klärung kommt sofort zurück, und niemand bekommt das Spiel beruhigt.',
  'commentary.flow.secondA.3': 'Physio kommt für einen Schlag aufs Feld.|Der Physio kommt rein, ein Spieler liegt am Boden und braucht Behandlung.|Unterbrechung, während ein Schlag am Spielfeldrand untersucht wird.|Behandlung auf dem Platz, und das wird am Ende draufgeschlagen.',
  'commentary.flow.secondB.0': 'Mittelfeldschlacht heizt sich auf.|Im Zentrum fliegen jetzt die Grätschen.|Niemand gewinnt das Mittelfeld, aber jeder kämpft darum.|Aus dem Mittelfeld ist eine echte Schlacht geworden.',
  'commentary.flow.secondB.1': 'Distanzschuss — direkt auf den Keeper.|Dreißig Meter raus, und er zieht ab — der Keeper hält ihn locker fest.|Der Ball senkt sich aus der Distanz, landet aber genau in den Armen des Keepers.|Ambitioniert aus weiter Entfernung, aber nie wirklich gefährlich fürs Tor.',
  'commentary.flow.secondB.2': 'Brillanter Doppelpass im Strafraum, gerade noch geklärt!|Ein Doppelpass reißt die Abwehr auf, und die letzte Berührung kommt vom Bein eines Verteidigers.|Wunderbar herausgespielt im Strafraum, und im letzten Moment weggegrätscht.|Zwei Pässe, und die Abwehrkette war geschlagen — aber die Klärung kommt doch noch.',
  'commentary.forces_save': '{who} erzwingt eine Parade!|{who} verlagern nach außen und flanken — der Keeper kratzt sie im Hechtsprung weg.|Ein schneller Doppelpass am Strafraumrand von {who}, und der Schuss wird flach zum kurzen Pfosten abgewehrt.|{who} kontern mit drei gegen zwei, und nur eine Fußabwehr hält den Ball draußen.|Der Ball fällt {who} aus acht Metern vor die Füße — und irgendwie ist der Torhüter dahinter.|{who} kommen aus spitzem Winkel zum Schuss, und der Keeper lenkt ihn am Pfosten vorbei.|Ein Kopfball nach einer Ecke von {who} wird irgendwie auf der Linie gehalten.|{who} spielen ihn flach quer durchs Tor, und der Keeper bekommt eine starke Hand dahinter.',
  'commentary.goal.equalise.no_scorer': '{us} gleichen aus!|{us} ziehen gleich!|{us} sind dran — alles offen!|Spiel ist offen! {us} gleichen aus!|{us} finden den Ausgleich!|{us} sind wieder dran!|Alles wieder offen — {us} haben ihn!|{us} stellen den Ausgleich her!',
  'commentary.goal.equalise.with_scorer': '{scorer} gleicht für {us} aus!|Zurück im Spiel — {scorer} drischt für {us} ein!|{scorer} antwortet — {us} sind dran!|Spiel ist offen! {us} gleichen durch {scorer} aus.|{scorer} findet einen Weg durch — {us} sind wieder dran!|Alles ausgeglichen! {scorer} mit dem Abschluss für {us}!|{scorer} macht ihn rein — {us} haben ausgeglichen!|Mitten durchs Zentrum des Tores von {scorer}, und {us} sind ausgeglichen!',
  'commentary.goal.extend.no_scorer': '{us} legen nach!|{us} bauen die Führung aus!|{us} stürmen!|{us} ziehen davon!|{us} legen noch einen nach!|{us} ziehen davon!|Denen läuft das Spiel davon — schon wieder {us}!|{us} drehen die Daumenschrauben weiter!',
  'commentary.goal.extend.with_scorer': '{scorer} legt für {us} nach!|Zweikontakt-Finish von {scorer} — {us} bauen aus!|{scorer} verdoppelt — {us} stürmen!|Eiskalt von {scorer} — {us} ziehen davon!|{scorer} bringt {us} außer Reichweite!|Noch einer für {us}, und {scorer} macht ihn!|Schon wieder {scorer} — {us} drehen weiter auf!|{us} sind kaum zu stoppen, und {scorer} steht mittendrin!',
  'commentary.goal.lead.no_scorer': '{us} gehen in Führung!|{us} liegen vorn!|{us} brechen den Bann!|{us} ziehen vor!|{us} liegen vorn!|Der Durchbruch — {us} führen!|{us} erzielen den Führungstreffer!|Der erste Treffer geht an {us}!',
  'commentary.goal.lead.with_scorer': '{scorer} bringt {us} in Führung!|Was für ein Schuss von {scorer}! {us} vorn!|{scorer} bricht den Bann für {us}!|Eingeschoben von {scorer} — {us} führen!|{scorer} erzielt den Durchbruch — {us} liegen vorn!|{us} führen, und {scorer} war es, der es gemacht hat!|Ein Abschluss aus dem Nichts von {scorer}, und {us} liegen vorn!|{scorer} trifft ins Netz — Vorteil {us}!',
  'commentary.goal.pullback.no_scorer': '{us} markieren einen!|{us} schnappen sich einen Rettungsanker!|{us} sind zurück im Spiel!|{us} bekommen Halt!|{us} verkürzen!|Ein Tor für {us} — da ist wieder ein Spiel!|{us} verkleinern den Rückstand!|Noch nicht vorbei — {us} treffen!',
  'commentary.goal.pullback.with_scorer': '{scorer} verkürzt für {us}!|Hoffnung! {scorer} trägt sich für {us} ein!|{scorer} hält {us} im Spiel!|{scorer} verwandelt für {us}!|{scorer} gibt {us} wieder etwas, woran sie sich festhalten können!|Ein Anschlusstreffer für {us} durch {scorer} — hier ist wieder ein Spiel!|{scorer} trifft, und {us} sind noch nicht fertig!|Etwas Hoffnung für {us}, und {scorer} liefert sie!',
  'commentary.halftime_ahead': '{us} führen zur Pause!|{us} gehen mit einer Führung in die Kabine.|Halbzeit, und {us} liegen vorn.|{us} gehen mit Vorsprung rein — in der zweiten Hälfte geht es ums Verwalten.',
  'commentary.halftime_behind': '{us} liegen zurück — jetzt reagieren.|Halbzeit, und {us} haben Arbeit vor sich.|{us} liegen zur Pause zurück, da muss sich etwas ändern.|Eine Halbzeit zum Vergessen für {us}, und fünfundvierzig Minuten, um es geradezubiegen.',
  'commentary.halftime_level': 'Unentschieden zur Halbzeit.|Zur Pause trennt die beiden nichts.|Alles ausgeglichen zur Halbzeit.|Unentschieden nach fünfundvierzig Minuten, und es ist völlig offen.',
  'commentary.high_scoring_loss': 'Offenes Spiel. {us}–{them} bei {opp}. Wir haben einiges getroffen — nur einen zu viel kassiert.|{us}–{them} bei {opp}. Auf der einen Seite reichlich, auf der anderen viel zu viel.|Wir waren nie ganz draußen aus dem Spiel, aber auch nie wirklich sicher. {us}–{them}.|{us}–{them}. Toreschießen ist nicht unser Problem. Das Verhindern schon.|Das hat allen Spaß gemacht, außer mir. {us}–{them}, und nächste Woche verteidigen wir besser.',
  'commentary.high_scoring_win': 'Tolles Spiel. {us}–{them} gegen {opp} — Tore überall, aber wir holen das Ergebnis. So abzuschließen ist einen Sponsor-Anruf wert.|{us}–{them} gegen {opp}. Hin und her, herzrasend, und drei Punkte.|Wir haben reichlich getroffen und auch einiges kassiert. {us}–{them}, und das nehme ich mit.|{us}–{them}! Die Offensive war nicht zu halten. Über die Abwehr reden wir noch.|Ein Schlagabtausch mit {opp}, {us}–{them}, und wir hatten das letzte Wort.',
  'commentary.hit_post': '{who} treffen den Pfosten!|{who} ziehen mit voller Wucht ab, und das ganze Stadion hört den Pfosten.|Der Ball springt von einem Verteidiger hoch, fällt für {who} unter die Latte — und klatscht im Herausfallen ans Aluminium.|{who} lassen den langen Pfosten aus zwanzig Metern erzittern, und der Ball bleibt draußen.|Die Latte rettet — {who} waren nur einen Zentimeter vom Tor entfernt.|Ein Kopfball von {who} knallt an die Latte und springt auf der falschen Seite der Linie runter.|Innenpfosten und die Linie entlang — {who} können es nicht fassen.',
  'commentary.injury': '{player} muss verletzt raus!|{player} kann nicht weitermachen — das ist ein herber Verlust.|{player} bleibt stehen und winkt zur Bank. Der Nachmittag ist für ihn vorbei.|{player} geht zu Boden, und das sieht nicht so aus, als würde er selbst vom Platz gehen.',
  'commentary.nervy_one_nil': 'Ein 1–0 gegen {opp}. Nicht hübsch, aber drei Punkte sind drei Punkte. Zu null gespielt, einsacken, weiter.|1–0. Wir hätten es uns nicht so schwer machen müssen, aber ein Sieg gegen {opp} ist ein Sieg.|Zu null gespielt und drei Punkte gegen {opp}. Im April erinnert sich keiner mehr daran, wie.|Ein zerfahrenes 1–0. Die guten Mannschaften gewinnen solche Spiele, da beschwere ich mich nicht.|Ein Tor hat gegen {opp} gereicht. Das hat sich die Abwehr verdient.',
  'commentary.nil_nil': 'Null-null gegen {opp}. Trister Nachmittag — Punkt mitnehmen und nächstes Mal mehr versuchen.|Null zu null gegen {opp}. Darüber wird niemand reden, aber ein Punkt ist ein Punkt.|Immerhin zu null gespielt. {opp} haben von uns nichts bekommen, und wir von ihnen auch nicht.|Torlos gegen {opp}. Wir hätten bis Mitternacht spielen können und trotzdem nicht getroffen.|Ein Punkt, zu null gespielt, und sehr lange neunzig Minuten gegen {opp}.',
  'commentary.opp_goal': '{them} treffen!|Was für ein Tor von {them}!|Saubere Kombi von {them} — direkt rein.|{them} bestrafen einen Schlampigkeitsmoment in der Abwehr.|{them} fädeln einen ein — eiskalte Vollendung.|Verteidigung schläft — {them} schlagen zu.|Knaller von {them}, der Keeper konnte nichts machen.|Glücklich für {them}, aber zählt.|{them} treffen ins Eck — Weltklasse.|Eine Ecke, die keiner angreift, ein Kopfball, den keiner stört — und {them} bekommen ihn geschenkt.|{them} spielen den Außenspieler frei und schieben am kurzen Pfosten ein.|Ein Abfälscher vom Schuh bringt alle aus dem Tritt, und {them} haben ihn.|Ein Pass reißt die Abwehrkette auf, und {them} erledigen den Rest.|{them} kommen an einer Flanke zum Kopfball, die niemals hätte reinkommen dürfen.|Ein langer Ball, ein Abtropfer, und {them} sind durch und vollenden.',
  'commentary.opp_sub': '{opp} wechselt — frische Beine von der Bank.|Wechsel bei {opp} — frische Beine kommen rein.|{opp} greift auf die Bank zurück.|{opp} nehmen einen Wechsel vor, und der Neue geht direkt in die Spitze.|Ein müdes {opp}-Trikot geht raus, ein ausgeruhtes kommt rein.',
  'commentary.shot_over': '{who} jagen ihn drüber!|{who} legen zurück in den Strafraum und ziehen ab — und setzen ihn auf den Oberrang.|Ein Meter Raum hätte {who} gereicht, und aus zwölf Metern geht er weit drüber.|{who} haben das ganze Tor vor sich und jagen ihn drüber.|Ein freier Kopfball für {who} aus sechs Metern, und der fliegt in die Kurve.|Der Volleyschuss von {who} ist gut getroffen und viel zu hoch.|Ein Drehschuss von {who}, und der fliegt deutlich über die Latte.',
  'commentary.shot_wide': '{who} setzen ihn daneben!|{who} wollen ihn ins lange Eck zirkeln und sehen ihn einen Fuß daneben treiben.|Der Ball springt {who} im Winkel perfekt auf — und rutscht durch den Fünfer, wo keiner steht.|{who} ziehen nach innen und zirkeln ihn einen Meter am Pfosten vorbei.|Ein Direktschuss von {who}, der das Tor nie wirklich gefährdet.|Schön herausgespielt von {who}, und aus dem Strafraum weit vorbeigezogen.|Der Rückpass findet ein {who}-Trikot, und der Schuss geht quer durchs Tor und raus.',
  'commentary.snub': '{opp} wirken nach dem Affront wütend — auf ein feindliches Spiel einstellen.|Hier gibt es eine Vorgeschichte, und {opp} haben sie nicht vergessen.|{opp} sind für dieses Spiel rausgekommen, um etwas zu beweisen.',
  'commentary.thriller_draw': '{us}–{them}! Hin und her mit {opp}. Die Neutralen haben\'s geliebt, auch wenn wir nur einen Punkt mitnehmen.|{us}–{them} gegen {opp}, und keiner von uns beiden hätte das verdient verloren. Den Punkt nehmen wir mit.|Da hat alles gefehlt außer einem Siegtor. {us}–{them}, und wir teilen uns die Beute mit {opp}.|Ein Punkt aus {us}–{them}. Unterhaltsam, anstrengend, und nicht ganz genug.|{us}–{them} gegen {opp}. Wenn jede Woche so wäre, hätte ich keine Stimme mehr.',
  'commentary.thriller_loss': 'Herzschmerz in einem {us}–{them}-Krimi gegen {opp}. Wir haben alles gegeben — nur das Siegtor fehlte.|{us}–{them} gegen {opp}. Wir waren bis zum letzten Ball drin, und trotzdem ist es uns entglitten.|Für {us}–{them} müssen wir uns nicht schämen. Wir hatten unseren Anteil an einem guten Spiel und haben es verloren.|Das wird wehtun. {us}–{them}, und ein einziger Moment hat den ganzen Nachmittag entschieden.|Wir waren {opp} überall ebenbürtig, nur nicht auf der Anzeigetafel. {us}–{them}, und zurück an die Arbeit.',
  'commentary.thriller_win': 'Was für ein Spiel! {us}–{them} gegen {opp} — wir haben einen Klassiker knapp gewonnen. Solche Spiele füllen Stadien.|{us}–{them}. Beim Zuschauen bin ich zehn Jahre gealtert, und nächste Woche mache ich es wieder.|Da haben wir ein echtes Fußballspiel gewonnen, {us}–{them}. {opp} haben uns alles abverlangt.|Das war allein den Eintritt wert. {us}–{them} gegen {opp}, und wir haben auf der richtigen Seite gestanden.|{us}–{them}! Fragt mich nicht wie, aber wir haben den einen gefunden, der zählte.',

};
