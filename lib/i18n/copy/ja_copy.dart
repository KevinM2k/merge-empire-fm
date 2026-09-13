/// Japanese copy for the match write-up. See `lib/i18n/locale_copy.dart`.
///
/// Voice and conventions taken from `locales/ja.g.dart`'s own `report.*` block:
/// plain form throughout — "3ポイントは3ポイントだ" — with the clubs as bare
/// topics, "{club}は". The minute is written "{minute}分", which is why
/// `ordinalOf` hands every locale but English a bare number.
library;

/// Replaces the generated entry, or adds a key Japanese did not have.
const Map<String, String> jaCopy = <String, String>{
  'customise.item.face.bubblegum': 'ガム',

  // サウンド・音楽に並ぶ3つ目の行。すべてのボタンのタップ音。
  'settings.ui_sounds': '操作音',

  // このタブは音だけではなくなり、振動が加わった。
  'settings.tab.controls': '操作',
  'settings.haptics': 'バイブ',
  'settings.haptics.hint': 'タップするたびに軽く振動します。端末側のバイブ設定でもオフにできます。',
  'settings.tap_ripple': 'タップ波紋',

  // ── 見出し ────────────────────────────────────────────────────────────────
  //
  // 差し替えであって追加ではない。生成された文はすべて{score}で始まる。
  // {minute}が届くのは`.late`の3つだけ。
  'report.win.rout':
      '試合終了、完全な一方通行だった。{club}が{opp}から{ours}点、しかも汗ひとつ'
          'かかずに。|'
      'ホイッスルが鳴った。{club}が{ours}、{opp}が{theirs} — この点差が救って'
          'いるのは勝者だけだ。|'
      '終了。{club}が{opp}を解体した。{ours}得点、もっと入っていてもおかしく'
          'なかった。',
  'report.win.comfortable':
      'ホイッスルが鳴り、{club}は流したまま勝ち切った。{opp}に3点差。|'
      '試合終了。最後まで3点差、{club}がそれを吐き出す危険は一度もなかった。|'
      '終了。{club}が3点差で勝ち、力むことなく仕事を終えた。',
  'report.win.clear':
      'ホイッスルが鳴り、{club}が2点差で勝った。{opp}にも時間帯はあったが、追い'
          'つく気配までは出なかった。|'
      '試合終了、2点差。2点目が入った時点から、{club}が午後を管理していた。|'
      '終了。{club}の2点差の勝利は、聞こえるとおりに危なげなかった。',
  'report.win.narrow':
      'ホイッスルが鳴り、差は1点だけ — そしてそれは{club}のものだった。|'
      '試合終了。最後に両者を分けたのは1点、勝点は{club}へ。|'
      '終了、{club}が競り勝った。1点差、どちらに転んでもおかしくなかった。',
  'report.win.late':
      'ホイッスルが鳴り、{club}が遅い時間に勝ち切った。決勝点は{minute}分。|'
      '試合終了、そして見事な幕切れ。{minute}分まで同点、そこで{club}が、{opp}に'
          '返す時間の残らない1点を見つけた。|'
      '終了。{minute}分までは引き分けが最有力に見えていた。そこで{club}が'
          '勝ち取った。',
  'report.win.thriller':
      '試合終了、なんという打ち合いか。両者で{total}点、そして{club}のものに'
          'なった。|'
      '{total}点の乱打戦にホイッスル。勝点を持ち帰るのは{club}だ。|'
      '終了、ひと息つこう。{total}点、そして1点の差で{club}に転がった。',
  'report.draw.goalless':
      'ホイッスルが鳴り、両者を分けるものは何もない。得点なし、決定機もさほど'
          'なかった。|'
      '試合終了、スコアレス。2人のGKにとっては静かな午後だった。|'
      '終了、電光掲示板は0のまま、痛み分けだ。',
  'report.draw.shared':
      'ホイッスルが鳴り、引き分け。{ours}点ずつ、{club}も{opp}も決着の1点を'
          '見つけられなかった。|'
      '試合終了、勝点を分け合う。{ours}点ずつ、どこかに勝者がいてもおかしく'
          'ない試合だった。|'
      '終了、五分。どちらのロッカールームも完全には納得しないだろう。',
  'report.draw.late':
      'ホイッスルが鳴り、引き分け。同点弾は{minute}分まで来なかった — 一方には'
          '拾った勝点、もう一方には落とした2点だ。|'
      '試合終了、五分。そこへ辿り着くのに{minute}分までかかった。|'
      '終了、同点ゴールは{minute}分に生まれた。',
  'report.draw.thriller':
      '試合終了、なんという試合か。{total}点、それでも差はつかなかった。|'
      'どちらも勝ち切れなかった{total}点の乱打戦にホイッスル。|'
      '終了、両者で{total}点を分け合ったあとの勝点1ずつ。',
  'report.loss.narrow':
      'ホイッスルが鳴り、差は1点だけ — そしてそれは{opp}のものだった。|'
      '試合終了。{opp}が1点差で持っていき、{club}には問いだけが残る。|'
      '終了、{club}は最少差で落とした。細部の差で、それが{opp}に転がった。',
  'report.loss.late':
      'ホイッスルが鳴り、{club}は遅い時間に落とした。{opp}の決勝点は{minute}分。|'
      '試合終了、残酷な幕切れ。{minute}分まで同点、そこで{opp}が効く1点を'
          '決めた。|'
      '終了。{club}は{minute}分までは勝点1に届いていた。それ以上は1分も'
          'なかった。',
  'report.loss.thriller':
      '試合終了、なんという打ち合いか。両者で{total}点、しかし{opp}のものに'
          'なった。|'
      '{total}点の乱打戦にホイッスル。{club}は何も持たずに去る。|'
      '終了、ひと息つこう。{total}点、そして1点の差で{opp}に転がった。',
  'report.loss.clear':
      'ホイッスルが鳴り、{opp}が2点差で勝った。{club}は両ペナルティエリアで後手に'
          '回った。|'
      '試合終了、2点差。2点目のあと、{club}は本当の意味では戻ってこなかった。|'
      '終了。肝心なところで鋭かった{opp}に、{club}は2点差で敗れた。',
  'report.loss.comfortable':
      'ホイッスルが鳴り、{club}は完敗した。最後は{opp}に3点差。|'
      '試合終了。3点差、{club}は終わるずっと前から凌ぐだけになっていた。|'
      '終了、{club}には堪える午後だった。3点差の敗戦。',
  'report.loss.rout':
      '試合終了、これは灸だった。{opp}が{club}から{theirs}点。|'
      '大勝にホイッスル。{opp}が{theirs}、{club}が{ours}、誰にも言い分はない。|'
      '終了、{club}は解体された。{theirs}失点、もっと入っていてもおかしくは'
          'なかった。',

  // ── 相手はどう戦ったか ────────────────────────────────────────────────────
  'report.opp.comeback':
      '{opp}は敗色濃厚に見えて、一度もそういう戦い方をしなかった。終わってみれば'
          '賭けるならこちらだった。|'
      '{opp}に敬意を。劣勢の時間を経て、午後をひっくり返してみせた。|'
      'ビハインドがむしろ{opp}を落ち着かせたように見えたのは、この相手を'
          '物語っている。',
  'report.opp.rampant':
      '{opp}は圧巻だった。すべてが速く、出てきたミスをひとつも見逃さなかった。|'
      'これが最良の{opp}だ。彼らのために足を運んだ人は一週間この話をするだろう。|'
      '{opp}はやること全部が当たった。今日の彼らに付き合えるチームは多くない。',
  'report.opp.shut_us_out':
      '{opp}はボールを持たない時間も持つ時間と同じだけ良く、{club}は最後まで'
          '抜け道を見つけられなかった。|'
      '無失点と勝点は{opp}のもの。最初の1分から最後の1分まで、自陣ボックスを'
          '正しく守り切った。|'
      '{opp}は{club}に手がかりを何も与えなかった。勝因としては前線の出来と'
          '同じだけ大きい。',
  'report.opp.clinical':
      '両者に大きな差はなかった。チャンスが来たときに鋭かったのが{opp}だった、'
          'それだけだ。|'
      '{opp}は決めどころを決め、{club}は決めなかった。たいていはそれが全部だ。|'
      '{opp}は勝つために上回っている必要はなかったし、どのみち大差もなかった。',
  'report.opp.fought_back':
      '{opp}はリードを許してもなお来続けた。この勝点を不当だと言う人はスタジアムに'
          'ほとんどいないだろう。|'
      'この試合に戻ってくるには、{opp}に相応の胆力が要った。|'
      '{opp}は受け入れることを拒み、難しいやり方で午後の取り分を勝ち取った。',
  'report.opp.stalemate':
      '{opp}は{club}に劣らず整っていて、どちらも隙間を見つけられなかった。|'
      '選ぶところがほとんどない。{opp}は{club}と同じだけ崩しにくかった。|'
      '{opp}は勝点1を取りに来て、本気のチームらしく守り切った。',
  'report.opp.matched':
      '{opp}は長い時間{club}と渡り合い、結果への感想もほぼ同じだろう。|'
      '正直で互角の{opp}の試合ぶり。一度もリードを許さず、一度も前に出切らな'
          'かった。|'
      '両者に差はほとんどなく、{opp}もここで何かを失ったとは思わないはずだ。',
  'report.opp.outclassed':
      '{opp}には長い午後だった。ほとんどで後手に回り、試合に足がかりを掴めな'
          'かった。|'
      '{opp}は早く忘れたい一戦だろう。うまくいったことがあまりに少ない。|'
      '{opp}はほとんど機能せず、2チームの差は終わるずっと前から明らかだった。',
  'report.opp.pushed':
      '{opp}は{club}に仕事をさせたし、自分たちも遠くはなかった。|'
      '{opp}には、何かを持ち帰るだけの試合内容があったという感触が残るだろう。|'
      'この試合には、スコアが{opp}に与えている以上のものがあった。',

  // ── ゴールは、時系列ではなく話題として ───────────────────────────────────
  'report.goals.opened':
      '{player}が{club}を走り出させた。|'
      '{club}にとって、これを始めたのは{player}だった。|'
      '{player}が均衡を破り、{club}はその上に午後を積み上げた。',
  'report.goals.surge.ours':
      '後半は完全に一方通行だった。{club}はハーフタイム後に好きなだけ決め、'
          '{opp}にはそのどれにも答えがなかった。|'
      '{club}は別のチームになって後半に出てきた。ゴールは、{opp}が数えるのを'
          'やめるまで続いた。|'
      'ハーフタイムに何が言われたにせよ効いた。そのあと{club}は試合を{opp}から'
          '遠くへ運んでいった。',
  'report.goals.surge.theirs':
      '{opp}が後半を解体した。ハーフタイムにはまだ試合の中にいた{club}が、'
          '終わってみれば近くにもいなかった。|'
      'ハーフタイムがすべてを悪い方へ変えた。{opp}はそのあと何度も決め、{club}は'
          'そのどれも止められなかった。|'
      '{club}は後半に出てきて飲み込まれた。{opp}はインターバルのあと容赦が'
          'なかった。',

  // ── 試合の総括、数字はひとつも使わない ───────────────────────────────────
  //
  // 最初の2つはボール支配を主張してはいけない。片方の軸だけでも出るので、
  // {club}がボールを持ちながら後手に回っていた試合でも選ばれる。
  'report.stats.on_top':
      '{club}がこの試合の良いところを持っていき、ほぼ通して怖さがあったのも'
          'こちらだった。|'
      'これは{club}が握るべき試合で、実際に握った。{opp}はかなりの時間を追いかけて'
          '過ごした。|'
      '90分の大半を仕切ったのは{club}で、{opp}にそれを変えられる気配はほとんど'
          'なかった。',
  'report.stats.pinned_back':
      '{club}はかなりの時間を守って過ごし、ゴールの気配があったのは{opp}の方'
          'だった。|'
      '{opp}が早い時間からこの試合の良いところを持ち、{club}はその下からほとんど'
          '出られなかった。|'
      'ここには上回っていたチームがいて、それは{club}ではなかった。{opp}が試合を'
          '運んできた。',
  'report.stats.ball_only':
      '{club}はボールをたっぷり持ち、見せるものはほとんどなかった。{opp}は自陣'
          'ボックスを守り、それで満足していた。|'
      '世界中のポゼッションが{club}のものだったが、そこから出てきたチャンスは'
          '大した値打ちではなかった。|'
      '{club}がボールを持ち、{opp}は効くところから{club}を遠ざけ続けた。',
  'report.stats.counter':
      'ボールは{opp}が持ち、決定機は{club}が持った。これは偶然であると同時に'
          'ひとつの戦い方でもある。|'
      '{club}は{opp}に持たせ、回ってきたものからはるかに多くを引き出した。|'
      'ポゼッションは一方へ、明確なチャンスはもう一方へ。{club}はそれを少しも'
          '嫌がらないだろう。',
  'report.stats.even':
      'ボールがあってもなくても、両者の差はごくわずかだった。|'
      '{club}と{opp}は、この午後が思わせるとおりに互角だった。|'
      '{club}も{opp}も、自分の試合と呼べるほど長くは試合を持てなかった。',

  // ── 終盤を、もう一方のベンチから ─────────────────────────────────────────
  //
  // {chaser}は終盤をビハインドで迎えた側、{holder}はリードしていた側。どちらの
  // 側から読んでも文が成り立つようにしてある。
  'report.late.held_out':
      '{chaser}は終盤に全部を前へ放り込み、こじ開けられなかった。|'
      '終盤は{chaser}のものだったが、{holder}が持ちこたえた。|'
      '{chaser}は突破口を求めて押し込み続け、それは最後まで来なかった。',
  'report.late.consolation':
      '{chaser}は終盤に全員を押し上げて1点を引き出したが、得たのはそれだけ'
          'だった。|'
      '遅い時間の得点は、押し込んだ{chaser}に見せるものを残しはしたが、届く'
          '気配は最後までなかった。|'
      '長い攻勢の果てに{chaser}が1点を見つけたときには、{holder}はもう難しい'
          'ところを終えていた。',

  // ── ベンチ ────────────────────────────────────────────────────────────────
  'report.subs.impact':
      '{player}がベンチから出てきて、{club}に違いをもたらした。|'
      '{club}の交代が当たった。{player}が入って決めた。|'
      'ベンチが元を取った — {player}が入り、{club}のためにスコアに絡んだ。',
  'report.subs.changes':
      '{club}は何かを探して交代を使っていった。|'
      '{club}は試合に入り込む糸口を求めてベンチを空にした。|'
      '{club}の交代は次々と続いたが、どれも大きくは動かさなかった。',

  // ── 主審 ──────────────────────────────────────────────────────────────────
  //
  // 分は書かない。大事なのは、少ない人数で終えたという事実だ。
  'report.cards.our_red_named':
      '{player}が退場になり、{club}は始めたときより少ない人数で終えた。|'
      '{player}へのレッドで、{club}は残り時間を数的不利で戦うことになった。',
  'report.cards.our_booked_many':
      '{club}の{n}人が警告を受けた: {names}。|'
      '主審は{club}の{names}に警告を出し、合計{n}枚となった。',
  'report.cards.their_reds':
      '{opp}は{n}人が退場となり、まともなチームの形からはほど遠い状態で'
          '終えた。|'
      '{opp}に{n}枚のレッド。以降のすべてがそれに縛られた。',

  // ── 計画の変更 ────────────────────────────────────────────────────────────
  //
  // 分もシステム名も書かない。設定ではなく決断として書く。{minute}と{tactic}は
  // 引き続き渡されるが、ここでは使わない。
  'report.tactic.shut_up_shop':
      '{club}は終盤に向けてラインを下げ、持っているものを守りにかかった。|'
      '終盤、{club}は店じまいをし、{opp}を呼び込んで、守り切れると腹を括った。|'
      '{club}は残り時間、全員をボールの後ろに引かせ、そのまま午後を終えた。',
  'report.tactic.went_for_it':
      '{club}は終盤に人数を前へ送り、それに伴うリスクを引き受けた。|'
      '終盤、{club}は勝負に出た。手にしているもので満足せず、{opp}に対して'
          '押し上げた。|'
      '{club}は残り時間に賭け、体を前へ送り込んだ。',
  'report.tactic.settled':
      '{club}は終盤に向けて形を変え、その形のまま試合を終えた。|'
      '終盤の{club}の組み直しが、午後の終わり方を決めた。|'
      '{club}は残り時間に向けて並びを直し、そのやり方で試合を締めた。',

  // The settings screen's small print — see `en_copy.dart`.
  'settings.cutaways.hint':
      'オンにした側にチャンスが訪れると、試合がピッチに切り替わってその場面を再現します。'
          'あとから見直すこともできます。',
  'settings.matchSpeed.auto': 'オート',
  'settings.matchSpeed.hint':
      'オートは2倍速で進み、コーチが話しかけてきたときだけ半分の速さに落ちます。'
          '読んで手を打つ時間ができます。',

  // The training list's ceiling — see `en_copy.dart`.
  'training.up_to': '最大',

  // 休憩中のドリルとキックオフのカウントダウン — `en_copy.dart` を参照。
  'training.resting': 'クールダウン {time}',
  'mg.countdown_go': 'スタート！',

  // ショップ：無料棚をやめ、収入をブーストから分けた — `en_copy.dart` を参照。
  'shop.lucky_boot_name': 'ラッキーブーツ',
  'shop.lucky_boot_desc': '次の1試合、相手の能力が{pct}%低下',
  'shop.section.income': '収入',
  'product.energy_director.desc': 'エネルギー+50 · 上限15に拡張 · 回復が{energyPct}%高速化 — リセット後も永続！',

  'shop.section.looks': '監督のスタイル',

  // Colin relays an offer and calls it; then his tour after the tutorial.
  'coach.bid.relay': '{club}から電話があった、ボス。{player}が欲しいそうで、{price}を提示している。',
  'coach.sponsor.relay': '{company}から連絡があった、ボス。{player}をブランドの顔にしたいそうだ。契約中はその選手からの収入が{n}%増える。',
  'coach.verdict.accept': '私の判断：受けよう',
  'coach.verdict.decline': '私の判断：断ろう',
  'coach.verdict.your_call': '私の判断：どちらとも言えない',
  'manager.transfer.starter_short': '{player}は毎週先発で、代わりに入れる控えがいない。すぐに補充をスカウトするつもりがなければ断ろう。',
  'manager.transfer.relegation': '我々は降格圏にいて、{player}は先発だ。今売れば、一番苦しい時に戦力が落ちる。',
  'manager.transfer.flying': '首位で、資金も潤沢だ。この金は必要ない。チームを崩すな。',
  'manager.transfer.need_money': '正直、金がない。この額なら新戦力を丸ごと獲れる。{player}よりコインが必要だ。',
  'manager.transfer.bench_warmer': '{player}は先発にすら入っていないし、価格も妥当だ。金を受け取って、必要な場所を補強しよう。',
  'manager.sponsor.clean': 'これに裏はない。契約しよう。ただの収入だ。',
  'manager.sponsor.relegation_starter': '{player}は先発で、我々は降格圏だ。先発が弱くなるのは一番困る。断ろう。',
  'manager.sponsor.injury_prone': '{player}はすでに{seasons}シーズン走っていて、この契約は負傷リスクを上げる。割に合わない。',
  'manager.sponsor.poor_form': '{player}の調子はすでに悪く、この契約でさらに下がる。断ろう。',
  'manager.sponsor.need_money': 'コインが足りないし、これは毎秒入ってくる。デメリットに見合う。契約しよう。',
  'manager.sponsor.bench': '{player}は先発ではないから、デメリットはピッチ上では何も響かない。契約しよう。',
  'manager.sponsor.rating_cost': '{player}のレーティングが{n}下がる。しかも先発だ。収入増と引き換えにチームが弱くなる。君の判断だ。',
  'manager.sponsor.fair': 'デメリットは小さく、収入は大きい。私なら契約する。',
  'guide.scout': 'スカウトをタップして新しい選手を獲ろう。同じ種類の二人をドラッグして重ねると、より良い選手に合成される。',
  'guide.squad_tab': 'いいぞ。次は{tab}タブを開いて、ベストの十一人をピッチに並べよう。',
  'guide.squad_fill': '空いている枠をタップして誰を置くか選ぶか、オートを押せば私が埋めておく。',
  'guide.dugout': '右下のメニューが見えるか？あれがDugoutだ。トレーニングとリーグ表はあの中にある。',
  'guide.club_tab': 'スタジアムも稼いでくれる。{tab}タブを見てみよう。',
  'guide.club_buy': 'ここで施設を買おう。持っている施設ひとつごとに、クラブの毎秒の収入が増える。',
  'guide.shop_tab': 'エネルギーやコインが足りない？{tab}タブにパックとブーストがある。',


  // ── Where it was won: the positional card and its write-up ─────────────
  'match.analysis.title':
      '勝負を決めた場所',
  'match.analysis.hint':
      '各チームがボールを持っていた場所。上方向へ攻める。サイドはそれぞれのチーム視点。',
  'match.analysis.flanks':
      'サイド別の攻撃',
  'match.analysis.left':
      '左',
  'match.analysis.centre':
      '中央',
  'match.analysis.right':
      '右',
  'match.analysis.shots':
      'シュート{shots}本、xG {xg}',
  'match.analysis.duel_record':
      '{name}は{total}回のデュエルのうち{won}回勝った。',
  'report.zone.down_right':
      '{club}は終始右サイドから攻め、脅威のほとんどはそこから生まれた。|{club}の攻撃はほぼすべて右サイド経由だった。',
  'report.zone.down_left':
      '{club}は終始左サイドから攻め、脅威のほとんどはそこから生まれた。|{club}の攻撃はほぼすべて左サイド経由だった。',
  'report.zone.through_middle':
      '{club}は中央から真っすぐ攻め、サイドをほとんど必要としなかった。|{club}はすべて中央から、ゴールへ一直線だった。',
  'report.zone.their_right':
      '{opp}は自陣右サイドからしつこく攻め、脅威の大半はそこから来た。|{opp}の攻撃はほぼすべて右サイド経由だった。',
  'report.zone.their_left':
      '{opp}は自陣左サイドからしつこく攻め、脅威の大半はそこから来た。|{opp}の攻撃はほぼすべて左サイド経由だった。',
  'report.zone.their_middle':
      '{opp}は{club}に対して中央を真っすぐ突き、サイドをほとんど使わなかった。|{opp}はすべて中央からだった。',
  'report.duel.dominant':
      '{name}は目の前に来たほぼすべてを勝ち取った。|{opp}の誰も終始{name}を抑えられなかった。',
  'report.duel.busy':
      '{name}は最初の笛から最後まで試合の中心にいた。|良くも悪くも、試合の多くが{name}を経由した。',
  'report.duel.struggled':
      '{name}は苦しい午後を過ごし、デュエルの大半で後れを取った。|{name}にはついてこず、勝ったより負けたデュエルの方が多かった。',

  // ── Strings the spec's own catalogues never translated ─────────────────
  //
  // Identical to English in all ten shipped locales — a gap in
  // `../merge-empire-fc`'s own catalogue, same shape as `champ.*` below.
  'match.subs': '交代',
  'match.subs.bench': 'ベンチ',
  'match.subs.empty_slot': '空き',
  'match.subs.done': '試合に戻る',
  'match.subs.on_pitch': 'ピッチ上',
  'match.subs.empty_bench': 'ベンチに選手がいない。',
  'match.subs.pick_off': '交代させる選手をタップ。',
  'match.subs.pick_on': '入れる選手をベンチからタップ（緑＝最適ポジション）。',
  'match.subs.none_left': '交代枠を使い切った。',
  'match.subs.feed': '{off}が下がり、{on}が入る。',
  'match.subs.feed_on': '{on}が入る。',
  'tut.loan_boost.title': '⭐ レンタルスター到着！',
  'tut.loan_boost.body': 'いくつか借りを作った…<strong>トッププレイヤー</strong>たちが君の初戦のために来てくれることになった！試合が終わればすぐ去っていくが — 今を楽しもう！',
  'tut.loan_boost.btn': 'スクワッドを見る →',
  'tut.loan_depart.title': '今こそ、自分たちのチームを作ろう',
  'tut.loan_depart.body': 'レンタルスターたちは去った — だが、俺たちにも渡り合えることを証明してくれた。今度は<strong>俺たち自身の</strong>チームを作る番だ。まずは<strong>500コイン</strong>を渡しておく。アドバイスがあれば左下にいるからな。',
  'tut.loan_depart.btn': 'さあ作ろう！ →',
  'difficulty.switch.confirm': 'よし、行こう',
  'difficulty.switch.toHard': 'プロモード：試合中は選手全員が疲労していく — スクワッドのエナジーを管理し、ベンチを回して脚を新鮮に保て。一番元気な11人を選ぶのは手伝えるが、戦術には口を出さない。切り替えると最初からやり直しになる。',
  'difficulty.switch.toEasy': 'カジュアルモード：選手の疲労はなく、ベンチは戦術的な交代と負傷のときだけ使う。オート選出とコーチのアドバイスが戻ってくる。切り替えると最初からやり直しになる。',
  'coachtip.subs_bench.title': 'ベンチがあるぞ',
  'coachtip.subs_bench.body': '試合中に交代をタップすればベンチを開ける — 1試合5回の交代ができて、選んでいる間は時計が止まる。負傷もここで扱う：誰かが倒れるとそのシャツはピッチを離れ、交代選手を入れるまで空いたままだ。放っておくなよ。',
  'coachtip.try_hard_mode.title': '挑戦してみるか？',
  'coachtip.try_hard_mode.body': 'ここまでよくやってきたな、ボス。プロモードの準備はいいか？試合中は選手が疲れていくから、スクワッドを回してベンチを活用することが本当に意味を持つようになる — オートをタップすれば一番元気な合法の11人を選んでやる — 戦術には口を出さない。新しいチームで始まることになる — やる気があるならな。',
  'coachtip.try_hard_mode.cta': '設定を開く',
  'coach.match.tired': '{name}が疲れ切っている — 元気な選手を入れろ！',
  'coach.tactic_tip.open_dominant': '両チームとも得点するだろうが、こっちが明らかに上だ。{tactic} — 勝ちにいけ。',
  'coach.tactic_tip.open_favoured': '両チームともチャンスを作るだろうが、こっちが上回るはずだ。{tactic}で試合を支配しろ。',
  'coach.tactic_tip.open_even': '両チームともチャンスを作るだろう。{tactic} — カウンターで{opp}を突け。',
  'coach.tactic_tip.open_underdog': '{opp}の方が強いが、オープンな展開になるだろう。{tactic} — チャンスが来たら逃すな。',
  'coach.tactic_tip.exploit_their_def': '{opp}の守備には穴がある。{tactic} — 勝ちにいけ。',
  'coach.tactic_tip.counter_their_atk': '{opp}の攻撃は危険だ。{tactic} — 耐えてから打ち返せ。',
  'coach.tactic_tip.park_underdog': '{opp}は本物の脅威で、こっちは得点に苦しむだろう。{tactic} — 被害を最小限に抑えろ。',
  'coach.tactic_tip.tight_favoured': '接戦だが、こっちに分がある。{tactic} — チャンスを作り出せ。',
  'coach.tactic_tip.tight_underdog': 'どちらも得点しづらい試合だ。{tactic} — 規律を守れ。',
  'ach.cat.hardmode': 'プロモード',
  'toast.energy_refilled': 'スクワッドのエナジーが全回復！',
  'toast.no_fit_players': '試合に出せる状態の選手が足りない — 休ませるか、広告を見て回復させよう。',
  'trait.name.iron_lungs': '鉄の肺',
  'trait.desc.iron_lungs': '疲れ知らずのエンジン — 試合中のエナジー消費が遅くなる（プロモード）',
  'champ.title': '優勝!',
  'champ.subtitle': 'チャンピオンズリーグ制覇',
  'champ.body': '全ディビジョンを制覇し、すべてのライバルを超えた。世界最高の監督として、ただ一人頂点に立っている。',
  'champ.prestige_teaser': 'サンデーリーグから、永続的な<strong>収入×{mult}ボーナス</strong>付きでリセットしてもう一度上り詰めよう。キャリアの実績は永遠に君のものだ。',
  'champ.new_adventure': '🌟 新たな冒険を始める',
  'champ.defend': '⚽ タイトルを防衛する',

  // ── The side dial on the squad tab ────────────────────────────────────
  'squad.side.label': '攻撃サイド',
  'squad.side.balanced': 'バランス',
  'squad.side.balanced.hint': '攻撃はフォーメーションが置いた場所から始まる。',
  'squad.side.left': '左',
  'squad.side.left.hint': '攻撃の大半が左サイドから始まる。',
  'squad.side.centre': '中央',
  'squad.side.centre.hint': '攻撃の大半が中央から始まる。',
  'squad.side.right': '右',
  'squad.side.right.hint': '攻撃の大半が右サイドから始まる。',

  // ── Roles on the wide slots ───────────────────────────────────────────
  'role.label': '役割',
  'role.natural': '通常',
  'role.natural.hint': 'フォーメーション通りのポジションで動く。',
  'role.winger': 'ウインガー',
  'role.winger.hint': '外に張ってゴールラインまで行く。どこで攻めるかであり、どれだけ上手いかではない。',
  'role.winger.short': 'W',
  'role.insideForward': 'インサイドフォワード',
  'role.insideForward.hint': 'サイドから内側のハーフスペースとボックスへ入っていく。',
  'role.insideForward.short': 'IF',
  'role.widePlaymaker': 'ワイドプレーメーカー',
  'role.widePlaymaker.hint': '下がってビルドアップに関わり、早い段階から多くのプレーが彼を経由する。',
  'role.widePlaymaker.short': 'WP',

  // ── The match inspector ─────────────────────────────────
  //
  // `ui/screens/match/match_inspector.dart`. Same frame as `match.analysis.*`:
  // attacking upward, and each side's own left and right.
  'match.inspect.open':
      '詳しく見る',
  'match.inspect.title':
      'マッチ分析',
  'match.inspect.touches':
      'プレー数',
  'match.inspect.shots':
      'シュート',
  'match.inspect.xg':
      'xG',
  'match.inspect.total':
      '{metric}：{ours} 対 {theirs}',
  'match.inspect.players':
      '選手別のデュエル。タップするとその選手だけのヒートマップになります。',
  'match.inspect.matchups':
      '対峙した組み合わせ',
  'match.inspect.duel_line':
      '{won}-{lost}（{pct}%）',
  'match.inspect.shot_line':
      'シュート{shots}本、xG {xg}',
  'match.inspect.versus':
      '{attacker} 対 {defender}',
  'match.inspect.whole_team':
      'チーム全体',
  'match.inspect.showing':
      '{name}のみ表示しています。',
  'match.inspect.hint':
      '自陣ゴールが下で、上方向へ攻めます。つまり一番上の帯が相手のボックスです。右サイドはピッチの左側、右サイビックが立つ場所です。',
};
