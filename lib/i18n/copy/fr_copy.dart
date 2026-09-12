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
  'customise.item.face.bubblegum': 'Chewing-gum',

  // Une troisième ligne à côté de Son et Musique : le clic de chaque bouton.
  'settings.ui_sounds': 'Interface',

  // L'onglet ne parle plus seulement de son : la vibration s'y ajoute.
  'settings.tab.controls': 'Commandes',
  'settings.haptics': 'Vibration',
  'settings.haptics.hint': 'Une petite vibration à chaque appui. Les réglages '
      'de vibration de votre téléphone peuvent aussi la désactiver.',
  'settings.tap_ripple': 'Ondes au toucher',

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

  // Colin relays an offer and calls it; then his tour after the tutorial.
  'coach.bid.relay': '{club} ont appelé, coach. Ils veulent {player} et mettent {price} sur la table.',
  'coach.sponsor.relay': '{company} nous ont contactés, coach. Ils veulent {player} comme visage de leur marque : {n}% de revenus en plus sur ce joueur tant que le contrat court.',
  'coach.verdict.accept': 'Mon avis : prends-la',
  'coach.verdict.decline': 'Mon avis : refuse',
  'coach.verdict.your_call': 'Mon avis : ça peut aller dans les deux sens',
  'manager.transfer.starter_short': '{player} est titulaire chaque semaine et il n\'y a personne sur le banc pour prendre le relais. Refuse, sauf si tu recrutes un remplaçant tout de suite après.',
  'manager.transfer.relegation': 'On est dans la zone rouge et {player} est dans le onze. Vendre maintenant nous affaiblit pile au moment où on ne peut pas se le permettre.',
  'manager.transfer.flying': 'On est en tête et les caisses sont pleines. On n\'a pas besoin de cet argent : garde le groupe soudé.',
  'manager.transfer.need_money': 'Franchement, on est à sec. Cette somme paie une recrue entière, et on a plus besoin des pièces que de {player}.',
  'manager.transfer.bench_warmer': '{player} n\'est même pas dans ton onze, et le prix est correct. Prends l\'argent et renforce là où ça compte.',
  'manager.sponsor.clean': 'Aucun piège sur celui-là. Signe : c\'est de l\'argent gratuit.',
  'manager.sponsor.relegation_starter': '{player} est dans le onze et on est dans la zone rouge. Un titulaire affaibli, c\'est la dernière chose qu\'il nous faut : refuse.',
  'manager.sponsor.injury_prone': '{player} a déjà {seasons} saisons dans les jambes et ce contrat augmente le risque de blessure. Ça ne vaut pas le coup.',
  'manager.sponsor.poor_form': 'La forme de {player} est déjà mauvaise et ce contrat l\'enfonce encore. Dis non.',
  'manager.sponsor.need_money': 'On manque de pièces et ça paie chaque seconde. Le piège vaut le coup : signe.',
  'manager.sponsor.bench': '{player} n\'est pas dans ton onze, donc le piège ne nous coûte rien sur le terrain. Signe.',
  'manager.sponsor.rating_cost': 'Ça coûte {n} de note à {player}, et c\'est un titulaire. Plus de revenus contre une équipe plus faible : à toi de voir.',
  'manager.sponsor.fair': 'Le piège est petit et les revenus ne le sont pas. Je signerais.',
  'guide.scout': 'Appuie sur Recruter pour signer quelqu\'un de nouveau. Deux joueurs du même type glissés l\'un sur l\'autre fusionnent en un meilleur joueur.',
  'guide.squad_tab': 'Bien. Ouvre maintenant l\'onglet {tab} et mets ton meilleur onze sur la pelouse.',
  'guide.squad_fill': 'Touche une case vide pour choisir qui joue là, ou appuie sur Auto et je te compose l\'équipe.',
  'guide.dugout': 'Tu vois le Menu, en bas à droite ? C\'est le Dugout : l\'entraînement et le classement sont là-dedans.',
  'guide.club_tab': 'Le stade rapporte aussi. Jette un œil à l\'onglet {tab}.',
  'guide.club_buy': 'Achète une installation ici. Chacune que tu possèdes s\'ajoute à ce que le club gagne chaque seconde.',
  'guide.shop_tab': 'À court d\'énergie ou de pièces ? L\'onglet {tab} a des packs et des bonus quand tu en as besoin.',

  // ── Commentary pools the spec's own catalogues never widened ───────────
  //
  // English grew these `commentary.*` pools over time; the translated
  // locales stayed at the original length. Existing lines are kept
  // verbatim; new lines fill the gap so every locale draws from the same
  // number of variants. `commentary.opp_sub`'s original single variant was
  // itself untranslated English in every locale — replaced here too.
  'commentary.blocked': '{who} voient la frappe contrée !|{who} déclenchent de l\'entrée et un corps se jette devant — voilà un défenseur qui gagne son salaire.|Trois maillots de {who} se présentent sur le renvoi, et chacun est contré à son tour.|Une frappe de {who} à douze mètres, contrée par une jambe surgie de nulle part.|{who} récupèrent et retentent leur chance — et de nouveau un corps se jette devant.|Contrée dès la source, et {who} doivent tout reconstruire.|La défense se jette devant tout ce que {who} tentent.',
  'commentary.booking.opp_red': 'Rouge direct pour {opp}, et personne dans le stade ne conteste — {opp} à dix.|Un tacle épouvantable d\'un joueur de {opp}, et l\'arbitre sort directement le rouge. {opp} sont à dix.|Un joueur de {opp} prend le chemin des vestiaires. L\'arbitre n\'avait pas le choix sur ce coup-là.|Carton rouge pour {opp}, et leur banc n\'a rien à redire. Ils sont à dix.',
  'commentary.booking.opp_second_yellow': 'Deuxième jaune pour {opp}, et il sort — ils se sont compliqué l\'après-midi tout seuls.|Deux avertissements pour le même joueur de {opp}, et l\'arbitre doit l\'expulser. {opp} à dix.|Deux avertissements pour le même joueur de {opp}, et l\'arbitre l\'expulse. {opp} termineront à dix.|Un second jaune pour {opp}, synonyme de rouge. Ils viennent de se compliquer la tâche.',
  'commentary.booking.opp_yellow': 'Un maillot de {opp} passe sur le carnet pour un croche-pied cynique — l\'arbitre en avait assez vu.|{opp} concède un coup franc inutile et récolte un jaune avec.|Carton jaune pour {opp}, et leur banc n\'apprécie pas du tout.|Un joueur de {opp} est averti pour avoir retenu un adversaire lancé — l\'arbitre n\'avait pas le choix.|Tacle en retard et maladroit de {opp} — le jaune est presque une faveur.',
  'commentary.booking.red': 'Rouge direct pour {player}, et il n\'y a rien à contester — dernier défenseur, et il prend les jambes. {us} finissent à dix.|{player} perd complètement la tête et l\'arbitre n\'hésite pas. Dehors. Une longue demi-heure attend {us}.|{player} est expulsé. Une intervention qui ne cherchait pas le ballon, et {us} termineront à dix.|L\'arbitre va directement à la poche pour {player}, et c\'est rouge. {us} passent à dix.',
  'commentary.booking.second_yellow': 'Et c\'est un second jaune pour {player} — rien de méchant, mais il était déjà averti et il le savait. {us} à dix.|{player} y retourne, et l\'arbitre n\'a pas le choix : deux avertissements, il sort. {us} finissent en infériorité.|Deux jaunes pour {player}, et c\'est la douche. {us} finiront à dix.|{player} averti une seconde fois, et le rouge suit forcément. {us} sont en infériorité.',
  'commentary.booking.yellow': '{player} est averti pour antijeu — le premier de l\'après-midi, il va devoir faire attention.|Tacle en retard de {player}, et l\'arbitre sort le jaune avant même qu\'il se relève.|{player} retient le maillot pour couper le contre. Il n\'y a qu\'une issue : carton.|Contestation de {player} — de toutes les façons idiotes d\'entrer dans le carnet.|{player} arrive en retard sur le tacle, l\'arbitre n\'a pas le choix — carton jaune.|Croche-pied de {player} au milieu de terrain, et le carton sort.|{player} entre dans le carnet pour une faute qui ne valait vraiment pas le coup.',
  'commentary.demolition': '{us}–{them} — quelle prestation ! On a démantelé {opp}. Les gars vont planer pendant des jours.|{us}–{them}. Tout ce qu\'on a tenté a fonctionné, et {opp} n\'avait aucune réponse.|On n\'a jamais aussi bien joué. {us}–{them} face à {opp} — savourez.|{us}–{them} ! Je ne pouvais pas leur en demander plus aujourd\'hui.|On a été impitoyables. {us}–{them}, et {opp} a été soulagé d\'entendre le coup de sifflet.',
  'commentary.dispossessed': '{who} se font tacler — quelle intervention !|{who} prennent une touche de trop dans la surface, et le tacle est parfaitement propre.|{who} lèvent la tête pour la passe qui existait il y a une seconde — on vient de leur prendre le ballon au pied.|Un tacle parfaitement chronométré met fin à l\'offensive de {who}.|{who} se font dépouiller à l\'entrée de la surface par une intervention surgie de nulle part.|Le ballon est subtilisé à {who} au moment même de la frappe.|{who} tardent sur le ballon et paient cette seconde de trop.',
  'commentary.drubbing': 'Vilaine sortie. {us}–{them} chez {opp}. On se relève — toute équipe a un mauvais jour.|{us}–{them} chez {opp}. Rien n\'a fonctionné et je ne vais pas prétendre le contraire.|C\'était une correction, tout simplement. {us}–{them}. On tourne la page et on repart.|{us}–{them}. {opp} a été meilleur que nous sur tout le terrain. Ça arrive.|Pas grand-chose à dire sur {us}–{them}. Mauvais jour, mémoire courte, on passe au suivant.',
  'commentary.flow.addedtime.0': 'Du suspense dans le temps additionnel !|Temps additionnel, et rien n\'est joué.|Rebondissement de dernière minute en fin de match.|Tout se joue dans ces dernières secondes.',
  'commentary.flow.addedtime.1': 'Ils tiennent bon jusque dans les arrêts de jeu.|Loin dans le temps additionnel, et on s\'accroche.|Chaque seconde est grappillée, et personne sur le banc ne s\'en plaint.|Seule l\'horloge compte, à présent.',
  'commentary.flow.addedtime.2': 'Le panneau du quatrième arbitre s\'affiche — temps additionnel en cours.|Le panneau est levé, il reste encore du temps à jouer.|Le quatrième arbitre annonce les minutes additionnelles, et il y en a plus que prévu.|Le temps additionnel est confirmé, et aucun des deux bancs n\'a l\'air ravi du chiffre.',
  'commentary.flow.addedtime.3': 'Encore le temps pour une dernière occasion.|Il reste le temps pour une dernière offensive.|Un dernier ballon dans la surface, sûrement.|Ce n\'est pas terminé — il en reste encore une là-dedans.',
  'commentary.flow.closing.0': 'Dans le money time !|Dix minutes à jouer, et tout va se décider ici.|L\'horloge tourne et l\'urgence monte.|Dans les dix dernières minutes, et les deux bancs sont debout.',
  'commentary.flow.closing.1': 'Chaque tacle compte maintenant.|Chaque duel est disputé comme si c\'était le dernier de la saison.|Plus aucun cadeau nulle part sur le terrain.|Chacun se jette corps et âme aux deux bouts du terrain.',
  'commentary.flow.closing.2': 'Vont-ils tenir ?|La question, maintenant, c\'est de savoir s\'ils vont tenir.|Les jambes commencent à lâcher, et il reste du temps à jouer.|On défend avec tout ce qu\'on a, et il reste des minutes à jouer.',
  'commentary.flow.closing.3': 'Dernière carte de l\'adversaire.|Le dernier changement est fait — tout part vers l\'avant à partir de maintenant.|Un défenseur central est monté en attaque. Voilà où on en est.|C\'est le dernier assaut, et plus rien n\'est gardé en réserve.',
  'commentary.flow.closing.4': 'La tension monte tout autour du stade.|On sent la nervosité monter, ici.|Chaque passe manquée est accueillie par un grognement.|Le public siffle pour réclamer la fin.',
  'commentary.flow.firstA.0': 'Votre équipe prend confiance.|La confiance grandit, et les passes s\'accélèrent avec elle.|Une période de possession installée — une équipe a pris le contrôle du milieu.|Les passes ont trouvé leur rythme, désormais.',
  'commentary.flow.firstA.1': 'Tir à bout portant — à côté !|Frappe instantanée à huit mètres, et ça passe à quelques centimètres du poteau.|Mêlée dans les six mètres, et le ballon file à côté après une déviation.|Une tête de près, et le ballon retombe juste à côté du montant.',
  'commentary.flow.firstA.2': 'Belle combinaison sur le côté gauche.|Trois passes à gauche, toutes en une touche, et le centre est presque parfait.|Du beau jeu sur le côté droit, et l\'arrière latéral déborde à l\'extérieur.|Un une-deux sur la ligne de touche ouvre le terrain, l\'espace d\'un instant.',
  'commentary.flow.firstA.3': 'Le gardien repousse des poings sur un corner.|Le corner est centré, et le gardien sort le captant au-dessus de tout le monde.|Un coup de pied arrêté profond sème la panique avant d\'être dégagé en catastrophe.|Corner après corner, et la défense continue de mettre la tête dessus.',
  'commentary.flow.firstB.0': 'Coup franc dangereux à venir...|Un coup franc dans une zone dangereuse, vingt-deux mètres et dans l\'axe.|Le mur se met en place, et c\'est une vraie occasion.|Une faute à l\'entrée de la surface, et il y a une vraie occasion ici.',
  'commentary.flow.firstB.1': 'Le gardien intervient — belle parade !|Frappe puissante de loin, et le gardien la capte à la deuxième tentative.|Quelle parade, plongeon à sa gauche, et le rebond est repoussé en catastrophe.|Le gardien sort vite de sa ligne et étouffe l\'occasion aux pieds de l\'attaquant.',
  'commentary.flow.firstB.3': 'Tir bloqué sur la ligne !|Dégagé sur la ligne, et personne dans le stade ne sait comment.|Un corps se jette devant la frappe, et le contre part en corner.|Contré, puis contré à nouveau sur le rebond — la défense est aux abois.',
  'commentary.flow.open.0': 'Coup d\'envoi ! Les deux équipes prennent leurs marques.|Et c\'est parti ! Les deux équipes prennent leurs marques.|L\'arbitre donne le coup d\'envoi, et les premières passes sont prudentes.|C\'est parti. Aucune des deux équipes ne veut rien céder dans ces premières minutes.',
  'commentary.flow.open.1': 'Pression précoce du milieu de terrain.|C\'est au milieu de terrain que tout se joue pour l\'instant.|Une première période de possession, et le premier vrai territoire conquis de l\'après-midi.|Les deux équipes pressent haut, et personne n\'a encore pris le contrôle du ballon.',
  'commentary.flow.open.2': 'Le public est déjà en ébullition.|Le stade est debout, et on n\'en est même pas à dix minutes de jeu.|Une grosse ambiance dans le stade à chaque fois que le ballon avance.|L\'ambiance monte ici depuis l\'échauffement.',
  'commentary.flow.secondA.0': 'La seconde mi-temps est lancée — votre équipe pousse.|De retour pour la seconde période, et il y a déjà plus d\'urgence dans le jeu.|La reprise apporte un changement de rythme — c\'est plus rapide que la première mi-temps.|Seconde période, et les consignes de la pause ont visiblement été entendues.',
  'commentary.flow.secondA.1': 'Le changement tactique semble fonctionner.|Le système a changé, et les espaces s\'ouvrent en conséquence.|Un remaniement venu du banc, et ça produit son effet.|Quelqu\'un s\'est décalé vers l\'intérieur, et le terrain paraît plus grand pour ça.',
  'commentary.flow.secondA.2': 'C\'est de bout en bout maintenant.|Le match s\'est complètement ouvert — ça va d\'un bout à l\'autre du terrain.|Plus aucune des deux équipes ne cherche à garder le ballon.|Chaque dégagement revient aussitôt, et personne n\'arrive à calmer le jeu.',
  'commentary.flow.secondA.3': 'Le kiné est appelé pour un coup.|Le kiné est appelé, un joueur au sol a besoin de soins.|Une interruption pendant qu\'on examine un coup en touche.|Soins sur le terrain, et ça va s\'ajouter au temps additionnel.',
  'commentary.flow.secondB.0': 'Le combat au milieu de terrain s\'intensifie.|Les tacles pleuvent au milieu de terrain, maintenant.|Personne ne gagne la bataille du milieu, et tout le monde s\'y essaie.|C\'est devenu une vraie bagarre dans le tiers central.',
  'commentary.flow.secondB.1': 'Frappe lointaine — directement sur le gardien.|Trente mètres et ça tire — le gardien capte tranquillement.|Ça descend bien depuis loin, mais ça atterrit droit dans les mains du gardien.|Tentative ambitieuse de loin, mais le but n\'a jamais été inquiété.',
  'commentary.flow.secondB.2': 'Brillant un-deux dans la surface, juste dégagé !|Un une-deux ouvre la défense, et le dernier geste revient au pied d\'un défenseur.|Superbement travaillé dans la surface, et dégagé au dernier moment.|Deux passes ont suffi à éliminer la défense — mais le dégagement arrive.',
  'commentary.forces_save': '{who} force une parade !|{who} écartent le jeu et centrent — le gardien la détourne en pleine extension.|Une-deux rapide de {who} à l\'entrée de la surface, et la frappe est repoussée au premier poteau.|{who} partent en contre à trois contre deux, et seule une sortie au sol l\'empêche.|Le ballon retombe pour {who} à huit mètres — et le gardien est là, on ne sait comment.|{who} arment une frappe depuis un angle fermé, et le gardien la détourne du bout des doigts.|Une tête sur corner de {who} est repoussée on ne sait comment sur la ligne.|{who} croisent une frappe basse, et le gardien y met une main ferme.',
  'commentary.goal.equalise.no_scorer': '{us} égalisent !|{us} reviennent à hauteur !|{us} égalisent — match ouvert !|Le match est lancé ! {us} égalisent !|{us} trouvent l\'égalisation !|{us} sont de nouveau à hauteur !|Tout est à refaire — {us} égalisent !|{us} rétablissent l\'égalité !',
  'commentary.goal.equalise.with_scorer': '{scorer} égalise pour {us} !|Retour dans le match — {scorer} marque pour {us} !|{scorer} répond — {us} reviennent à hauteur !|Le match est lancé ! {us} égalisent grâce à {scorer}.|{scorer} trouve la faille — {us} reviennent à hauteur !|Tout est à refaire ! {scorer} conclut pour {us} !|{scorer} ne tremble pas — {us} égalisent !|En plein milieu du but pour {scorer}, et {us} recollent au score !',
  'commentary.goal.extend.no_scorer': '{us} en remettent une couche !|{us} creusent l\'écart !|{us} déroulent !|{us} prennent le large !|{us} enfoncent le clou !|{us} s\'envolent au score !|Ça leur échappe — encore {us} !|{us} resserrent l\'étau !',
  'commentary.goal.extend.with_scorer': '{scorer} ajoute un de plus pour {us} !|Reprise en deux temps de {scorer} — {us} creusent l\'écart !|{scorer} double la mise — {us} déroulent !|Clinique de {scorer} — {us} prennent le large !|{scorer} met ce match hors de portée pour {us} !|Un de plus pour {us}, signé {scorer} !|Encore {scorer} — {us} resserrent l\'étau !|{us} sont injouables, et {scorer} est au cœur de tout ça !',
  'commentary.goal.lead.no_scorer': '{us} prennent la tête !|{us} passent devant !|{us} font sauter le verrou !|{us} prennent l\'avantage !|{us} ouvrent le score !|La percée tant attendue — {us} mènent !|{us} trouvent l\'ouverture du score !|Premier sang pour {us} !',
  'commentary.goal.lead.with_scorer': '{scorer} place {us} en tête !|Quel tir de {scorer} ! {us} devant !|{scorer} fait sauter le verrou pour {us} !|Plaqué par {scorer} — {us} mènent !|{scorer} fait la différence — {us} passent devant !|{us} mènent, et c\'est {scorer} qui a fait le travail !|Une finition sortie de nulle part de {scorer}, et {us} prennent l\'avantage !|{scorer} trouve le fond des filets — avantage {us} !',
  'commentary.goal.pullback.no_scorer': '{us} reviennent au score !|{us} attrapent une bouée !|{us} sont à nouveau dans le match !|{us} prennent un point d\'appui !|{us} réduisent l\'écart !|Un but pour {us} — la partie reprend vie !|{us} refont surface !|Ce n\'est pas fini — {us} marquent !',
  'commentary.goal.pullback.with_scorer': '{scorer} réduit l\'écart pour {us} !|Espoir ! {scorer} marque pour {us} !|{scorer} maintient {us} dans le coup !|{scorer} convertit pour {us} !|{scorer} redonne un peu d\'espoir à {us} !|Un but pour {us} grâce à {scorer} — la partie reprend vie !|{scorer} frappe, et {us} ne sont pas finis !|Un peu d\'espoir pour {us}, et c\'est {scorer} qui l\'apporte !',
  'commentary.halftime_ahead': '{us} mènent à la pause !|{us} rentrent aux vestiaires avec l\'avantage.|Mi-temps, et {us} mènent au score.|{us} rentrent devant — la seconde période consistera à gérer ça.',
  'commentary.halftime_behind': '{us} sont menés — il faut réagir.|Mi-temps, et {us} ont du travail à faire.|{us} sont menés à la pause, et quelque chose doit changer.|Une première période à oublier pour {us}, et quarante-cinq minutes pour redresser la barre.',
  'commentary.halftime_level': 'À égalité à la mi-temps.|Rien ne les sépare à la pause.|Tout est à égalité à la mi-temps.|À égalité après quarante-cinq minutes, tout reste possible.',
  'commentary.high_scoring_loss': 'Match ouvert. {us}–{them} chez {opp}. On a marqué pas mal — on en a juste pris un de trop.|{us}–{them} chez {opp}. Ça a marqué dans les deux sens, mais beaucoup trop du mauvais côté.|On n\'a jamais été largués, mais on n\'a jamais paru en sécurité non plus. {us}–{them}.|{us}–{them}. Marquer, ce n\'est pas notre problème. Les arrêter, si.|C\'était sympa pour tout le monde sauf pour moi. {us}–{them}, et on défendra mieux la semaine prochaine.',
  'commentary.high_scoring_win': 'Beau match. {us}–{them} face à {opp} — des buts partout mais on prend les trois points. Cette efficacité vaut un coup de fil d\'un sponsor.|{us}–{them} face à {opp}. Complètement ouvert, à couper le souffle, et trois points.|On a marqué beaucoup et on en a pris quelques-uns aussi. {us}–{them}, et je prends volontiers.|{us}–{them} ! Les attaquants étaient injouables. Les défenseurs, on en reparlera.|Un duel au sommet face à {opp}, {us}–{them}, et on a eu le dernier mot.',
  'commentary.hit_post': '{who} touchent le poteau !|{who} frappent de toutes leurs forces, et tout le stade entend le montant.|Le ballon rebondit sur un défenseur et retombe sous la barre pour {who} — puis ressort en claquant le poteau.|{who} frappent le poteau opposé de vingt mètres, et ça reste dehors.|La barre les sauve — {who} sont passés à un rien du but.|Une tête de {who} s\'écrase sur la barre et retombe du mauvais côté de la ligne.|Sur l\'intérieur du poteau puis le long de la ligne de but — {who} n\'en reviennent pas.',
  'commentary.injury': '{player} sort sur blessure !|{player} ne peut pas continuer — c\'est un coup dur.|{player} se tient la jambe et fait signe au banc. L\'après-midi est terminée pour lui.|{player} s\'écroule, et celui-là n\'a pas l\'air de pouvoir repartir sur ses jambes.',
  'commentary.nervy_one_nil': 'Un 1–0 contre {opp}. Pas joli, mais trois points c\'est trois points. Cage inviolée, on encaisse les points et on passe.|1–0. On n\'avait pas besoin de se compliquer autant la vie, mais une victoire face à {opp} reste une victoire.|Cage inviolée et trois points face à {opp}. Personne ne se souviendra comment en avril.|Un 1–0 poussif. Les bonnes équipes gagnent ce genre de match, donc je ne vais pas me plaindre.|Un seul but a suffi face à {opp}. La défense a mérité celui-là.',
  'commentary.nil_nil': 'Zéro partout face à {opp}. Après-midi terne — on prend le point et on en cherche plus la prochaine fois.|Zéro partout face à {opp}. Personne ne parlera de ce match, mais un point reste un point.|Au moins la cage est restée inviolée. {opp} n\'a rien tiré de nous, et nous rien tiré d\'eux.|Sans but face à {opp}. On aurait pu jouer jusqu\'à minuit sans marquer.|Un point, une cage inviolée, et quatre-vingt-dix minutes très longues face à {opp}.',
  'commentary.opp_goal': '{them} marquent !|Quel but de {them} !|Belle combinaison de {them} — direct dedans.|{them} punissent un moment de relâchement défensif.|{them} enfilent une passe — finition clinique.|Défense endormie — {them} en profitent.|Quelle frappe de {them}, le gardien n\'y pouvait rien.|Pas joli pour {them}, mais ça compte.|{them} trouvent la lucarne — classe pure.|Un corner que personne n\'attaque, une tête que personne ne conteste, et {them} l\'ont pour rien.|{them} travaillent le débordement et la glissent au premier poteau.|Une déviation surprend tout le monde, et {them} en profitent.|Une passe suffit à éliminer la défense, et {them} font le reste.|{them} placent une tête sur un centre qui n\'aurait jamais dû arriver.|Un long ballon, une remise, et {them} sont seuls devant le but pour conclure.',
  'commentary.opp_sub': '{opp} fait un changement — du sang neuf depuis le banc.|Changement pour {opp} — du sang neuf sur le terrain.|{opp} font appel à leur banc.|{opp} font un changement, et l\'entrant part directement en attaque.|Un maillot de {opp} fatigué sort, un maillot frais entre.',
  'commentary.shot_over': '{who} la mettent au-dessus !|{who} la remettent dans la surface et s\'appuient dessus — direction le deuxième anneau.|Un mètre suffisait à {who}, et de douze mètres c\'est parti dans les nuages.|{who} ont tout le but à viser, et l\'envoient par-dessus.|Une tête libre de {who} à six mètres, et ça finit dans le public.|La reprise de volée de {who} est bien frappée, mais bien trop haute.|Une frappe en pivot de {who}, et ça passe largement au-dessus de la barre.',
  'commentary.shot_wide': '{who} la mettent à côté !|{who} tentent de l\'enrouler au second poteau et la voient filer d\'un rien à côté.|Le ballon se présente parfaitement pour {who} — et traverse toute la surface sans personne au bout.|{who} rentrent dans l\'axe et l\'enroulent à un mètre du poteau.|Une frappe en première intention de {who} qui n\'a jamais vraiment inquiété le but.|Bien travaillé par {who}, et la frappe part à côté depuis l\'entrée de la surface.|Le centre en retrait trouve un maillot de {who}, et le tir traverse le but pour sortir.',
  'commentary.snub': '{opp} ont l\'air furieux après l\'affront — match hostile en vue.|Il y a un passif entre ces deux équipes, et {opp} ne l\'a pas oublié.|{opp} est sorti des vestiaires avec quelque chose à prouver.',
  'commentary.thriller_draw': '{us}–{them} ! Du foot d\'attaque face à {opp}. Les neutres ont adoré même si on ne ramène qu\'un point.|{us}–{them} face à {opp}, et aucune des deux équipes ne méritait de perdre. On prend le point.|Ce match avait tout sauf un vainqueur. {us}–{them}, et on partage les points avec {opp}.|Un point pour {us}–{them}. Spectaculaire, épuisant, et pas tout à fait suffisant.|{us}–{them} face à {opp}. Si chaque semaine ressemblait à ça, je n\'aurais plus de voix.',
  'commentary.thriller_loss': 'Crève-cœur dans un thriller {us}–{them} face à {opp}. On a tout donné — il a manqué le but de la victoire.|{us}–{them} face à {opp}. On y était jusqu\'au dernier ballon, et ça nous a quand même échappé.|Rien à regretter dans ce {us}–{them}. On a fait notre part dans un bon match, et on l\'a perdu.|Celui-là va faire mal. {us}–{them}, et un seul instant a décidé de toute l\'après-midi.|On a fait jeu égal avec {opp} partout sauf au score. {us}–{them}, et retour au travail.',
  'commentary.thriller_win': 'Quel match ! {us}–{them} contre {opp} — on a gagné un classique de justesse. Des matchs comme ça remplissent les stades.|{us}–{them}. J\'ai vieilli de dix ans en regardant ça, et je recommencerais la semaine prochaine.|On a gagné un vrai match de football, {us}–{them}. {opp} nous a donné du fil à retordre.|Ça valait le prix du billet à soi seul. {us}–{them} face à {opp}, et on est du bon côté du résultat.|{us}–{them} ! Ne me demandez pas comment, mais on a trouvé celui qui comptait.',

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
  'match.subs': 'Rempl.',
  'match.subs.done': 'Retour au match',
  'match.subs.on_pitch': 'Sur le terrain',
  'match.subs.bench': 'Banc',
  'match.subs.empty_bench': 'Aucun joueur sur le banc.',
  'match.subs.empty_slot': 'Vide',
  'match.subs.pick_off': 'Touchez un joueur à faire sortir.',
  'match.subs.pick_on':
      'Touchez un joueur du banc à faire entrer (vert = meilleur poste).',
  'match.subs.none_left': 'Plus de remplacements disponibles.',
  'match.subs.feed': '{off} sort, {on} entre.',
  'match.subs.feed_on': '{on} entre en jeu.',
  'difficulty.switch.toHard':
      'Mode Pro : chaque joueur se fatigue pendant le match — gérez l\'énergie '
      'de l\'effectif et faites tourner le banc pour garder des jambes '
      'fraîches. Je peux vous aider à choisir les onze les plus frais, mais je '
      'resterai muet sur la tactique. Changer de mode vous fera tout '
      'recommencer.',
  'difficulty.switch.toEasy':
      'Mode Casual : aucune fatigue, le banc ne sert donc qu\'aux changements '
      'tactiques et aux blessures. La sélection auto et les conseils du coach '
      'reviennent. Changer de mode vous fera tout recommencer.',
  'tut.loan_boost.title': '⭐ Des stars en prêt arrivent !',
  'tut.loan_boost.body':
      'J\'ai fait jouer quelques relations… des <strong>joueurs de haut '
      'niveau</strong> ont accepté de nous rejoindre pour votre premier match ! '
      'Ils repartent juste après — alors profitons-en !',
  'tut.loan_boost.btn': 'Voir mon effectif →',
  'tut.loan_depart.title': 'À nous de bâtir notre équipe',
  'tut.loan_depart.body':
      'Les stars prêtées sont parties — mais elles ont prouvé que nous pouvons '
      'rivaliser. Construisons maintenant quelque chose qui soit <strong>à '
      'nous</strong>. Voici <strong>500 pièces</strong> pour démarrer. Je serai '
      'en bas à gauche dès que j\'aurai un conseil.',
  'tut.loan_depart.btn': 'C\'est parti ! →',
  'ach.cat.hardmode': 'Mode Pro',
  'coachtip.subs_bench.title': 'Vous avez un banc',
  'coachtip.subs_bench.body':
      'Touchez Rempl. pendant le match pour ouvrir le banc : vous avez 5 '
      'changements par rencontre, et le chrono s\'arrête pendant que vous '
      'choisissez. Les blessures passent par là aussi désormais : quand un '
      'joueur tombe, son maillot quitte le terrain et la place reste vide tant '
      'que vous n\'envoyez personne, alors ne le laissez pas comme ça.',
  'coachtip.try_hard_mode.title': 'Envie d\'un défi ?',
  'coachtip.try_hard_mode.body':
      'Vous avez fait du chemin, patron. Prêt pour le Mode Pro ? Les joueurs se '
      'fatiguent pendant les matchs, donc faire tourner l\'effectif et utiliser '
      'le banc compte vraiment — touchez Auto et je vous aligne le onze '
      'réglementaire le plus frais — et je resterai muet sur la tactique. On '
      'repart avec une équipe neuve : seulement si vous le sentez.',
  'coachtip.try_hard_mode.cta': 'Ouvrir les Paramètres',
  'coach.match.tired': '{name} est épuisé — faites entrer un joueur frais !',
  'toast.energy_refilled': 'Énergie de l\'effectif rechargée !',
  'toast.no_fit_players':
      'Pas assez de joueurs en état de jouer — faites-les récupérer ou regardez '
      'une pub pour recharger.',
  'trait.name.iron_lungs': 'Poumons d\'acier',
  'trait.desc.iron_lungs':
      'Moteur infatigable — consomme l\'énergie plus lentement en match (Mode '
      'Pro)',
  'champ.title': 'CHAMPIONS !',
  'champ.subtitle': 'Ligue des Champions conquise',
  'champ.body':
      'Vous avez conquis toutes les divisions et dominé tous vos rivaux. Vous '
      'êtes seul au sommet, le plus grand entraîneur du monde.',
  'champ.prestige_teaser':
      'Repartez de zéro depuis la Ligue du Dimanche avec un <strong>bonus de '
      'revenus ×{mult} permanent</strong>. Les succès de votre carrière vous '
      'restent acquis pour toujours.',
  'champ.new_adventure': '🌟 Commencer une nouvelle aventure',
  'champ.defend': '⚽ Défendre le titre',
  'game.training.intro':
      'Touchez {n} tirs à mesure qu\'ils arrivent. Vous avez {secs} s par '
      'exercice.',

  // ── Two strings that quoted POUNDS in every language ─────────────────────
  //
  // The badge's figure is a RATIO between bundles and has no currency in it at
  // all; "/£" was decoration that happened to be sterling. And the consent
  // notice named the range in pounds to a parent who does not pay in them —
  // it takes the store's own two figures now, see `age_gate_sheet.dart`.
  'shop.coin_value_badge': '+{pct}% de valeur',
  'agegate.purchases_body':
      'Des packs de pièces ({min} – {max}), des packs d\'énergie et un pass VIP '
      'sont disponibles. Tous les achats sont traités de façon sécurisée par '
      'Google Play. Aucun abonnement n\'est requis. Le consentement parental '
      'ci-dessous débloque ces achats pour ce compte.',

  // What settled a level cup tie. Under the score in a 42pt slot,
  // so it is an abbreviation. See `league_sheets.dart`.
  'fixtures.on_pens': 't.a.b.',
};
