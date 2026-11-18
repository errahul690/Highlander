import 'package:flutter/material.dart';
import 'package:Highlanders/core/media/media_cache.dart';
import 'package:Highlanders/shared/widgets/profile_photo_transition.dart';

import 'package:Highlanders/features/auth/data/otp_api.dart';
import 'package:Highlanders/features/gallery/screens/photo_viewer_screen.dart';
import 'package:Highlanders/core/session/session.dart';
import 'package:Highlanders/core/theme/theme.dart';

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
      final savedPhoto = MediaCache.instance.bytesFor(url);
      final ImageProvider photoProvider = savedPhoto == null
          ? NetworkImage(url)
          : MemoryImage(savedPhoto);
      final avatar = CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: ClipOval(
          child: SizedBox.square(
            dimension: radius * 2,
            child: url.isEmpty
                ? _initial(label)
                : Image(
                    image: photoProvider,
                    key: ValueKey(own ? '$url:$revision' : url),
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => _initial(label),
                  ),
          ),
        ),
      );
      return Semantics(
        button: true,
        label: label.trim().isEmpty
            ? 'View profile photo'
            : 'View $label profile photo',
        child: GestureDetector(
          onTap: () {
            final reducedMotion = MediaQuery.disableAnimationsOf(context);
            final navigator = Navigator.of(context);
            final box = context.findRenderObject()! as RenderBox;
            final overlayBox =
                navigator.overlay!.context.findRenderObject()! as RenderBox;
            final origin = overlayBox.globalToLocal(
              box.localToGlobal(Offset.zero),
            );
            final sourceRect = origin & box.size;
            navigator.push(
              PageRouteBuilder<void>(
                opaque: false,
                transitionDuration: Duration(
                  milliseconds: reducedMotion ? 0 : 520,
                ),
                reverseTransitionDuration: Duration(
                  milliseconds: reducedMotion ? 0 : 300,
                ),
                pageBuilder: (_, _, _) => PhotoViewerScreen(
                  images: const [],
                  imageProvider: url.isEmpty ? null : photoProvider,
                  authorName: label,
                  emptyMessage: 'No Profile Pic',
                ),
                transitionsBuilder: (_, animation, _, child) => url.isEmpty
                    ? FadeTransition(opacity: animation, child: child)
                    : ProfilePhotoTransition(
                        animation: animation,
                        source: sourceRect,
                        image: photoProvider,
                        child: child,
                      ),
              ),
            );
          },
          child: avatar,
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
