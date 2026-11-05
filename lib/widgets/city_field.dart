import 'dart:async';
import 'package:flutter/material.dart';
import '../cities_api.dart';
import '../theme.dart';

class CityField extends StatefulWidget {
  const CityField({
    super.key,
    required this.controller,
    this.readOnly = false,
    this.decoration,
  });
  final TextEditingController controller;
  final bool readOnly;
  final InputDecoration? decoration;
  @override
  State<CityField> createState() => _CityFieldState();
}

class _CityFieldState extends State<CityField> {
  Timer? _timer;
  int _request = 0;
  bool _loading = false;
  List<Map<String, dynamic>> _cities = [];
  String _error = '';

  void _changed(String value) {
    _timer?.cancel();
    final request = ++_request;
    setState(() { _cities = []; _error = ''; _loading = false; });
    if (value.trim().length < 2) return;
    _timer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      try {
        final cities = await CitiesApi.instance.search(value.trim());
        if (mounted && request == _request) setState(() => _cities = cities);
      } catch (error) {
        if (mounted && request == _request) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted && request == _request) setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _request++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(controller: widget.controller, readOnly: widget.readOnly, maxLength: 100, textCapitalization: TextCapitalization.words,
        style: const TextStyle(color: clubInk, fontSize: 16, fontWeight: FontWeight.w600), onChanged: _changed,
        decoration: (widget.decoration ?? const InputDecoration(
          hintText: 'Search your city',
          hintStyle: TextStyle(color: Color(0xFF9299A6), fontSize: 14),
        )).copyWith(
          counterText: '',
          suffixIcon: _loading
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
              : widget.decoration?.suffixIcon,
        )),
      if (_cities.isNotEmpty && !widget.readOnly) Container(margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(border: Border.all(color: clubLine), borderRadius: BorderRadius.circular(10)), child: Column(children: [
        ..._cities.map((city) => ListTile(dense: true, title: Text(city['name'] as String), subtitle: Text(city['description'] as String), onTap: () {
          _request++;
          _timer?.cancel();
          widget.controller.text = city['description'] as String;
          setState(() { _cities = []; _loading = false; });
          FocusScope.of(context).unfocus();
        })),
        Padding(padding: const EdgeInsets.all(8), child: Image.network('https://maps.gstatic.com/mapfiles/api-3/images/powered-by-google-on-white3.png', height: 16,
          errorBuilder: (_, error, stack) => const Text('Powered by Google', style: TextStyle(fontSize: 10, color: authMuted)))),
      ])),
      if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error, style: const TextStyle(color: authMuted, fontSize: 11))),
    ]);
  }
}
