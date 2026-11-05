import 'package:flutter/material.dart';

bool storyHasText(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
      .trim()
      .isNotEmpty;
}

class StoryHtml extends StatelessWidget {
  const StoryHtml({super.key, required this.html, required this.style});
  final String html;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final blocks = storyBlocks(html, style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
}

List<Widget> storyBlocks(String source, TextStyle style) {
  final html = source.trim();
  if (!storyHasText(html)) return const [];
  if (!html.contains('<')) {
    return [
      for (final part in html.split(RegExp(r'\n\s*\n')))
        if (part.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(part.trim(), style: style),
          ),
    ];
  }

  final blocks = <Widget>[];
  final runs = <TextSpan>[];
  var current = style;
  final stack = <TextStyle>[style];
  final tokens = RegExp(
    r'<(/?)([a-zA-Z0-9]+)([^>]*)>|([^<]+)',
  ).allMatches(html);

  void flush() {
    final text = runs.map((span) => span.text ?? '').join();
    if (text.trim().isEmpty) {
      runs.clear();
      return;
    }
    blocks.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text.rich(TextSpan(children: [...runs]), style: style),
      ),
    );
    runs.clear();
  }

  void addText(String raw) {
    final text = _decode(raw).replaceAll(RegExp(r'[ \t\r\n]+'), ' ');
    if (text.trim().isEmpty) {
      if (text.contains(' ') && runs.isNotEmpty) {
        runs.add(TextSpan(text: ' ', style: current));
      }
      return;
    }
    runs.add(TextSpan(text: text, style: current));
  }

  for (final token in tokens) {
    final word = token.group(4);
    if (word != null) {
      addText(word);
      continue;
    }
    final closing = token.group(1) == '/';
    final tag = (token.group(2) ?? '').toLowerCase();
    final attrs = token.group(3) ?? '';
    if (tag == 'br') {
      if (runs.isNotEmpty) runs.add(TextSpan(text: '\n', style: current));
      continue;
    }
    const blocksTags = {'p', 'div', 'h1', 'h2', 'h3', 'li', 'blockquote'};
    if (blocksTags.contains(tag)) {
      if (closing || runs.isNotEmpty) flush();
      if (!closing && tag == 'li') {
        runs.add(TextSpan(text: '• ', style: current));
      }
    }
    if (closing) {
      if (stack.length > 1) stack.removeLast();
      current = stack.last;
      continue;
    }
    current = _apply(current, tag, attrs);
    stack.add(current);
  }
  flush();
  return blocks;
}

TextStyle _apply(TextStyle base, String tag, String attrs) {
  switch (tag) {
    case 'strong':
    case 'b':
    case 'h1':
    case 'h2':
    case 'h3':
      final sized = switch (tag) {
        'h1' => 22.0,
        'h2' => 18.0,
        'h3' => 16.0,
        _ => base.fontSize,
      };
      return base.copyWith(fontWeight: FontWeight.w800, fontSize: sized);
    case 'em':
    case 'i':
      return base.copyWith(fontStyle: FontStyle.italic);
    case 'u':
      return base.copyWith(decoration: TextDecoration.underline);
    case 'span':
      final size = RegExp(
        r'font-size\s*:\s*(\d+(?:\.\d+)?)px',
        caseSensitive: false,
      ).firstMatch(attrs);
      final bold = RegExp(
        r'font-weight\s*:\s*(bold|[6-9]00)',
        caseSensitive: false,
      ).hasMatch(attrs);
      var next = base;
      final px = double.tryParse(size?.group(1) ?? '');
      if (px != null) next = next.copyWith(fontSize: px.clamp(12, 40));
      if (bold) next = next.copyWith(fontWeight: FontWeight.w800);
      return next;
    default:
      return base;
  }
}

String _decode(String value) {
  return value
      .replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|\d+);'), (match) {
        final raw = match.group(1)!;
        final code = raw.startsWith('x')
            ? int.tryParse(raw.substring(1), radix: 16)
            : int.tryParse(raw);
        return code != null && code >= 0 && code <= 0x10FFFF
            ? String.fromCharCode(code)
            : match.group(0)!;
      })
      .replaceAll(
        RegExp('&nbsp;', caseSensitive: false),
        ' ',
      )
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}
