import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:cfm/player/player_status.dart';

YoutubePlayerValue _value(
  PlayerState state, {
  YoutubeError error = YoutubeError.none,
}) => YoutubePlayerValue(playerState: state, error: error);

void main() {
  group('PlayerStatus.from while tuning in', () {
    test(
      'loading states stay "tuning" instead of flipping to idle/stopped',
      () {
        for (final state in [
          PlayerState.unknown,
          PlayerState.unStarted,
          PlayerState.cued,
          PlayerState.paused,
        ]) {
          expect(
            PlayerStatus.from(_value(state), tuningIn: true),
            PlayerStatus.tuning,
            reason: '$state',
          );
        }
      },
    );

    test('ignores the error left over from before the retry', () {
      expect(
        PlayerStatus.from(
          _value(PlayerState.unStarted, error: YoutubeError.html5Error),
          tuningIn: true,
          staleError: YoutubeError.html5Error,
        ),
        PlayerStatus.tuning,
      );
    });

    test('a new error still shows', () {
      expect(
        PlayerStatus.from(
          _value(PlayerState.unStarted, error: YoutubeError.notEmbeddable),
          tuningIn: true,
          staleError: YoutubeError.html5Error,
        ),
        PlayerStatus.error,
      );
    });

    test('playing goes on air', () {
      expect(
        PlayerStatus.from(_value(PlayerState.playing), tuningIn: true),
        PlayerStatus.onAir,
      );
    });
  });

  group('PlayerStatus.from', () {
    test('before playback is idle', () {
      expect(PlayerStatus.from(_value(PlayerState.unknown)), PlayerStatus.idle);
      expect(PlayerStatus.from(_value(PlayerState.cued)), PlayerStatus.idle);
    });

    test('maps playing and buffering to active states', () {
      expect(
        PlayerStatus.from(_value(PlayerState.playing)),
        PlayerStatus.onAir,
      );
      expect(
        PlayerStatus.from(_value(PlayerState.buffering)),
        PlayerStatus.tuning,
      );
      expect(PlayerStatus.onAir.isActive, isTrue);
      expect(PlayerStatus.tuning.isActive, isTrue);
    });

    test('paused or ended is stopped', () {
      expect(
        PlayerStatus.from(_value(PlayerState.paused)),
        PlayerStatus.stopped,
      );
      expect(
        PlayerStatus.from(_value(PlayerState.ended)),
        PlayerStatus.stopped,
      );
      expect(PlayerStatus.stopped.isActive, isFalse);
    });

    test('reports errors unless the stream is playing again', () {
      expect(
        PlayerStatus.from(
          _value(PlayerState.unStarted, error: YoutubeError.html5Error),
        ),
        PlayerStatus.error,
      );
      expect(
        PlayerStatus.from(
          _value(PlayerState.playing, error: YoutubeError.html5Error),
        ),
        PlayerStatus.onAir,
      );
    });
  });
}
