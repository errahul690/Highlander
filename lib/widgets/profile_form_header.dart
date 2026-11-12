import 'package:flutter/material.dart';

import '../theme.dart';

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
  });
  final String action, photoLabel;
  final Widget photo;
  final VoidCallback? onPhotoTap;
  final Key? photoKey;

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
      SizedBox(
        height: 170,
        child: OverflowBox(
          maxWidth: MediaQuery.sizeOf(context).width,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width,
            height: 170,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/profile-stadium.png',
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
                Column(
                  children: [
                    const SizedBox(height: 16),
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
                              width: 116,
                              height: 116,
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
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: authRed,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.photo_camera_outlined,
                                  color: Colors.white,
                                  size: 20,
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
                        textStyle: const TextStyle(
                          fontFamily: authFontFamily,
                          fontSize: 17,
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
      ),
    ],
  );
}
