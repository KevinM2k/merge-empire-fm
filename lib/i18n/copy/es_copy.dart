/// Spanish copy for the match write-up. See `lib/i18n/locale_copy.dart`.
///
/// Voice and conventions taken from `locales/es.g.dart`'s own `report.*` block:
/// the club takes an article and a singular verb — "El {club} se echó atrás" —
/// and the opponent the same. Third person throughout; nothing here says "we".
library;

/// Replaces the generated entry, or adds a key Spanish did not have.
const Map<String, String> esCopy = <String, String>{
  // ── El rastro posterior al tutorial ──────────────────────────────────────
  //
  // Seis avisos que Colin deja al terminar el tutorial. Cada uno se gasta la
  // primera vez que el jugador hace lo que nombra. Véase
  // `engine/coach_guide_engine.dart`. Las pestañas se llaman como en la barra.
  'guide.players_tab':
      'Tu plantilla vive en la pestaña Jugadores. Ahí fichas caras '
      'nuevas, y si arrastras dos iguales uno encima del otro se '
      'fusionan en uno mejor.',
  'guide.squad_tab':
      'Échale un vistazo a la pestaña Plantilla. Ahí están tu once y '
      'tu banquillo, y tú eliges quién sale.',
  'guide.dugout':
      'Toca Menú, abajo a la derecha, para abrir el banquillo. La '
      'tabla, el calendario, tus misiones y el campo de entrenamiento '
      'están todos ahí dentro.',
  'guide.training':
      'El entrenamiento está en ese menú y no cuesta nada. Unos '
      'minutos en el campo mejoran a un jugador más que cualquier '
      'fichaje que puedas pagar ahora.',
  'guide.club_tab':
      'La pestaña Club es donde se construye el estadio. Cada mejora '
      'te paga más en día de partido: es el dinero que gana dinero.',
  'guide.shop_tab':
      '¿Se te acumulan las monedas? La Tienda tiene ojeadores, '
      'energía y alguna cosa para mantener la racha.',

  // Una tercera fila junto a Sonido y Música: el clic de cada botón.
  'settings.ui_sounds': 'Interfaz',

  // ── The headline ─────────────────────────────────────────────────────────
  //
  // Replaced, not widened: the generated pools all open on {score}, and the
  // English was rewritten to open like the whistle has just gone. `{minute}`
  // reaches only the three `.late` pools; the rest must not name it.
  'report.win.rout':
      'Se acabó, y fue un baile: el {club} le metió {ours} al {opp} sin '
          'despeinarse.|'
      'Pitido final para una goleada. {ours} del {club}, {theirs} del {opp}, y '
          'el marcador no favorece a nadie salvo al ganador.|'
      'Final, y el {club} ha desarmado al {opp}: {ours} goles, y pudieron ser '
          'más.',
  'report.win.comfortable':
      'Ha sonado el pitido y el {club} lo ha ganado al trote, tres goles por '
          'encima del {opp}.|'
      'Se acabó. Tres goles al final, y el {club} nunca corrió el riesgo de '
          'devolverlos.|'
      'Final. El {club} gana por tres y hace el trabajo sin necesidad de '
          'forzar.',
  'report.win.clear':
      'Ha sonado el pitido y el {club} lo gana por dos. El {opp} tuvo ratos sin '
          'llegar nunca a empatarlo.|'
      'Se acabó, dos goles de diferencia, y el {club} manejó la tarde desde que '
          'entró el segundo.|'
      'Final, y una victoria por dos del {club} tan cómoda como suena.',
  'report.win.narrow':
      'Ha sonado el pitido y solo hubo un gol de diferencia — y fue del '
          '{club}.|'
      'Se acabó. Un solo gol los separa al final, y los puntos son del {club}.|'
      'Final, y el {club} lo ha arañado. Un gol, y pudo caer de cualquier '
          'lado.',
  'report.win.late':
      'Ha sonado el pitido y el {club} lo ha ganado tarde: el gol que lo '
          'decidió llegó en el minuto {minute}.|'
      'Se acabó, y menudo final: empate hasta el minuto {minute}, y entonces el '
          '{club} encontró el que el {opp} ya no tuvo tiempo de responder.|'
      'Final. El empate parecía lo más probable hasta el minuto {minute}, '
          'cuando el {club} lo ganó.',
  'report.win.thriller':
      'Se acabó, y vaya partido: {total} goles entre los dos, y se lo lleva el '
          '{club}.|'
      'Pitido final a un partido de {total} goles, y el {club} sale de él con '
          'los puntos.|'
      'Final, y a respirar. {total} goles, y cayó del lado del {club} por el de '
          'la diferencia.',
  'report.draw.goalless':
      'Ha sonado el pitido y nada los separa: sin goles, y sin muchas ocasiones '
          'tampoco.|'
      'Se acabó, sin goles. Los dos porteros tuvieron una tarde tranquila.|'
      'Final, y reparto de honores con el marcador a cero.',
  'report.draw.shared':
      'Ha sonado el pitido con empate: {ours} para cada uno, y ni el {club} ni '
          'el {opp} encontraron el que lo resolvía.|'
      'Se acabó, y se reparten los puntos. {ours} cada uno, en un partido que '
          'tenía ganador en alguna parte.|'
      'Final, e iguales. En ninguno de los dos vestuarios quedarán del todo '
          'contentos.',
  'report.draw.late':
      'Ha sonado el pitido con empate, y el gol de la igualada no llegó hasta '
          'el minuto {minute}: un punto ganado para unos y dos perdidos para '
          'otros.|'
      'Se acabó, iguales, y costó hasta el minuto {minute} llegar ahí.|'
      'Final, con el gol del empate cayendo en el minuto {minute}.',
  'report.draw.thriller':
      'Se acabó, y menudo partido: {total} goles y nada que los separe.|'
      'Pitido final a un partido de {total} goles que ninguno de los dos pudo '
          'ganar.|'
      'Final, y un punto para cada uno después de {total} goles entre ellos.',
  'report.loss.narrow':
      'Ha sonado el pitido y solo hubo un gol de diferencia — y fue del '
          '{opp}.|'
      'Se acabó. El {opp} se lo lleva por un gol, y al {club} le quedan las '
          'preguntas.|'
      'Final, y el {club} pierde por la mínima. Detalles, y cayeron del lado '
          'del {opp}.',
  'report.loss.late':
      'Ha sonado el pitido y el {club} lo ha perdido tarde: el gol del {opp} '
          'llegó en el minuto {minute}.|'
      'Se acabó, y un final cruel: empate hasta el minuto {minute}, y entonces '
          'el {opp} marcó el que contaba.|'
      'Final. Al {club} le había alcanzado para el punto hasta el minuto '
          '{minute}, y ni un minuto más.',
  'report.loss.thriller':
      'Se acabó, y vaya partido: {total} goles entre los dos, pero se lo lleva '
          'el {opp}.|'
      'Pitido final a un partido de {total} goles, y el {club} se va de él sin '
          'nada.|'
      'Final, y a respirar. {total} goles, y cayó del lado del {opp} por el de '
          'la diferencia.',
  'report.loss.clear':
      'Ha sonado el pitido y el {opp} lo gana por dos. El {club} fue segundo en '
          'las dos áreas.|'
      'Se acabó, dos goles de diferencia, y el {club} nunca volvió del todo al '
          'partido tras el segundo.|'
      'Final, y derrota por dos del {club} ante un {opp} más afilado donde '
          'importaba.',
  'report.loss.comfortable':
      'Ha sonado el pitido y al {club} le han pasado por encima: tres goles '
          'para el {opp} al final.|'
      'Se acabó. Tres de diferencia, y el {club} llevaba mucho rato solo '
          'conteniendo.|'
      'Final, y una tarde para olvidar del {club}, batido por tres.',
  'report.loss.rout':
      'Se acabó, y fue un correctivo: el {opp} le metió {theirs} al {club}.|'
      'Pitido final a una goleada. {theirs} del {opp}, {ours} del {club}, y '
          'nadie tiene nada que reclamar.|'
      'Final, y al {club} lo han desarmado: {theirs} encajados, y pudieron ser '
          'más.',

  // ── Cómo jugó el rival ───────────────────────────────────────────────────
  //
  // The write-up is for both sets of supporters; everything else in it is a
  // fact about {club}.
  'report.opp.comeback':
      'El {opp} parecía batido y no jugó como tal, y al final era el equipo por '
          'el que uno habría apostado.|'
      'Mérito para el {opp}: fue segundo un buen rato y le dio la vuelta a la '
          'tarde.|'
      'Algo dice del {opp} que ir por detrás pareciera asentarlo.',
  'report.opp.rampant':
      'El {opp} estuvo enorme, rápido en todo y sin perdonar un solo error.|'
      'Este fue el {opp} en su mejor versión, y quien estuvo allí por ellos '
          'hablará del partido toda la semana.|'
      'Al {opp} le salió todo. No hay muchos equipos que le hubieran aguantado '
          'hoy.',
  'report.opp.shut_us_out':
      'El {opp} fue tan bueno sin balón como con él, y el {club} no encontró '
          'nunca la manera de pasar.|'
      'Portería a cero y puntos para el {opp}, que defendió su área como es '
          'debido de principio a fin.|'
      'El {opp} no le dio nada al {club} con lo que trabajar, y eso explica la '
          'victoria tanto como lo que hizo arriba.',
  'report.opp.clinical':
      'No hubo mucho entre los dos; el {opp} sencillamente estuvo más fino '
          'cuando llegaron las ocasiones.|'
      'El {opp} aprovechó sus momentos y el {club} no, que suele ser todo el '
          'asunto.|'
      'Al {opp} no le hizo falta ser mejor para ganar esto, y tampoco anduvo '
          'lejos de serlo.',
  'report.opp.fought_back':
      'El {opp} iba por detrás y no dejó de venir, y pocos en el campo dirían '
          'que el punto no lo merece.|'
      'Hizo falta carácter del {opp} para volver a meterse en este partido.|'
      'El {opp} se negó a darlo por perdido y se ganó su parte de la tarde por '
          'la vía difícil.',
  'report.opp.stalemate':
      'El {opp} estuvo tan ordenado como el {club}, y ninguno de los dos '
          'encontró el hueco.|'
      'Poco que elegir entre ellos: el {opp} fue tan difícil de romper como el '
          '{club}.|'
      'El {opp} vino a por un punto y defendió como un equipo que iba en '
          'serio.',
  'report.opp.matched':
      'El {opp} igualó al {club} durante largos ratos y saldrá pensando algo '
          'muy parecido del resultado.|'
      'Partido honesto y parejo del {opp}, que nunca fue por detrás ni llegó a '
          'ponerse por delante.|'
      'Hubo poco entre ellos, y el {opp} no sentirá que aquí perdió nada.',
  'report.opp.outclassed':
      'Fue una tarde larga para el {opp}, segundo en casi todo y sin poder '
          'agarrarse nunca al partido.|'
      'El {opp} querrá olvidar este cuanto antes. Muy poco le salió.|'
      'Al {opp} no le funcionó gran cosa, y la distancia entre los dos equipos '
          'quedó clara mucho antes del final.',
  'report.opp.pushed':
      'El {opp} hizo trabajar al {club} y tampoco anduvo lejos.|'
      'El {opp} sentirá que tuvo bastante de este partido como para llevarse '
          'algo.|'
      'Hubo más aquí para el {opp} de lo que le da el marcador.',

  // ── Los goles, como asunto y no como cronología ──────────────────────────
  'report.goals.opened':
      '{player} puso al {club} en marcha.|'
      'Fue {player} quien lo empezó para el {club}.|'
      '{player} abrió el marcador, y el {club} construyó la tarde sobre eso.',
  'report.goals.surge.ours':
      'La segunda parte fue de dirección única. El {club} marcó a placer tras '
          'el descanso y el {opp} no tuvo respuesta para nada de aquello.|'
      'El {club} salió a la segunda parte hecho otro equipo, y los goles '
          'siguieron llegando hasta que el {opp} dejó de contarlos.|'
      'Lo que se dijera en el descanso funcionó: el {club} se llevó el partido '
          'lejos del {opp} después de él.',
  'report.goals.surge.theirs':
      'El {opp} desmontó la segunda parte. El {club} seguía en el partido al '
          'descanso y no estaba ni cerca al final.|'
      'El descanso lo cambió todo a peor: el {opp} marcó una y otra vez después '
          'y el {club} no pudo frenar nada.|'
      'El {club} salió a la segunda parte y fue arrollado. El {opp} no dio '
          'tregua tras el intermedio.',

  // ── El balance del partido, sin una sola cifra ───────────────────────────
  //
  // Estos dos primeros no pueden reclamar la posesión: saltan también con un
  // solo eje, y el {club} pudo tener el balón y aun así ser segundo.
  'report.stats.on_top':
      'El {club} tuvo lo mejor del partido y pareció el más probable durante '
          'casi todo.|'
      'Este era un partido para que el {club} lo controlara, y lo controló. El '
          '{opp} pasó buena parte persiguiendo.|'
      'El {club} mandó la mayor parte de los noventa y el {opp} rara vez dio '
          'señales de cambiarlo.',
  'report.stats.pinned_back':
      'El {club} pasó buena parte defendiendo, y el {opp} fue el que parecía '
          'que iba a marcar.|'
      'El {opp} tuvo lo mejor de esto desde pronto y el {club} apenas logró '
          'salir de debajo.|'
      'Hubo un equipo por encima aquí y no fue el {club}. El {opp} le llevó el '
          'partido.',
  'report.stats.ball_only':
      'El {club} tuvo balón de sobra y bien poco que enseñar. El {opp} defendió '
          'su área y encantado.|'
      'Toda la posesión del mundo para el {club}, y las ocasiones que vinieron '
          'con ella no valían gran cosa.|'
      'El {club} guardó el balón y el {opp} lo mantuvo lejos de donde hacía '
          'daño.',
  'report.stats.counter':
      'El {opp} tuvo el balón y el {club} los momentos, que es tanto una manera '
          'de jugar como una casualidad.|'
      'El {club} se dejó estar ante el {opp} y sacó mucho más de lo que le '
          'llegó.|'
      'La posesión fue por un lado y las ocasiones claras por el otro. Al '
          '{club} no le va a importar nada.',
  'report.stats.even':
      'Hubo muy poco entre ellos, con balón y sin él.|'
      'El {club} y el {opp} estuvieron tan igualados como sugiere la tarde.|'
      'Ni el {club} ni el {opp} tuvieron bastante del partido durante bastante '
          'tiempo como para llamarlo suyo.',

  // ── El tramo final, desde el otro banquillo ──────────────────────────────
  //
  // `{chaser}` es el que llegó por detrás al tramo final y `{holder}` el que
  // iba delante, así que la frase sirve desde cualquiera de los dos lados.
  'report.late.held_out':
      'El {chaser} se lanzó con todo en el tramo final y no encontró la '
          'manera.|'
      'Los últimos minutos fueron todos del {chaser}, y el {holder} aguantó.|'
      'El {chaser} insistió e insistió buscando el gol y no llegó nunca.',
  'report.late.consolation':
      'El {chaser} volcó a todo el mundo arriba al final y sacó un gol de ahí, '
          'y poco más.|'
      'El gol tardío le dio al {chaser} algo que enseñar por el asedio y nunca '
          'pareció que fuera a alcanzar.|'
      'El {chaser} encontró uno al cabo de un largo rato de presión, y para '
          'entonces el {holder} ya tenía lo difícil hecho.',

  // ── El banquillo ─────────────────────────────────────────────────────────
  'report.subs.impact':
      '{player} salió del banquillo y marcó la diferencia para el {club}.|'
      'El cambio del {club} salió bien: {player} entró y marcó.|'
      'El banquillo se pagó solo: {player} entró y se metió en el marcador por '
          'el {club}.',
  'report.subs.changes':
      'El {club} fue gastando cambios buscando algo.|'
      'El {club} vació el banquillo a ver si entraba en el partido.|'
      'Los cambios se sucedieron en el {club}, sin que ninguno acabara de '
          'girar nada.',

  // ── El árbitro ───────────────────────────────────────────────────────────
  //
  // Sin minuto: lo que importa es que acabaron con uno menos.
  'report.cards.our_red_named':
      'A {player} lo expulsaron, y el {club} terminó con menos hombres de los '
          'que empezó.|'
      'La roja a {player} dejó al {club} en inferioridad el resto del partido.',
  'report.cards.our_booked_many':
      '{n} jugadores del {club} vieron amarilla: {names}.|'
      'El árbitro amonestó a {names} en el {club}, {n} tarjetas en total.',
  'report.cards.their_reds':
      'El {opp} tuvo {n} expulsados y acabó el partido muy lejos de un equipo '
          'entero.|'
      '{n} rojas para el {opp}, que condicionaron todo lo que vino después.',

  // ── Los cambios de plan ──────────────────────────────────────────────────
  //
  // Sin minuto y sin el nombre del sistema: una decisión, no un ajuste de
  // pantalla. `{minute}` y `{tactic}` siguen llegando y aquí no se usan.
  'report.tactic.shut_up_shop':
      'El {club} se metió atrás para el tramo final y se puso a proteger lo que '
          'tenía.|'
      'Ya al final el {club} cerró la portería, invitó al {opp} a venir y se '
          'fio de sí mismo para aguantarlo.|'
      'El {club} juntó a todo el mundo por detrás del balón para lo que quedaba '
          'y así terminó la tarde.',
  'report.tactic.went_for_it':
      'El {club} volcó gente arriba para el tramo final y aceptó el riesgo que '
          'venía con ello.|'
      'Ya al final el {club} fue a por ello, apretando arriba al {opp} en lugar '
          'de conformarse con lo que tenía.|'
      'El {club} se jugó lo que quedaba y mandó cuerpos hacia adelante.',
  'report.tactic.settled':
      'El {club} cambió de dibujo para el tramo final y terminó el partido '
          'así.|'
      'Una reorganización del {club} ya al final marcó cómo acabó la tarde.|'
      'El {club} se recolocó para lo que quedaba y sacó el partido de esa '
          'manera.',
  // ── La tabla, y el acuerdo con el número ─────────────────────────────────
  //
  // "1 puestos" y "1 puntos". Es la misma falta que se reportó en inglés — el
  // texto generado lleva el plural dentro de la palabra — y el motor ya manda
  // los sufijos {s} y {ps} para resolverla. En español ambos son una `s`, así
  // que basta con moverlos a la copia.
  'report.table.climbed':
      'Eso sube al {club} {n} puesto{s}, a {pos} con {pts} punto{ps}.|'
      '{n} plaza{s} arriba, a {pos}, con {pts} punto{ps}.|'
      '{pos} ahora el {club}, {n} puesto{s} mejor que antes, con {pts} '
          'punto{ps}.',
  'report.table.dropped':
      'Le cuesta al {club} {n} puesto{s}: {pos}, con {pts} punto{ps}.|'
      '{n} plaza{s} abajo, a {pos}, con {pts} punto{ps}.|'
      '{pos} y cayendo, {n} puesto{s} peor, con {pts} punto{ps}.',
  'report.table.held':
      'Sigue {pos}, ahora con {pts} punto{ps}.|'
      '{pos}, sin cambios, {pts} punto{ps}.|'
      'Sin movimiento: {pos} con {pts} punto{ps}.',

  // The settings screen's small print — see `en_copy.dart`.
  'settings.cutaways.hint':
      'Cuando le cae una ocasión a un bando que tengas activado, el partido '
          'corta al campo y juega el momento — y luego puedes repetirlo.',
  'settings.matchSpeed.auto': 'Auto',
  'settings.matchSpeed.hint':
      'Auto va a 2x y baja a media velocidad en cuanto el entrenador tiene algo '
          'que decir, para que te dé tiempo a leerlo y actuar.',

  // The training list's ceiling — see `en_copy.dart`.
  'training.up_to': 'Hasta',

  // El entrenamiento en descanso y la cuenta atrás — ver `en_copy.dart`.
  'training.resting': 'Enfriamiento {time}',
  'mg.countdown_go': '¡YA!',

  // Tienda: el estante ya no es gratis, y los ingresos salen de las mejoras —
  // ver `en_copy.dart`.
  'shop.lucky_boot_name': 'Bota de la suerte',
  'shop.lucky_boot_desc': 'El próximo rival es un {pct}% más débil (un partido)',
  'shop.section.income': 'Ingresos',
  'product.energy_director.desc': '+50 energía ya · Capacidad subida a 15 · recarga {energyPct}% más rápida — para siempre, ¡incluso tras resets!',

  'shop.section.looks': 'Estilo del entrenador',

};
