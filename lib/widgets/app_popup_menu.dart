import 'package:flutter/material.dart';

import '../brand_colors.dart';

/// Shared overflow menu surface and placement throughout the app.
class AppPopupMenu<T> extends StatelessWidget {
  const AppPopupMenu({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.tooltip,
    this.enabled = true,
    this.icon,
    this.buttonSize = 40,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final String? tooltip;
  final bool enabled;
  final Widget? icon;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    final available = (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 248.0);
    return PopupMenuButton<T>(
      tooltip: tooltip,
      enabled: enabled,
      onSelected: onSelected,
      itemBuilder: itemBuilder,
      icon: icon ?? const Icon(Icons.more_vert, size: 22),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: Size.square(buttonSize),
        maximumSize: Size.square(buttonSize),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.transparent,
      ),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shadowColor: const Color(0x18000000),
      menuPadding: const EdgeInsets.all(6),
      constraints: BoxConstraints(
        minWidth: available.clamp(0.0, 192.0),
        maxWidth: available,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFECE8EB), width: .7),
      ),
    );
  }
}

class AppMenuItem<T> extends PopupMenuItem<T> {
  AppMenuItem({
    super.key,
    required super.value,
    required String label,
    required IconData icon,
    bool danger = false,
    bool enabled = true,
  }) : super(
         enabled: enabled,
         height: 46,
         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
         child: AppMenuRow(
           label: label,
           icon: icon,
           danger: danger,
           enabled: enabled,
         ),
       );
}

class AppMenuRow extends StatelessWidget {
  const AppMenuRow({
    super.key,
    required this.label,
    required this.icon,
    this.danger = false,
    this.enabled = true,
  });
  final String label;
  final IconData icon;
  final bool danger, enabled;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? const Color(0xFFB1ABB1)
        : danger
        ? brandAccent
        : const Color(0xFF302B32);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: danger ? const Color(0xFFFAEFF3) : const Color(0xFFF6F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
