import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rxdart/rxdart.dart';

class SimpleLiveAudioHandler extends BaseAudioHandler {
  Player? _player;
  final List<StreamSubscription> _subscriptions = [];

  @override
  final BehaviorSubject<PlaybackState> playbackState = BehaviorSubject<PlaybackState>();
  @override
  final BehaviorSubject<MediaItem?> mediaItem = BehaviorSubject<MediaItem?>();

  SimpleLiveAudioHandler() {
    _updatePlaybackState();
  }

  void attachPlayer(Player player, String title, String artist) {
    _detachPlayer();
    _player = player;

    mediaItem.add(MediaItem(
      id: 'live_stream',
      album: 'Simple Live',
      title: title,
      artist: artist,
    ));

    _subscriptions.add(_player!.stream.playing.listen((_) => _updatePlaybackState()));
    _subscriptions.add(_player!.stream.buffering.listen((_) => _updatePlaybackState()));
    _subscriptions.add(_player!.stream.completed.listen((_) => _updatePlaybackState()));
    _subscriptions.add(_player!.stream.error.listen((_) => _updatePlaybackState()));

    _updatePlaybackState();
  }

  void _detachPlayer() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _player = null;
    _updatePlaybackState();
  }

  void _updatePlaybackState() {
    final playing = _player?.state.playing ?? false;
    final buffering = _player?.state.buffering ?? false;

    playbackState.add(PlaybackState(
      controls: [
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.playPause,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1],
      processingState: buffering
          ? AudioProcessingState.buffering
          : playing
          ? AudioProcessingState.ready
          : AudioProcessingState.idle,
      playing: playing,
    ));
  }

  @override
  Future<void> play() => _player?.play() ?? Future.value();

  @override
  Future<void> pause() => _player?.pause() ?? Future.value();

  @override
  Future<void> stop() async {
    await _player?.pause();
    _detachPlayer();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
      controls: [],
    ));
    await super.stop();
  }

  Future<void> dispose() async {
    await stop();
  }
}

// 改为可空类型，支持赋值为 null
SimpleLiveAudioHandler? globalAudioHandler;

Future<void> initAudioServiceGlobal() async {
  if (!Platform.isAndroid) return;

  globalAudioHandler = await AudioService.init(
    builder: () => SimpleLiveAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.xycz.simple_live.channel.audio',
      androidNotificationChannelName: 'Simple Live Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      notificationColor: Color(0xFF2196F3),
      androidShowNotificationBadge: true,
    ),
  );
}