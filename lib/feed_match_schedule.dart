import 'models.dart';

enum FeedMatchPhase { upcoming, preview, live, report }

class FeedMatchSelection {
  const FeedMatchSelection(this.fixture, this.phase);
  final Fixture fixture;
  final FeedMatchPhase phase;
}

DateTime indiaDate(DateTime now) {
  final india = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime.utc(india.year, india.month, india.day);
}

FeedMatchSelection? selectFeedMatch(List<Fixture> fixtures, DateTime now) {
  final today = indiaDate(now);
  final choices = <(int, Fixture, FeedMatchPhase)>[];
  for (final fixture in fixtures) {
    if ([
      'cancelled',
      'postponed',
    ].contains(fixture.matchStatus.trim().toLowerCase())) {
      continue;
    }
    // Yesterday's confirmed result follows live/preview and precedes next match.
    final status = fixture.matchStatus.trim().toLowerCase();
    final stage = fixture.journeyStage.trim().toLowerCase();
    final section = fixture.section.trim().toLowerCase();
    final completed =
        stage == 'report' ||
        section == 'completed' ||
        [
          'completed',
          'finished',
          'full time',
          'full-time',
          'ft',
        ].contains(status);
    if (completed) {
      final date = DateTime.tryParse('${fixture.date}T00:00:00Z');
      if (date != null &&
          date.toIso8601String().substring(0, 10) == fixture.date &&
          today.difference(date).inDays == 1) {
        choices.add((2, fixture, FeedMatchPhase.report));
      }
      continue;
    }
    if (stage == 'live' || section == 'live' || status == 'live') {
      choices.add((0, fixture, FeedMatchPhase.live));
      continue;
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fixture.date)) continue;
    final date = DateTime.tryParse('${fixture.date}T00:00:00Z');
    if (date == null ||
        date.toIso8601String().substring(0, 10) != fixture.date) {
      continue;
    }
    final day = date.difference(today).inDays;
    final validTime = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
        .hasMatch(fixture.time);
    final kickoff = validTime
        ? DateTime.tryParse('${fixture.date}T${fixture.time}:00+05:30')
        : null;
    if (kickoff == null) {
      if (day == -1) {
        choices.add((2, fixture, FeedMatchPhase.report));
      } else if (day == 0 || day == 1) {
        choices.add((1, fixture, FeedMatchPhase.preview));
      } else if (day > 0) {
        choices.add((3, fixture, FeedMatchPhase.upcoming));
      }
      continue;
    }
    final remaining = kickoff.difference(now);
    if (remaining > const Duration(hours: 24)) {
      choices.add((3, fixture, FeedMatchPhase.upcoming));
    } else if (remaining > Duration.zero) {
      choices.add((1, fixture, FeedMatchPhase.preview));
    } else if (remaining > const Duration(hours: -6)) {
      // A source-confirmed final result, rather than the clock, ends the live stage.
      choices.add((0, fixture, FeedMatchPhase.live));
    } else if (day == -1) {
      // Show yesterday's match even if the source still labels it Upcoming.
      choices.add((2, fixture, FeedMatchPhase.report));
    }
  }
  choices.sort((a, b) {
    final rank = a.$1.compareTo(b.$1);
    if (rank != 0) return rank;
    final chronological = '${a.$2.date} ${a.$2.time} ${a.$2.home} ${a.$2.away}'
        .compareTo('${b.$2.date} ${b.$2.time} ${b.$2.home} ${b.$2.away}');
    return a.$3 == FeedMatchPhase.report ? -chronological : chronological;
  });
  return choices.isEmpty
      ? null
      : FeedMatchSelection(choices.first.$2, choices.first.$3);
}

FeedMatchPhase fixturePhase(Fixture fixture, DateTime now) {
  final manual = {
    'upcoming': FeedMatchPhase.upcoming,
    'preview': FeedMatchPhase.preview,
    'live': FeedMatchPhase.live,
    'report': FeedMatchPhase.report,
  }[fixture.journeyStage];
  if (manual != null) return manual;
  if (fixture.section == 'completed' || fixture.played) {
    return FeedMatchPhase.report;
  }
  if (fixture.section.toLowerCase() == 'live' ||
      fixture.matchStatus.trim().toLowerCase() == 'live') {
    return FeedMatchPhase.live;
  }
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fixture.date)) {
    return FeedMatchPhase.upcoming;
  }
  final validTime = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(fixture.time);
  final kickoff = validTime
      ? DateTime.tryParse('${fixture.date}T${fixture.time}:00+05:30')
      : null;
  if (kickoff == null) return FeedMatchPhase.upcoming;
  final remaining = kickoff.difference(now);
  if (remaining > const Duration(hours: 24)) return FeedMatchPhase.upcoming;
  if (remaining > Duration.zero) return FeedMatchPhase.preview;
  if (remaining > const Duration(hours: -6)) return FeedMatchPhase.live;
  return FeedMatchPhase.upcoming;
}

String feedMatchThumbnail(
  Fixture fixture,
  FeedMatchPhase phase,
  String defaultThumbnail,
) {
  final specific = switch (phase) {
    FeedMatchPhase.upcoming => fixture.feedThumbnail,
    FeedMatchPhase.preview => fixture.previewThumbnail,
    FeedMatchPhase.report => fixture.reportThumbnail,
    FeedMatchPhase.live =>
      fixture.liveThumbnail.isNotEmpty
          ? fixture.liveThumbnail
          : 'assets/images/matchday_live_default.png',
  };
  return specific.isNotEmpty ? specific : defaultThumbnail;
}
