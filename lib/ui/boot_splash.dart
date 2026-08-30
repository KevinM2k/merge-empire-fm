/// The boot splash. Ported from `index.html`'s `#splash` block and the
/// `setupSplash` controller in `main.js`.
///
/// **It sits OUTSIDE the app, which is the spec's own shape.** In the JS the
/// splash markup is a sibling of `#app` in `index.html`, painted by inline CSS
/// before a line of `main.js` runs, and torn out of the DOM once the game
/// mounts. Here it wraps [MergeEmpireApp] rather than living inside it, for the
/// same reason: it must not depend on the theme, the locale or the save, all of
/// which are things it is covering the loading of.
///
/// That placement also means no widget test that pumps `MergeEmpireApp` ever
/// sees it — the splash is `main()`'s, exactly as the JS's is `index.html`'s.
///
/// The progress bar is FAKE, and deliberately so: the JS creeps a single CSS
/// transition to 100% over a fixed window rather than reporting real work,
/// because the work it covers finishes in wildly different times and a bar that
/// jumped to full in 80ms reads as a flash rather than a loading screen.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/boot_gate.dart' show bootGateTimeout;

/// The minimum time the splash holds. `MIN_SPLASH_MS` in `main.js`.
const splashWindow = Duration(milliseconds: 2600);

/// The beat between the bar filling and the fade starting.
const _splashHold = Duration(milliseconds: 200);

/// `transition: opacity 0.45s` on `#splash`.
const _splashFade = Duration(milliseconds: 450);

/// The palette is `index.html`'s, hardcoded there and here for the same
/// reason — it paints before anything that could theme it exists, and it
/// matches the native launch screen's `splash_background` so the handover from
/// the OS window to the first Flutter frame has no seam.
const _splashInk = Color(0xFFEAFFF0);
const _splashDim = Color(0xFF8FCF9F);
const _splashBarFrom = Color(0xFF4CAF50);
const _splashBarTo = Color(0xFF8BE07A);

/// Wraps [child] with the splash, which fades itself out and is then gone.
class BootSplash extends StatefulWidget {
  const BootSplash({
    required this.child,
    this.window = splashWindow,
    this.gate,
    this.gateTimeout = bootGateTimeout,
    super.key,
  });

  final Widget child;

  /// Zero shows no splash at all, which is what a driver test wants.
  final Duration window;

  /// What the splash WAITS for, on top of its window.
  ///
  /// **This is the half of `setupSplash` the port never had.** The JS fades out
  /// when the cloud-save restore completes; the port faded out on a fixed
  /// clock, so a restore that landed a beat later swapped the whole save out
  /// from under a player already looking at their squad. Null keeps the old
  /// behaviour, which is what every test that is not about the gate wants.
  final Future<void>? gate;

  /// And never for longer than this. `main.js` is explicit that a slow network
  /// must not trap a player on the splash, and it is the rule rather than the
  /// gate that matters: whatever the restore is doing, the game opens.
  final Duration gateTimeout;

  @override
  State<BootSplash> createState() => _BootSplashState();
}

class _BootSplashState extends State<BootSplash>
    with TickerProviderStateMixin {
  late final AnimationController _fill;
  late final AnimationController _pulse;
  late final AnimationController _fade;
  bool _gone = false;

  /// The gate with its failure already absorbed.
  ///
  /// **Attached in `initState`, not when the bar finishes.** A restore that
  /// fails FAST — no network, no signed-in account — would otherwise be an
  /// unhandled error for the whole length of the window, which Flutter reports
  /// as a crash and a test zone turns into a failure. The splash's question is
  /// only whether the save has stopped moving; how it stopped is the sync
  /// layer's business.
  Future<void>? _gate;

  @override
  void initState() {
    super.initState();
    _gate = widget.gate?.then<void>((_) {}, onError: (Object _) {});
    _fill = AnimationController(vsync: this, duration: widget.window);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fade = AnimationController(vsync: this, duration: _splashFade);
    if (widget.window == Duration.zero) {
      _gone = true;
      return;
    }
    _pulse.repeat(reverse: true);
    _fill.forward().then((_) async {
      // **THE WINDOW IS A FLOOR, NOT THE ANSWER.** The bar finishing is the
      // earliest the splash may go; the restore settling is the other
      // condition, and the timeout is what stops the second one from becoming
      // a trap. Awaited AFTER the bar rather than raced with it, so a fast
      // restore cannot cut the window short — a splash that flashes past in
      // 80ms is the thing the window exists to prevent.
      final gate = _gate;
      if (gate != null) {
        await gate.timeout(widget.gateTimeout, onTimeout: () {});
        if (!mounted) return;
      }
      await Future<void>.delayed(_splashHold);
      if (!mounted) return;
      await _fade.forward();
      if (!mounted) return;
      // Removed from the tree rather than left at zero opacity: the JS calls
      // `el.remove()`, and a transparent full-screen layer would still be
      // swallowing every tap.
      setState(() => _gone = true);
    });
  }

  @override
  void dispose() {
    _fill.dispose();
    _pulse.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **THE APP KEEPS ITS PLACE IN THE TREE.** Returning the bare child once the
    // splash had gone swapped the Stack out from over the whole app, which
    // re-parents every widget in it — and does so INSIDE this build, so the
    // grid's `deactivate` wrote a provider mid-build and two and a half
    // thousand "setState() called during build" errors followed it on every
    // launch. The Stack stays; only the face is dropped.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (!_gone)
            Positioned.fill(
              child: FadeTransition(
                opacity: Tween<double>(begin: 1, end: 0).animate(_fade),
                child: _SplashFace(fill: _fill, pulse: _pulse),
              ),
            ),
        ],
      ),
    );
  }
}

class _SplashFace extends StatelessWidget {
  const _SplashFace({required this.fill, required this.pulse});

  final Animation<double> fill;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 0.9,
          colors: [Color(0xFF1F3D24), Color(0xFF0E1A10), Color(0xFF0A130C)],
          stops: [0, 0.7, 1],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = (box.maxWidth * 0.78).clamp(0.0, 340.0);
          return Center(
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 1, end: 1.05).animate(
                      CurvedAnimation(parent: pulse, curve: Curves.easeInOut),
                    ),
                    child: Image.asset(
                      'assets/ui/splash_logo.png',
                      width: 148,
                      height: 148,
                      fit: BoxFit.contain,
                      // A splash that renders a broken-image box is worse than
                      // one that renders nothing; `onerror` hides it in the JS.
                      errorBuilder: (_, _, _) => const SizedBox(height: 148),
                    ),
                  ),
                  const SizedBox(height: 22),
                  // The display name, not the bundle name — this is the one
                  // screen a first-time player reads it on. Two lines because
                  // it does not fit on one at this weight, and scaled down
                  // rather than wrapped again on a narrow phone.
                  const _SplashTitle('MERGE EMPIRE'),
                  const _SplashTitle('FOOTBALL MANAGER'),
                  const SizedBox(height: 16),
                  Text(
                    t('common.loading').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                      color: _splashDim,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SplashBar(fill: fill),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SplashTitle extends StatelessWidget {
  const _SplashTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          height: 1.15,
          color: _splashInk,
          shadows: [
            Shadow(
              blurRadius: 8,
              offset: Offset(0, 2),
              color: Color(0x80000000),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBar extends StatelessWidget {
  const _SplashBar({required this.fill});

  final Animation<double> fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: fill,
          builder: (context, _) => FractionallySizedBox(
            widthFactor: fill.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_splashBarFrom, _splashBarTo],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
