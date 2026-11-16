import 'package:flutter/material.dart';

const feedPhotos = [
  'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/e530d33f2_generated_b2f0c018.png',
  'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/313d904ba_generated_e86819ee.png',
  'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/d5a32b91a_generated_60575882.png',
];

class FeedPhoto extends StatelessWidget {
  const FeedPhoto({super.key, required this.index});
  final int index;
  @override
  Widget build(BuildContext context) => Image.network(feedPhotos[index % feedPhotos.length], fit: BoxFit.cover, width: double.infinity,
    errorBuilder: (_, error, stack) => const ColoredBox(color: Color(0xFF342322), child: Center(child: Icon(Icons.sports_soccer, color: Colors.white38, size: 48))),
  );
}
