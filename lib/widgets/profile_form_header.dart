import 'package:flutter/material.dart';

import '../theme.dart';
import 'profile_cover.dart';

InputDecoration profileFormField({
  String? hint,
  Widget? prefix,
  Widget? suffix,
}) => InputDecoration(
  hintText: hint,
  prefixIcon: prefix,
  suffixIcon: suffix,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  hintStyle: const TextStyle(
    color: authMuted,
    fontSize: 15,
    fontWeight: FontWeight.w400,
  ),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFC9CED8)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFC9CED8)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: authRed),
  ),
);

class ProfileFormHeader extends StatelessWidget {
  const ProfileFormHeader({
    super.key,
    required this.action,
    required this.photo,
    required this.photoLabel,
    required this.onPhotoTap,
    this.photoKey,
    this.coverPreview,
    this.coverSource = '',
    this.onCoverTap,
    this.overlapCover = false,
  });
  final String action, photoLabel;
  final Widget photo;
  final VoidCallback? onPhotoTap;
  final Key? photoKey;
  final ImageProvider? coverPreview;
  final String coverSource;
  final VoidCallback? onCoverTap;
  final bool overlapCover;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$action your '),
              const TextSpan(
                text: 'profile',
                style: TextStyle(color: authRed),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -.7,
            color: clubInk,
          ),
        ),
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = overlapCover
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final coverHeight = overlapCover ? width * .4 : 170.0;
          final height = overlapCover ? coverHeight + 88 : 170.0;
          return SizedBox(
            height: height,
            child: OverflowBox(
              maxWidth: width,
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: coverHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          overlapCover ? 12 : 0,
                        ),
                        child: ProfileCover(
                          fallbackAsset: 'assets/images/profile-stadium.png',
                          source: coverSource,
                          preview: coverPreview,
                          onEdit: onCoverTap,
                          editLabel: overlapCover
                              ? (coverPreview != null || coverSource.isNotEmpty
                                    ? 'Change cover'
                                    : 'Add cover')
                              : null,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        SizedBox(height: overlapCover ? coverHeight - 56 : 16),
                        Semantics(
                          button: true,
                          label: '$photoLabel profile photo',
                          child: InkWell(
                            key: photoKey,
                            onTap: onPhotoTap,
                            customBorder: const CircleBorder(),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: overlapCover ? 104 : 116,
                                  height: overlapCover ? 104 : 116,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFCE0E2),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x18000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(child: photo),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: overlapCover ? 34 : 38,
                                    height: overlapCover ? 34 : 38,
                                    decoration: BoxDecoration(
                                      color: authRed,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.photo_camera_outlined,
                                      color: Colors.white,
                                      size: overlapCover ? 18 : 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onPhotoTap,
                          style: TextButton.styleFrom(
                            foregroundColor: authRed,
                            minimumSize: const Size(0, 36),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: TextStyle(
                              fontFamily: authFontFamily,
                              fontSize: overlapCover ? 16 : 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(photoLabel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}
