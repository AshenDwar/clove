import 'package:clove/data/database.dart';
import 'package:clove/models/clove_track.dart';
import 'package:clove/screens/playlist_detail_screen.dart';
import 'package:clove/services/playlist_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PlaylistRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = PlaylistRepository(database);
  });

  tearDown(() async => database.close());

  testWidgets('tapping outside playlist search does not close it', (
    tester,
  ) async {
    const track = CloveTrack(
      path: '/music/search-touch-test.mp3',
      title: 'Search touch test song',
      artist: 'Test artist',
      album: 'Test album',
      duration: Duration(minutes: 3),
    );
    await repository.setLiked(track, true);

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(repository: repository, likedSongs: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    final pageSize = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(pageSize.width / 2, pageSize.height - 20));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(track.title), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    // Drift schedules stream cleanup on a zero-delay timer after the final
    // StreamBuilder unsubscribes.
    await tester.pump(const Duration(seconds: 1));
  });
}
