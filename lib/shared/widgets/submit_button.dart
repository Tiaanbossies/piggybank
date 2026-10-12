import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';

/// The primary pill for a full-screen form (M9). While [busy], the label
/// crossfades to a progress ring inside the same box: the label stays laid
/// out (invisibly), so the button keeps its width and height, and the fill
/// stays primary rather than greying out. Instant under reduced motion.
class SubmitButton extends StatelessWidget {
  const SubmitButton({required this.label, required this.onPressed, this.busy = false, super.key});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  static const ringSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final duration = context.reducedMotion ? Duration.zero : AppMotion.stateChange;
    return Semantics(
      liveRegion: busy,
      label: busy ? '$label, working' : null,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: busy
            ? ElevatedButton.styleFrom(disabledBackgroundColor: t.primary, disabledForegroundColor: t.onPrimary)
            : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(opacity: busy ? 0 : 1, duration: duration, curve: AppMotion.easeOut, child: Text(label)),
            AnimatedOpacity(
              opacity: busy ? 1 : 0,
              duration: duration,
              curve: AppMotion.easeOut,
              child: busy
                  ? SizedBox.square(
                      key: const Key('submit-ring'),
                      dimension: ringSize,
                      child: CircularProgressIndicator(strokeWidth: 2, color: t.onPrimary),
                    )
                  : const SizedBox.square(dimension: ringSize),
            ),
          ],
        ),
      ),
    );
  }
}
