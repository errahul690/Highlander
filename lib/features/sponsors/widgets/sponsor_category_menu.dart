import 'package:flutter/material.dart';

import 'package:Highlanders/features/sponsors/data/sponsors_repository.dart';
import 'package:Highlanders/features/sponsors/widgets/sponsor_style.dart';

class SponsorCategoryMenu extends StatelessWidget {
  const SponsorCategoryMenu({
    super.key,
    required this.sponsors,
    required this.selectedTier,
    required this.onSelected,
  });

  final List<Sponsor> sponsors;
  final String selectedTier;
  final ValueChanged<String> onSelected;

  int _count(String tier) => tier == 'all'
      ? sponsors.length
      : sponsors.where((sponsor) => sponsor.tier == tier).length;

  static const _icons = {
    'all': Icons.people_outline,
    'principal': Icons.person_outline,
    'kit': Icons.checkroom_outlined,
    'associate': Icons.handshake_outlined,
    'official': Icons.star_outline,
    'gov': Icons.account_balance_outlined,
    'cause': Icons.favorite_border,
  };

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: const ValueKey('sponsor-category-menu'),
    tooltip: 'Filter partners by category',
    onSelected: onSelected,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 12,
    position: PopupMenuPosition.under,
    offset: const Offset(0, 10),
    constraints: const BoxConstraints(minWidth: 260, maxWidth: 285),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFF0E9EC)),
    ),
    itemBuilder: (context) => [
      const PopupMenuItem<String>(
        enabled: false,
        height: 38,
        child: Text(
          'SELECT PARTNER TYPE',
          style: TextStyle(
            color: Color(0xFF98949A),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.7,
          ),
        ),
      ),
      for (final entry in SponsorStyle.tierLabels.entries)
        PopupMenuItem<String>(
          key: ValueKey('sponsor-tier-${entry.key}'),
          value: entry.key,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Semantics(
            selected: selectedTier == entry.key,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: selectedTier == entry.key
                    ? const Color(0xFFFFF0F3)
                    : Colors.white,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Icon(_icons[entry.key], color: SponsorStyle.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.key == 'all' ? 'All Partners' : entry.value,
                      style: TextStyle(
                        color: selectedTier == entry.key
                            ? SponsorStyle.red
                            : SponsorStyle.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 25),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selectedTier == entry.key
                          ? SponsorStyle.red
                          : const Color(0xFFF5F4F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_count(entry.key)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: selectedTier == entry.key
                            ? Colors.white
                            : SponsorStyle.soft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    child: selectedTier == entry.key
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: SponsorStyle.red,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        enabled: false,
        height: 34,
        child: Text(
          'Tap a category to filter sponsors.',
          style: TextStyle(fontSize: 10, color: SponsorStyle.soft),
        ),
      ),
    ],
    // child: Semantics(
    //   button: true,
    //   label:
    //       'Filter partners, ${SponsorStyle.tierLabels[selectedTier]}, '
    //       '${_count(selectedTier)} partners',
    //   child: Container(
    //     constraints: const BoxConstraints(minHeight: 44),
    //     padding: const EdgeInsets.symmetric(horizontal: 10),
    //     decoration: BoxDecoration(
    //       color: Colors.white,
    //       borderRadius: BorderRadius.circular(99),
    //       border: Border.all(color: const Color(0xFFEEECEE)),
    //       boxShadow: const [
    //         BoxShadow(
    //           color: Color(0x1A160F1B),
    //           blurRadius: 15,
    //           offset: Offset(0, 5),
    //         ),
    //       ],
    //     ),
    //     // child: Row(
    //     //   mainAxisSize: MainAxisSize.min,
    //     //   children: [
    //     //     const Icon(
    //     //       Icons.people_outline,
    //     //       size: 18,
    //     //       color: Color(0xFFDF0A37),
    //     //     ),
    //     //     const SizedBox(width: 5),
    //     //     Text(
    //     //       '${_count(selectedTier)}',
    //     //       style: const TextStyle(
    //     //         color: SponsorStyle.red,
    //     //         fontSize: 12,
    //     //         fontWeight: FontWeight.w900,
    //     //       ),
    //     //     ),
    //     //     const SizedBox(width: 5),
    //     //     Text(
    //     //       selectedTier == 'all'
    //     //           ? 'PARTNERS'
    //     //           : SponsorStyle.tierLabels[selectedTier]!.toUpperCase(),
    //     //       style: const TextStyle(
    //     //         fontSize: 10.5,
    //     //         color: Color(0xFF5B5A60),
    //     //         fontWeight: FontWeight.w800,
    //     //       ),
    //     //     ),
    //     //     const SizedBox(width: 5),
    //     //     const Icon(Icons.expand_more, size: 16, color: SponsorStyle.soft),
    //     //   ],
    //     // ),
    //   ),
    // ),
  );
}
