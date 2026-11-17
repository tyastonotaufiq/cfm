import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// A terminal-style | / - \ spinner.
class AsciiSpinner extends StatefulWidget {
  const AsciiSpinner({super.key, this.style});

  final TextStyle? style;

  @override
  State<AsciiSpinner> createState() => _AsciiSpinnerState();
}

class _AsciiSpinnerState extends State<AsciiSpinner> {
  static const _frames = ['|', '/', '-', r'\'];

  late final Timer _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      setState(() => _frame = (_frame + 1) % _frames.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(_frames[_frame], style: widget.style);
}
