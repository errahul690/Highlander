import 'package:flutter/material.dart';
import 'package:Highlanders/features/sponsors/data/sponsors_repository.dart';
import 'package:Highlanders/features/sponsors/widgets/sponsor_style.dart';

class SponsorTierFilters extends StatelessWidget {
  const SponsorTierFilters({
    super.key,
    required this.sponsors,
    required this.selectedTier,
    required this.onSelected,
  });
  final List<Sponsor> sponsors;
  final String selectedTier;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: SponsorStyle.line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x04000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          for (final tier in [
            'all',
            ...Sponsor.tiers.where(
              (tier) => sponsors.any((s) => s.tier == tier),
            ),
          ])
            _Tab(
              tier: tier,
              count: tier == 'all'
                  ? sponsors.length
                  : sponsors.where((s) => s.tier == tier).length,
              selected: tier == selectedTier,
              onTap: () => onSelected(tier),
            ),
        ],
      ),
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.tier,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String tier;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('sponsor-tier-$tier'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFF8ECEF) : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    SponsorStyle.tierLabels[tier]!,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                      color: selected ? SponsorStyle.red : SponsorStyle.soft,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 21),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? SponsorStyle.red
                          : const Color(0xFFF3F1F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : SponsorStyle.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                left: 27,
                right: 27,
                bottom: 0,
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    color: SponsorStyle.red,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
