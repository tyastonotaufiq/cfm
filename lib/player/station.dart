/// A YouTube live stream the app can tune in to.
class Station {
  const Station({
    required this.name,
    required this.tagline,
    required this.videoId,
    required this.channel,
  });

  final String name;
  final String tagline;
  final String videoId;
  final String channel;
}

const claudeFm = Station(
  name: 'Claude FM',
  tagline: 'music for thinking and building',
  videoId: 'tRsQsTMvPNg',
  channel: 'youtube.com/@claude',
);
