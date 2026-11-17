import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android picture-in-picture, backed by `MainActivity.kt`.
///
/// While enabled (the stream is playing), leaving the app shrinks it into a
/// floating video window instead of stopping the music. The video stays
/// visible, as YouTube's embedded-player rules require.
class PictureInPicture {
  PictureInPicture() {
    if (isAvailable) _channel.setMethodCallHandler(_onCall);
  }

  static const _channel = MethodChannel('cfm/pip');

  /// iOS can't put the embedded YouTube player into PiP, and desktop/web
  /// have no such mode.
  static bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether the app is currently showing as the floating PiP window.
  final ValueNotifier<bool> active = ValueNotifier(false);

  bool _enabled = false;

  Future<void> setEnabled(bool enabled) async {
    if (!isAvailable || enabled == _enabled) return;
    _enabled = enabled;
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on PlatformException catch (e) {
      debugPrint('PiP unavailable: ${e.message}');
    }
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method == 'pipChanged') active.value = call.arguments as bool;
  }

  void dispose() {
    if (isAvailable) _channel.setMethodCallHandler(null);
    active.dispose();
  }
}
