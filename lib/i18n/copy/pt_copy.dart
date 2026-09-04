/// Portuguese copy for the match write-up. See `lib/i18n/locale_copy.dart`.
///
/// Voice and conventions taken from `locales/pt.g.dart`'s own `report.*` block:
/// European Portuguese — "golo", "equipa", "baliza" — with the club taking an
/// article and a singular verb, "O {club} recuou". Third person throughout.
library;

/// Replaces the generated entry, or adds a key Portuguese did not have.
const Map<String, String> ptCopy = <String, String>{
  // ── O título ─────────────────────────────────────────────────────────────
  //
  // Substituídos, não alargados: os textos gerados abrem todos com {score}.
  // `{minute}` só chega aos três textos `.late`.
  'report.win.rout':
      'Acabou, e foi um passeio: o {club} meteu {ours} ao {opp} sem se '
          'despentear.|'
      'Apito final para uma goleada. {ours} do {club}, {theirs} do {opp}, e o '
          'resultado não favorece ninguém a não ser quem ganhou.|'
      'Final, e o {club} desmontou o {opp}: {ours} golos, e podiam ter sido '
          'mais.',
  'report.win.comfortable':
      'Soou o apito e o {club} ganhou isto a passo, três golos acima do {opp}.|'
      'Acabou. Três golos no fim, e o {club} nunca correu o risco de os '
          'devolver.|'
      'Final. O {club} ganha por três e faz o trabalho sem nunca ter de '
          'forçar.',
  'report.win.clear':
      'Soou o apito e o {club} ganha por dois. O {opp} teve períodos sem nunca '
          'parecer capaz de empatar.|'
      'Acabou, dois golos de diferença, e o {club} geriu a tarde a partir do '
          'momento em que entrou o segundo.|'
      'Final, e uma vitória por dois do {club} tão confortável quanto soa.',
  'report.win.narrow':
      'Soou o apito e houve um golo de diferença — e foi do {club}.|'
      'Acabou. Um único golo separa-os no fim, e os pontos são do {club}.|'
      'Final, e o {club} levou-a à tangente. Um golo, e podia ter caído para '
          'qualquer lado.',
  'report.win.late':
      'Soou o apito e o {club} ganhou tarde: o golo que decidiu chegou aos '
          '{minute} minutos.|'
      'Acabou, e que final: empatado até aos {minute} minutos, e depois o '
          '{club} encontrou aquele a que o {opp} já não teve tempo de '
          'responder.|'
      'Final. O empate parecia o resultado mais provável até aos {minute} '
          'minutos, quando o {club} a ganhou.',
  'report.win.thriller':
      'Acabou, e que jogo: {total} golos entre os dois, e vai para o {club}.|'
      'Apito final num jogo de {total} golos, e o {club} sai dele com os '
          'pontos.|'
      'Final, e respirar. {total} golos, e caiu para o lado do {club} pelo da '
          'diferença.',
  'report.draw.goalless':
      'Soou o apito e nada os separa: sem golos, e sem grandes ocasiões '
          'também.|'
      'Acabou, sem golos. Os dois guarda-redes tiveram uma tarde sossegada.|'
      'Final, e honras repartidas com o marcador a zero.',
  'report.draw.shared':
      'Soou o apito com empate: {ours} para cada um, e nem o {club} nem o {opp} '
          'encontraram aquele que resolvia.|'
      'Acabou, e repartem os pontos. {ours} cada um, num jogo que tinha um '
          'vencedor algures.|'
      'Final, e iguais. Nenhum dos balneários vai ficar inteiramente contente '
          'com isso.',
  'report.draw.late':
      'Soou o apito com empate, e o golo que igualou só chegou aos {minute} '
          'minutos: um ponto ganho para uns e dois perdidos para outros.|'
      'Acabou, iguais, e foi preciso esperar até aos {minute} minutos para lá '
          'chegar.|'
      'Final, com o golo do empate a cair aos {minute} minutos.',
  'report.draw.thriller':
      'Acabou, e que jogo: {total} golos e nada que os separe.|'
      'Apito final num jogo de {total} golos que nenhum dos dois conseguiu '
          'ganhar.|'
      'Final, e um ponto para cada um ao fim de {total} golos entre eles.',
  'report.loss.narrow':
      'Soou o apito e houve um golo de diferença — e foi do {opp}.|'
      'Acabou. O {opp} leva-a por um golo, e ao {club} ficam as perguntas.|'
      'Final, e o {club} perde pela margem mínima. Detalhes, e caíram para o '
          'lado do {opp}.',
  'report.loss.late':
      'Soou o apito e o {club} perdeu tarde: o golo do {opp} chegou aos '
          '{minute} minutos.|'
      'Acabou, e um final cruel: empatado até aos {minute} minutos, e depois o '
          '{opp} marcou aquele que contava.|'
      'Final. Ao {club} tinha chegado para o ponto até aos {minute} minutos, e '
          'nem um minuto mais.',
  'report.loss.thriller':
      'Acabou, e que jogo: {total} golos entre os dois, mas vai para o {opp}.|'
      'Apito final num jogo de {total} golos, e o {club} sai dele sem nada.|'
      'Final, e respirar. {total} golos, e caiu para o lado do {opp} pelo da '
          'diferença.',
  'report.loss.clear':
      'Soou o apito e o {opp} ganha por dois. O {club} foi segundo nas duas '
          'áreas.|'
      'Acabou, dois golos de diferença, e o {club} nunca voltou realmente ao '
          'jogo depois do segundo.|'
      'Final, e uma derrota por dois do {club} diante de um {opp} mais afiado '
          'onde interessava.',
  'report.loss.comfortable':
      'Soou o apito e o {club} levou uma sova: três golos para o {opp} no fim.|'
      'Acabou. Três de diferença, e o {club} andava só a segurar muito antes '
          'do apito.|'
      'Final, e uma tarde para esquecer do {club}, batido por três.',
  'report.loss.rout':
      'Acabou, e foi uma lição: o {opp} meteu {theirs} ao {club}.|'
      'Apito final numa goleada. {theirs} do {opp}, {ours} do {club}, e '
          'ninguém tem de que se queixar.|'
      'Final, e o {club} foi desmontado: {theirs} sofridos, e podiam ter sido '
          'mais.',

  // ── Como jogou o adversário ──────────────────────────────────────────────
  'report.opp.comeback':
      'O {opp} parecia batido e nunca jogou como tal, e no fim era a equipa em '
          'que se teria apostado.|'
      'Mérito para o {opp} — foi segundo durante um período e virou a tarde do '
          'avesso.|'
      'Diz alguma coisa sobre o {opp} que ir atrás no marcador pareça '
          'acalmá-lo.',
  'report.opp.rampant':
      'O {opp} esteve enorme, rápido em tudo o que fez e implacável com cada '
          'erro que apareceu.|'
      'Este foi o {opp} na sua melhor versão, e quem lá esteve por eles vai '
          'falar do jogo a semana toda.|'
      'Ao {opp} saiu tudo. Não são muitas as equipas que lhe teriam aguentado '
          'hoje.',
  'report.opp.shut_us_out':
      'O {opp} foi tão bom sem bola como com ela, e o {club} nunca encontrou '
          'maneira de passar.|'
      'Baliza a zeros e os pontos para o {opp}, que defendeu a sua área como '
          'deve ser do primeiro ao último minuto.|'
      'O {opp} não deu nada ao {club} com que trabalhar, e isso explica a '
          'vitória tanto como o que fez lá à frente.',
  'report.opp.clinical':
      'Não houve grande coisa entre os dois; o {opp} foi simplesmente mais '
          'certeiro quando as ocasiões apareceram.|'
      'O {opp} aproveitou os seus momentos e o {club} não, que costuma ser '
          'tudo.|'
      'O {opp} não precisou de ser a melhor equipa para ganhar isto, e também '
          'não andou longe de o ser.',
  'report.opp.fought_back':
      'O {opp} esteve atrás e não parou de vir, e poucos no estádio diriam que '
          'o ponto não é merecido.|'
      'Foi preciso carácter do {opp} para voltar a entrar neste jogo.|'
      'O {opp} recusou-se a aceitá-lo e ganhou a sua parte da tarde pelo '
          'caminho difícil.',
  'report.opp.stalemate':
      'O {opp} esteve tão organizado como o {club}, e nenhum dos dois encontrou '
          'a brecha.|'
      'Pouco a escolher entre eles — o {opp} foi tão difícil de partir como o '
          '{club}.|'
      'O {opp} veio à procura de um ponto e defendeu como uma equipa que o '
          'queria a sério.',
  'report.opp.matched':
      'O {opp} igualou o {club} durante longos períodos e vai sentir mais ou '
          'menos o mesmo sobre o resultado.|'
      'Jogo honesto e equilibrado do {opp}, que nunca esteve atrás nem chegou '
          'a estar bem à frente.|'
      'Houve pouco entre eles, e o {opp} não vai sentir que perdeu aqui o que '
          'quer que seja.',
  'report.opp.outclassed':
      'Foi uma tarde longa para o {opp}, segundo em quase tudo e sem nunca '
          'conseguir agarrar o jogo.|'
      'O {opp} vai querer esquecer este depressa. Muito pouco lhe correu bem.|'
      'Pouco funcionou ao {opp}, e a diferença entre as duas equipas era clara '
          'muito antes do fim.',
  'report.opp.pushed':
      'O {opp} obrigou o {club} a trabalhar e também não andou longe.|'
      'O {opp} vai sentir que teve deste jogo o suficiente para levar alguma '
          'coisa.|'
      'Havia aqui mais para o {opp} do que o resultado lhe dá.',

  // ── Os golos, como assunto e não como cronologia ─────────────────────────
  'report.goals.opened':
      '{player} pôs o {club} em andamento.|'
      'Foi {player} quem começou isto pelo {club}.|'
      '{player} abriu o marcador, e o {club} construiu a tarde a partir dali.',
  'report.goals.surge.ours':
      'A segunda parte foi de sentido único. O {club} marcou à vontade depois '
          'do intervalo e o {opp} não teve resposta para nada daquilo.|'
      'O {club} entrou para a segunda parte outra equipa, e os golos foram '
          'chegando até o {opp} deixar de os contar.|'
      'O que quer que se tenha dito ao intervalo resultou: o {club} levou o '
          'jogo para longe do {opp} depois dele.',
  'report.goals.surge.theirs':
      'O {opp} desfez a segunda parte. O {club} ainda estava no jogo ao '
          'intervalo e não estava nem perto no fim.|'
      'O intervalo mudou tudo para pior: o {opp} marcou uma e outra vez depois '
          'dele e o {club} não conseguiu travar nada.|'
      'O {club} entrou para a segunda parte e foi atropelado. O {opp} não deu '
          'tréguas depois do intervalo.',

  // ── O balanço do jogo, sem um único número ───────────────────────────────
  //
  // Os dois primeiros não podem reclamar a posse: também disparam com um só
  // eixo, e o {club} pode ter tido a bola e ainda assim ter sido segundo.
  'report.stats.on_top':
      'O {club} teve o melhor disto e pareceu o mais provável durante quase '
          'todo o jogo.|'
      'Este era um jogo para o {club} controlar, e controlou. O {opp} passou '
          'boa parte a correr atrás.|'
      'O {club} mandou na maior parte dos noventa e o {opp} raramente deu '
          'sinais de mudar isso.',
  'report.stats.pinned_back':
      'O {club} passou boa parte a defender, e o {opp} foi quem parecia que ia '
          'marcar.|'
      'O {opp} teve o melhor disto desde cedo e o {club} raramente conseguiu '
          'sair de baixo.|'
      'Houve uma equipa por cima aqui e não foi o {club}. O {opp} levou-lhe o '
          'jogo.',
  'report.stats.ball_only':
      'O {club} teve bola de sobra e muito pouco para mostrar. O {opp} defendeu '
          'a sua área e ficou bem com isso.|'
      'Toda a posse do mundo para o {club}, e as ocasiões que vieram com ela '
          'não valiam grande coisa.|'
      'O {club} guardou a bola e o {opp} manteve-o longe de onde ela fazia '
          'estragos.',
  'report.stats.counter':
      'O {opp} teve a bola e o {club} teve os momentos, o que é tanto uma '
          'maneira de jogar como um acaso.|'
      'O {club} deixou-se estar perante o {opp} e tirou muito mais do que lhe '
          'apareceu.|'
      'A posse foi para um lado e as ocasiões claras para o outro. Ao {club} '
          'isso não vai custar nada.',
  'report.stats.even':
      'Houve muito pouco entre eles, com bola e sem ela.|'
      'O {club} e o {opp} estiveram tão equilibrados como a tarde sugere.|'
      'Nem o {club} nem o {opp} tiveram jogo suficiente durante tempo '
          'suficiente para lhe chamar seu.',

  // ── O período final, do outro banco ──────────────────────────────────────
  //
  // `{chaser}` é quem chegou atrás ao período final e `{holder}` quem estava à
  // frente, para a frase servir de qualquer um dos lados.
  'report.late.held_out':
      'O {chaser} atirou tudo para a frente na parte final e não encontrou '
          'maneira de passar.|'
      'Os últimos minutos foram todos do {chaser}, e o {holder} aguentou.|'
      'O {chaser} insistiu e insistiu à procura do golo e ele nunca chegou.',
  'report.late.consolation':
      'O {chaser} empurrou toda a gente para a frente no fim e tirou dali um '
          'golo, e pouco mais.|'
      'O golo tardio deu ao {chaser} alguma coisa para mostrar pela pressão e '
          'nunca pareceu que fosse chegar.|'
      'O {chaser} encontrou um ao fim de um longo período de pressão, e a essa '
          'altura o {holder} já tinha feito o mais difícil.',

  // ── O banco ──────────────────────────────────────────────────────────────
  'report.subs.impact':
      '{player} saiu do banco e fez a diferença para o {club}.|'
      'A substituição do {club} resultou: {player} entrou e marcou.|'
      'O banco pagou-se a si próprio — {player} entrou e meteu-se no marcador '
          'pelo {club}.',
  'report.subs.changes':
      'O {club} foi gastando substituições à procura de alguma coisa.|'
      'O {club} esvaziou o banco a ver se entrava no jogo.|'
      'As trocas sucederam-se no {club}, sem que nenhuma virasse grande '
          'coisa.',

  // ── O árbitro ────────────────────────────────────────────────────────────
  //
  // Sem minuto: o que interessa é que acabaram com menos um.
  'report.cards.our_red_named':
      '{player} foi expulso, e o {club} terminou com menos homens do que '
          'começou.|'
      'O vermelho a {player} deixou o {club} em inferioridade o resto do '
          'jogo.',
  'report.cards.our_booked_many':
      '{n} jogadores do {club} viram amarelo: {names}.|'
      'O árbitro admoestou {names} no {club}, {n} cartões ao todo.',
  'report.cards.their_reds':
      'O {opp} teve {n} expulsos e acabou o jogo muito longe de uma equipa '
          'inteira.|'
      '{n} vermelhos para o {opp}, que condicionaram tudo o que veio a '
          'seguir.',

  // ── As mudanças de plano ─────────────────────────────────────────────────
  //
  // Sem minuto e sem o nome do sistema: uma decisão, não um ajuste de ecrã.
  // `{minute}` e `{tactic}` continuam a chegar e aqui não se usam.
  'report.tactic.shut_up_shop':
      'O {club} recuou para a parte final e pôs-se a proteger o que tinha.|'
      'Já no fim o {club} fechou a loja, convidou o {opp} a vir e confiou em si '
          'para aguentar.|'
      'O {club} juntou toda a gente atrás da bola para o que faltava e acabou a '
          'tarde assim.',
  'report.tactic.went_for_it':
      'O {club} atirou gente para a frente na parte final e aceitou o risco que '
          'vinha com isso.|'
      'Já no fim o {club} foi a ele, subindo sobre o {opp} em vez de se '
          'contentar com o que tinha.|'
      'O {club} arriscou o que faltava e mandou corpos para a frente.',
  'report.tactic.settled':
      'O {club} mudou de desenho para a parte final e acabou o jogo assim.|'
      'Uma reorganização do {club} já no fim marcou a forma como a tarde '
          'acabou.|'
      'O {club} recolocou-se para o que faltava e levou o jogo até ao fim '
          'dessa maneira.',
  // ── A tabela, e a concordância com o número ──────────────────────────────
  //
  // "1 lugares" e "1 pontos", a mesma falta reportada em inglês. {ps} resolve
  // "ponto{ps}" porque em português o sufixo é mesmo um `s`; "lugares" não, por
  // isso essa metade está reescrita para não contar substantivo nenhum.
  'report.table.climbed':
      'Isso faz o {club} subir {n} na classificação: {pos}, com {pts} '
          'ponto{ps}.|'
      'Sobe {n} na tabela, {pos}, com {pts} ponto{ps}.|'
      '{pos} agora o {club}, {n} acima de onde estava, com {pts} ponto{ps}.',
  'report.table.dropped':
      'Isso faz o {club} descer {n} na classificação: {pos}, com {pts} '
          'ponto{ps}.|'
      'Desce {n} na tabela, {pos}, com {pts} ponto{ps}.|'
      '{pos} e a cair, {n} abaixo de onde estava, com {pts} ponto{ps}.',
  'report.table.held':
      'Continua {pos}, agora com {pts} ponto{ps}.|'
      '{pos}, sem alteração, {pts} ponto{ps}.|'
      'Sem movimento — {pos} com {pts} ponto{ps}.',

  // The settings screen's small print — see `en_copy.dart`.
  'settings.cutaways.hint':
      'Quando surge uma ocasião para um lado que tenhas ligado, o jogo corta '
          'para o relvado e joga o lance — e podes revê-lo depois.',
  'settings.matchSpeed.auto': 'Auto',
  'settings.matchSpeed.hint':
      'O Auto corre a 2x e desce a meia velocidade sempre que o mister tem algo '
          'a dizer, para teres tempo de ler e agir.',

  // The training list's ceiling — see `en_copy.dart`.
  'training.up_to': 'Até',

  // O treino em descanso e a contagem decrescente — ver `en_copy.dart`.
  'training.resting': 'Tempo de espera {time}',
  'mg.countdown_go': 'VAI!',

  // Loja: a prateleira já não é grátis, e as receitas saem dos reforços — ver
  // `en_copy.dart`.
  'shop.lucky_boot_name': 'Bota da sorte',
  'shop.lucky_boot_desc': 'Próximo adversário {pct}% mais fraco (um jogo)',
  'shop.section.income': 'Receitas',
  'product.energy_director.desc': '+50 energia agora · Cap aumentado para 15 · recarga {energyPct}% mais rápida — para sempre, mesmo após resets!',

  'shop.section.looks': 'Estilo do treinador',

};
