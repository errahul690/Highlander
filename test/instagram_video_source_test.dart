import 'package:flutter_test/flutter_test.dart';
import 'package:Highlanders/features/gallery/data/instagram_video_source.dart';

void main() {
  test('Reel sharing parameters are removed before loading the embed', () {
    final link = instagramVideoPermalink(
      ' https://www.instagram.com/reel/C7Ab_123-xy/?igsh=tracking ',
    );
    expect(link.toString(), 'https://www.instagram.com/reel/C7Ab_123-xy/');
    expect(
      link!.resolve('embed/').toString(),
      'https://www.instagram.com/reel/C7Ab_123-xy/embed/',
    );
  });

  test('Post and user-prefixed Reel URLs are recognized', () {
    for (final path in [
      'reel/ABC123',
      'reels/ABC123/',
      'club.name/reel/ABC123/',
      'reel/ABC123/embed/',
    ]) {
      expect(
        instagramVideoPermalink('https://instagram.com/$path').toString(),
        'https://www.instagram.com/reel/ABC123/',
      );
    }
    expect(
      instagramVideoPermalink('https://instagram.com/p/ABC123/').toString(),
      'https://www.instagram.com/p/ABC123/',
    );
  });

  test(
    'Other videos, profile links and unsafe URLs are not Instagram embeds',
    () {
      for (final source in [
        'https://cdn.example.test/video.mp4',
        'https://youtu.be/mUI5buxDdOY',
        'https://instagram.com.evil.test/reel/ABC123/',
        'https://user:pass@instagram.com/reel/ABC123/',
        'https://instagram.com/club.name/',
        'https://instagram.com/stories/club.name/123/',
        'https://instagram.com/share/reel/ABC123/',
        'javascript:alert(1)',
      ]) {
        expect(instagramVideoPermalink(source), isNull, reason: source);
      }
    },
  );
}
