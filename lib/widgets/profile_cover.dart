import 'package:flutter/material.dart';

import '../club_repository.dart';

/// Shared cover artwork for profile setup, your profile and other users.
class ProfileCover extends StatelessWidget {
  const ProfileCover({
    super.key,
    this.source = '',
    this.preview,
    this.fallbackAsset = 'assets/images/profile-cover.png',
    this.onEdit,
    this.busy = false,
    this.editLabel,
  });

  final String source, fallbackAsset;
  final ImageProvider? preview;
  final VoidCallback? onEdit;
  final bool busy;
  final String? editLabel;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Image.asset(fallbackAsset, fit: BoxFit.cover);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (preview != null)
          Image(
            image: preview!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          )
        else if (source.trim().isNotEmpty)
          Image.network(
            ClubRepository.mediaUrl(source.trim()),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (_, child, frame, synchronous) =>
                synchronous || frame != null ? child : fallback(),
            errorBuilder: (_, _, _) => fallback(),
          )
        else
          fallback(),
        if (onEdit != null || busy)
          Positioned(
            right: 12,
            top: editLabel == null ? null : 8,
            bottom: editLabel == null ? 16 : null,
            child: Material(
              color: const Color(0xCCFFFFFF),
              elevation: editLabel == null ? 0 : 2,
              shape: editLabel == null
                  ? const CircleBorder()
                  : const StadiumBorder(),
              child: editLabel != null
                  ? TextButton.icon(
                      key: const ValueKey('edit-profile-cover'),
                      onPressed: busy ? null : onEdit,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFAA1640),
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(editLabel!),
                    )
                  : IconButton(
                      key: const ValueKey('edit-profile-cover'),
                      tooltip: 'Change cover photo',
                      onPressed: busy ? null : onEdit,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.add_a_photo_outlined,
                              color: Color(0xFF222222),
                              size: 22,
                            ),
                    ),
            ),
          ),
      ],
    );
  }
}
