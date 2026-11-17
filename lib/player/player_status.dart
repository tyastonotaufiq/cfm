import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// What the radio is doing, reduced from the YouTube player's state.
enum PlayerStatus {
  idle('tap play to tune in'),
  tuning('tuning in…'),
  onAir('on air'),
  stopped('stopped'),
  error("couldn't reach the stream · tap play to retry");

  const PlayerStatus(this.label);

  final String label;

  /// Whether audio is playing, or about to be.
  bool get isActive => this == tuning || this == onAir;

  /// [tuningIn] is true from the moment the user taps play until the stream
  /// is on air. While loading, YouTube briefly reports "unstarted" (and
  /// sometimes "paused") before buffering; those must not flip the button
  /// back to play.
  ///
  /// The player only clears an error once playback starts, so the error
  /// that was showing when the user tapped play is passed as [staleError]
  /// and ignored; only a different error counts.
  static PlayerStatus from(
    YoutubePlayerValue value, {
    bool tuningIn = false,
    YoutubeError staleError = YoutubeError.none,
  }) {
    final freshError = value.hasError && value.error != staleError;
    return switch (value.playerState) {
      PlayerState.playing => onAir,
      PlayerState.buffering => tuning,
      _ when freshError => error,
      _ when tuningIn => tuning,
      PlayerState.paused || PlayerState.ended => stopped,
      PlayerState.unknown || PlayerState.unStarted || PlayerState.cued => idle,
    };
  }
}
