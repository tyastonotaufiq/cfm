import 'package:material_ui/material_ui.dart';

import 'app/theme.dart';
import 'player/player_screen.dart';
import 'player/station.dart';

void main() {
  runApp(const CfmApp());
}

class CfmApp extends StatelessWidget {
  const CfmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CFM',
      debugShowCheckedModeBanner: false,
      theme: buildCfmTheme(),
      home: const PlayerScreen(station: claudeFm),
    );
  }
}
