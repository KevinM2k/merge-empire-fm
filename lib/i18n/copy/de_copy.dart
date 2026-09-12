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


  // ── Where it was won: the positional card and its write-up ─────────────
  'match.analysis.title':
      'Wo es entschieden wurde',
  'match.analysis.hint':
      'Wo jede Seite den Ball hatte, Angriff nach oben. Die Seiten sind jeweils aus eigener Sicht.',
  'match.analysis.flanks':
      'Angriffe nach Flanke',
  'match.analysis.left':
      'Links',
  'match.analysis.centre':
      'Mitte',
  'match.analysis.right':
      'Rechts',
  'match.analysis.shots':
      '{shots} Schüsse, {xg} xG',
  'match.analysis.duel_record':
      '{name} gewann {won} von {total} Zweikämpfen.',
  'report.zone.down_right':
      '{club} kam den ganzen Nachmittag über rechts, und fast alles Gefährliche entstand dort.|Fast alles, was {club} aufbaute, lief über die rechte Flanke.',
  'report.zone.down_left':
      '{club} kam den ganzen Nachmittag über links, und fast alles Gefährliche entstand dort.|Fast alles, was {club} aufbaute, lief über die linke Flanke.',
  'report.zone.through_middle':
      '{club} kam direkt durch die Mitte und brauchte die Flügel kaum.|Bei {club} lief alles durchs Zentrum, geradewegs auf das Tor zu.',
  'report.zone.their_right':
      '{opp} kam immer wieder über die eigene rechte Seite, und von dort kam die meiste Gefahr.|Fast alles, was {opp} entwickelte, lief über die rechte Flanke.',
  'report.zone.their_left':
      '{opp} kam immer wieder über die eigene linke Seite, und von dort kam die meiste Gefahr.|Fast alles, was {opp} entwickelte, lief über die linke Flanke.',
  'report.zone.their_middle':
      '{opp} kam geradewegs durch die Mitte auf {club} zu und nutzte die Flügel kaum.|Bei {opp} lief alles durchs Zentrum.',
  'report.duel.dominant':
      '{name} gewann fast jeden Zweikampf des Nachmittags.|Niemand bei {opp} bekam {name} den ganzen Nachmittag in den Griff.',
  'report.duel.busy':
      '{name} war vom ersten bis zum letzten Pfiff mitten im Geschehen.|Ein Großteil des Spiels lief über {name}, im Guten wie im Schlechten.',
  'report.duel.struggled':
      '{name} hatte einen schweren Nachmittag und verlor die meisten Zweikämpfe.|Für {name} lief es nicht: mehr Duelle verloren als gewonnen.',

  // ── Strings the spec's own catalogues never translated ─────────────────
  //
  // Identical to English in all ten shipped locales — a gap in
  // `../merge-empire-fc`'s own catalogue, same shape as `champ.*` below.
  'match.subs': 'Wechsel',
  'match.subs.bench': 'Bank',
  'match.subs.empty_slot': 'Leer',
  'match.subs.done': 'Zurück zum Spiel',
  'match.subs.on_pitch': 'Auf dem Platz',
  'match.subs.empty_bench': 'Keine Spieler auf der Bank.',
  'match.subs.pick_off': 'Tipp einen Spieler an, um ihn auszuwechseln.',
  'match.subs.pick_on': 'Tipp einen Spieler von der Bank an, um ihn einzuwechseln (grün = beste Position).',
  'match.subs.none_left': 'Keine Wechsel mehr.',
  'match.subs.feed': '{off} raus, {on} rein.',
  'match.subs.feed_on': '{on} kommt rein.',
  'tut.loan_boost.title': '⭐ Leihstars treffen ein!',
  'tut.loan_boost.body': 'Ich hab ein paar Gefallen eingefordert… <strong>Topspieler</strong> haben zugesagt, für dein erstes Spiel zu uns zu stoßen! Sie gehen gleich danach wieder — aber lass uns das Beste draus machen!',
  'tut.loan_boost.btn': 'Meinen Kader ansehen →',
  'tut.loan_depart.title': 'Jetzt bauen wir unser Team',
  'tut.loan_depart.body': 'Die Leihstars sind weg — aber sie haben bewiesen, dass wir mithalten können. Jetzt bauen wir etwas, das <strong>uns gehört</strong>. Hier sind <strong>500 Münzen</strong> für den Anfang. Ich bin unten links, sobald ich einen Rat habe.',
  'tut.loan_depart.btn': 'Auf geht\'s! →',
  'difficulty.switch.confirm': 'Los geht\'s',
  'difficulty.switch.toHard': 'Pro-Modus: Jeder Spieler ermüdet während eines Spiels — verwalte die Energie deines Kaders und wechsle durch, damit die Beine frisch bleiben. Ich kann dir helfen, deine frischeste Elf zu wählen, aber bei der Taktik halte ich mich raus. Der Wechsel lässt dich neu beginnen.',
  'difficulty.switch.toEasy': 'Casual-Modus: keine Spielermüdigkeit, die Bank ist nur für taktische Wechsel und Verletzungen da. Auto-Aufstellung und Trainertipps kehren zurück. Der Wechsel lässt dich neu beginnen.',
  'coachtip.subs_bench.title': 'Du hast eine Bank',
  'coachtip.subs_bench.body': 'Tipp während eines Spiels auf Wechsel, um deine Bank zu öffnen — du hast 5 Wechsel pro Spiel, und die Uhr stoppt, während du wählst. Verletzungen laufen jetzt auch darüber: Wenn jemand umknickt, verlässt sein Trikot den Platz und der Platz bleibt leer, bis du einen Ersatz einwechselst — also lass ihn nicht einfach so stehen.',
  'coachtip.try_hard_mode.title': 'Lust auf eine Herausforderung?',
  'coachtip.try_hard_mode.body': 'Du hast einen weiten Weg zurückgelegt, Chef. Bereit für den Pro-Modus? Spieler ermüden während der Spiele, also zählt es wirklich, den Kader zu rotieren und die Bank zu nutzen — tipp auf Auto und ich wähle deine frischeste zulässige Elf — und bei der Taktik halte ich mich raus. Es startet ein neues Team — nur wenn du bereit dafür bist.',
  'coachtip.try_hard_mode.cta': 'Einstellungen öffnen',
  'coach.match.tired': '{name} ist erschöpft — bring einen frischen Spieler!',
  'coach.tactic_tip.open_dominant': 'Beide Teams werden treffen, aber wir sind klar stärker. {tactic} — spiel auf Sieg.',
  'coach.tactic_tip.open_favoured': 'Beide Seiten werden Chancen kreieren und wir sollten die Nase vorn haben. {tactic}, um das Spiel zu kontrollieren.',
  'coach.tactic_tip.open_even': 'Beide Teams werden Chancen kreieren. {tactic} — triff {opp} im Konter.',
  'coach.tactic_tip.open_underdog': '{opp} sind stärker, aber es wird offen. {tactic} — nutze deine Chancen, wenn sie kommen.',
  'coach.tactic_tip.exploit_their_def': 'Die Abwehr von {opp} ist offen. {tactic} — spiel auf Sieg.',
  'coach.tactic_tip.counter_their_atk': '{opp} sind gefährlich nach vorne. {tactic} — verteidige und schlag zurück.',
  'coach.tactic_tip.park_underdog': '{opp} sind eine echte Bedrohung und wir werden uns schwertun zu treffen. {tactic} — begrenze den Schaden.',
  'coach.tactic_tip.tight_favoured': 'Ein enges Spiel, aber wir haben die Nase vorn. {tactic} — erspiel dir die Chance.',
  'coach.tactic_tip.tight_underdog': 'Schwer zu treffen auf beiden Seiten. {tactic} — bleib diszipliniert.',
  'ach.cat.hardmode': 'Pro-Modus',
  'toast.energy_refilled': 'Kaderenergie aufgefüllt!',
  'toast.no_fit_players': 'Nicht genug einsatzbereite Spieler — lass sie ruhen oder schau eine Werbung, um aufzufüllen.',
  'trait.name.iron_lungs': 'Eiserne Lunge',
  'trait.desc.iron_lungs': 'Unermüdlicher Motor — Energie sinkt während Spielen langsamer (Pro-Modus)',
  'champ.title': 'MEISTER!',
  'champ.subtitle': 'Champions League erobert',
  'champ.body': 'Du hast jede Division erobert und dich über alle Rivalen erhoben. Du stehst allein da, als der größte Manager der Welt.',
  'champ.prestige_teaser': 'Setz zurück und steig wieder auf, von der Sonntagsliga mit einem dauerhaften <strong>×{mult}-Einkommensbonus</strong>. Deine Karriereerfolge bleiben dir für immer erhalten.',
  'champ.new_adventure': '🌟 Neues Abenteuer starten',
  'champ.defend': '⚽ Titel verteidigen',

  // ── The side dial on the squad tab ────────────────────────────────────
  'squad.side.label': 'Angriff über',
  'squad.side.balanced': 'Ausgeglichen',
  'squad.side.balanced.hint': 'Die Angriffe beginnen dort, wo die Aufstellung sie hinstellt.',
  'squad.side.left': 'Links',
  'squad.side.left.hint': 'Die meisten Angriffe beginnen über die linke Seite.',
  'squad.side.centre': 'Die Mitte',
  'squad.side.centre.hint': 'Die meisten Angriffe beginnen durch die Mitte.',
  'squad.side.right': 'Rechts',
  'squad.side.right.hint': 'Die meisten Angriffe beginnen über die rechte Seite.',
};
