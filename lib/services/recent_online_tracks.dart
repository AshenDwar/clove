import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/online_music_track.dart';

/// Persists the most recently played online tracks for the Search screen.
class RecentOnlineTracks {
  static const int limit = 50;
  static const String _fileName = 'recent_online_tracks.json';

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<List<OnlineMusicTrack>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((entry) => _decode(Map<String, dynamic>.from(entry)))
          .whereType<OnlineMusicTrack>()
          .take(limit)
          .toList(growable: false);
    } on FormatException {
      return const [];
    } on FileSystemException {
      return const [];
    }
  }

  Future<List<OnlineMusicTrack>> record(
    OnlineMusicTrack track, {
    bool moveToTop = true,
  }) async {
    final tracks = await load();
    final key = _key(track);
    if (!moveToTop && tracks.any((item) => _key(item) == key)) {
      return tracks;
    }
    final withoutTrack = tracks.where((item) => _key(item) != key).toList();
    final updated =
        (moveToTop ? [track, ...withoutTrack] : [...withoutTrack, track])
            .take(limit)
            .toList(growable: false);
    await _write(updated);
    return updated;
  }

  Future<List<OnlineMusicTrack>> remove(OnlineMusicTrack track) async {
    final tracks = await load();
    final updated = tracks
        .where((item) => _key(item) != _key(track))
        .toList(growable: false);
    await _write(updated);
    return updated;
  }

  Future<void> _write(List<OnlineMusicTrack> tracks) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode(tracks.map(_encode).toList(growable: false)),
      flush: true,
    );
  }

  String _key(OnlineMusicTrack track) => '${track.providerId}:${track.id}';

  Map<String, Object?> _encode(OnlineMusicTrack track) => {
    'providerId': track.providerId,
    'id': track.id,
    'title': track.title,
    'artist': track.artist,
    'creatorName': track.creatorName,
    'uploaderName': track.uploaderName,
    'album': track.album,
    'artworkUri': track.artworkUri?.toString(),
    'sourcePageUri': track.sourcePageUri?.toString(),
    'durationMs': track.duration?.inMilliseconds,
    'tags': track.tags,
  };

  OnlineMusicTrack? _decode(Map<String, dynamic> data) {
    final providerId = data['providerId'];
    final id = data['id'];
    final title = data['title'];
    if (providerId is! String || id is! String || title is! String) {
      return null;
    }
    final duration = data['durationMs'];
    final tags = data['tags'];
    return OnlineMusicTrack(
      providerId: providerId,
      id: id,
      title: title,
      artist: data['artist'] as String?,
      creatorName: data['creatorName'] as String?,
      uploaderName: data['uploaderName'] as String?,
      album: data['album'] as String?,
      artworkUri: _parseUri(data['artworkUri']),
      sourcePageUri: _parseUri(data['sourcePageUri']),
      duration: duration is num
          ? Duration(milliseconds: duration.toInt())
          : null,
      tags: tags is List ? tags.whereType<String>().toList() : const [],
    );
  }

  Uri? _parseUri(Object? value) => value is String ? Uri.tryParse(value) : null;
}
