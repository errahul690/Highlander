import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'startup_football.dart';

/// Shared by splash and initial feed loading, without introducing a second splash.
class StartupLoader extends StatelessWidget {
  const StartupLoader({super.key, this.ready = false, this.onFinished});
  final bool ready;
  final VoidCallback? onFinished;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: clubCloud,
      systemNavigationBarContrastEnforced: false,
    ),
    child: Semantics(
      label: 'Loading your Highlanders feed',
      container: true,
      child: ColoredBox(
        key: const ValueKey('startup-loader'),
        color: clubCloud,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: Opacity(
                opacity: 0.38,
                child: Image.asset(
                  'assets/images/stadium_bg.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sceneWidth = (constraints.maxWidth - 48).clamp(
                    0.0,
                    408.0,
                  );
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RepaintBoundary(
                          child: SizedBox(
                            width: sceneWidth,
                            child: StartupFootball(
                              key: const ValueKey('startup-football-kick'),
                              ready: ready,
                              onFinished: onFinished,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _LoadingDots(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: clubRed.withValues(
                alpha: (_pulse.value * 3).floor() == index ? 1 : 0.2,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
