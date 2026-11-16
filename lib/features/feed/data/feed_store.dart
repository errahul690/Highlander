import 'package:flutter/foundation.dart';

class FeedPost {
  const FeedPost({required this.author, required this.title, required this.body});
  final String author, title, body;
}

// Local drafts/posts for the current app session.
class FeedStore {
  static final posts = ValueNotifier<List<FeedPost>>([]);
  static void add(FeedPost post) => posts.value = [post, ...posts.value];
  static void clear() => posts.value = [];
}
