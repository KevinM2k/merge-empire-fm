/// Spanish copy for the match write-up. See `lib/i18n/locale_copy.dart`.
///
/// Voice and conventions taken from `locales/es.g.dart`'s own `report.*` block:
/// the club takes an article and a singular verb — "El {club} se echó atrás" —
/// and the opponent the same. Third person throughout; nothing here says "we".
library;

/// Replaces the generated entry, or adds a key Spanish did not have.
const Map<String, String> esCopy = <String, String>{
  'customise.item.face.bubblegum': 'Chicle',

  // Una tercera fila junto a Sonido y Música: el clic de cada botón.
  'settings.ui_sounds': 'Interfaz',

  // La pestaña ya no es solo sonido: la vibración se suma.
  'settings.tab.controls': 'Controles',
  'settings.haptics': 'Vibración',
  'settings.haptics.hint': 'Una pequeña vibración al pulsar. Los ajustes de '
      'vibración de tu teléfono también pueden desactivarla.',
  'settings.tap_ripple': 'Ondas al tocar',

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

  // Colin relays an offer and calls it; then his tour after the tutorial.
  'coach.bid.relay': '{club} han llamado, míster. Quieren a {player} y ponen {price} sobre la mesa.',
  'coach.sponsor.relay': '{company} se han puesto en contacto, míster. Quieren a {player} como imagen de su marca: un {n}% más de ingresos por ese jugador mientras dure el acuerdo.',
  'coach.verdict.accept': 'Mi consejo: acéptalo',
  'coach.verdict.decline': 'Mi consejo: recházalo',
  'coach.verdict.your_call': 'Mi consejo: podría ir de cualquier manera',
  'manager.transfer.starter_short': '{player} es titular cada semana y no hay nadie en el banquillo para sustituirle. Recházalo, salvo que fiches un reemplazo justo después.',
  'manager.transfer.relegation': 'Estamos en zona de descenso y {player} está en el once. Vender ahora nos debilita justo cuando no podemos permitírnoslo.',
  'manager.transfer.flying': 'Somos líderes y las arcas están sanas. No necesitamos este dinero: mantén la plantilla unida.',
  'manager.transfer.need_money': 'Sinceramente, estamos sin blanca. Esta cantidad paga un fichaje entero, y necesitamos las monedas más que a {player}.',
  'manager.transfer.bench_warmer': '{player} ni siquiera está en tu once, y el precio es justo. Coge el dinero y refuerza donde importa.',
  'manager.sponsor.clean': 'Este no tiene pega. Fírmalo: es dinero gratis.',
  'manager.sponsor.relegation_starter': '{player} está en el once y estamos en zona de descenso. Un titular más débil es lo último que necesitamos: recházalo.',
  'manager.sponsor.injury_prone': '{player} ya lleva {seasons} temporadas en las piernas y este acuerdo aumenta el riesgo de lesión. No merece la pena.',
  'manager.sponsor.poor_form': 'La forma de {player} ya es mala y este acuerdo la empeora. Di que no.',
  'manager.sponsor.need_money': 'Andamos cortos de monedas y esto paga cada segundo. Merece la pena la pega: fírmalo.',
  'manager.sponsor.bench': '{player} no está en tu once, así que la pega no nos cuesta nada en el campo. Fírmalo.',
  'manager.sponsor.rating_cost': 'Le cuesta {n} de valoración a {player}, y es titular. Más ingresos a cambio de un equipo más flojo: tú decides.',
  'manager.sponsor.fair': 'La pega es pequeña y los ingresos no. Yo lo firmaría.',
  'guide.scout': 'Pulsa Ojear para fichar a alguien nuevo. Dos del mismo tipo arrastrados juntos se fusionan en un jugador mejor.',
  'guide.squad_tab': 'Bien. Ahora abre la pestaña {tab} y pon a tus mejores once sobre el césped.',
  'guide.squad_fill': 'Toca un hueco vacío para elegir quién juega ahí, o pulsa Auto y yo te completo el equipo.',
  'guide.dugout': '¿Ves el Menú, abajo a la derecha? Es el Dugout: ahí están los entrenamientos y la clasificación.',
  'guide.club_tab': 'El estadio también genera dinero. Échale un vistazo a la pestaña {tab}.',
  'guide.club_buy': 'Compra una instalación aquí. Cada una que tengas suma a lo que el club gana cada segundo.',
  'guide.shop_tab': '¿Corto de energía o monedas? La pestaña {tab} tiene packs y mejoras cuando los necesites.',

  // ── Commentary pools the spec's own catalogues never widened ───────────
  //
  // English grew these `commentary.*` pools over time; the translated
  // locales stayed at the original length. Existing lines are kept
  // verbatim; new lines fill the gap so every locale draws from the same
  // number of variants. `commentary.opp_sub`'s original single variant was
  // itself untranslated English in every locale — replaced here too.
  'commentary.blocked': '¡Le bloquean el disparo a {who}!|{who} disparan desde la frontal y un cuerpo se cruza — así se gana el sueldo un central.|Tres camisetas de {who} hacen cola para el rechace, y a todas se las bloquean.|Disparo de {who} desde doce metros, y una pierna salida de la nada lo bloquea.|{who} la recuperan y disparan otra vez — y otra vez aparece un cuerpo en medio.|Cortado en origen, y {who} tienen que reiniciar la jugada.|La defensa se lanza a bloquear todo lo que encuentra {who}.',
  'commentary.booking.opp_red': 'Roja directa para el {opp}, y nadie en el campo la discute: el {opp} se queda con diez.|Una entrada terrible de una camiseta del {opp}, y el árbitro va directo a la roja. Los visitantes, con uno menos.|Un jugador del {opp} se va expulsado. No había otra tarjeta posible para esa entrada.|Roja para el {opp}, y su banquillo no tiene nada que reprochar. Diez hombres ahora.',
  'commentary.booking.opp_second_yellow': 'Segunda amarilla para el {opp}, y a la calle: se han complicado la tarde ellos solos.|Dos amonestaciones para el mismo jugador del {opp}, y el árbitro no tiene más remedio que expulsarlo. El {opp} se queda con diez.|Dos amonestaciones para el mismo jugador del {opp}, y el árbitro lo expulsa. El {opp} juega el resto con diez.|Segunda amarilla para el {opp}, y eso es roja. Se lo han puesto mucho más difícil ellos solos.',
  'commentary.booking.opp_yellow': 'Una camiseta del {opp} va al libro por una zancadilla cínica: el árbitro ya había visto suficientes.|{opp} regala una falta innecesaria y encima se lleva amarilla.|Amonestación para el {opp}, y a su banquillo no le gusta nada.|Una camiseta del {opp} se lleva la amarilla por frenar a un rival por detrás — el árbitro no tenía otra opción.|Tarde y torpe del {opp}, y la amarilla es lo de menos.',
  'commentary.booking.red': 'Roja directa a {player}, y no hay discusión — último hombre, y se lleva las piernas. {us} acaban con diez.|{player} pierde la cabeza por completo y el árbitro no duda. Fuera. A {us} le espera media hora larga.|{player} se va expulsado. Una entrada sin ninguna intención de jugar el balón, y {us} termina con diez.|El árbitro va directo al bolsillo por {player}, y es roja. {us} se queda con diez hombres.',
  'commentary.booking.second_yellow': 'Y esa es la segunda amarilla de {player} — sin mala intención, pero ya estaba amonestado y lo sabía. {us} se quedan con diez.|{player} vuelve a entrar, y el árbitro no tiene opción: dos amarillas, a la calle. {us} juegan el resto en inferioridad.|Dos amarillas para {player}, y ese es un camino muy largo al vestuario. {us} se queda con diez para lo que resta.|{player} vuelve a ver la amarilla, y la roja llega detrás. {us} se queda con uno menos.',
  'commentary.booking.yellow': '{player} ve la amarilla por perder tiempo — la primera de la tarde, ahora tendrá que andarse con cuidado.|Entrada tarde de {player}, y el árbitro saca la amarilla antes de que se levante.|{player} agarra la camiseta para cortar el contragolpe. Solo hay un desenlace: amarilla.|Protesta {player} — de todas las tonterías con las que entrar en el libro.|{player} llega tarde a la entrada y el árbitro no tiene opción — amarilla.|Zancadilla de {player} en el centro del campo, y sale la tarjeta.|{player} entra en el libro por una falta que no merecía la pena cometer.',
  'commentary.demolition': '{us}–{them} — ¡qué exhibición! Hicimos pedazos a {opp}. Los chicos van a estar eufóricos.|{us}–{them}. Todo lo que intentamos salió bien, y el {opp} no tuvo respuesta para nada de eso.|Así de bien hemos jugado. {us}–{them} contra el {opp} — disfrútenlo.|¡{us}–{them}! No podía pedirles más hoy.|Fuimos implacables. {us}–{them}, y el {opp} agradeció el pitido final.',
  'commentary.dispossessed': '¡Le roban el balón a {who} — gran entrada!|{who} dan un toque de más en el área, y la entrada es limpísima.|{who} levantan la cabeza buscando el pase que había hace un segundo — y ya se la han robado del pie.|Una entrada perfectamente cronometrada acaba con el ataque de {who}.|Le roban el balón a {who} en la frontal del área con una entrada salida de la nada.|Le quitan el balón a {who} justo cuando llegaba el disparo.|{who} se entretienen con el balón y lo pagan con ese segundo de más.',
  'commentary.drubbing': 'Feo, ese. {us}–{them} en {opp}. A sacudirse el polvo — todo equipo tiene un mal día.|{us}–{them} en {opp}. Nada salió bien y no voy a fingir lo contrario.|Eso ha sido una paliza, sin más vueltas. {us}–{them}. Lo dejamos atrás y a por el siguiente.|{us}–{them}. El {opp} fue mejor que nosotros en todas las zonas del campo. Estas cosas pasan.|Poco que decir de {us}–{them}. Mal día, memoria corta, siguiente partido.',
  'commentary.flow.addedtime.0': '¡Drama en el tiempo de descuento!|Tiempo de descuento, y esto todavía no está decidido.|Drama de última hora al final del partido.|Todo está pasando en estos últimos segundos.',
  'commentary.flow.addedtime.1': 'Aguantando hasta el final del descuento.|Bien metidos en el descuento, y esto se aguanta como se puede.|Se estira cada segundo ahora, y en ese banquillo nadie protesta.|Aquí ya solo importa el reloj.',
  'commentary.flow.addedtime.2': 'El cuarto árbitro levanta el cartel — empieza el tiempo añadido.|Se levanta el cartel, y todavía queda partido por delante.|El cuarto árbitro señala los minutos añadidos, y son más de los esperados.|Se confirma el tiempo añadido, y en ningún banquillo gusta la cifra.',
  'commentary.flow.addedtime.3': 'Todavía hay tiempo para una última ocasión.|Todavía hay tiempo para un último ataque.|Seguro que entra un último balón al área.|Esto no ha terminado — todavía queda una más.',
  'commentary.flow.closing.0': '¡Recta final!|Diez minutos por delante, y aquí se va a decidir todo.|El reloj corre y la urgencia ha subido con él.|Entramos en los últimos diez, y los dos banquillos están de pie.',
  'commentary.flow.closing.1': 'Cada barrida cuenta ahora.|Cada disputa se pelea como si fuera la última del año.|No se regala nada en ninguna zona del campo ahora mismo.|Cuerpo a tierra en las dos áreas.',
  'commentary.flow.closing.2': '¿Aguantarán?|La pregunta ahora es si esto se puede aguantar hasta el final.|Las piernas empiezan a fallar, y todavía queda reloj.|Se defiende con todo, y aún quedan minutos.',
  'commentary.flow.closing.3': 'Último cartucho de la oposición.|Se hace el último cambio — a partir de ahora todo va hacia adelante.|Un central sube hasta la delantera. Así está la cosa.|Es el último empujón, y no se guarda nada.',
  'commentary.flow.closing.4': 'Los nervios se notan en todo el estadio.|Se notan los nervios en todo el estadio ahora mismo.|Cada pase fallado se recibe con un gruñido de la grada.|La afición pita pidiendo que llegue el final.',
  'commentary.flow.firstA.0': 'Tu equipo ganando confianza.|Crece la confianza, y el pase se ha vuelto más rápido con ella.|Un tramo asentado — un equipo ha tomado el control del centro del campo.|El pase ya tiene ritmo propio.',
  'commentary.flow.firstA.1': 'Disparo a corta distancia — ¡por poco!|Disparo raso desde ocho metros, y se va rozando el palo por fuera.|Tumulto en el área pequeña, y el balón se escapa desviado tras tocar en un defensa.|Cabezazo desde cerca, y cae justo fuera del poste.',
  'commentary.flow.firstA.2': 'Buena combinación por la banda izquierda.|Tres pases por la izquierda, todos al primer toque, y el centro sale casi perfecto.|Buen fútbol por la derecha, y el lateral se va por fuera.|Una pared en la banda abre el campo por un instante.',
  'commentary.flow.firstA.3': 'El portero despeja un córner con los puños.|Se lanza el córner cerrado, y el portero sale a reclamarlo por encima de todos.|Un balón parado al segundo palo genera un momento de pánico antes de despejarse como sea.|Córner tras córner ahora, y la defensa siempre llega a rechazar de cabeza.',
  'commentary.flow.firstB.0': 'Tiro libre peligroso a la vista...|Falta en una zona muy incómoda, veinte metros y centrada.|Se coloca la barrera, y esto es una ocasión de verdad.|Falta en la frontal del área, y hay una oportunidad clara aquí.',
  'commentary.flow.firstB.1': '¡Portero a escena — buena atajada!|Disparo seco desde fuera del área, y el portero la sujeta al segundo intento.|Gran parada, abajo a su izquierda, y el rechace se despeja como se puede.|El portero sale rápido de la línea y se la quita al delantero en los pies.',
  'commentary.flow.firstB.3': '¡Tiro bloqueado en la línea!|Se despeja sobre la línea, y nadie en el estadio sabe cómo.|Un cuerpo se lanza delante del disparo, y el bloqueo lo manda a córner.|Bloqueado, y bloqueado otra vez en el rechace — defensa desesperada.',
  'commentary.flow.open.0': '¡Pitido inicial! Ambos equipos buscando ritmo.|Y ya estamos en marcha. Los dos equipos entrando poco a poco en el partido.|El árbitro lo pone en marcha, y los primeros pases son prudentes.|Allá vamos. Ninguno de los dos quiere regalar nada en estos primeros minutos.',
  'commentary.flow.open.1': 'Presión temprana del centro del campo.|El centro del campo es donde se está decidiendo esto de momento.|Primer tramo de posesión, y el primer territorio real de la tarde.|Los dos equipos presionan arriba, y nadie se ha asentado con el balón todavía.',
  'commentary.flow.open.2': 'La afición ya está vociferando.|El estadio ya está en pie, y todavía no van diez minutos.|Un ruidazo en las gradas cada vez que el balón avanza.|El ambiente aquí lleva creciendo desde el calentamiento.',
  'commentary.flow.secondA.0': 'Segundo tiempo en marcha — tu equipo empuja hacia adelante.|De vuelta para la segunda parte, y ya se nota más urgencia.|El reinicio trae un cambio de ritmo — esto va más rápido que la primera parte.|Segunda parte, y lo que se dijo en el descanso se ha tomado en serio.',
  'commentary.flow.secondA.1': 'El cambio táctico parece estar funcionando.|Ha cambiado el dibujo, y el espacio se abre gracias a eso.|Retoque desde el banquillo, y está teniendo efecto.|Alguien se ha movido hacia dentro, y el campo se ve más grande por ello.',
  'commentary.flow.secondA.2': 'Ahora es de un lado al otro.|El partido se ha abierto del todo — esto es de área a área.|A ninguno de los dos le interesa ya guardar el balón.|Cada despeje vuelve directo, y nadie consigue calmar el partido.',
  'commentary.flow.secondA.3': 'Llaman al fisio por un golpe.|Entra el fisio, hay un jugador en el suelo que necesita asistencia.|Se detiene el juego mientras revisan un golpe en la banda.|Asistencia médica en el campo, y esto se sumará al final.',
  'commentary.flow.secondB.0': 'La batalla en el centro del campo se calienta.|Llueven las entradas por el centro del campo ahora mismo.|Nadie gana el centro del campo, aunque todos lo intentan.|Esto se ha convertido en una pelea en el medio campo.',
  'commentary.flow.secondB.1': 'Disparo de larga distancia — directo al portero.|Desde treinta metros prueba fortuna — el portero la controla sin problema.|Tiene su punto de comba desde lejos, pero va directa a las manos del portero.|Ambicioso desde fuera del área, y nunca inquieta la portería.',
  'commentary.flow.secondB.2': '¡Brillante uno-dos en el área, despejado por poco!|Una pared la abre por completo, y el último toque es de un defensa.|Trabajada con mucha calidad dentro del área, y despejada en el último instante.|Dos pases y la línea defensiva quedó rota — pero llega el despeje.',
  'commentary.forces_save': '¡{who} fuerza una atajada!|{who} la abren a la banda y meten el centro: el portero la saca en estirada.|Pared rápida de {who} en la frontal, y el disparo se repele abajo al primer palo.|{who} salen al contragolpe tres contra dos, y solo una salida a ras de suelo lo evita.|Le cae mansa a {who} a ocho metros — y el portero, no se sabe cómo, está detrás.|{who} sacan un disparo desde el ángulo y el portero la desvía a córner con los dedos.|Un cabezazo en un córner de {who} se queda increíblemente fuera, sobre la línea.|{who} cruzan un disparo raso ante portería y el portero llega con una mano firme.',
  'commentary.goal.equalise.no_scorer': '¡{us} empatan!|¡{us} igualan el marcador!|¡{us} a nivel — partido abierto!|¡Partido abierto! ¡{us} empatan!|¡{us} encuentran el empate!|¡{us} de vuelta en el marcador!|¡Todo igualado — {us} lo consiguen!|¡{us} restablecen la igualdad!',
  'commentary.goal.equalise.with_scorer': '¡{scorer} empata para {us}!|De vuelta — ¡{scorer} la mete para {us}!|{scorer} responde — ¡{us} a nivel!|¡Partido abierto! {us} empatan con {scorer}.|¡{scorer} encuentra el hueco — {us} de vuelta en el marcador!|¡Todo igualado! ¡{scorer} pone la definición para {us}!|¡{scorer} no perdona — {us} han igualado el marcador!|Directo por el centro de la portería, {scorer}, ¡y {us} están a nivel!',
  'commentary.goal.extend.no_scorer': '¡{us} suman otro!|¡{us} amplían la ventaja!|¡{us} arrasan!|¡{us} extienden el colchón!|¡{us} suman uno más!|¡{us} se marchan en el marcador!|¡Se les escapa el partido — otra vez {us}!|¡{us} aprietan más la tuerca!',
  'commentary.goal.extend.with_scorer': '¡{scorer} suma otro para {us}!|Definición a un toque de {scorer} — ¡{us} amplían!|{scorer} repite — ¡{us} arrasan!|Clínico de {scorer} — ¡{us} extienden!|¡{scorer} pone este partido fuera de alcance para {us}!|¡Otro más para {us}, y es de {scorer}!|¡{scorer} otra vez — {us} aprietan más la tuerca!|¡{us} están desatados, y {scorer} está en el centro de todo!',
  'commentary.goal.lead.no_scorer': '¡{us} se ponen por delante!|¡{us} toman la ventaja!|¡{us} rompen el empate!|¡{us} se adelantan!|¡{us} están por delante!|La brecha — ¡{us} mandan!|¡{us} encuentran el primer gol!|¡Primera sangre para {us}!',
  'commentary.goal.lead.with_scorer': '¡{scorer} pone a {us} por delante!|¡Qué disparo de {scorer}! ¡{us} arriba!|¡{scorer} rompe el empate para {us}!|Definido por {scorer} — ¡{us} ganan!|¡{scorer} logra el primer gol — {us} están por delante!|¡{us} mandan, y es {scorer} quien lo ha conseguido!|Una definición salida de la nada de {scorer}, ¡y {us} están arriba!|¡{scorer} encuentra la red — ventaja para {us}!',
  'commentary.goal.pullback.no_scorer': '¡{us} marcan uno!|¡{us} agarran un balón salvavidas!|¡{us} de vuelta a la pelea!|¡{us} ganan terreno!|¡{us} descuentan uno!|¡Gol de {us} — hay partido!|¡{us} reducen la desventaja!|Esto no ha terminado — ¡marcan {us}!',
  'commentary.goal.pullback.with_scorer': '¡{scorer} descuenta para {us}!|¡Esperanza! ¡{scorer} marca para {us}!|¡{scorer} mantiene a {us} con vida!|¡{scorer} convierte para {us}!|¡{scorer} le da a {us} algo a lo que agarrarse!|Uno para {us} con la firma de {scorer} — ¡otra vez hay partido!|¡{scorer} golpea, y {us} no han dicho la última palabra!|Algo de esperanza para {us}, ¡y es {scorer} quien la trae!',
  'commentary.halftime_ahead': '¡{us} van por delante en el descanso!|{us} se van al vestuario con ventaja.|Descanso, y {us} van por delante.|{us} llegan al descanso arriba — la segunda parte es cuestión de mantenerlo.',
  'commentary.halftime_behind': '{us} van por detrás — hora de reaccionar.|Descanso, y {us} tienen trabajo por hacer.|{us} van por detrás en el descanso, y algo tiene que cambiar.|Una primera parte para olvidar de {us}, y cuarenta y cinco minutos para arreglarlo.',
  'commentary.halftime_level': 'Empate en el descanso.|Nada los separa en el descanso.|Todo igualado al descanso.|Empate tras cuarenta y cinco minutos, y puede ganar cualquiera.',
  'commentary.high_scoring_loss': 'Abierto, ese. {us}–{them} en {opp}. Anotamos bastante — solo encajamos uno de más.|{us}–{them} en {opp}. De todo en un área, demasiado en la otra.|Nunca estuvimos fuera de ese partido y tampoco estuvimos seguros en ningún momento. {us}–{them}.|{us}–{them}. Marcar no es nuestro problema. Evitar que nos marquen, sí.|Eso ha sido divertido para todos menos para mí. {us}–{them}, y la próxima semana defendemos mejor.',
  'commentary.high_scoring_win': 'Partidazo. {us}–{them} contra {opp} — goles por todos lados pero nos llevamos el resultado. Definir así vale una llamada de patrocinador.|{us}–{them} contra el {opp}. Un partido loco, para el infarto, y tres puntos.|Marcamos bastante y encajamos algunos. {us}–{them}, y me quedo con eso.|¡{us}–{them}! La delantera fue imparable. De la defensa, ya hablaremos.|Un tiroteo con el {opp}, {us}–{them}, y tuvimos la última palabra.',
  'commentary.hit_post': '¡{who} dan en el palo!|{who} sacan un zapatazo y todo el campo oye el palo.|Rebota en un defensa y cae bajo el larguero para {who} — y sale golpeando la madera.|{who} hacen vibrar el palo contrario desde veinte metros, y se queda fuera.|El larguero los salva — {who} estuvieron a un centímetro del gol.|Un cabezazo de {who} golpea el larguero y bota hacia el lado equivocado de la línea.|En la cara interna del palo y por toda la línea de gol — {who} no lo puede creer.',
  'commentary.injury': '¡{player} se retira lesionado!|{player} no puede continuar — un golpe duro para el equipo.|{player} se resiente y hace la señal al banquillo. Se le acabó la tarde.|Cae {player}, y este no tiene pinta de irse por su propio pie.',
  'commentary.nervy_one_nil': 'Un 1–0 sobre {opp}. No fue bonito, pero tres puntos son tres puntos. Portería a cero, al banco y a otra cosa.|1–0. No hacía falta ponérnoslo tan difícil, pero ganar al {opp} es ganar.|Portería a cero y tres puntos contra el {opp}. En abril nadie se acuerda de cómo.|Un 1–0 feo. Los buenos equipos ganan así, así que no me voy a quejar.|Un gol bastó contra el {opp}. La defensa se lo ganó.',
  'commentary.nil_nil': 'Cero-cero con {opp}. Tarde aburrida — nos llevamos el punto y a buscar más la próxima.|Cero a cero contra el {opp}. Nadie va a hablar de este partido, y un punto es un punto.|Al menos portería a cero. El {opp} no nos sacó nada y nosotros tampoco a ellos.|Sin goles con el {opp}. Podríamos haber jugado hasta medianoche sin marcar.|Un punto, portería a cero, y noventa minutos muy largos contra el {opp}.',
  'commentary.opp_goal': '¡{them} marcan!|¡Qué gol de {them}!|Combinación limpia de {them} — directo dentro.|{them} castigan un mal momento atrás.|{them} pasan uno a través — definición clínica.|Defensa dormida — {them} se aprovechan.|Golazo de {them}, nada que el portero pudiera hacer.|Sucio para {them}, pero cuenta.|{them} encuentran el ángulo — clase superior.|Un córner que nadie ataca, un cabezazo que nadie disputa, y {them} lo tienen de regalo.|{them} trabajan el desdoblamiento y la cuelan al primer palo.|Un desvío en una bota descoloca a todos, y {them} se lo quedan.|Un pase rompe toda la línea defensiva y {them} hacen el resto.|{them} cabecean un centro que nunca debió llegar.|Balón largo, una dejada, y {them} se plantan solos para definir.',
  'commentary.opp_sub': 'El {opp} hace un cambio — piernas frescas desde el banquillo.|Cambio para el {opp} — piernas frescas al campo.|El {opp} recurre al banquillo.|El {opp} hace un cambio, y el que entra se va directo a la delantera.|Sale una camiseta del {opp} ya cansada, y entra una descansada.',
  'commentary.shot_over': '¡{who} la mandan por encima!|{who} la devuelven al área y le pegan de primeras — y la mandan a la segunda grada.|A {who} le bastaba un metro, y desde doce la manda a las nubes.|{who} tienen toda la portería para apuntar y la manda por encima del larguero.|Cabezazo libre de {who} desde seis metros, y se va a la grada.|La volea de {who} sale bien golpeada, pero muchísimo más alta de lo debido.|Disparo de {who} al primer toque, y se marcha por encima del larguero con margen.',
  'commentary.shot_wide': '¡{who} la mandan desviada!|{who} intentan rosquearla al palo largo y la ven irse un palmo fuera.|Le queda perfecta a {who} en el escorzo — y cruza toda la boca de gol sin nadie.|{who} se cuelan hacia dentro y la rosca se va por poco pegada al palo.|Disparo al primer toque de {who} que nunca inquietó de verdad la portería.|Bien trabajada por {who}, y se va desviada desde la frontal del área.|El pase de la muerte encuentra a una camiseta de {who}, y el disparo cruza la portería y se va fuera.',
  'commentary.snub': '{opp} parecen furiosos tras el desaire — espera un partido hostil.|Aquí hay historia, y el {opp} no se ha olvidado de ella.|El {opp} ha salido a este partido con algo que demostrar.',
  'commentary.thriller_draw': '¡{us}–{them}! De ida y vuelta con {opp}. Los neutrales lo disfrutaron aunque solo nos llevemos un punto.|{us}–{them} con el {opp}, y ninguno de los dos merecía perderlo. Nos quedamos con el punto.|Ese partido tuvo de todo menos un ganador. {us}–{them}, y repartimos con el {opp}.|Un punto de {us}–{them}. Entretenido, agotador, y no del todo suficiente.|{us}–{them} contra el {opp}. Si todas las semanas fueran así, me quedaría sin voz.',
  'commentary.thriller_loss': 'Crueldad en un thriller {us}–{them} contra {opp}. Dimos lo nuestro — solo nos faltó el gol del triunfo.|{us}–{them} contra el {opp}. Estuvimos metidos en el partido hasta el último balón y aun así se nos escapó.|No hay nada de qué avergonzarse en {us}–{them}. Pusimos nuestra parte en un buen partido y lo perdimos.|Ese va a doler. {us}–{them}, y un solo instante decidió toda la tarde.|Igualamos al {opp} en todo menos en el marcador. {us}–{them}, y a seguir trabajando.',
  'commentary.thriller_win': '¡Qué partido! {us}–{them} contra {opp} — apenas ganamos un clásico. Partidos así llenan estadios.|{us}–{them}. He envejecido diez años viendo eso, y lo repetiría la semana que viene.|Ahí ganamos un partidazo de verdad, {us}–{them}. El {opp} nos lo puso todo difícil.|Eso ha valido la entrada por sí solo. {us}–{them} contra el {opp}, y nos quedamos del lado bueno.|¡{us}–{them}! No me pregunten cómo, pero encontramos el gol que importaba.',

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
  'match.subs': 'Cambios',
  'match.subs.done': 'Volver al partido',
  'match.subs.on_pitch': 'En el campo',
  'match.subs.bench': 'Banquillo',
  'match.subs.empty_bench': 'No hay jugadores en el banquillo.',
  'match.subs.empty_slot': 'Vacío',
  'match.subs.pick_off': 'Toca un jugador para sustituirlo.',
  'match.subs.pick_on':
      'Toca un jugador del banquillo para que entre (verde = mejor posición).',
  'match.subs.none_left': 'No quedan cambios.',
  'match.subs.feed': 'Sale {off}, entra {on}.',
  'match.subs.feed_on': 'Entra {on}.',
  'difficulty.switch.toHard':
      'Modo Pro: todos los jugadores se cansan durante el partido — gestiona la '
      'energía de la plantilla y rota el banquillo para mantener piernas '
      'frescas. Puedo ayudarte a elegir el once más fresco, pero no diré nada '
      'sobre táctica. Cambiar de modo te hará empezar de cero.',
  'difficulty.switch.toEasy':
      'Modo Casual: sin fatiga, así que el banquillo es solo para cambios '
      'tácticos y lesiones. Vuelven la selección automática y los consejos del '
      'entrenador. Cambiar de modo te hará empezar de cero.',
  'tut.loan_boost.title': '⭐ ¡Llegan estrellas cedidas!',
  'tut.loan_boost.body':
      'He pedido algunos favores… ¡unos <strong>jugadores de primer '
      'nivel</strong> han aceptado unirse para tu primer partido! Se marchan '
      'justo después, así que vamos a aprovecharlos.',
  'tut.loan_boost.btn': 'Ver mi plantilla →',
  'tut.loan_depart.title': 'Ahora construyamos nuestro equipo',
  'tut.loan_depart.body':
      'Las estrellas cedidas se han ido, pero demostraron que podemos competir. '
      'Ahora construyamos algo <strong>nuestro</strong>. Aquí tienes '
      '<strong>500 monedas</strong> para empezar. Estaré abajo a la izquierda '
      'siempre que tenga un consejo.',
  'tut.loan_depart.btn': '¡A construir! →',
  'ach.cat.hardmode': 'Modo Pro',
  'coachtip.subs_bench.title': 'Tienes banquillo',
  'coachtip.subs_bench.body':
      'Toca Cambios durante el partido para abrir el banquillo: tienes 5 '
      'cambios por encuentro y el reloj se detiene mientras eliges. Las '
      'lesiones también pasan por ahí ahora: cuando alguien cae, su camiseta '
      'sale del campo y el hueco queda vacío hasta que metas un relevo, así que '
      'no lo dejes así.',
  'coachtip.try_hard_mode.title': '¿Te apetece un reto?',
  'coachtip.try_hard_mode.body':
      'Has llegado lejos, jefe. ¿Listo para el Modo Pro? Los jugadores se '
      'cansan durante el partido, así que rotar la plantilla y usar el '
      'banquillo importa de verdad — toca Auto y te pongo el once reglamentario '
      'más fresco — y no diré nada sobre táctica. Se empieza con un equipo '
      'nuevo: solo si te ves capaz.',
  'coachtip.try_hard_mode.cta': 'Abrir Ajustes',
  'coach.match.tired': '¡{name} está agotado, mete a un jugador fresco!',
  'toast.energy_refilled': '¡Energía de la plantilla recargada!',
  'toast.no_fit_players':
      'No hay suficientes jugadores en condiciones — déjalos descansar o mira '
      'un anuncio para recargar.',
  'trait.name.iron_lungs': 'Pulmones de acero',
  'trait.desc.iron_lungs':
      'Motor incansable — gasta energía más despacio durante los partidos (Modo '
      'Pro)',
  'champ.title': '¡CAMPEONES!',
  'champ.subtitle': 'Liga de Campeones conquistada',
  'champ.body':
      'Has conquistado todas las divisiones y superado a todos tus rivales. '
      'Estás solo en la cima, como el mejor entrenador del mundo.',
  'champ.prestige_teaser':
      'Reinicia y vuelve a subir desde la Liga Dominical con un <strong>bonus '
      'de ingresos ×{mult} permanente</strong>. Los logros de tu carrera se '
      'quedan contigo para siempre.',
  'champ.new_adventure': '🌟 Empezar nueva aventura',
  'champ.defend': '⚽ Defender el título',
  'game.training.intro':
      'Toca {n} disparos según llegan. Tienes {secs} s por ejercicio.',
};
