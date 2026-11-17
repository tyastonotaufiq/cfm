import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

/// A compact volume control drawn as rising bars (▁▂▃▄▅▆▇), so it can't be
/// mistaken for a video progress bar. Tap or drag to set; arrow keys work
/// when focused.
class VolumeMeter extends StatefulWidget {
  const VolumeMeter({
    super.key,
    required this.volume,
    required this.muted,
    required this.onChanged,
  });

  /// 0–100, in steps of [step].
  final int volume;

  /// Shows the remembered level dimmed.
  final bool muted;

  final ValueChanged<int> onChanged;

  static const segments = 10;
  static const step = 100 ~/ segments;

  @override
  State<VolumeMeter> createState() => _VolumeMeterState();
}

class _VolumeMeterState extends State<VolumeMeter> {
  static const _width = 112.0;
  static const _height = 24.0;
  static const _gap = 3.0;

  /// Padding plus focus border around the bars.
  static const _inset = 5.0;

  final _focusNode = FocusNode(debugLabel: 'VolumeMeter');
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _set(int volume) {
    final clamped = volume.clamp(0, 100);
    if (clamped != widget.volume) widget.onChanged(clamped);
  }

  void _setFromPosition(double dx) {
    // Touching a bar fills up to and including it; the far left edge is 0.
    final x = dx - _inset;
    final level = x < 4 ? 0 : (x / _width * VolumeMeter.segments).ceil();
    _set(level.clamp(0, VolumeMeter.segments) * VolumeMeter.step);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowUp => 1,
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowDown => -1,
      _ => 0,
    };
    if (delta == 0) return KeyEventResult.ignored;
    _set(widget.volume + delta * VolumeMeter.step);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final level = (widget.volume / VolumeMeter.step).round();
    final filledColor = widget.muted ? CfmColors.inkMuted : CfmColors.ink;

    return Semantics(
      slider: true,
      label: 'Volume',
      value: '${widget.volume}%',
      increasedValue: '${(widget.volume + VolumeMeter.step).clamp(0, 100)}%',
      decreasedValue: '${(widget.volume - VolumeMeter.step).clamp(0, 100)}%',
      onIncrease: () => _set(widget.volume + VolumeMeter.step),
      onDecrease: () => _set(widget.volume - VolumeMeter.step),
      child: Tooltip(
        message: 'Volume ${widget.volume}%',
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: _onKey,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _setFromPosition(d.localPosition.dx),
              onHorizontalDragUpdate: (d) =>
                  _setFromPosition(d.localPosition.dx),
              child: Container(
                padding: const EdgeInsets.all(_inset - 1),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _focused ? CfmColors.ink : Colors.transparent,
                  ),
                ),
                child: SizedBox(
                  width: _width,
                  height: _height,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < VolumeMeter.segments; i++) ...[
                        if (i > 0) const SizedBox(width: _gap),
                        Expanded(
                          child: Container(
                            height:
                                6 +
                                (_height - 6) * i / (VolumeMeter.segments - 1),
                            color: i < level
                                ? filledColor
                                : CfmColors.paperDeep,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
