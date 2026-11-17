import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

/// A "● LIVE" tag whose dot pulses red while the stream is on air.
class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key, required this.onAir});

  final bool onAir;

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.3,
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(LiveBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onAir != widget.onAir) _syncPulse();
  }

  void _syncPulse() {
    if (widget.onAir) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.onAir ? CfmColors.live : CfmColors.inkMuted,
      ),
    );

    return Semantics(
      label: widget.onAir ? 'Live, on air' : 'Live stream, not playing',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: CfmColors.ink, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(opacity: _pulse, child: dot),
            const SizedBox(width: 8),
            Text(
              'LIVE',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}
