import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Highlanders/features/posts/screens/create_post_screen.dart';
import 'package:Highlanders/features/gallery/screens/gallery_screen.dart';
import 'package:Highlanders/features/gallery/data/gallery_repository.dart';

class StaticGallery extends GalleryRepository {
  final entries = List.generate(
    12,
    (index) => GalleryItem(
      id: '$index',
      title: 'Album $index',
      tagline: 'Photos',
      thumbnail: '',
    ),
  );
  @override
  bool hasLoaded(String type) => true;
  @override
  List<GalleryItem> current(String type) => entries;
  @override
  Future<List<GalleryItem>> revalidate(
    String type, {
    bool force = false,
  }) async => entries;
}

void main() {
  testWidgets(
    'Create Post stays fixed and fits with and without the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(const MaterialApp(home: CreatePostScreen()));
      await tester.pump();
      expect(find.byType(NestedScrollView), findsNothing);
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('post-editor-box'))).height,
        lessThanOrEqualTo(172),
      );
      final before = tester.getTopLeft(find.byKey(const ValueKey('post-body')));
      await tester.drag(
        find.byKey(const ValueKey('post-body')),
        const Offset(0, -150),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('post-body'))),
        before,
      );
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pump();
      expect(find.byKey(const ValueKey('post-body')), findsOneWidget);
      expect(find.text('Add Images'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('post-editor-box'))).height,
        lessThanOrEqualTo(172),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('gallery tabs stay fixed while albums scroll below them', (
    tester,
  ) async {
    final previous = GalleryRepository.instance;
    GalleryRepository.instance = StaticGallery();
    addTearDown(() => GalleryRepository.instance = previous);
    await tester.pumpWidget(const MaterialApp(home: GalleryScreen()));
    await tester.pump();
    expect(find.byType(NestedScrollView), findsNothing);
    final tabs = find.text('Photos');
    final before = tester.getTopLeft(tabs);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(tabs), before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
