import 'package:flutter/material.dart';

import '../otp_api.dart';
import '../session.dart';
import '../theme.dart';

// Every view of the signed-in user follows the same saved profile photo.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.userId = '',
    this.email = '',
    this.name = '',
    this.image = '',
    this.currentUser = false,
    this.radius = 20,
    this.backgroundColor = const Color(0xFFF7E7E5),
    this.foregroundColor = authRed,
  });
  final String userId, email, name, image;
  final bool currentUser;
  final double radius;
  final Color backgroundColor, foregroundColor;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: Session.profileChanges,
    builder: (context, revision, _) {
      final own =
          currentUser ||
          (userId.isNotEmpty && userId == Session.userId) ||
          (email.isNotEmpty &&
              Session.email.isNotEmpty &&
              email.toLowerCase() == Session.email.toLowerCase());
      final photo = own ? Session.profilePhoto : image;
      final label = own ? Session.name : name;
      final url = photo.trim().isEmpty
          ? ''
          : Uri.parse(OtpApi.apiBase).resolve(photo).toString();
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: ClipOval(
          child: SizedBox.square(
            dimension: radius * 2,
            child: url.isEmpty
                ? _initial(label)
                : Image.network(
                    url,
                    key: ValueKey(own ? '$url:$revision' : url),
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => _initial(label),
                  ),
          ),
        ),
      );
    },
  );

  Widget _initial(String label) => Center(
    child: Text(
      label.trim().characters.firstOrNull?.toUpperCase() ?? 'H',
      style: TextStyle(
        color: foregroundColor,
        fontWeight: FontWeight.w700,
        fontSize: radius * .75,
      ),
    ),
  );
}
