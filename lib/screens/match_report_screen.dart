import 'package:flutter/material.dart';

import '../widgets/club_header.dart';
import '../widgets/club_page_body.dart';

import '../models.dart';

import '../widgets/match_page_cards.dart';
import '../widgets/match_photo_gallery.dart';
import '../widgets/match_insights.dart';
import '../widgets/match_highlights_player.dart';
import '../widgets/match_highlights_source.dart';
import '../widgets/story_html.dart';

class MatchReportScreen extends StatefulWidget {
  const MatchReportScreen({
    super.key,
    required this.fixture,
    this.lineups,
    this.playHighlights = false,
  });
  final Fixture fixture;
  final Widget? lineups;
  final bool playHighlights;
  @override
  State<MatchReportScreen> createState() => _MatchReportScreenState();
}

class _MatchReportScreenState extends State<MatchReportScreen> {
  late bool _playing;
  ScrollController? _scrollController;
  final _headerScrollController = ScrollController();
  final _overviewKey = GlobalKey();
  Fixture get f => widget.fixture;

  @override
  void initState() {
    super.initState();
    final source = f.highlightsUrl.isNotEmpty
        ? f.highlightsUrl
        : matchHighlightsSource(f);
    _playing = widget.playHighlights && source.isNotEmpty;
  }

  void _playHighlights() {
    setState(() => _playing = true);
    _scrollController?.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _headerScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _headerScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MatchReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (matchHighlightsSource(oldWidget.fixture) != matchHighlightsSource(f)) {
      _playing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = f.highlightsUrl.isNotEmpty
        ? f.highlightsUrl
        : matchHighlightsSource(f);
    return ClubScaffold(
      scrollController: _headerScrollController,
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: const ClubHeader(
        title: 'Match Report',
        showBack: true,
        uppercaseTitle: false,
        showSearch: false,
        showSupport: false,
      ),
      body: Builder(
        builder: (context) {
          _scrollController = PrimaryScrollController.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Container(
                key: const ValueKey('match-report-card'),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF162B3D),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _playing && source.isNotEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 38,
                            padding: const EdgeInsets.only(left: 12, right: 6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0C1722),
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFF243442),
                                  width: .5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.play_circle_outline_rounded,
                                  color: Color(0xFFEC424B),
                                  size: 16,
                                ),
                                const SizedBox(width: 7),
                                const Text(
                                  'Highlights',
                                  style: TextStyle(
                                    color: Color(0xFFF1F4F7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  key: const ValueKey('close-match-highlights'),
                                  tooltip: 'Close highlights',
                                  constraints: const BoxConstraints.tightFor(
                                    width: 28,
                                    height: 28,
                                  ),
                                  padding: EdgeInsets.zero,
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF25313D),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  color: Colors.white,
                                  onPressed: () =>
                                      setState(() => _playing = false),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          MatchHighlightsPlayer(
                            key: ValueKey(source),
                            source: source,
                          ),
                        ],
                      )
                    : _hero(),
              ),
              const SizedBox(height: 18),
              KeyedSubtree(key: _overviewKey, child: _overview()),
              const SizedBox(height: 22),
              if (f.details.stats.isNotEmpty)
                _details(
                  'Match stats',
                  Column(
                    children: f.details.stats
                        .map(
                          (stat) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: MatchStatComparison(stat: stat),
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (widget.lineups != null &&
                  (f.details.homeLineup.isNotEmpty ||
                      f.details.awayLineup.isNotEmpty))
                _details('Line-ups', widget.lineups!),
              if (f.details.events.isNotEmpty)
                _details('Match timeline', MatchTimeline(fixture: f)),
            ],
          );
        },
      ),
    );
  }

  Widget _overview() {
    final summary = f.summary.trim();
    final title = f.reportTitle.trim();
    final heading = f.heading.trim();
    final showHeading =
        heading.isNotEmpty && heading.toLowerCase() != title.toLowerCase();
    final showReport = storyHasText(f.report) && f.report.trim() != summary;
    const momentLabels = {
      'goal': 'Goal',
      'own_goal': 'Own goal',
      'penalty': 'Penalty',
      'missed_penalty': 'Penalty missed',
      'red_card': 'Red card',
      'var': 'VAR decision',
      'other': 'Key moment',
    };
    final moments = f.details.events
        .where(
          (event) => [
            'goal',
            'own_goal',
            'penalty',
            'missed_penalty',
            'red_card',
            'var',
            'other',
          ].contains(event.type),
        )
        .take(8)
        .toList();
    final hasOverview =
        showHeading ||
        title.isNotEmpty ||
        summary.isNotEmpty ||
        showReport ||
        f.images.isNotEmpty ||
        moments.isNotEmpty;
    if (!hasOverview) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('match-report-overview'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E2DC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C172433),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEE),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.article_outlined,
                  size: 18,
                  color: Color(0xFFD91624),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Match overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172433),
                  ),
                ),
              ),
            ],
          ),
          if (showHeading) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                heading.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD91624),
                ),
              ),
            ),
          ],
          if (title.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w800,
                letterSpacing: -.3,
                color: Color(0xFF172433),
              ),
            ),
          ],
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF6F3),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: const Border(
                  left: BorderSide(color: Color(0xFFD91624), width: 3),
                ),
              ),
              child: Text(
                summary,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3848),
                ),
              ),
            ),
          ],
          if (f.images.isNotEmpty) ...[
            const SizedBox(height: 18),
            MatchPhotoGallery(images: f.images),
          ],
          if (showReport) ...[
            const SizedBox(height: 16),
            StoryHtml(
              html: f.report,
              style: const TextStyle(
                fontSize: 15,
                height: 1.7,
                color: Color(0xFF3E4854),
              ),
            ),
          ],
          if (moments.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 22, bottom: 12),
              child: Text(
                'KEY MOMENTS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172433),
                ),
              ),
            ),
            for (final event in moments)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFC),
                  border: Border.all(color: const Color(0xFFEDF0F3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${event.minute}'",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD91624),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.player.isEmpty
                                ? momentLabels[event.type] ?? 'Key moment'
                                : event.player,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [
                              if (event.team == 'home') f.home,
                              if (event.team == 'away') f.away,
                              momentLabels[event.type] ?? 'Key moment',
                              if (event.detail.isNotEmpty) event.detail,
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: Color(0xFF748397),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _details(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.all(14),
        children: [child],
      ),
    ),
  );

  void _readReport() {
    final section = _overviewKey.currentContext;
    if (section != null) {
      Scrollable.ensureVisible(
        section,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _hero() => MatchPageHero(
    key: const ValueKey('match-report-hero'),
    fixture: f,
    onOpen: _readReport,
    showReportAction: false,
    minHeight: 210,
    onHighlights:
        (f.highlightsUrl.isNotEmpty || matchHighlightsSource(f).isNotEmpty)
        ? _playHighlights
        : null,
  );
}
