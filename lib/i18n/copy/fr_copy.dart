/// French copy for the match write-up. See `lib/i18n/locale_copy.dart`.
///
/// Voice and conventions taken from `locales/fr.g.dart`'s own `report.*` block:
/// the club takes no article and a masculine singular verb — "{club} est passé
/// en défense" — and the minute is written "à la {minute}e", which is why the
/// `e` is in the copy rather than in the value. `ordinalOf` hands every locale
/// but English a bare number for exactly that reason.
library;

/// Replaces the generated entry, or adds a key French did not have.
const Map<String, String> frCopy = <String, String>{
  // ── Le résumé d'ouverture ────────────────────────────────────────────────
  //
  // Remplacés plutôt qu'élargis : les textes générés ouvrent tous sur {score}.
  // `{minute}` n'arrive qu'aux trois textes `.late`.
  'report.win.rout':
      'C\'est fini, et ce fut une démonstration : {club} en a mis {ours} à '
          '{opp} sans forcer.|'
      'Coup de sifflet final sur une correction. {ours} pour {club}, {theirs} '
          'pour {opp}, et l\'écart ne flatte que le vainqueur.|'
      'Fin du match, et {club} a démonté {opp} : {ours} buts, et il aurait pu '
          'y en avoir plus.',
  'report.win.comfortable':
      'Le coup de sifflet est tombé et {club} a gagné au petit trot, trois buts '
          'devant {opp}.|'
      'C\'est fini. Trois buts d\'écart à l\'arrivée, et {club} n\'a jamais '
          'risqué de les rendre.|'
      'Fin du match. {club} gagne de trois et fait le travail sans jamais '
          'avoir à forcer.',
  'report.win.clear':
      'Le coup de sifflet est tombé et {club} l\'emporte de deux. {opp} a eu '
          'des périodes sans jamais sembler pouvoir revenir.|'
      'C\'est fini, deux buts d\'écart, et {club} a géré l\'après-midi dès que '
          'le deuxième est entré.|'
      'Fin du match, et une victoire de deux buts pour {club}, aussi tranquille '
          'qu\'elle en a l\'air.',
  'report.win.narrow':
      'Le coup de sifflet est tombé et il n\'y a eu qu\'un but d\'écart — et il '
          'était pour {club}.|'
      'C\'est fini. Un seul but les sépare à l\'arrivée, et les points sont '
          'pour {club}.|'
      'Fin du match, et {club} l\'a arraché. Un but, et cela pouvait tomber des '
          'deux côtés.',
  'report.win.late':
      'Le coup de sifflet est tombé et {club} l\'a gagné tard : le but qui a '
          'décidé est arrivé à la {minute}e minute.|'
      'C\'est fini, et quelle fin : à égalité jusqu\'à la {minute}e, puis {club} '
          'a trouvé celui auquel {opp} n\'a plus eu le temps de répondre.|'
      'Fin du match. Le nul semblait le plus probable jusqu\'à la {minute}e '
          'minute, quand {club} l\'a emporté.',
  'report.win.thriller':
      'C\'est fini, et quel match : {total} buts entre les deux, et cela va à '
          '{club}.|'
      'Coup de sifflet final sur un match à {total} buts, et {club} en sort '
          'avec les points.|'
      'Fin du match, et on respire. {total} buts, et cela a basculé du côté de '
          '{club} pour un rien.',
  'report.draw.goalless':
      'Le coup de sifflet est tombé et rien ne les sépare : pas de but, et pas '
          'beaucoup d\'occasions non plus.|'
      'C\'est fini, zéro partout. Les deux gardiens ont passé un après-midi '
          'tranquille.|'
      'Fin du match, et honneurs partagés avec un tableau vierge.',
  'report.draw.shared':
      'Le coup de sifflet est tombé sur un nul : {ours} partout, et ni {club} '
          'ni {opp} n\'a trouvé celui qui tranchait.|'
      'C\'est fini, et ils se partagent les points. {ours} chacun, dans un '
          'match qui avait un vainqueur quelque part.|'
      'Fin du match, à égalité. Aucun des deux vestiaires ne sera vraiment '
          'satisfait de cela.',
  'report.draw.late':
      'Le coup de sifflet est tombé sur un nul, et l\'égalisation n\'est '
          'arrivée qu\'à la {minute}e minute : un point gagné pour les uns et '
          'deux perdus pour les autres.|'
      'C\'est fini, à égalité, et il a fallu attendre la {minute}e minute pour '
          'y arriver.|'
      'Fin du match, avec le but de l\'égalisation tombé à la {minute}e '
          'minute.',
  'report.draw.thriller':
      'C\'est fini, et quel match : {total} buts et rien pour les séparer.|'
      'Coup de sifflet final sur un match à {total} buts qu\'aucun des deux '
          'n\'a pu gagner.|'
      'Fin du match, et un point chacun après {total} buts entre eux.',
  'report.loss.narrow':
      'Le coup de sifflet est tombé et il n\'y a eu qu\'un but d\'écart — et il '
          'était pour {opp}.|'
      'C\'est fini. {opp} l\'emporte d\'un but, et il reste les questions à '
          '{club}.|'
      'Fin du match, et {club} perd d\'un rien. Des détails, et ils sont tombés '
          'du côté de {opp}.',
  'report.loss.late':
      'Le coup de sifflet est tombé et {club} l\'a perdu tard : le but de {opp} '
          'est arrivé à la {minute}e minute.|'
      'C\'est fini, et une fin cruelle : à égalité jusqu\'à la {minute}e, puis '
          '{opp} a marqué celui qui comptait.|'
      'Fin du match. {club} en avait assez fait pour le point jusqu\'à la '
          '{minute}e minute, et pas une de plus.',
  'report.loss.thriller':
      'C\'est fini, et quel match : {total} buts entre les deux, mais cela va à '
          '{opp}.|'
      'Coup de sifflet final sur un match à {total} buts, et {club} en sort '
          'sans rien.|'
      'Fin du match, et on respire. {total} buts, et cela a basculé du côté de '
          '{opp} pour un rien.',
  'report.loss.clear':
      'Le coup de sifflet est tombé et {opp} l\'emporte de deux. {club} a été '
          'second dans les deux surfaces.|'
      'C\'est fini, deux buts d\'écart, et {club} n\'est jamais vraiment revenu '
          'dans le match après le deuxième.|'
      'Fin du match, et une défaite de deux buts pour {club} face à un {opp} '
          'plus tranchant là où il fallait.',
  'report.loss.comfortable':
      'Le coup de sifflet est tombé et {club} a été largement battu — trois '
          'buts d\'écart pour {opp} à l\'arrivée.|'
      'C\'est fini. Trois d\'écart, et {club} ne faisait plus que contenir bien '
          'avant la fin.|'
      'Fin du match, et un après-midi à oublier pour {club}, battu de trois.',
  'report.loss.rout':
      'C\'est fini, et ce fut une correction : {opp} en a mis {theirs} à '
          '{club}.|'
      'Coup de sifflet final sur une démonstration. {theirs} pour {opp}, '
          '{ours} pour {club}, et personne n\'a rien à redire.|'
      'Fin du match, et {club} a été démonté : {theirs} encaissés, et il aurait '
          'pu y en avoir plus.',

  // ── Comment l'adversaire a joué ──────────────────────────────────────────
  'report.opp.comeback':
      '{opp} semblait battu et n\'a jamais joué comme tel, et à la fin '
          'c\'était l\'équipe sur laquelle on aurait misé.|'
      'Bravo à {opp} — second pendant un moment, il a retourné l\'après-midi.|'
      'Cela dit quelque chose de {opp} qu\'être mené ait eu l\'air de le '
          'rassurer.',
  'report.opp.rampant':
      '{opp} a été énorme, rapide dans tout et impitoyable sur la moindre '
          'erreur.|'
      'C\'était {opp} au sommet, et ceux qui étaient là pour lui en parleront '
          'toute la semaine.|'
      'Tout a réussi à {opp}. Peu d\'équipes lui auraient résisté aujourd\'hui.',
  'report.opp.shut_us_out':
      '{opp} a été aussi bon sans ballon qu\'avec, et {club} n\'a jamais trouvé '
          'le moyen de passer.|'
      'Une cage inviolée et les points pour {opp}, qui a défendu sa surface '
          'comme il faut de la première à la dernière minute.|'
      '{opp} n\'a rien donné à {club}, et cela explique la victoire autant que '
          'ce qu\'il a fait devant.',
  'report.opp.clinical':
      'Il n\'y avait pas grand-chose entre les deux ; {opp} a simplement été '
          'plus tranchant quand les occasions sont venues.|'
      '{opp} a saisi ses moments et {club} non, ce qui fait généralement tout.|'
      '{opp} n\'avait pas besoin d\'être la meilleure équipe pour gagner, et il '
          'n\'en était pas loin de toute façon.',
  'report.opp.fought_back':
      '{opp} était mené et n\'a pas cessé de revenir, et peu de monde dans le '
          'stade dirait le point immérité.|'
      'Il a fallu du caractère à {opp} pour revenir dans ce match.|'
      '{opp} a refusé de l\'accepter et a gagné sa part de l\'après-midi à la '
          'dure.',
  'report.opp.stalemate':
      '{opp} a été aussi organisé que {club}, et aucun des deux n\'a trouvé la '
          'faille.|'
      'Peu de choses à départager — {opp} a été aussi difficile à bouger que '
          '{club}.|'
      '{opp} est venu chercher un point et a défendu comme une équipe qui le '
          'voulait vraiment.',
  'report.opp.matched':
      '{opp} a tenu tête à {club} pendant de longues périodes et pensera à peu '
          'près la même chose du résultat.|'
      'Un match honnête et équilibré de {opp}, jamais mené et jamais vraiment '
          'devant.|'
      'Il y avait peu entre eux, et {opp} n\'aura pas le sentiment d\'avoir '
          'perdu quoi que ce soit ici.',
  'report.opp.outclassed':
      'L\'après-midi a été long pour {opp}, second sur presque tout et jamais '
          'capable de s\'installer dans le match.|'
      '{opp} voudra oublier celui-ci rapidement. Très peu de choses ont '
          'tourné pour lui.|'
      'Pas grand-chose n\'a fonctionné pour {opp}, et l\'écart entre les deux '
          'équipes était clair bien avant la fin.',
  'report.opp.pushed':
      '{opp} a fait travailler {club} et n\'en était pas loin non plus.|'
      '{opp} aura le sentiment d\'avoir eu assez de ce match pour en prendre '
          'quelque chose.|'
      'Il y avait ici plus pour {opp} que ce que le score lui donne.',

  // ── Les buts, comme sujet et non comme chronologie ───────────────────────
  'report.goals.opened':
      '{player} a lancé {club}.|'
      'C\'est {player} qui a tout commencé pour {club}.|'
      '{player} a ouvert le score, et {club} a bâti son après-midi dessus.',
  'report.goals.surge.ours':
      'La seconde période a été à sens unique. {club} a marqué à sa guise après '
          'la pause et {opp} n\'avait de réponse à rien de tout cela.|'
      '{club} est revenu des vestiaires en autre équipe, et les buts ont '
          'continué jusqu\'à ce que {opp} cesse de les compter.|'
      'Ce qui a été dit à la mi-temps a marché : {club} a emmené le match loin '
          'de {opp} juste après.',
  'report.goals.surge.theirs':
      '{opp} a démonté la seconde période. {club} était encore dans le match à '
          'la pause et n\'en était plus nulle part à la fin.|'
      'La pause a tout changé en pire : {opp} a marqué encore et encore après '
          'elle et {club} n\'a rien pu endiguer.|'
      '{club} est revenu des vestiaires et a été submergé. {opp} n\'a laissé '
          'aucun répit après la mi-temps.',

  // ── Le bilan du match, sans un seul chiffre ──────────────────────────────
  //
  // Ces deux premiers ne peuvent pas revendiquer le ballon : ils sortent aussi
  // sur un seul axe, et {club} a pu avoir la possession en étant second.
  'report.stats.on_top':
      '{club} a eu le meilleur de ce match et a paru le plus dangereux d\'un '
          'bout à l\'autre.|'
      'C\'était un match à contrôler pour {club}, et il l\'a contrôlé. {opp} en '
          'a passé une bonne partie à courir après.|'
      '{club} a tenu la plus grande partie des quatre-vingt-dix minutes et '
          '{opp} n\'a presque jamais donné le sentiment de pouvoir changer '
          'cela.',
  'report.stats.pinned_back':
      '{club} a passé une bonne partie du match à défendre, et {opp} était '
          'celui qui semblait pouvoir marquer.|'
      '{opp} a eu le meilleur de ce match très tôt et {club} n\'est presque '
          'jamais sorti de dessous.|'
      'Il y avait une équipe au-dessus ici et ce n\'était pas {club}. {opp} lui '
          'a porté le match.',
  'report.stats.ball_only':
      '{club} a eu le ballon en quantité et bien peu à en montrer. {opp} a '
          'défendu sa surface et s\'en est très bien accommodé.|'
      'Toute la possession du monde pour {club}, et les occasions qui allaient '
          'avec ne valaient pas grand-chose.|'
      '{club} a gardé le ballon et {opp} l\'a tenu loin de tout endroit qui '
          'comptait.',
  'report.stats.counter':
      '{opp} a eu le ballon et {club} les occasions, ce qui est autant une '
          'façon de jouer qu\'un hasard.|'
      '{club} a laissé venir {opp} et a bien mieux exploité ce qui lui est '
          'arrivé.|'
      'La possession est allée d\'un côté et les vraies occasions de l\'autre. '
          '{club} ne s\'en plaindra pas du tout.',
  'report.stats.even':
      'Il y avait très peu entre eux, ballon au pied ou non.|'
      '{club} et {opp} se sont valus autant que l\'après-midi le laisse '
          'penser.|'
      'Ni {club} ni {opp} n\'a eu assez du match assez longtemps pour '
          'l\'appeler le sien.',

  // ── La fin de match, vu de l'autre banc ──────────────────────────────────
  //
  // `{chaser}` est celui qui abordait la fin mené et `{holder}` celui qui
  // menait, pour que la phrase tienne des deux côtés.
  'report.late.held_out':
      '{chaser} a tout jeté vers l\'avant dans le dernier quart d\'heure sans '
          'trouver la faille.|'
      'La fin de match a été entièrement pour {chaser}, et {holder} a tenu.|'
      '{chaser} a poussé et poussé pour l\'ouverture, et elle n\'est jamais '
          'venue.',
  'report.late.consolation':
      '{chaser} a fait monter tout le monde en fin de match et en a tiré un '
          'but, pas grand-chose de plus.|'
      'Le but tardif a donné à {chaser} quelque chose à montrer pour sa '
          'pression, sans jamais sembler suffire.|'
      '{chaser} en a trouvé un au bout d\'un long temps fort, et {holder} avait '
          'alors fait le plus dur.',

  // ── Le banc ──────────────────────────────────────────────────────────────
  'report.subs.impact':
      '{player} est sorti du banc et a fait la différence pour {club}.|'
      'Le changement de {club} a payé : {player} est entré et a marqué.|'
      'Le banc s\'est remboursé tout seul — {player} est entré et a marqué pour '
          '{club}.',
  'report.subs.changes':
      '{club} a déroulé ses changements en cherchant quelque chose.|'
      '{club} a vidé son banc pour tenter d\'entrer dans le match.|'
      'Les changements se sont enchaînés du côté de {club}, sans qu\'aucun ne '
          'fasse vraiment basculer quoi que ce soit.',

  // ── L'arbitre ────────────────────────────────────────────────────────────
  //
  // Sans minute : ce qui compte, c'est qu'ils ont fini à un de moins.
  'report.cards.our_red_named':
      '{player} a été expulsé, et {club} a terminé avec moins d\'hommes qu\'au '
          'coup d\'envoi.|'
      'Le rouge pour {player} a laissé {club} en infériorité pour le reste du '
          'match.',
  'report.cards.our_booked_many':
      '{n} joueurs de {club} ont été avertis : {names}.|'
      'L\'arbitre a averti {names} chez {club}, {n} cartons en tout.',
  'report.cards.their_reds':
      '{opp} a eu {n} joueurs expulsés et a fini le match très loin d\'une '
          'équipe complète.|'
      '{n} cartons rouges pour {opp}, qui ont conditionné tout ce qui a suivi.',

  // ── Les changements de plan ──────────────────────────────────────────────
  //
  // Sans minute et sans le nom du système : une décision, pas un réglage.
  // `{minute}` et `{tactic}` continuent d'arriver et ne servent pas ici.
  'report.tactic.shut_up_shop':
      '{club} est descendu d\'un cran pour la fin de match et s\'est mis à '
          'protéger son avantage.|'
      'En fin de match {club} a fermé la boutique, laissé venir {opp} et fait '
          'confiance à sa défense.|'
      '{club} a ramené tout le monde derrière le ballon pour la dernière partie '
          'et a fini l\'après-midi comme cela.',
  'report.tactic.went_for_it':
      '{club} a jeté des hommes vers l\'avant pour la fin de match et accepté '
          'le risque qui allait avec.|'
      'En fin de match {club} y est allé, en remontant sur {opp} plutôt qu\'en '
          'se contentant de ce qu\'il avait.|'
      '{club} a joué le tout pour le tout sur la dernière partie et envoyé du '
          'monde devant.',
  'report.tactic.settled':
      '{club} a changé de dispositif pour la fin de match et a terminé la '
          'rencontre ainsi.|'
      'Un remaniement de {club} en fin de match a décidé de la façon dont '
          'l\'après-midi s\'est terminé.|'
      '{club} s\'est réorganisé pour la dernière partie et a géré la fin de '
          'cette manière.',
  // ── Le classement, et l'accord avec le nombre ────────────────────────────
  //
  // "1 places" et "1 points" : la faute signalée en anglais, encore vivante
  // ici. Le moteur envoie déjà {s} et {ps}, et en français les deux sont bien
  // un `s` — il suffisait de les mettre dans le texte.
  'report.table.climbed':
      'Cela fait gagner {n} place{s} à {club} : {pos}, avec {pts} point{ps}.|'
      '{n} place{s} de mieux, {pos}, {pts} point{ps} au compteur.|'
      '{pos} désormais pour {club}, {n} place{s} de mieux qu\'avant, avec '
          '{pts} point{ps}.',
  'report.table.dropped':
      'Cela coûte {n} place{s} à {club} — {pos}, avec {pts} point{ps}.|'
      '{n} place{s} de moins, {pos}, avec {pts} point{ps}.|'
      '{pos} et en baisse, {n} place{s} de moins, avec {pts} point{ps}.',
  'report.table.held':
      'Toujours {pos}, désormais avec {pts} point{ps}.|'
      '{pos}, inchangé, {pts} point{ps}.|'
      'Aucun mouvement — {pos} avec {pts} point{ps}.',

  // The settings screen's small print — see `en_copy.dart`.
  'settings.cutaways.hint':
      'Quand une occasion tombe pour un camp que vous avez activé, le match '
          'bascule sur la pelouse et joue le moment — et vous pouvez le revoir '
          'ensuite.',
  'settings.matchSpeed.auto': 'Auto',
  'settings.matchSpeed.hint':
      'Auto tourne en 2x et passe en vitesse réduite dès que le coach a quelque '
          'chose à dire, le temps de le lire et d\'agir.',

  // The training list's ceiling — see `en_copy.dart`.
  'training.up_to': 'Jusqu\'à',

  // La séance au repos et le décompte du coup d'envoi — voir `en_copy.dart`.
  'training.resting': 'Délai {time}',
  'mg.countdown_go': 'PARTEZ !',

  // La boutique : le rayon n'est plus gratuit, et les revenus quittent les
  // bonus — voir `en_copy.dart`.
  'shop.lucky_boot_name': 'Botte porte-bonheur',
  'shop.lucky_boot_desc': 'Prochain adversaire {pct}% plus faible (un match)',
  'shop.section.income': 'Revenus',
  'product.energy_director.desc': '+50 énergie immédiate · Plafond passé à 15 · recharge {energyPct}% plus rapide — à vie, même après les resets !',

  'shop.section.looks': 'Style d\'entraîneur',

};
