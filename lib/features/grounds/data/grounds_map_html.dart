/// Remove the cinematic entrance from our uploaded interactive grounds artwork.
/// Applied at display time so existing on-device caches benefit immediately.
String prepareGroundsMapHtml(String html) {
  if (!html.contains('Highlanders Grounds Hero') ||
      !html.contains('const cam = { x: 0.5, y: 0.5, s: 1.32 };')) {
    return html;
  }
  return html
      .replaceFirst(
        'const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;',
        'const reduce = true;',
      )
      .replaceFirst(
        'const cam = { x: 0.5, y: 0.5, s: 1.32 };',
        'const cam = { x: 0.5, y: 0.5, s: 1.04 };',
      )
      .replaceFirst('drawFx(t, dt);', 'drawFx(t + 4, dt);')
      .replaceFirst('drawMist(t, ox, oy, s);', 'drawMist(t + 4, ox, oy, s);')
      .replaceFirst('drawRoute(t);', 'drawRoute(t + 4);')
      .replaceFirst(
        '.pin.flip .lab { left: auto; right: clamp(13px, 2cqw, 24px); text-align: right; clip-path: inset(0 0 0 100%); }',
        '.pin.flip .lab { left: clamp(13px, 2cqw, 24px); right: auto; text-align: left; clip-path: inset(0 100% 0 0); }',
      )
      .replaceFirst(
        '.hero.ready .pin.flip .lab { clip-path: inset(-20% 0 -20% -10%); }',
        '.hero.ready .pin.flip .lab { clip-path: inset(-20% -10% -20% 0); }',
      )
      .replaceFirst('</head>', '''
<style data-ground-mobile-stable>
.curtain { display: none !important; }
.pin .drop { opacity: 1; transform: none; transition: none !important; }
.pin .lab { clip-path: inset(-20% -10% -20% 0); transition: none !important; }
.pin.flip .lab, .hero.ready .pin.flip .lab {
  left: clamp(13px, 2cqw, 24px) !important;
  right: auto !important;
  text-align: left !important;
  clip-path: inset(-20% -10% -20% 0) !important;
  transform: none !important;
}
.grain { animation: none !important; }
</style></head>''');
}

/// Wait for artwork decoding, fonts and browser paint before revealing the view.
String groundsMapReadyScript(int generation) =>
    '''
(async function () {
  await Promise.all(Array.from(document.images).map(async function (img) {
    try { await img.decode(); } catch (_) {}
  }));
  if (document.fonts) await document.fonts.ready;
  requestAnimationFrame(function () {
    requestAnimationFrame(function () {
      GroundsMapReady.postMessage('$generation');
    });
  });
})();
''';
