import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// Colors taken from the stream's ASCII-art look.
abstract final class CfmColors {
  static const paper = Color(0xFFEDEBE3);
  static const paperDeep = Color(0xFFE2DFD4);
  static const ink = Color(0xFF1F1E1B);
  static const inkMuted = Color(0xFF6B675E);
  static const clay = Color(0xFFD97757);
  static const live = Color(0xFFD64541);
}

ThemeData buildCfmTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CfmColors.clay,
    surface: CfmColors.paper,
    onSurface: CfmColors.ink,
    primary: CfmColors.clay,
    onPrimary: CfmColors.paper,
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: CfmColors.paper,
    textTheme: GoogleFonts.jetBrainsMonoTextTheme(base.textTheme)
        .apply(bodyColor: CfmColors.ink, displayColor: CfmColors.ink),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? CfmColors.paper
            : CfmColors.inkMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? CfmColors.ink
            : CfmColors.paperDeep,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(CfmColors.ink),
    ),
  );
}
