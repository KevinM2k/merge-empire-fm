/// Chinese copy for the match write-up. See `lib/i18n/locale_copy.dart`.
///
/// Voice and conventions taken from `locales/zh.g.dart`'s own `report.*` block:
/// simplified Chinese, plain register, clubs as bare subjects. The minute is
/// written "第{minute}分钟", which is why `ordinalOf` hands every locale but
/// English a bare number.
library;

/// Replaces the generated entry, or adds a key Chinese did not have.
const Map<String, String> zhCopy = <String, String>{
  // 位于“声音”和“音乐”旁的第三行：每个按钮的点击音。
  'settings.ui_sounds': '按键音',

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

};
