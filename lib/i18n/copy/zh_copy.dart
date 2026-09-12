/// Chinese copy for the match write-up. See `lib/i18n/locale_copy.dart`.
///
/// Voice and conventions taken from `locales/zh.g.dart`'s own `report.*` block:
/// simplified Chinese, plain register, clubs as bare subjects. The minute is
/// written "第{minute}分钟", which is why `ordinalOf` hands every locale but
/// English a bare number.
library;

/// Replaces the generated entry, or adds a key Chinese did not have.
const Map<String, String> zhCopy = <String, String>{
  'customise.item.face.bubblegum': '泡泡糖',

  // 位于“声音”和“音乐”旁的第三行：每个按钮的点击音。
  'settings.ui_sounds': '按键音',

  // 该标签页不再只关乎声音：振动也归入其中。
  'settings.tab.controls': '操作',
  'settings.haptics': '振动',
  'settings.haptics.hint': '每次点按时轻微振动。手机自身的振动设置也可以将其关闭。',
  'settings.tap_ripple': '点击涟漪',

  // ── 头条 ──────────────────────────────────────────────────────────────────
  //
  // 是替换而不是扩充：生成的文案一律以{score}开头。{minute}只送到三条`.late`。
  'report.win.rout':
      '终场哨响，这是一场碾压：{club}打进{ours}球，而且几乎没出汗。|'
      '大胜的终场哨。{club}{ours}球，{opp}{theirs}球，这个比分只照顾了赢家。|'
      '全场结束，{club}把{opp}拆开了——{ours}个进球，还本可以更多。',
  'report.win.comfortable':
      '哨声响起，{club}是小跑着赢下来的，领先{opp}三球。|'
      '结束了。终场三球差距，{club}从没有过把球送回去的风险。|'
      '全场结束。{club}净胜三球，全程没有一刻需要用力。',
  'report.win.clear':
      '哨声响起，{club}以两球取胜。{opp}也有过自己的时段，但始终没有追平的样子。|'
      '结束了，两球差距，从第二球进去那一刻起，这个下午就由{club}掌管。|'
      '全场结束，{club}两球取胜，听上去多轻松，实际就多轻松。',
  'report.win.narrow':
      '哨声响起，只差一球——而这一球属于{club}。|'
      '结束了。终场分开两队的只有一球，三分归{club}。|'
      '全场结束，{club}险胜。一球之差，倒向哪边都不奇怪。',
  'report.win.late':
      '哨声响起，{club}赢在了最后：决定胜负的一球来自第{minute}分钟。|'
      '结束了，多么精彩的收尾：一直平到第{minute}分钟，然后{club}找到了那一球，'
          '{opp}再没有时间回应。|'
      '全场结束。直到第{minute}分钟，平局都还像是最可能的结果，然后{club}把它'
          '拿走了。',
  'report.win.thriller':
      '结束了，多么过瘾的一场：两队合计{total}球，最后归{club}。|'
      '{total}个进球的对攻战吹响终场哨，带走三分的是{club}。|'
      '全场结束，喘口气。{total}个球，最后以一球之差倒向{club}。',
  'report.draw.goalless':
      '哨声响起，两队之间没有分别：没有进球，机会也不多。|'
      '结束了，零比零。两位门将过了个安静的下午。|'
      '全场结束，记分牌空着，各取所需。',
  'report.draw.shared':
      '哨声响起，握手言和：各进{ours}球，{club}和{opp}都没能找到那个定胜负的。|'
      '结束了，分享积分。各{ours}球，这场比赛里其实藏着一个胜者。|'
      '全场结束，打平。两间更衣室都不会完全满意。',
  'report.draw.late':
      '哨声响起，握手言和，而扳平的一球直到第{minute}分钟才来——对一方是赚到的'
          '一分，对另一方是丢掉的两分。|'
      '结束了，打平，走到这一步花了到第{minute}分钟。|'
      '全场结束，扳平的进球出现在第{minute}分钟。',
  'report.draw.thriller':
      '结束了，多么好看的一场：{total}个进球，仍然分不出高下。|'
      '一场谁都没能赢下的{total}球对攻战吹响终场哨。|'
      '全场结束，两队合计{total}球之后各拿一分。',
  'report.loss.narrow':
      '哨声响起，只差一球——而这一球属于{opp}。|'
      '结束了。{opp}以一球带走比赛，留给{club}的是问题。|'
      '全场结束，{club}以最小的差距落败。细节而已，而细节倒向了{opp}。',
  'report.loss.late':
      '哨声响起，{club}输在了最后：{opp}的制胜球来自第{minute}分钟。|'
      '结束了，残酷的收尾：一直平到第{minute}分钟，然后{opp}打进了那个要命的。|'
      '全场结束。到第{minute}分钟为止，{club}做的已经够拿一分，再多一分钟就不'
          '够了。',
  'report.loss.thriller':
      '结束了，多么过瘾的一场：两队合计{total}球，但归{opp}。|'
      '{total}个进球的对攻战吹响终场哨，{club}什么都没拿到。|'
      '全场结束，喘口气。{total}个球，最后以一球之差倒向{opp}。',
  'report.loss.clear':
      '哨声响起，{opp}以两球取胜。{club}在两个禁区里都慢了一步。|'
      '结束了，两球差距，第二球之后{club}再没有真正回到比赛里。|'
      '全场结束，{club}两球落败，对手{opp}在要紧的地方更锋利。',
  'report.loss.comfortable':
      '哨声响起，{club}被打得很透——终场落后{opp}三球。|'
      '结束了。三球差距，{club}在终场哨很久以前就只是在扛。|'
      '全场结束，对{club}是个难受的下午，净负三球。',
  'report.loss.rout':
      '结束了，这是一堂课：{opp}打进{club}{theirs}球。|'
      '大胜的终场哨。{opp}{theirs}球，{club}{ours}球，谁也没什么好说的。|'
      '全场结束，{club}被拆开了——丢{theirs}球，还本可以更多。',

  // ── 对手踢得如何 ──────────────────────────────────────────────────────────
  'report.opp.comeback':
      '{opp}看着像输定了，却一次也没那样踢，到最后反倒是你会押注的那支。|'
      '要给{opp}掌声——落后了一阵，然后把整个下午翻了过来。|'
      '落后反而像是让{opp}安定下来，这一点很说明问题。',
  'report.opp.rampant':
      '{opp}表现极其出色，一切都快，出现的每个失误都不放过。|'
      '这是最好状态的{opp}，为他们到场的人会聊上一整个星期。|'
      '{opp}做什么成什么。今天能跟得住他们的球队不多。',
  'report.opp.shut_us_out':
      '{opp}无球时和有球时一样好，{club}始终没找到过去的路。|'
      '零封加三分归{opp}，从第一分钟到最后一分钟，他们把自己的禁区守得像样。|'
      '{opp}没给{club}留下任何可用的东西，这和他们前场做的事一样是取胜的原因。',
  'report.opp.clinical':
      '两队之间差得不多；只是机会来临时{opp}更锋利。|'
      '{opp}抓住了自己的时刻而{club}没有，通常这就是全部。|'
      '{opp}并不需要更强才能赢下这场，何况他们本来也不差多少。',
  'report.opp.fought_back':
      '{opp}落后了还一直压上来，场内没有几个人会说这一分不该拿。|'
      '要重新回到这场比赛里，{opp}拿出了性格。|'
      '{opp}拒绝接受，用最难的方式挣到了属于自己的那份下午。',
  'report.opp.stalemate':
      '{opp}和{club}一样有组织，两边都没能找到缝隙。|'
      '几乎无从取舍——{opp}和{club}一样难攻。|'
      '{opp}是奔着一分来的，也守得像一支当真的球队。',
  'report.opp.matched':
      '{opp}在很长的时段里和{club}分庭抗礼，对这个结果的感受多半也差不多。|'
      '{opp}踢得诚实而均势，没落后过，也没真正领先过。|'
      '两队之间差得不多，{opp}不会觉得自己在这里丢了什么。',
  'report.opp.outclassed':
      '对{opp}是个漫长的下午，几乎处处慢半拍，始终没能在比赛里站稳。|'
      '{opp}会想尽快忘掉这一场。顺的事情太少了。|'
      '{opp}几乎没什么运转起来，两队的差距远在终场之前就已经很清楚。',
  'report.opp.pushed':
      '{opp}让{club}费了力气，自己也不算远。|'
      '{opp}会觉得这场比赛里有足够多的东西，本该带走点什么。|'
      '这场比赛给{opp}的，比比分给他们的要多。',

  // ── 进球，作为话题而不是时间表 ────────────────────────────────────────────
  'report.goals.opened':
      '{player}把{club}带动了起来。|'
      '为{club}开这个头的是{player}。|'
      '{player}打破僵局，{club}的整个下午就建在这上面。',
  'report.goals.surge.ours':
      '下半场是单向的。{club}中场休息后想进就进，{opp}对其中任何一个都没有答案。|'
      '{club}下半场像换了一支球队出来，进球一直来到{opp}不再数了为止。|'
      '中场休息说了什么都奏效了：此后{club}把比赛带得离{opp}越来越远。',
  'report.goals.surge.theirs':
      '{opp}把下半场拆开了。中场休息时{club}还在比赛里，终场时连边都摸不着。|'
      '中场休息把一切变得更糟：{opp}此后一个接一个地进，{club}一个也拦不住。|'
      '{club}下半场出来就被淹没了。中场休息之后，{opp}没有留过情。',

  // ── 全场评价，一个数字都不用 ──────────────────────────────────────────────
  //
  // 前两条不能声称控球：单一维度也会触发，{club}完全可能控着球却还是被压着。
  'report.stats.on_top':
      '这场比赛好的部分归{club}，几乎全程更有威胁的也是他们。|'
      '这是一场该由{club}掌控的比赛，他们也确实掌控了。{opp}有很长时间在追。|'
      '九十分钟里大部分时间是{club}说了算，{opp}几乎没有过要改变这一点的迹象。',
  'report.stats.pinned_back':
      '{club}有很长时间在防守，看着像要进球的是{opp}。|'
      '{opp}很早就拿走了这场比赛好的部分，{club}很少能从底下探出头来。|'
      '这里有一支球队占着上风，而那不是{club}。{opp}把比赛压了过来。',
  'report.stats.ball_only':
      '{club}球权多得很，能拿出来的东西却很少。{opp}守住自己的禁区，并且很乐意'
          '这么守。|'
      '全世界的控球都给了{club}，随之而来的机会却不值几个钱。|'
      '{club}把球留在脚下，{opp}把他们挡在了会疼的地方之外。',
  'report.stats.counter':
      '球在{opp}脚下，机会在{club}手里，这既可能是偶然，也可能就是一种踢法。|'
      '{club}乐得让{opp}拿球，把落到自己这边的东西用得好得多。|'
      '控球去了一边，真正的机会去了另一边。{club}一点也不会介意。',
  'report.stats.even':
      '无论有球还是无球，两队之间的差别都极小。|'
      '{club}和{opp}势均力敌，正如这个下午所显示的。|'
      '{club}和{opp}都没能把比赛拿在手里够久，久到可以称之为自己的。',

  // ── 收官阶段，从另一条替补席看 ────────────────────────────────────────────
  //
  // {chaser}是带着落后进入收官阶段的一方，{holder}是领先的一方，这样句子从哪
  // 一边读都成立。
  'report.late.held_out':
      '{chaser}在最后一段把所有人都压了上去，始终没能凿开。|'
      '收官阶段全是{chaser}的，而{holder}扛住了。|'
      '{chaser}一次又一次地压，那个突破口始终没有出现。',
  'report.late.consolation':
      '{chaser}在最后阶段把所有人推上前，换来一个进球，也就只有这个。|'
      '这个迟来的进球给了{chaser}一点可以拿出手的东西，却从来不像够用。|'
      '{chaser}在长时间的压制之后找到一球，那时{holder}早已把难的部分做完了。',

  // ── 替补席 ────────────────────────────────────────────────────────────────
  'report.subs.impact':
      '{player}替补登场，为{club}带来了不同。|'
      '{club}的换人奏效了：{player}上场并且破门。|'
      '替补席把自己赚了回来——{player}上场，为{club}打进一球。',
  'report.subs.changes':
      '{club}把换人名额一个个用掉，找些什么。|'
      '{club}掏空了替补席，想找到进入比赛的路。|'
      '{club}的换人一个接一个，却没有哪一个真正扭转了什么。',

  // ── 主裁判 ────────────────────────────────────────────────────────────────
  //
  // 不写分钟：要紧的是他们少一个人踢完了比赛。
  'report.cards.our_red_named':
      '{player}被罚下，{club}以比开场时更少的人数踢完。|'
      '{player}的红牌让{club}在余下的时间里少打一人。',
  'report.cards.our_booked_many':
      '{club}有{n}名球员被出示黄牌：{names}。|'
      '主裁判向{club}的{names}出示黄牌，全场共{n}张。',
  'report.cards.their_reds':
      '{opp}有{n}人被罚下，收场时离一支完整的球队差得很远。|'
      '{opp}吃到{n}张红牌，此后的一切都被它们框住了。',

  // ── 计划的调整 ────────────────────────────────────────────────────────────
  //
  // 不写分钟，也不写阵型名：写成一个决定，而不是一次设置。{minute}和{tactic}
  // 仍然会传进来，这里不用。
  'report.tactic.shut_up_shop':
      '{club}为收官阶段把阵线回收，开始保护手里的东西。|'
      '临近尾声，{club}关门落锁，请{opp}压上来，相信自己守得住。|'
      '{club}把所有人都收到球后面踢完剩下的时间，这个下午就这么结束了。',
  'report.tactic.went_for_it':
      '{club}为收官阶段把人往前送，也接受了随之而来的风险。|'
      '临近尾声，{club}选择去搏，向{opp}压了上去，而不是守着手里的东西。|'
      '{club}拿剩下的时间赌了一把，把人往前推。',
  'report.tactic.settled':
      '{club}为收官阶段换了个结构，并以这个结构踢完了比赛。|'
      '{club}在临近尾声的重新调整，决定了这个下午的收场方式。|'
      '{club}为剩下的时间重新摆了阵，也就这么把比赛带到了终点。',

  // The settings screen's small print — see `en_copy.dart`.
  'settings.cutaways.hint': '当你开启的一方获得机会时，比赛会切到球场上演这一幕——事后还可以回放。',
  'settings.matchSpeed.auto': '自动',
  'settings.matchSpeed.hint': '自动模式以 2 倍速进行，教练一开口就降到半速，让你有时间读完并做出调整。',

  // The training list's ceiling — see `en_copy.dart`.
  'training.up_to': '最多',

  // 休息中的训练与开场倒数 — 见 `en_copy.dart`。
  'training.resting': '冷却中 {time}',
  'mg.countdown_go': '开始！',

  // 商店：货架不再免费，收入从加成中分出 — 见 `en_copy.dart`。
  'shop.lucky_boot_name': '幸运球靴',
  'shop.lucky_boot_desc': '下一场比赛对手能力下降{pct}%',
  'shop.section.income': '收入',
  'product.energy_director.desc': '立即 +50 能量 · 上限提至 15 · 充能速度提升 {energyPct}%——永久，重置后仍保留！',

  'shop.section.looks': '主教练风格',

  // Colin relays an offer and calls it; then his tour after the tutorial.
  'coach.bid.relay': '{club}来电话了，老板。他们想要{player}，出价{price}。',
  'coach.sponsor.relay': '{company}联系了我们，老板。他们想让{player}做品牌代言人：合约期间这名球员的收入增加{n}%。',
  'coach.verdict.accept': '我的建议：接受',
  'coach.verdict.decline': '我的建议：拒绝',
  'coach.verdict.your_call': '我的建议：两可之间',
  'manager.transfer.starter_short': '{player}每周首发，替补席上没人能顶上。除非你马上再球探一个替代者，否则拒绝。',
  'manager.transfer.relegation': '我们在降级区，而{player}在首发阵容里。现在卖掉，正是在我们最承受不起的时候削弱自己。',
  'manager.transfer.flying': '我们排名榜首，钱也不缺。不需要这笔钱：把阵容留住。',
  'manager.transfer.need_money': '老实说，我们没钱了。这笔费用够买一名新球员，我们比需要{player}更需要金币。',
  'manager.transfer.bench_warmer': '{player}根本不在你的首发里，价格也公道。拿钱去补强真正重要的位置。',
  'manager.sponsor.clean': '这份没有任何附带条件。签吧：白送的钱。',
  'manager.sponsor.relegation_starter': '{player}在首发里，而我们在降级区。首发变弱是我们最不需要的：拒绝。',
  'manager.sponsor.injury_prone': '{player}已经踏过{seasons}个赛季，这份合约还会增加受伤风险。不值。',
  'manager.sponsor.poor_form': '{player}的状态已经很差，这份合约还会拖得更低。说不。',
  'manager.sponsor.need_money': '我们缺金币，而这份合约每秒都在进账。附带条件值得：签吧。',
  'manager.sponsor.bench': '{player}不在你的首发里，附带条件在球场上不会有任何影响。签吧。',
  'manager.sponsor.rating_cost': '{player}会掉{n}评分，而且是首发。用更弱的阵容换更多收入：你来定。',
  'manager.sponsor.fair': '附带条件很小，收入不小。我会签。',
  'guide.scout': '点击球探来签下新人。把两名同类球员拖到一起，就能合并成更强的球员。',
  'guide.squad_tab': '很好。现在打开{tab}标签页，把你最好的十一人排上球场。',
  'guide.squad_fill': '点击空位选择谁上场，或者点自动，我来替你排好阵容。',
  'guide.dugout': '看到右下角的菜单了吗？那就是Dugout：训练和联赛积分榜都在里面。',
  'guide.club_tab': '球场也能挣钱。去看看{tab}标签页。',
  'guide.club_buy': '在这里购买设施。你拥有的每一处设施都会增加俱乐部每秒的收入。',
  'guide.shop_tab': '能量或金币不够？{tab}标签页有礼包和加成，随时可用。',

  // ── Commentary pools the spec's own catalogues never widened ───────────
  //
  // English grew these `commentary.*` pools over time; the translated
  // locales stayed at the original length. Existing lines are kept
  // verbatim; new lines fill the gap so every locale draws from the same
  // number of variants. `commentary.opp_sub`'s original single variant was
  // itself untranslated English in every locale — replaced here too.
  'commentary.blocked': '{who}的射门被封堵！|{who}在弧顶起脚，一名后卫用身体挡了下来——这就是后卫该拿的薪水。|三名{who}球员依次抢补射，却一次接一次地被封堵。|{who}在十二码处起脚，一条不知从哪伸出的腿把球挡了下来。|{who}把球抢回来再次施射——还是被一个身影挡在了门前。|球刚出脚就被封堵，{who}只能把进攻从头再来。|无论{who}怎么摆脱，对方后防总能舍身挡在球路上。',
  'commentary.booking.opp_red': '{opp}被直接红牌罚下，全场没人有异议——{opp}只剩十人。|{opp}球员一次可怕的铲球，主裁判直接掏出红牌。客队少一人作战。|{opp}球员被罚下——主裁判除了红牌别无选择。|{opp}吃到红牌，他们的替补席无话可说。客队只剩十人。',
  'commentary.booking.opp_second_yellow': '{opp}再吃一张黄牌，两黄变红下场——客队自己把下午变难了。|同一名{opp}球员两次被警告，主裁判只能将他罚下。{opp}只剩十人。|{opp}同一名球员两次染黄，主裁判将他罚下。{opp}只能用十人踢完剩下的比赛。|{opp}再吃一张黄牌，两黄变红——他们把这场比赛留给自己的路变窄了。',
  'commentary.booking.opp_yellow': '{opp}的球员因一次故意绊人被记名，主裁判已经看够了。|{opp}送出一次毫无必要的任意球，还搭上一张黄牌。|{opp}吃到黄牌，他们的替补席相当不满。|{opp}球员拉拽对方前插球员染黄——主裁判别无选择。|{opp}这一脚又晚又笨拙，黄牌都算轻的。',
  'commentary.booking.red': '{player}被直接红牌罚下，没有任何争议——最后一名防守球员，他铲的是腿。{us}将以十人踢完。|{player}彻底失去了理智，主裁毫不犹豫。罚下。{us}还有漫长的半小时要熬。|{player}被罚下。那一脚根本没想碰球，{us}只能以十人踢完比赛。|主裁判直接掏牌，{player}被红牌罚下。{us}少打一人。',
  'commentary.booking.second_yellow': '{player}拿到第二张黄牌——动作并不恶劣，但他早已在册，自己也清楚。{us}只剩十人。|{player}又一次伸腿，主裁没有别的选择：两黄罚下。{us}将少一人打完剩下的比赛。|{player}两黄变红，这一路走得漫长。{us}接下来只能用十人应战。|{player}再次被警告，红牌随之而来。{us}少一人应战。',
  'commentary.booking.yellow': '{player}因拖延时间被出示黄牌——今天的第一张，接下来他得小心了。|{player}上抢慢了半拍，他还没爬起来，主裁的黄牌已经掏了出来。|{player}拉住球衣阻止反击，结果只有一个：黄牌。|{player}抗议判罚——在所有愚蠢的领牌方式里，这算一种。|{player}这一次抢断晚了半拍，主裁判别无选择——黄牌。|{player}在中场一次绊人，黄牌随即掏出。|{player}因一次毫无必要的犯规被记入名单。',
  'commentary.demolition': '{us}–{them}——好一场表演！我们把 {opp} 撕碎了。球员们会兴奋好几天。|{us}–{them}。我们做的每一次尝试都成功了，{opp}毫无办法。|这是我们打得最好的一场之一。{us}–{them}力克{opp}——好好享受这一刻。|{us}–{them}！今天球员们的表现无可挑剔。|我们冷酷无情。{us}–{them}，{opp}恨不得哨声早点响起。',
  'commentary.dispossessed': '{who}被抢断——漂亮的铲球！|{who}在禁区里多带了一下，这记铲断干净利落。|{who}抬头去找一秒前还存在的那条传球线——球已经从脚下被捅走了。|一次时机拿捏精准的铲断终结了{who}的进攻。|{who}在禁区边缘被一次突如其来的抢断断了球。|就在{who}要起脚的瞬间，球被断走了。|{who}多停留了一秒，代价立刻到来。',
  'commentary.drubbing': '难看的一场。{us}–{them} 客场对 {opp}。振作起来——每支球队都有糟糕的一天。|客场{us}–{them}负于{opp}。没有一件事做对，我不打算掩饰这一点。|这是一场彻头彻尾的完败。{us}–{them}。翻篇，继续前进。|{us}–{them}。{opp}在场上每个环节都比我们强。这种事总会发生。|{us}–{them}，没什么好说的。糟糕的一天，尽快忘掉，迎接下一场。',
  'commentary.flow.addedtime.0': '补时阶段有戏剧性一幕！|补时阶段，胜负还没有定数。|比赛尾声，戏剧性的一幕正在上演。|最后这几秒钟，什么都可能发生。',
  'commentary.flow.addedtime.1': '坚持到补时尾声。|补时已经很深了，这份领先正被死死守住。|每一秒都在被拖延，替补席上没人有意见。|此刻场上，时间就是一切。',
  'commentary.flow.addedtime.2': '第四官员举牌——补时开始。|第四官员举起了牌子——比赛还要继续。|第四官员示意补时时间，比预想的要长。|补时时间已经确定，两队替补席都不太满意这个数字。',
  'commentary.flow.addedtime.3': '还有时间制造最后机会。|还有时间再组织一次进攻。|肯定还能往禁区里送最后一个球。|还没结束——这场比赛还有戏。',
  'commentary.flow.closing.0': '冲刺阶段！|还剩十分钟，胜负将在这里见分晓。|时间在流逝，紧迫感在上升。|进入最后十分钟，两队替补席都站了起来。',
  'commentary.flow.closing.1': '现在每次铲球都关键。|现在每一次拼抢都像是这个赛季的最后一战。|场上任何一个位置都没人手软。|两端球门前都在拼命封堵。',
  'commentary.flow.closing.2': '能守住吗？|现在的问题是这份优势能不能守住。|球员们体力已经透支，比赛还没结束。|他们在拼尽全力防守，比赛还剩几分钟。',
  'commentary.flow.closing.3': '对手最后一搏。|最后一次换人完成——接下来全力压上。|一名中后卫被顶上了前场，局势可见一斑。|最后一搏，什么都不再保留。',
  'commentary.flow.closing.4': '全场紧张气氛弥漫。|现在能感觉到全场的紧张气氛。|每一次传球失误都引来一片叹息。|看台上的球迷已经在吹口哨催促终场。',
  'commentary.flow.firstA.0': '你的球队信心渐足。|信心在增长，传球的节奏也随之加快。|一段稳定的控场期——一方已经掌控了中场。|传球开始有了节奏。',
  'commentary.flow.firstA.1': '近距离射门——稍稍偏出！|八码处的一记快射，只差几英寸偏出立柱。|小禁区内一片混乱，球从后卫身上折射偏出。|近距离头球，球贴着立柱外侧飞出。',
  'commentary.flow.firstA.2': '左路精彩配合。|左路三次一脚出球，传中几近完美。|右路一脚精妙配合，边后卫已经绕到了外侧。|边线上一次撞墙配合，瞬间打开了场地空间。',
  'commentary.flow.firstA.3': '门将出拳化解角球。|角球传入禁区，门将高高跃起在人群中稳稳没收。|一次落点很深的定位球一度造成混乱，最终被解围。|角球一个接一个，后防线一直能顶到球。',
  'commentary.flow.firstB.0': '危险的任意球即将开出……|任意球落在危险位置，正对球门二十二码处。|人墙正在排列，这是一个真正的机会。|禁区弧顶附近一次犯规，这里有真正的机会。',
  'commentary.flow.firstB.1': '门将出击——精彩扑救！|一记远射力道十足，门将第二次扑救才将球稳稳抱住。|一记漂亮的扑救，球飞向左下角，第二落点被解围出底线。|门将迅速出击，在前锋脚下将球没收。',
  'commentary.flow.firstB.3': '射门被门线挡出！|球在门线上被解围，全场都没看清是怎么做到的。|一名球员舍身挡在射门线路上，球被封出边线角球。|封堵一次，补射又被封堵——这防守堪称拼命。',
  'commentary.flow.open.0': '开球！双方都在找感觉。|比赛开始！双方都在逐渐找到状态。|主裁判鸣哨开赛，开局的几脚传球都很谨慎。|比赛开始了。开场几分钟双方都不愿冒险。',
  'commentary.flow.open.1': '中场早早施压。|目前为止，中场是这场比赛的胜负手。|一方开始掌控球权，今天下午第一次真正占据场地优势。|双方都在高位逼抢，还没人能稳稳控住球。',
  'commentary.flow.open.2': '观众已经群情激昂。|全场已经沸腾，比赛还不到十分钟。|每次球向前推进，看台上都是一片欢呼。|从热身开始，这里的气氛就在不断升温。',
  'commentary.flow.secondA.0': '下半场开始——球队压上。|下半场重新开始，场上已经多了几分急迫感。|重新开球带来了节奏的变化——比上半场更快了。|下半场开始，中场休息时的部署显然被听进去了。',
  'commentary.flow.secondA.1': '战术调整似乎奏效。|阵型发生了变化，空间也因此被打开。|教练席的调整正在发挥作用。|有人内切换位，场地看起来一下子开阔了许多。',
  'commentary.flow.secondA.2': '现在是攻防互换。|比赛完全打开了——两端你来我往。|双方都不再执着于控球。|每一次解围都被直接打了回来，场面完全乱了。',
  'commentary.flow.secondA.3': '理疗师上场处理碰撞。|队医上场，一名球员倒地需要治疗。|比赛暂停，边线上正在检查一处伤情。|场上正在进行治疗，这段时间会算进补时。',
  'commentary.flow.secondB.0': '中场争夺日趋激烈。|中场的拼抢现在越来越激烈。|没人能拿下中场控制权，但双方都在拼命争取。|中场已经成了一片混战。',
  'commentary.flow.secondB.1': '远射——直接被门将抱住。|三十码外一记怒射——门将轻松将球稳稳抱住。|远射带着下坠，但正好飞向门将怀中。|这脚远射太冒险，根本没能对球门构成威胁。',
  'commentary.flow.secondB.2': '禁区内精彩的二过一，险被破门！|一次撞墙配合撕开防线，最后一触被后卫的脚挡下。|禁区内的配合行云流水，最后关头被解围。|两脚传递就打穿了防线——但解围还是来了。',
  'commentary.forces_save': '{who} 迫使门将扑救！|{who}拉开边路起球——门将奋力伸展把球扑了出去。|{who}在禁区前沿做出一次二过一，射门被门将低手挡向近门柱。|{who}三打二发动反击，全靠门将一次张开双腿的封堵。|球落到八米处的{who}脚下——门将却不知怎么已经站在了那里。|{who}在小角度起脚，门将将球托出立柱。|{who}角球造成的头球攻门，不知怎么被挡在了门线上。|{who}打出一记贴地射门，门将用力将球托了出去。',
  'commentary.goal.equalise.no_scorer': '{us} 扳平！|{us} 追平比分！|{us} 扳平——比赛重启！|比赛重启！{us} 扳平！|{us}扳平比分！|{us}重回同一起跑线！|扳平了——是{us}打进的！|{us}将比分扳平！',
  'commentary.goal.equalise.with_scorer': '{scorer} 为 {us} 扳平！|反击之势——{scorer} 为 {us} 抽射入网！|{scorer} 回敬——{us} 扳平！|比赛重启！{us} 凭借 {scorer} 扳平比分。|{scorer}找到破门良机——{us}扳平比分！|扳平了！{scorer}为{us}完成致命一击！|{scorer}没有浪费机会——{us}扳平了比分！|{scorer}正中球门，{us}扳平了比分！',
  'commentary.goal.extend.no_scorer': '{us} 再下一城！|{us} 扩大领先！|{us} 大开杀戒！|{us} 拉开差距！|{us}再入一球！|{us}已经遥遥领先！|对手快追不上了——又是{us}进球！|{us}继续扩大优势！',
  'commentary.goal.extend.with_scorer': '{scorer} 为 {us} 再下一城！|{scorer} 二次触球破门——{us} 扩大领先！|{scorer} 梅开二度——{us} 大开杀戒！|{scorer} 冷静推射——{us} 拉开差距！|{scorer}让{us}把比分拉开到追不上的地步！|{us}再入一球，进球的是{scorer}！|又是{scorer}——{us}不断扩大优势！|{us}势如破竹，{scorer}正是核心！',
  'commentary.goal.lead.no_scorer': '{us} 取得领先！|{us} 反超比分！|{us} 打破僵局！|{us} 抢得先机！|{us}取得领先！|破局了——{us}领先！|{us}打入首球！|{us}抢得头彩！',
  'commentary.goal.lead.with_scorer': '{scorer} 帮 {us} 取得领先！|{scorer} 一脚劲射！{us} 反超！|{scorer} 打破僵局——{us} 领先！|{scorer} 稳稳收下——{us} 领先！|{scorer}率先打破僵局——{us}取得领先！|{us}领先了，功臣是{scorer}！|{scorer}在毫无征兆中完成打门，{us}领先了！|{scorer}破门——{us}占得先机！',
  'commentary.goal.pullback.no_scorer': '{us} 追回一球！|{us} 抓住救命稻草！|{us} 重回赛场！|{us} 扳回阵脚！|{us}追回一球！|{us}进球了——比赛还有悬念！|{us}缩小了比分差距！|还没结束——{us}进球了！',
  'commentary.goal.pullback.with_scorer': '{scorer} 为 {us} 追回一城！|希望犹在！{scorer} 为 {us} 进球！|{scorer} 让 {us} 留在比赛中！|{scorer} 为 {us} 转化机会！|{scorer}为{us}留下了希望！|{scorer}为{us}追回一球——比赛又有了悬念！|{scorer}破门，{us}还没有放弃！|{us}看到了希望，带来这份希望的是{scorer}！',
  'commentary.halftime_ahead': '{us} 半场领先！|{us}带着领先优势走进更衣室。|中场休息，{us}处于领先。|{us}领先进入下半场——接下来要做的就是守住这份优势。',
  'commentary.halftime_behind': '{us} 处于落后——该反击了。|中场休息，{us}还有功课要补。|{us}中场落后，必须做出改变。|对{us}来说这半场该忘掉，还有四十五分钟去纠正。',
  'commentary.halftime_level': '半场战平。|中场休息，两队难分高下。|中场比分持平。|四十五分钟战罢战平，鹿死谁手还未可知。',
  'commentary.high_scoring_loss': '攻防开放。{us}–{them} 客场负 {opp}。我们进球不少——只是多丢了一个。|客场{us}–{them}负于{opp}。我们这头进球不少，另一头丢球更多。|这场比赛我们从未掉队，但也从未安全过。{us}–{them}。|{us}–{them}。进球不是我们的问题，防守才是。|除了我，所有人都看得很开心。{us}–{them}，下周我们要把防守做好。',
  'commentary.high_scoring_win': '精彩对决。{us}–{them} 战胜 {opp}——双方进球如雨，但我们拿到结果。这种把握能力值得赞助商来电。|{us}–{them}力克{opp}。比赛毫无保留、惊心动魄，最终收获三分。|我们进了不少球，也丢了几个。{us}–{them}，这个结果我接受。|{us}–{them}！锋线今天无人能挡，后防线的问题，我们回头再谈。|与{opp}打成了一场对攻战，{us}–{them}，最后笑到最后的是我们。',
  'commentary.hit_post': '{who}击中门柱！|{who}倾尽全力一击——全场都听见了立柱的回响。|球打在后卫身上弹起，落向{who}这边的横梁之下——出界时还砸了一下门框。|{who}二十码外的一脚射门击中远端立柱，球没有进。|横梁救了对方一命——{who}只差一点就能得分。|{who}的一记头球砸中横梁，弹地后落在门线外。|球打在立柱内侧沿着门线弹出——{who}简直不敢相信。',
  'commentary.injury': '{player} 因伤退出！|{player}无法继续比赛——这是一个打击。|{player}突然停下并示意替补席，他今天的比赛结束了。|{player}倒地不起，看样子无法自行走下场。',
  'commentary.nervy_one_nil': '1–0 战胜 {opp}。不漂亮，但三分就是三分。零封拿下、收入囊中、继续前进。|1–0。本不必打得这么艰难，但战胜{opp}就是胜利。|零封{opp}拿下三分。到了赛季末，没人会记得过程如何。|一场难看的1–0。强队才能赢下这种比赛，我没什么好抱怨的。|面对{opp}，一粒进球就足够了。这场胜利后防线功不可没。',
  'commentary.nil_nil': '与 {opp} 0–0 闷战。沉闷的下午——拿到一分，下场再去争更多。|与{opp}0–0战平。不会有人记得这场比赛，但一分就是一分。|至少保住了零封。{opp}没能从我们这里拿到什么，我们也一样。|与{opp}互交白卷。就算踢到半夜恐怕也进不了球。|一分、一次零封，还有一场与{opp}漫长难熬的九十分钟。',
  'commentary.opp_goal': '{them} 进球！|{them} 一脚世界波！|{them} 简洁配合——直接破门。|{them} 抓住后防漏洞。|{them} 直塞——冷静射门。|后防睡着——{them} 抓住机会。|{them} 一记惊天远射，门将无能为力。|{them} 进得有点乱，但算数。|{them} 球进死角——顶级水准。|没人上抢的角球，没人争顶的头球，{them}白拿了一个。|{them}打出一次套边配合，球从近门柱滑入网窝。|一次触球折射让所有人都措手不及，{them}进球了。|一脚直塞就撕开了防线，剩下的交给{them}。|{them}顶进了一记本不该传进来的传中球。|一脚长传，一次做球，{them}就这样突入禁区完成了打门。',
  'commentary.opp_sub': '{opp}换人——替补席送上生力军。|{opp}换人——替补席派上生力军。|{opp}使用了换人名额。|{opp}完成换人，新登场的球员直接顶到锋线。|{opp}换下一名体力透支的球员，换上一名养精蓄锐的生力军。',
  'commentary.shot_over': '{who}射门高出横梁！|{who}把球回敲到禁区里迎球一搡——直接送上了二层看台。|{who}只需要一码的空间，结果十二码处打飞了。|{who}面对空荡荡的球门，却把球打飞了。|{who}在六码处头球攻门毫无阻碍，球却飞进了看台。|{who}这记凌空抽射力道十足，可惜打得太高。|{who}转身抽射，球高出横梁一大截。',
  'commentary.shot_wide': '{who}射门偏出！|{who}想把球兜向远角，却看着它偏出了一脚的距离。|球在角度上给{who}垫得恰到好处——却从门前横穿而过，无人跟进。|{who}内切一脚兜射，球贴着立柱外侧一码偏出。|{who}一脚一停打门，从未真正对球门构成威胁。|{who}的配合十分流畅，可惜禁区边缘的射门拉偏了。|回敲球找到了{who}球员，可这脚打门横穿球门出了底线。',
  'commentary.snub': '{opp} 因被怠慢而愤怒——准备一场敌意满满的比赛。|这里面有恩怨，{opp}没有忘记。|{opp}这场比赛憋着一股劲要证明自己。',
  'commentary.thriller_draw': '{us}–{them}！与 {opp} 攻防大战。中立球迷大饱眼福，尽管我们只拿到一分。|{us}–{them}战平{opp}，双方都不该输掉这场比赛。拿下这一分吧。|这场比赛什么都有，就是没有制胜一球。{us}–{them}，我们与{opp}平分秋色。|{us}–{them}拿到一分。精彩，也耗尽体力，可惜还不够。|{us}–{them}战平{opp}。要是每周都这样，我的嗓子都要喊哑了。',
  'commentary.thriller_loss': '{us}–{them} 大战 {opp} 痛失好局。我们打得不差——就差一记制胜球。|{us}–{them}负于{opp}。我们坚持到了最后一脚，还是功亏一篑。|{us}–{them}，没什么好惭愧的。我们在一场精彩比赛里尽了力，只是输了。|这场失利会很痛。{us}–{them}，一个瞬间就决定了整个下午。|除了比分，我们各项都不输给{opp}。{us}–{them}，回去继续努力。',
  'commentary.thriller_win': '精彩比赛！{us}–{them} 险胜 {opp}。这样的比赛能让球场座无虚席。|{us}–{them}。看这场比赛我老了十岁，但下周还想再来一次。|{us}–{them}，我们赢下了一场真正的足球比赛。{opp}拼尽了全力。|光凭这场比赛就值回票价。{us}–{them}力克{opp}，我们笑到了最后。|{us}–{them}！别问我是怎么做到的，反正我们找到了那记制胜球。',

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
  'match.subs': '换人',
  'match.subs.done': '返回比赛',
  'match.subs.on_pitch': '场上',
  'match.subs.bench': '替补席',
  'match.subs.empty_bench': '替补席上没有球员。',
  'match.subs.empty_slot': '空位',
  'match.subs.pick_off': '点击要换下的球员。',
  'match.subs.pick_on': '点击要换上的替补球员（绿色＝最佳位置）。',
  'match.subs.none_left': '没有剩余换人名额。',
  'match.subs.feed': '{off}下场，{on}上场。',
  'match.subs.feed_on': '{on}替补登场。',
  'difficulty.switch.toHard': '职业模式：每名球员都会在比赛中疲劳——管理阵容体力，轮换替补，保持双腿新鲜。我可以帮你挑出体力最好的十一人，但战术上我不会多嘴。切换模式会让你从头开始。',
  'difficulty.switch.toEasy': '休闲模式：球员不会疲劳，替补席只用于战术换人和伤病。自动选人和教练提示会回归。切换模式会让你从头开始。',
  'tut.loan_boost.title': '⭐ 租借球星驾到！',
  'tut.loan_boost.body': '我动用了一些人情……<strong>顶级球员</strong>答应为你的首场比赛出战！赛后他们马上就走——所以要好好把握！',
  'tut.loan_boost.btn': '查看我的阵容 →',
  'tut.loan_depart.title': '现在来打造我们自己的球队',
  'tut.loan_depart.body': '租借球星走了——但他们证明了我们能够竞争。现在来打造<strong>属于我们</strong>的球队。这里有<strong>500 金币</strong>作为起步。有建议时，我会在左下角。',
  'tut.loan_depart.btn': '开始打造！ →',
  'ach.cat.hardmode': '职业模式',
  'coachtip.subs_bench.title': '你有替补席',
  'coachtip.subs_bench.body': '比赛中点击“换人”即可打开替补席——每场 5 个换人名额，挑选时计时暂停。现在伤病也走这里：有人倒下时，他的球衣会离开球场，位置会一直空着，直到你换人为止，所以别不管他。',
  'coachtip.try_hard_mode.title': '想来点挑战吗？',
  'coachtip.try_hard_mode.body': '老板，你已经走了很远了。准备好进入职业模式了吗？球员在比赛中会疲劳，所以轮换阵容、用好替补是真的有用——点击“自动”，我会为你排出体力最好的合规十一人——战术上我不会多嘴。这会从一支全新球队开始：想好了再来。',
  'coachtip.try_hard_mode.cta': '打开设置',
  'coach.match.tired': '{name}体力透支了——换个生力军上场！',
  'toast.energy_refilled': '阵容体力已恢复！',
  'toast.no_fit_players': '可出场的球员不足——让他们休息，或观看广告恢复体力。',
  'trait.name.iron_lungs': '铁肺',
  'trait.desc.iron_lungs': '不知疲倦的引擎——比赛中体力消耗更慢（职业模式）',
  'champ.title': '冠军！',
  'champ.subtitle': '征服冠军联赛',
  'champ.body': '你征服了每一个级别，压倒了所有对手。你独自站在顶端，是世界上最伟大的主帅。',
  'champ.prestige_teaser': '重置后从周日联赛重新攀升，并获得永久的<strong>×{mult} 收入加成</strong>。你的生涯成就将永远保留。',
  'champ.new_adventure': '🌟 开始新征程',
  'champ.defend': '⚽ 卫冕冠军',
  'game.training.intro': '在{n}次射门飞来时点击。每个训练有{secs}秒。',

  // ── Two strings that quoted POUNDS in every language ─────────────────────
  //
  // The badge's figure is a RATIO between bundles and has no currency in it at
  // all; "/£" was decoration that happened to be sterling. And the consent
  // notice named the range in pounds to a parent who does not pay in them —
  // it takes the store's own two figures now, see `age_gate_sheet.dart`.
  'shop.coin_value_badge': '性价比+{pct}%',
  'agegate.purchases_body': '可购买金币包（{min} – {max}）、体力包和 VIP 通行证。所有购买均通过 Google Play 安全处理。无需订阅。在下方完成家长同意后，本账号即可进行购买。',

  // What settled a level cup tie. Under the score in a 42pt slot,
  // so it is an abbreviation. See `league_sheets.dart`.
  'fixtures.on_pens': '点球',
};
