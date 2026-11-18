import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:Highlanders/core/network/network_read.dart';
import 'package:Highlanders/features/sponsors/data/sponsors_catalog.dart';

const _sponsorsWebsite = 'https://neufc.in/';
const _base44AppId = '6a7206ad13fad16ac9170985';

String _logoUrl(Object? raw) {
  final value = '${raw ?? ''}'.trim();
  return value.isEmpty
      ? ''
      : Uri.parse(_sponsorsWebsite).resolve(value).toString();
}

final _bundledLogos = {
  for (final row in bundledSponsorCatalog)
    _logoUrl(row['logo']): '${row['asset_logo']}',
};

class Sponsor {
  const Sponsor({
    required this.id,
    required this.name,
    required this.logo,
    this.role = '',
    this.subtitle = '',
    this.tier = 'official',
    this.order = 0,
    this.assetLogo = '',
  });

  final String id, name, logo, role, subtitle, tier, assetLogo;
  final int order;

  factory Sponsor.fromJson(Map<String, dynamic> json) => Sponsor(
    id: '${json['id'] ?? json['_id'] ?? json['slug'] ?? json['name']}',
    name: '${json['name'] ?? ''}'.trim(),
    logo: _logoUrl(json['logo']),
    assetLogo: _bundledLogos[_logoUrl(json['logo'])] ?? '',
    role: '${json['partner_type'] ?? ''}'.trim(),
    subtitle: '${json['subtitle'] ?? ''}'.trim(),
    tier: _tier(json),
    order: (json['display_order'] as num?)?.toInt() ?? 0,
  );

  static const tiers = [
    'principal',
    'kit',
    'associate',
    'official',
    'gov',
    'cause',
  ];

  static String _tier(Map<String, dynamic> json) {
    final explicit = '${json['tier'] ?? ''}'.trim();
    if (tiers.contains(explicit)) return explicit;
    final role = '${json['partner_type'] ?? ''}'.toLowerCase();
    if (role.contains('principal') || role.contains('title')) {
      return 'principal';
    }
    if (role.contains('kit')) return 'kit';
    if (role.contains('associate')) return 'associate';
    if (role.contains('cause') || role.contains('welfare')) return 'cause';
    if ('${json['subtitle'] ?? ''}'.toLowerCase().contains('government')) {
      return 'gov';
    }
    return 'official';
  }
}

/// Reads the public Partner entity used by the existing Base44 club website.
/// The bundled snapshot provides real sponsors before the first network result.
class SponsorsRepository {
  SponsorsRepository({http.Client? client})
    : _client = client ?? http.Client(),
      _cached = _ordered(bundledSponsorCatalog.map(Sponsor.fromJson));

  static final instance = SponsorsRepository();
  final http.Client _client;
  List<Sponsor> _cached;
  List<Sponsor> get cached => _cached;

  static List<Sponsor> _ordered(Iterable<Sponsor> sponsors) =>
      List.unmodifiable(
        sponsors.toList()..sort((a, b) {
          final tier = Sponsor.tiers
              .indexOf(a.tier)
              .compareTo(Sponsor.tiers.indexOf(b.tier));
          return tier != 0 ? tier : a.order.compareTo(b.order);
        }),
      );

  Future<List<Sponsor>> load() async {
    final response = await getWithRetry(
      _client,
      Uri.parse(
        'https://app.base44.com/api/apps/$_base44AppId/entities/Partner',
      ).replace(queryParameters: {'sort': 'display_order', 'limit': '500'}),
      timeout: const Duration(seconds: 8),
    );
    if (response.statusCode != 200) {
      throw ApiRequestException(
        'Could not load sponsors.',
        response.statusCode,
      );
    }
    final body = jsonDecode(response.body);
    if (body is! List) throw const FormatException('Invalid sponsor list');
    final sponsors = body
        .whereType<Map>()
        .where((row) => row['status'] == 'active')
        .map((row) => Sponsor.fromJson(Map<String, dynamic>.from(row)))
        .where((sponsor) => sponsor.name.isNotEmpty);
    return _cached = _ordered(sponsors);
  }
}
