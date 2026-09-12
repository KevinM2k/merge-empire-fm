/// Portuguese copy for the match write-up. See `lib/i18n/locale_copy.dart`.
///
/// Voice and conventions taken from `locales/pt.g.dart`'s own `report.*` block:
/// European Portuguese — "golo", "equipa", "baliza" — with the club taking an
/// article and a singular verb, "O {club} recuou". Third person throughout.
library;

/// Replaces the generated entry, or adds a key Portuguese did not have.
const Map<String, String> ptCopy = <String, String>{
  'customise.item.face.bubblegum': 'Chiclete',

  // Uma terceira linha ao lado de Som e Música: o clique de cada botão.
  'settings.ui_sounds': 'Interface',

  // A aba deixou de ser só som: a vibração entra nela.
  'settings.tab.controls': 'Controles',
  'settings.haptics': 'Vibração',
  'settings.haptics.hint': 'Uma leve vibração ao tocar. As configurações de '
      'vibração do seu telefone também podem desativá-la.',
  'settings.tap_ripple': 'Ondas ao tocar',

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

  // Colin relays an offer and calls it; then his tour after the tutorial.
  'coach.bid.relay': 'O {club} ligou, chefe. Eles querem {player} e estão colocando {price} na mesa.',
  'coach.sponsor.relay': 'A {company} entrou em contato, chefe. Querem {player} como cara da marca: {n}% a mais de renda desse jogador enquanto o acordo durar.',
  'coach.verdict.accept': 'Minha opinião: aceite',
  'coach.verdict.decline': 'Minha opinião: recuse',
  'coach.verdict.your_call': 'Minha opinião: pode ir pra qualquer lado',
  'manager.transfer.starter_short': '{player} é titular toda semana e não tem ninguém no banco pra entrar. Recuse, a menos que você contrate um substituto logo depois.',
  'manager.transfer.relegation': 'Estamos na zona de rebaixamento e {player} está no time titular. Vender agora nos enfraquece justo quando não podemos.',
  'manager.transfer.flying': 'Somos líderes e o caixa está saudável. Não precisamos desse dinheiro: mantenha o elenco junto.',
  'manager.transfer.need_money': 'Sinceramente, estamos sem dinheiro. Esse valor paga uma contratação inteira, e precisamos das moedas mais do que de {player}.',
  'manager.transfer.bench_warmer': '{player} nem está no seu time titular, e o preço é justo. Pegue o dinheiro e reforce onde importa.',
  'manager.sponsor.clean': 'Esse não tem pegadinha. Assine: é dinheiro de graça.',
  'manager.sponsor.relegation_starter': '{player} está no time titular e estamos na zona de rebaixamento. Um titular mais fraco é a última coisa que precisamos: recuse.',
  'manager.sponsor.injury_prone': '{player} já tem {seasons} temporadas nas pernas e esse acordo aumenta o risco de lesão. Não vale a pena.',
  'manager.sponsor.poor_form': 'A forma de {player} já está ruim e esse acordo piora ainda mais. Diga não.',
  'manager.sponsor.need_money': 'Estamos curtos de moedas e isso paga a cada segundo. Vale a pegadinha: assine.',
  'manager.sponsor.bench': '{player} não está no seu time titular, então a pegadinha não nos custa nada em campo. Assine.',
  'manager.sponsor.rating_cost': 'Custa {n} de avaliação a {player}, e ele é titular. Mais renda em troca de um time mais fraco: você decide.',
  'manager.sponsor.fair': 'A pegadinha é pequena e a renda não. Eu assinaria.',
  'guide.scout': 'Toque em Olheiro para contratar alguém novo. Dois do mesmo tipo arrastados juntos se fundem num jogador melhor.',
  'guide.squad_tab': 'Boa. Agora abra a aba {tab} e coloque seus melhores onze em campo.',
  'guide.squad_fill': 'Toque numa vaga vazia para escolher quem joga ali, ou aperte Auto e eu completo o time pra você.',
  'guide.dugout': 'Viu o Menu, embaixo à direita? É o Dugout: os treinos e a tabela do campeonato ficam lá.',
  'guide.club_tab': 'O estádio também gera dinheiro. Dê uma olhada na aba {tab}.',
  'guide.club_buy': 'Compre uma instalação aqui. Cada uma que você tiver soma ao que o clube ganha a cada segundo.',
  'guide.shop_tab': 'Faltando energia ou moedas? A aba {tab} tem pacotes e bônus quando você precisar.',

  // ── Commentary pools the spec's own catalogues never widened ───────────
  //
  // English grew these `commentary.*` pools over time; the translated
  // locales stayed at the original length. Existing lines are kept
  // verbatim; new lines fill the gap so every locale draws from the same
  // number of variants. `commentary.opp_sub`'s original single variant was
  // itself untranslated English in every locale — replaced here too.
  'commentary.blocked': '{who} veem o remate bloqueado!|{who} rematam da entrada e um corpo atravessa-se — é assim que um central ganha o ordenado.|Três camisolas do {who} fazem fila para a recarga, e todas são tapadas.|Um remate do {who} a doze metros é bloqueado por uma perna que surge do nada.|{who} recuperam a bola e rematam de novo — e de novo há um corpo no caminho.|Cortado na origem, e {who} têm de recomeçar a jogada.|A defesa atira-se à frente de tudo o que {who} conseguem arranjar.',
  'commentary.booking.opp_red': 'Vermelho direto para o {opp}, e ninguém no estádio contesta — o {opp} fica com dez.|Uma entrada horrível de uma camisola do {opp}, e o árbitro vai direto ao vermelho. O {opp} fica com menos um.|Um jogador do {opp} vai para o chuveiro. Não havia outra decisão possível para aquilo.|Vermelho para o {opp}, e o banco deles não tem nada a dizer sobre isso. Ficam com dez.',
  'commentary.booking.opp_second_yellow': 'Segundo amarelo para o {opp}, e vai para o balneário — complicaram a tarde sozinhos.|São dois amarelos para o mesmo jogador do {opp}, e o árbitro tem de o expulsar. O {opp} fica com dez.|Dois cartões para o mesmo jogador do {opp}, e o árbitro manda ele embora. O {opp} joga o resto com dez.|Segundo amarelo para o {opp}, e isso é vermelho. Complicaram tudo para eles mesmos.',
  'commentary.booking.opp_yellow': 'Uma camisola do {opp} vai para o livro por uma rasteira cínica — o árbitro já tinha visto que chegasse.|O {opp} oferece uma falta desnecessária e leva amarelo por cima.|Amarelo para o {opp}, e o banco deles não gosta nada.|Uma camisola do {opp} leva amarelo por puxar um jogador em fuga — o árbitro não teve escolha.|Entrada atrasada e desajeitada do {opp}, e o amarelo é o menos que podia levar.',
  'commentary.booking.red': 'Vermelho direto para {player}, e não há discussão — último homem, e leva-lhe as pernas. {us} acabam com dez.|{player} perde completamente a cabeça e o árbitro não hesita. Rua. {us} têm de aguentar o resto com dez.|{player} está fora. Uma entrada sem nenhuma intenção de jogar a bola, e {us} terminam com dez.|O árbitro vai direto ao bolso por {player}, e é vermelho. {us} ficam reduzidos a dez.',
  'commentary.booking.second_yellow': 'E é o segundo amarelo de {player} — nada de malicioso, mas já estava advertido e sabia-o. {us} ficam com dez.|{player} entra outra vez, e o árbitro não tem alternativa: dois amarelos, rua. {us} jogam o resto em inferioridade.|Dois amarelos para {player}, e é um caminho longo até o vestiário. {us} ficam com dez pelo resto do jogo.|{player} é advertido de novo, e o vermelho vem em seguida. {us} ficam com um a menos.',
  'commentary.booking.yellow': '{player} é advertido por perda de tempo — o primeiro da tarde, agora vai ter de ter cuidado.|Entrada tardia de {player}, e o árbitro tira o amarelo antes de ele se levantar.|{player} agarra a camisola para travar o contra-ataque. Só há um desfecho: amarelo.|Protesto de {player} — de todas as maneiras parvas de entrar no livro.|{player} chega atrasado na entrada e o árbitro não tem opção — amarelo.|Uma rasteira de {player} no meio-campo, e o cartão sai.|{player} entra para o livro por uma falta que nem valia a pena cometer.',
  'commentary.demolition': '{us}–{them} — que atuação! Desmontamos o {opp}. Os jogadores vão ficar empolgados por dias.|{us}–{them}. Tudo o que tentamos deu certo, e o {opp} não teve resposta para nada.|Não jogamos melhor que isso. {us}–{them} contra o {opp} — aproveitem o momento.|{us}–{them}! Não podia pedir mais do que isso deles hoje.|Fomos implacáveis. {us}–{them}, e o {opp} ficou feliz de ouvir o apito final.',
  'commentary.dispossessed': '{who} perdem a bola — grande desarme!|{who} dão um toque a mais na área, e a entrada é limpíssima.|{who} levantam a cabeça à procura do passe que havia há um segundo — e já lha tiraram do pé.|Um desarme no tempo certo encerra o ataque do {who}.|{who} são roubados na entrada da área por uma entrada que saiu do nada.|A bola é tirada do {who} bem na hora do chute.|{who} demoram demais com a bola e pagam pelo segundo a mais.',
  'commentary.drubbing': 'Feio, esse. {us}–{them} em {opp}. Sacudam a poeira — todo time tem um dia ruim.|{us}–{them} em {opp}. Nada deu certo e não vou fingir o contrário.|Foi uma surra, sem meio-termo. {us}–{them}. Deixamos isso pra trás e seguimos em frente.|{us}–{them}. O {opp} foi melhor que a gente em todos os setores do campo. Acontece.|Não tem muito o que dizer sobre {us}–{them}. Dia ruim, memória curta, próximo jogo.',
  'commentary.flow.addedtime.0': 'Drama nos acréscimos!|Tempo de acréscimo, e isso ainda não está decidido.|Drama lá na reta final deste jogo.|Está acontecendo tudo nesses últimos segundos.',
  'commentary.flow.addedtime.1': 'Aguentando até o fim dos acréscimos.|Bem dentro dos acréscimos, e o resultado está sendo segurado com unhas e dentes.|Cada segundo está sendo aproveitado agora, e ninguém no banco está reclamando.|O relógio é a única coisa que importa agora.',
  'commentary.flow.addedtime.2': 'A placa do quarto árbitro é exibida — acréscimos em andamento.|A placa está no ar, e ainda tem jogo pela frente.|O quarto árbitro sinaliza os minutos de acréscimo, e são mais do que o esperado.|O acréscimo está confirmado, e nenhum dos bancos gostou do número.',
  'commentary.flow.addedtime.3': 'Ainda há tempo para mais uma chance.|Ainda dá tempo para mais um ataque aqui.|Mais uma bola na área, com certeza.|Ainda não acabou — ainda tem mais um lance nesse jogo.',
  'commentary.flow.closing.0': 'Reta final!|Faltam dez minutos, e é aqui que tudo vai se decidir.|O relógio está correndo e a urgência aumentou.|Nos últimos dez minutos, e os dois bancos estão de pé.',
  'commentary.flow.closing.1': 'Cada divisão conta agora.|Cada disputa está sendo travada como se fosse a última da temporada.|Ninguém dá trégua em nenhum canto do campo agora.|Corpo e alma nas duas pontas do campo.',
  'commentary.flow.closing.2': 'Será que vão aguentar?|A pergunta agora é se vão conseguir segurar o resultado.|As pernas estão pesando, e ainda tem tempo no relógio.|Estão defendendo com tudo que têm, e ainda faltam minutos.',
  'commentary.flow.closing.3': 'Último cartão do adversário.|A última mudança foi feita — agora é tudo pra frente.|Um zagueiro foi jogado lá na frente. É esse o estado da coisa.|É o último empurrão, e ninguém está segurando nada.',
  'commentary.flow.closing.4': 'Nervosismo por todo o estádio.|Dá pra sentir o nervosismo aqui agora.|Cada passe errado é recebido com um gemido da torcida.|A torcida já está vaiando pedindo o fim do jogo.',
  'commentary.flow.firstA.0': 'Sua equipe ganhando confiança.|A confiança está crescendo, e os passes ficaram mais rápidos com ela.|Um momento de controle — um dos lados tomou conta do meio-campo.|Os passes já têm um ritmo agora.',
  'commentary.flow.firstA.1': 'Chute de curta distância — passou perto!|Um chute rápido de sete metros, e passa a centímetros do poste.|Bate-rebate na pequena área, e a bola escapa pela lateral após desviar num defensor.|Cabeceio de perto, e a bola passa raspando o poste.',
  'commentary.flow.firstA.2': 'Boa troca de passes pela esquerda.|Três passes pela esquerda, todos de primeira, e o cruzamento sai quase perfeito.|Um futebol bonito pela direita, e o lateral passa por fora.|Uma parede na linha lateral abre o campo por um instante.',
  'commentary.flow.firstA.3': 'Goleiro afasta com os punhos um escanteio.|O escanteio é cobrado, e o goleiro sai e agarra a bola por cima de todo mundo.|Uma bola parada longa causa um momento de pânico antes de ser afastada.|Escanteio atrás de escanteio agora, e a defesa segue afastando de cabeça.',
  'commentary.flow.firstB.0': 'Falta perigosa pra cima...|Uma falta numa área perigosa, a vinte metros e bem centralizada.|A barreira está sendo montada, e essa é uma chance de verdade.|Falta na entrada da grande área, e a chance aqui é real.',
  'commentary.flow.firstB.1': 'Goleiro acionado — boa defesa!|Um chute forte de longe, e o goleiro segura na segunda tentativa.|Que defesa, rasteira à esquerda, e o rebote é afastado como dá.|O goleiro sai rápido da linha e abafa a bola nos pés do atacante.',
  'commentary.flow.firstB.3': 'Chute bloqueado na linha!|É afastada em cima da linha, e ninguém no estádio sabe como.|Um corpo se joga na frente do chute, e o bloqueio manda a bola para escanteio.|Bloqueado, e bloqueado de novo no rebote — a defesa está desesperada.',
  'commentary.flow.open.0': 'Apito inicial! Os dois lados se ajustando.|E o jogo está rolando. Os dois lados se ajustando.|O árbitro dá início, e os primeiros passes são cautelosos.|Lá vamos nós. Nenhum dos dois lados quer se arriscar nos minutos iniciais.',
  'commentary.flow.open.1': 'Pressão precoce do meio-campo.|O meio-campo é onde tudo está sendo decidido até agora.|Um primeiro momento de posse de bola, e o primeiro território real da tarde.|Os dois times pressionam alto, e ninguém ainda se acostumou com a bola.',
  'commentary.flow.open.2': 'A torcida já está barulhenta.|O estádio já está em festa, e ainda nem fez dez minutos.|Um barulhão no estádio toda vez que a bola vai pra frente.|O clima aqui vem crescendo desde o aquecimento.',
  'commentary.flow.secondA.0': 'Segundo tempo começou — sua equipe avança.|De volta para o segundo tempo, e já dá pra sentir mais urgência.|A volta traz uma mudança de ritmo — está mais rápido que o primeiro tempo.|Segundo tempo, e o que foi dito no intervalo parece ter sido ouvido.',
  'commentary.flow.secondA.1': 'A mudança tática parece estar funcionando.|O esquema mudou, e o espaço está abrindo por causa disso.|Uma mudança vinda do banco, e está fazendo efeito.|Alguém mudou de posição pro meio, e o campo parece maior por isso.',
  'commentary.flow.secondA.2': 'Agora é de lá pra cá.|O jogo abriu de vez — é vai e volta o tempo todo.|Nenhum dos dois times quer mais segurar a bola.|Todo afastamento volta na mesma hora, e ninguém consegue segurar o jogo.',
  'commentary.flow.secondA.3': 'Fisio chamado por uma pancada.|O fisioterapeuta entra, e tem um jogador caído precisando de atendimento.|O jogo para enquanto uma pancada é avaliada na lateral.|Atendimento em campo, e isso vai entrar no acréscimo.',
  'commentary.flow.secondB.0': 'A batalha no meio-campo esquentando.|As entradas estão voando pelo meio-campo agora.|Ninguém está vencendo a disputa no meio, e todo mundo está tentando.|Isso virou uma briga franca no meio-campo.',
  'commentary.flow.secondB.1': 'Chute de longe — direto no goleiro.|De trinta metros e mandou a bomba — o goleiro segura sem dificuldade.|Vem com efeito de longe, mas direto nas mãos do goleiro.|Ambicioso de longe, e nunca incomoda o gol.',
  'commentary.flow.secondB.2': 'Brilhante tabela na área, mal afastado!|Uma parede abre a defesa, e o último toque é da bota de um zagueiro.|Trabalhada com categoria dentro da área, e afastada em cima da hora.|Dois passes e a linha de fundo tinha sumido — mas o corte vem a tempo.',
  'commentary.forces_save': '{who} obriga uma defesa!|{who} abrem para a ala e cruzam — o guarda-redes tira-a em esticão.|Tabelinha rápida de {who} à entrada da área, e o remate é desviado rente ao primeiro poste.|{who} saem em contra-ataque três contra dois, e só uma defesa rasteira o impede.|A bola sobra para {who} a oito metros — e o guarda-redes, não se sabe como, está lá.|{who} conseguem rematar de ângulo fechado e o guarda-redes desvia para o poste.|Um cabeceamento de um canto do {who} é tirado, não se sabe como, em cima da linha.|{who} colocam uma bola rasteira na área e o guarda-redes tira com uma defesa forte.',
  'commentary.goal.equalise.no_scorer': '{us} empatam!|{us} igualam o placar!|{us} igualam — jogo aberto!|Jogo aberto! {us} empatam!|{us} encontram o gol de empate!|{us} voltam a ficar em igualdade!|Tudo igual — {us} conseguem!|{us} restabelecem o equilíbrio!',
  'commentary.goal.equalise.with_scorer': '{scorer} empata para {us}!|De volta — {scorer} solta a bomba para {us}!|{scorer} responde — {us} igualam!|Jogo aberto! {us} empatam com {scorer}.|{scorer} encontra um caminho — {us} voltam à igualdade!|Tudo igual! {scorer} com a finalização para {us}!|{scorer} não perdoa — {us} igualam o placar!|Bem no meio do gol, de {scorer}, e {us} estão empatados!',
  'commentary.goal.extend.no_scorer': '{us} marcam outro!|{us} ampliam a vantagem!|{us} dominando!|{us} aumentam a folga!|{us} marcam mais um!|{us} estão disparando no placar!|Está escapando pro adversário — {us} de novo!|{us} apertam ainda mais!',
  'commentary.goal.extend.with_scorer': '{scorer} faz outro para {us}!|Finalização de dois toques de {scorer} — {us} ampliam!|{scorer} repete — {us} dominando!|Clínico de {scorer} — {us} estendem!|{scorer} deixa esse fora de alcance para {us}!|Mais um para {us}, e é {scorer} quem marca!|{scorer} de novo — {us} apertam ainda mais!|{us} estão arrasadores, e {scorer} é o centro de tudo!',
  'commentary.goal.lead.no_scorer': '{us} assumem a liderança!|{us} ficam à frente!|{us} quebram o empate!|{us} disparam!|{us} ficam na frente!|O gol que faltava — {us} lideram!|{us} abrem o placar!|{us} saem na frente!',
  'commentary.goal.lead.with_scorer': '{scorer} coloca {us} na frente!|Que chute de {scorer}! {us} liderando!|{scorer} quebra o empate para {us}!|Encaixado por {scorer} — {us} na frente!|{scorer} abre o caminho — {us} ficam na frente!|{us} lideram, e foi {scorer} quem fez!|Uma finalização do nada de {scorer}, e {us} estão à frente!|{scorer} balança as redes — vantagem para {us}!',
  'commentary.goal.pullback.no_scorer': '{us} marcam um!|{us} pegam uma sobra de vida!|{us} voltam ao jogo!|{us} ganham espaço!|{us} descontam!|Gol para {us} — o jogo está aberto!|{us} diminuem a diferença!|Ainda não acabou — {us} marcam!',
  'commentary.goal.pullback.with_scorer': '{scorer} diminui para {us}!|Esperança! {scorer} aparece para {us}!|{scorer} mantém {us} no jogo!|{scorer} converte para {us}!|{scorer} dá a {us} algo para se agarrar!|Um a menos na diferença para {us} com {scorer} — o jogo está aberto de novo!|{scorer} marca, e {us} ainda não acabaram!|Uma esperança para {us}, e é {scorer} quem entrega!',
  'commentary.halftime_ahead': '{us} estão na frente no intervalo!|{us} vão para o vestiário na frente.|Intervalo, e {us} estão na frente.|{us} vão para o intervalo à frente — o segundo tempo é sobre segurar isso.',
  'commentary.halftime_behind': '{us} estão atrás — hora de reagir.|Intervalo, e {us} têm trabalho a fazer.|{us} estão atrás no intervalo, e algo precisa mudar.|Um primeiro tempo para esquecer de {us}, e quarenta e cinco minutos para consertar.',
  'commentary.halftime_level': 'Empate no intervalo.|Nada os separa no intervalo.|Tudo igual no intervalo.|Empatados depois de quarenta e cinco minutos, e pode ser de qualquer um.',
  'commentary.high_scoring_loss': 'Foi aberto, esse. {us}–{them} em {opp}. Marcamos bastante — só sofremos um a mais.|{us}–{them} em {opp}. Muita coisa boa de um lado, demais do outro.|Nunca saímos dessa, mas também nunca parecemos seguros nela. {us}–{them}.|{us}–{them}. Marcar não é o nosso problema. Evitar que marquem, é.|Foi divertido para todo mundo, menos para mim. {us}–{them}, e na próxima defendemos melhor.',
  'commentary.high_scoring_win': 'Jogão. {us}–{them} contra {opp} — gols pra todo lado mas levamos o resultado. Finalizar assim vale uma ligação de patrocinador.|{us}–{them} contra {opp}. Jogo aberto, de cortar o coração, e três pontos no bolso.|Marcamos bastante e também sofremos alguns. {us}–{them}, e eu fico com esse resultado.|{us}–{them}! O ataque estava impossível de parar. A defesa, a gente conversa depois.|Um tiroteio com {opp}, {us}–{them}, e a última palavra foi nossa.',
  'commentary.hit_post': '{who} acertam no poste!|{who} rematam com tudo e o estádio inteiro ouve o poste.|Bate num defesa e cai por baixo da barra para {who} — e sai a bater no ferro.|{who} acertam o poste mais distante de vinte metros, e a bola fica de fora.|O travessão salva — {who} estiveram a centímetros do gol ali.|Um cabeceamento do {who} bate na trave e quica do lado errado da linha.|Bate na parte interna do poste e corre pela linha do gol — {who} não acreditam.',
  'commentary.injury': '{player} sai lesionado!|{player} não consegue continuar — um golpe duro.|{player} para de repente e faz sinal para o banco. A tarde acabou para ele.|{player} cai no gramado, e esse aí não parece que vai sair andando.',
  'commentary.nervy_one_nil': 'Um 1–0 sobre {opp}. Não foi bonito, mas três pontos são três pontos. Sem sofrer, guarda no bolso, segue.|1–0. Não precisava ter sido tão difícil, mas vitória sobre o {opp} é vitória.|Sem sofrer gol e três pontos contra o {opp}. Ninguém vai lembrar como foi lá na frente.|Um 1–0 feio. Os bons times ganham esses jogos, então não vou reclamar.|Um gol bastou contra o {opp}. A defesa merece esse resultado.',
  'commentary.nil_nil': 'Zero a zero com {opp}. Tarde sem graça — guardamos o ponto e buscamos mais na próxima.|Zero a zero contra o {opp}. Ninguém vai lembrar desse jogo, e ponto é ponto.|Pelo menos não sofremos gol. O {opp} não tirou nada da gente e a gente não tirou nada deles.|Sem gols contra o {opp}. Podíamos jogar até meia-noite que não saía gol.|Um ponto, um jogo sem sofrer gol, e noventa minutos bem longos contra o {opp}.',
  'commentary.opp_goal': '{them} marcam!|Que gol do {them}!|Tabela limpa do {them} — direto pra dentro.|{them} punem um momento desatento atrás.|{them} costuram uma — finalização clínica.|Defesa dormindo — {them} aproveitam.|Bombaço do {them}, goleiro nada pôde fazer.|Bagunçado pro {them}, mas vale.|{them} encaixam no ângulo — classe pura.|Um canto que ninguém ataca, um cabeceamento que ninguém disputa, e {them} têm-no de graça.|{them} trabalham a jogada pela ponta e tocam no primeiro poste.|Um desvio na bota engana todo mundo, e é gol do {them}.|Um passe só rasga a linha de defesa e o {them} faz o resto.|{them} cabeceiam um cruzamento que nunca devia ter entrado.|Uma bola longa, um toque de leve, e o {them} fica na cara do gol para marcar.',
  'commentary.opp_sub': 'O {opp} faz uma substituição — pernas novas vindas do banco.|Mudança no {opp} — pernas novas em campo.|{opp} recorre ao banco.|{opp} faz uma alteração, e o novato já entra direto no ataque.|Sai um jogador cansado do {opp}, entra um descansado.',
  'commentary.shot_over': '{who} atiram por cima!|{who} devolvem-na à área e batem de primeira — e mandam-na para o segundo anel.|A {who} bastava um metro, e de doze manda-a às nuvens.|{who} têm o gol inteiro para mirar e mandam a bola por cima do travessão.|Cabeceio livre do {who} a seis metros, e a bola vai parar na arquibancada.|A voleio do {who} sai bem batida, mas alta demais.|Um chute de giro do {who}, e a bola passa longe por cima do travessão.',
  'commentary.shot_wide': '{who} atiram ao lado!|{who} tentam colocá-la ao segundo poste e vêem-na sair um palmo ao lado.|Fica perfeita para {who} no ângulo — e atravessa a boca da baliza sem ninguém lá.|{who} cortam para dentro e mandam a bola rente, passando perto do poste.|Um chute de primeira do {who} que nunca ameaçou de verdade o gol.|Bem trabalhada pelo {who}, e a bola sai para fora da entrada da área.|O corte para trás encontra uma camisa do {who}, e o chute atravessa o gol e sai.',
  'commentary.snub': '{opp} parecem furiosos depois do desprezo — espere um jogo hostil.|Tem história aqui, e o {opp} não esqueceu.|O {opp} entrou nesse jogo com algo a provar.',
  'commentary.thriller_draw': '{us}–{them}! Jogo de ida e volta com {opp}. Os neutros adoraram mesmo só ganhando um ponto.|{us}–{them} com o {opp}, e nenhum dos dois merecia perder esse jogo. Fico com o ponto.|Teve de tudo, menos um gol decisivo. {us}–{them}, e dividimos o resultado com o {opp}.|Um ponto em {us}–{them}. Divertido, cansativo, e não o suficiente.|{us}–{them} contra o {opp}. Se toda semana fosse assim eu já teria perdido a voz.',
  'commentary.thriller_loss': 'Dor de cabeça num jogo {us}–{them} contra {opp}. Demos tudo — só faltou o gol da vitória.|{us}–{them} contra o {opp}. Estivemos nessa até o último lance e mesmo assim escapou.|Não há vergonha nenhuma em {us}–{them}. Fizemos nossa parte num bom jogo e perdemos.|Essa vai doer. {us}–{them}, e um único lance decidiu a tarde inteira.|Empatamos com o {opp} em tudo, menos no placar. {us}–{them}, e de volta ao trabalho.',
  'commentary.thriller_win': 'Que jogo! {us}–{them} contra {opp} — vencemos um clássico por pouco. Jogos assim lotam estádios.|{us}–{them}. Envelheci dez anos vendo isso, e faria tudo de novo semana que vem.|Ganhamos um jogo e tanto ali, {us}–{them}. O {opp} deu tudo de si.|Só isso já valeu o ingresso. {us}–{them} contra o {opp}, e ficamos do lado certo do resultado.|{us}–{them}! Não me perguntem como, mas achamos o gol que importava.',

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
  'match.subs': 'Subst.',
  'match.subs.done': 'Voltar à partida',
  'match.subs.on_pitch': 'Em campo',
  'match.subs.bench': 'Banco',
  'match.subs.empty_bench': 'Nenhum jogador no banco.',
  'match.subs.empty_slot': 'Vazio',
  'match.subs.pick_off': 'Toque em um jogador para substituí-lo.',
  'match.subs.pick_on':
      'Toque em um jogador do banco para entrar (verde = melhor posição).',
  'match.subs.none_left': 'Não restam substituições.',
  'match.subs.feed': 'Sai {off}, entra {on}.',
  'match.subs.feed_on': 'Entra {on}.',
  'difficulty.switch.toHard':
      'Modo Pro: todos os jogadores se cansam durante a partida — cuide da '
      'energia do elenco e rode o banco para manter as pernas frescas. Posso '
      'ajudar a escolher os onze mais descansados, mas fico calado sobre '
      'táticas. Mudar de modo faz você recomeçar do zero.',
  'difficulty.switch.toEasy':
      'Modo Casual: sem fadiga, então o banco serve apenas para trocas táticas '
      'e lesões. A escalação automática e as dicas do treinador voltam. Mudar '
      'de modo faz você recomeçar do zero.',
  'tut.loan_boost.title': '⭐ Chegam estrelas emprestadas!',
  'tut.loan_boost.body':
      'Puxei alguns cordões… <strong>jogadores de primeira linha</strong> '
      'aceitaram se juntar a nós na sua primeira partida! Eles saem logo depois '
      '— mas vamos aproveitar ao máximo!',
  'tut.loan_boost.btn': 'Ver meu elenco →',
  'tut.loan_depart.title': 'Agora vamos construir nosso time',
  'tut.loan_depart.body':
      'As estrelas emprestadas foram embora — mas provaram que temos como '
      'competir. Agora vamos construir algo <strong>nosso</strong>. Aqui estão '
      '<strong>500 moedas</strong> para começar. Estarei no canto inferior '
      'esquerdo sempre que eu tiver um conselho.',
  'tut.loan_depart.btn': 'Vamos construir! →',
  'ach.cat.hardmode': 'Modo Pro',
  'coachtip.subs_bench.title': 'Você tem um banco',
  'coachtip.subs_bench.body':
      'Toque em Subst. durante a partida para abrir o banco: você tem 5 trocas '
      'por jogo e o relógio para enquanto você escolhe. As lesões passam por aí '
      'agora: quando alguém cai, a camisa sai de campo e o lugar fica vazio até '
      'você colocar um substituto, então não o deixe assim.',
  'coachtip.try_hard_mode.title': 'Que tal um desafio?',
  'coachtip.try_hard_mode.body':
      'Você já percorreu um longo caminho, chefe. Pronto para o Modo Pro? Os '
      'jogadores se cansam durante a partida, então rodar o elenco e usar o '
      'banco conta de verdade — toque em Auto e eu escalo os onze mais '
      'descansados dentro das regras — e fico calado sobre táticas. Começa um '
      'time novo: só se você estiver a fim.',
  'coachtip.try_hard_mode.cta': 'Abrir Configurações',
  'coach.match.tired': '{name} está exausto — coloque um jogador descansado!',
  'toast.energy_refilled': 'Energia do elenco recarregada!',
  'toast.no_fit_players':
      'Não há jogadores suficientes em condições — descanse-os ou assista a um '
      'anúncio para recarregar.',
  'trait.name.iron_lungs': 'Pulmões de aço',
  'trait.desc.iron_lungs':
      'Motor incansável — gasta energia mais devagar durante as partidas (Modo '
      'Pro)',
  'champ.title': 'CAMPEÕES!',
  'champ.subtitle': 'Liga dos Campeões conquistada',
  'champ.body':
      'Você conquistou todas as divisões e superou todos os rivais. Está '
      'sozinho no topo, como o maior treinador do mundo.',
  'champ.prestige_teaser':
      'Recomece e suba de novo desde a Liga Dominical com um <strong>bônus de '
      'renda ×{mult} permanente</strong>. As conquistas da sua carreira ficam '
      'com você para sempre.',
  'champ.new_adventure': '🌟 Começar nova aventura',
  'champ.defend': '⚽ Defender o título',
  'game.training.intro':
      'Toque em {n} chutes conforme eles chegam. Você tem {secs}s por treino.',

  // ── Two strings that quoted POUNDS in every language ─────────────────────
  //
  // The badge's figure is a RATIO between bundles and has no currency in it at
  // all; "/£" was decoration that happened to be sterling. And the consent
  // notice named the range in pounds to a parent who does not pay in them —
  // it takes the store's own two figures now, see `age_gate_sheet.dart`.
  'shop.coin_value_badge': '+{pct}% de valor',
  'agegate.purchases_body':
      'Estão disponíveis pacotes de moedas ({min} – {max}), pacotes de energia '
      'e um passe VIP. Todas as compras são processadas com segurança pelo '
      'Google Play. Nenhuma assinatura é necessária. O consentimento dos pais '
      'abaixo libera essas compras para esta conta.',

  // What settled a level cup tie. Under the score in a 42pt slot,
  // so it is an abbreviation. See `league_sheets.dart`.
  'fixtures.on_pens': 'pênaltis',
};
