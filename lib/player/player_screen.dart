import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../app/theme.dart';
import 'picture_in_picture.dart';
import 'player_status.dart';
import 'station.dart';
import 'widgets/ascii_spinner.dart';
import 'widgets/live_badge.dart';
import 'widgets/volume_meter.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.station});

  final Station station;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  late final YoutubePlayerController _controller;
  late final StreamSubscription<YoutubePlayerValue> _playerEvents;

  PlayerStatus _status = PlayerStatus.idle;
  int _volume = 100;
  bool _muted = false;
  bool _keepAwake = true;
  bool _wakelockHeld = false;
  final _playerKey = GlobalKey(debugLabel: 'player');
  final _pip = PictureInPicture();

  /// iOS only lets the hardware buttons change media volume, so the YouTube
  /// player ignores setVolume there (in the app and in mobile Safari).
  bool get _canSetVolume => defaultTargetPlatform != TargetPlatform.iOS;

  /// On Android, macOS and web, the web view or browser already keeps the
  /// display awake while the video plays, so the keep-awake toggle would do
  /// nothing there.
  bool get _hasKeepAwake =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _hasKeyboard =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.station.videoId,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        showVideoAnnotations: false,
        enableCaption: false,
        strictRelatedVideos: true,
        // Our own controls drive the player; taps on the video do nothing.
        pointerEvents: PointerEvents.none,
      ),
    );
    _playerEvents = _controller.stream.listen(_onPlayerValue);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pip.dispose();
    _tuneInTimeout?.cancel();
    _playerEvents.cancel();
    if (_wakelockHeld) unawaited(WakelockPlus.disable());
    unawaited(_controller.close());
    super.dispose();
  }

  /// Set from tapping play until the stream is on air (or fails), so the
  /// player's loading states don't flicker the button. See [PlayerStatus.from].
  Timer? _tuneInTimeout;
  YoutubeError _staleError = YoutubeError.none;
  bool get _tuningIn => _tuneInTimeout != null;

  void _onPlayerValue(YoutubePlayerValue value) {
    final next = PlayerStatus.from(
      value,
      tuningIn: _tuningIn,
      staleError: _tuningIn ? _staleError : YoutubeError.none,
    );
    if (next == PlayerStatus.onAir || next == PlayerStatus.error) {
      _endTuneIn();
    }
    _setStatus(next);
  }

  void _setStatus(PlayerStatus next) {
    if (next == _status) return;
    setState(() => _status = next);
    _syncWakelock();
    unawaited(_pip.setEnabled(next.isActive));
  }

  /// YouTube's embedded player must stay visible while it plays. On phones,
  /// "hidden" means the app is fully in the background: the PiP window was
  /// closed, the screen locked, or PiP is off for this app. (Inside the PiP
  /// window the app is only "inactive", so the music keeps going there.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final backgrounded =
        state == AppLifecycleState.hidden || state == AppLifecycleState.paused;
    if (_isMobile && backgrounded && _status.isActive) _stop();
  }

  void _endTuneIn() {
    _tuneInTimeout?.cancel();
    _tuneInTimeout = null;
  }

  /// Like a radio: playing always (re)joins the live edge of the stream
  /// instead of resuming from wherever it was stopped.
  void _tuneIn() {
    _endTuneIn();
    _staleError = _controller.value.error;
    _tuneInTimeout = Timer(const Duration(seconds: 20), () {
      _endTuneIn();
      _setStatus(PlayerStatus.error);
    });
    _setStatus(PlayerStatus.tuning);
    _controller.loadVideoById(videoId: widget.station.videoId);
    if (_canSetVolume) _controller.setVolume(_volume);
  }

  void _stop() {
    _endTuneIn();
    _setStatus(PlayerStatus.stopped);
    _controller.pauseVideo();
  }

  void _togglePlayback() => _status.isActive ? _stop() : _tuneIn();

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _muted ? _controller.mute() : _controller.unMute();
  }

  void _setVolume(int volume) {
    setState(() => _volume = volume);
    _controller.setVolume(volume);
    if (_muted && volume > 0) _toggleMute();
  }

  void _toggleKeepAwake() {
    setState(() => _keepAwake = !_keepAwake);
    _syncWakelock();
  }

  void _syncWakelock() {
    final want = _hasKeepAwake && _keepAwake && _status.isActive;
    if (want == _wakelockHeld) return;
    _wakelockHeld = want;
    unawaited(WakelockPlus.toggle(enable: want));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _pip.active,
      builder: (context, inPip, _) {
        // Android shrinks the window a moment before it reports PiP, so a
        // tiny window gets the video-only layout too (otherwise the
        // controls overflow for a frame).
        final size = MediaQuery.sizeOf(context);
        final tiny = size.width < 320 || size.height < 240;
        return inPip || tiny
            ? Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: _player),
              )
            : _buildApp(context);
      },
    );
  }

  Widget _buildApp(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _togglePlayback,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(child: LayoutBuilder(builder: _buildLayout)),
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final portraitPhone =
        constraints.maxWidth < 600 &&
        constraints.maxHeight > constraints.maxWidth * 1.3;
    return portraitPhone
        ? _buildPortraitLayout(context)
        : _buildWideLayout(context, constraints);
  }

  /// The player, kept under one [GlobalKey] so switching layouts (rotating
  /// the phone, resizing the window) moves the web view instead of
  /// recreating it, which would stop the music.
  Widget get _player => KeyedSubtree(
    key: _playerKey,
    child: YoutubePlayer(
      controller: _controller,
      backgroundColor: CfmColors.paper,
      autoFullScreen: false,
      enableFullScreenOnVerticalDrag: false,
    ),
  );

  Widget _footer(BuildContext context) {
    return Text(
      [
        'streaming live from ${widget.station.channel}',
        if (_hasKeyboard) 'space to play/stop',
      ].join(' · '),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: CfmColors.inkMuted),
    );
  }

  /// Tall phone screens: header on top, the video edge to edge in the
  /// middle, and the controls at the bottom within thumb reach.
  Widget _buildPortraitLayout(BuildContext context) {
    const side = 20.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(side, 16, side, 0),
          child: _Header(
            station: widget.station,
            onAir: _status == PlayerStatus.onAir,
          ),
        ),
        // On phones the package draws the web view in an overlay that
        // follows this placeholder, so it can't be clipped or covered;
        // keep it a plain full-width 16:9 box.
        Expanded(child: Center(child: _player)),
        Padding(
          padding: const EdgeInsets.fromLTRB(side, 12, side, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusLine(status: _status),
              const SizedBox(height: 12),
              _buildControls(context),
              const SizedBox(height: 16),
              _footer(context),
            ],
          ),
        ),
      ],
    );
  }

  /// Desktop, tablet, web and landscape: a centered column whose video is
  /// sized to the height left after the header and controls, so
  /// everything fits without scrolling. Only very short windows (like a
  /// phone in landscape) fall back to scrolling.
  Widget _buildWideLayout(BuildContext context, BoxConstraints constraints) {
    const padding = EdgeInsets.symmetric(horizontal: 20, vertical: 20);
    const maxContentWidth = 720.0;
    const minContentWidth = 340.0;
    const minVideoHeight = 160.0;
    // Text (header, status line, footer) scales with the user's font size;
    // the controls row, gaps and padding don't.
    final chromeHeight = MediaQuery.textScalerOf(context).scale(110) + 170;

    // Android lays out the first frame before the window has a size, so
    // the width can be 0 here; never let it go negative.
    final availableWidth = math.max(
      0.0,
      math.min(constraints.maxWidth - padding.horizontal, maxContentWidth),
    );
    final videoHeight = math.max(
      constraints.maxHeight - chromeHeight,
      minVideoHeight,
    );
    // The whole column takes the video's width, so the controls line up
    // with its edges.
    final contentWidth = math.min(
      availableWidth,
      math.max(videoHeight * 16 / 9, minContentWidth),
    );

    return SingleChildScrollView(
      padding: padding,
      child: ConstrainedBox(
        // Fill the viewport so spare height is split above and below.
        constraints: BoxConstraints(
          minHeight: math.max(0, constraints.maxHeight - padding.vertical),
        ),
        child: Center(
          child: SizedBox(
            width: contentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  station: widget.station,
                  onAir: _status == PlayerStatus.onAir,
                ),
                const SizedBox(height: 16),
                DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border.all(color: CfmColors.ink, width: 1.5),
                  ),
                  child: _player,
                ),
                const SizedBox(height: 12),
                _StatusLine(status: _status),
                const SizedBox(height: 12),
                _buildControls(context),
                const SizedBox(height: 16),
                _footer(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Row(
      children: [
        IconButton.filled(
          onPressed: _togglePlayback,
          tooltip: _status.isActive ? 'Stop' : 'Tune in',
          iconSize: 32,
          style: IconButton.styleFrom(
            fixedSize: const Size(64, 64),
            backgroundColor: CfmColors.clay,
            foregroundColor: CfmColors.paper,
          ),
          icon: Icon(
            _status.isActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: _toggleMute,
          tooltip: _muted ? 'Unmute' : 'Mute',
          icon: Icon(
            _muted || (_canSetVolume && _volume == 0)
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
          ),
        ),
        // iOS has no volume bars: only the hardware buttons change the volume.
        if (_canSetVolume)
          VolumeMeter(volume: _volume, muted: _muted, onChanged: _setVolume),
        if (_hasKeepAwake) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: _toggleKeepAwake,
            isSelected: _keepAwake,
            tooltip: _keepAwake
                ? 'Keeping screen awake while playing'
                : 'Screen may sleep while playing',
            icon: const Icon(Icons.coffee_outlined, color: CfmColors.inkMuted),
            selectedIcon: const Icon(
              Icons.coffee_rounded,
              color: CfmColors.ink,
            ),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.station, required this.onAir});

  final Station station;
  final bool onAir;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '♫ ${station.name}',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                station.tagline,
                style: text.bodyMedium?.copyWith(color: CfmColors.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        LiveBadge(onAir: onAir),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final PlayerStatus status;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: status == PlayerStatus.error ? CfmColors.live : CfmColors.ink,
    );
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Text('> ', style: style?.copyWith(color: CfmColors.inkMuted)),
          Flexible(child: Text(status.label, style: style)),
          if (status == PlayerStatus.tuning) ...[
            const SizedBox(width: 8),
            AsciiSpinner(style: style),
          ],
        ],
      ),
    );
  }
}
