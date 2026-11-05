import 'models.dart';

String upcomingFixtureTag(Fixture fixture) {
  final competition = matchCompetition(fixture);
  return [
    if (competition != 'Competition not available' && competition.isNotEmpty)
      competition == 'Indian Super League' ? 'ISL' : competition,
    fixture.homeAwayLabel,
  ].where((part) => part.isNotEmpty).join(' · ');
}

String matchCompetition(Fixture fixture) {
  final heading = fixture.heading.trim();
  for (final entry in <String, String>{
    r'\bindian super league\b|\bisl\b': 'Indian Super League',
    r'\bdurand(?: cup)?\b': 'Durand Cup',
    r'\bsuper cup\b': 'Super Cup',
    r'\bi[- ]league\b': 'I-League',
  }.entries) {
    if (RegExp(entry.key, caseSensitive: false).hasMatch(heading))
      return entry.value;
  }
  // Older records sometimes store the fixture title in the competition field.
  // Do not repeat the teams above the same teams, or guess a league for them.
  if (heading.isEmpty ||
      RegExp(
        r'\bvs?\.?\s|\bversus\b',
        caseSensitive: false,
      ).hasMatch(heading)) {
    return 'Competition not available';
  }
  return heading;
}
