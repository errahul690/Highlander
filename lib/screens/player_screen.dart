import '../brand_colors.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/club_bar.dart';
import '../widgets/club_page_body.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.player});

  final Player player;
  static const _red = brandAccent;
  static const _paper = Color(0xFFFBF7F6);

  @override
  Widget build(BuildContext context) {
    final image = player.frontImage.trim().isNotEmpty
        ? player.frontImage
        : player.image;
    final jersey = player.jerseyLabel;
    return ClubScaffold(
      backgroundColor: _paper,
      appBar: const ClubBar(title: 'Player Profile'),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: constraints.maxWidth * .88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (jersey.isNotEmpty)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 48,
                        ),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            jersey,
                            key: const ValueKey('player-profile-number'),
                            style: const TextStyle(
                              fontSize: 300,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFFF0DDE0),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                      child: image.isEmpty
                          ? _placeholder()
                          : Image.network(
                              image,
                              key: const ValueKey('player-profile-photo'),
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                              semanticLabel: player.name,
                              errorBuilder: (_, _, _) => _placeholder(),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 12, 30, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  key: const ValueKey('player-profile-name'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 38,
                    height: 1.03,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (jersey.isNotEmpty)
                      _badge(player.jerseyBadge, primary: true),
                    if (player.position.trim().isNotEmpty)
                      _badge(player.position),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 28, 17, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFEDE5E5)),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x16382026),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Player information',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _PlayerInfoRow(
                    icon: Icons.shield_outlined,
                    label: 'Club',
                    value: 'NorthEast United FC',
                  ),
                  _PlayerInfoRow(
                    icon: Icons.directions_run,
                    label: 'Position',
                    value: player.position.trim().isEmpty
                        ? 'Not available'
                        : player.position,
                  ),
                  _PlayerInfoRow(
                    icon: Icons.sports_outlined,
                    jersey: jersey,
                    label: 'Jersey number',
                    value: jersey.isEmpty ? 'Not available' : jersey,
                    divider: false,
                  ),
                ],
              ),
            ),
          ),
          if (player.quote.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 24, 30, 0),
              child: Text(
                player.quote,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF56505A),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() => const Center(
    child: Icon(Icons.person_outline, size: 100, color: Color(0xFFCCADB4)),
  );

  Widget _badge(String text, {bool primary = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: primary ? _red : const Color(0xFFF0DCDD),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: primary ? Colors.white : _red,
        fontSize: 18,
        height: 1.15,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _PlayerInfoRow extends StatelessWidget {
  const _PlayerInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.jersey,
    this.divider = true,
  });
  final IconData icon;
  final String label, value;
  final String? jersey;
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 57),
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      border: divider
          ? const Border(bottom: BorderSide(color: Color(0xFFE9E1E2)))
          : null,
    ),
    child: Row(
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: jersey == null
              ? Icon(icon, color: PlayerScreen._red, size: 27)
              : CustomPaint(painter: _JerseyIcon(jersey!)),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: jersey == null ? 3 : 5,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              height: 1.25,
              color: Color(0xFF15151E),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          flex: jersey == null ? 5 : 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: Color(0xFF15151E),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _JerseyIcon extends CustomPainter {
  const _JerseyIcon(this.number);
  final String number;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    canvas.drawPath(
      Path()
        ..moveTo(10, 3)
        ..lineTo(5, 5)
        ..lineTo(1, 11)
        ..lineTo(6, 15)
        ..lineTo(8, 12)
        ..lineTo(8, 29)
        ..lineTo(24, 29)
        ..lineTo(24, 12)
        ..lineTo(26, 15)
        ..lineTo(31, 11)
        ..lineTo(27, 5)
        ..lineTo(22, 3)
        ..quadraticBezierTo(16, 10, 10, 3)
        ..close(),
      Paint()
        ..color = PlayerScreen._red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    final text = TextPainter(
      text: TextSpan(
        text: number,
        style: const TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: PlayerScreen._red,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 15);
    text.paint(canvas, Offset((32 - text.width) / 2, 15));
    text.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_JerseyIcon oldDelegate) => oldDelegate.number != number;
}
