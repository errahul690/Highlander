import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../feed_startup.dart';
import '../otp_api.dart';
import '../posts_api.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/city_field.dart';
import 'shell.dart';

class _Dial {
  const _Dial(this.name, this.code, this.flag);
  final String name;
  final String code;
  final String flag;
}

const _dials = [
  _Dial('India', '91', '🇮🇳'),
  _Dial('United Arab Emirates', '971', '🇦🇪'),
  _Dial('United States', '1', '🇺🇸'),
  _Dial('United Kingdom', '44', '🇬🇧'),
  _Dial('Nepal', '977', '🇳🇵'),
  _Dial('Bangladesh', '880', '🇧🇩'),
  _Dial('Sri Lanka', '94', '🇱🇰'),
  _Dial('Singapore', '65', '🇸🇬'),
  _Dial('Malaysia', '60', '🇲🇾'),
  _Dial('Australia', '61', '🇦🇺'),
  _Dial('Canada', '1', '🇨🇦'),
  _Dial('Saudi Arabia', '966', '🇸🇦'),
  _Dial('Qatar', '974', '🇶🇦'),
  _Dial('Oman', '968', '🇴🇲'),
  _Dial('Kuwait', '965', '🇰🇼'),
  _Dial('Bahrain', '973', '🇧🇭'),
  _Dial('Thailand', '66', '🇹🇭'),
  _Dial('Indonesia', '62', '🇮🇩'),
  _Dial('Germany', '49', '🇩🇪'),
  _Dial('France', '33', '🇫🇷'),
  _Dial('South Africa', '27', '🇿🇦'),
  _Dial('New Zealand', '64', '🇳🇿'),
];

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});
  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _dobText = TextEditingController();
  _Dial _dial = _dials.first;
  DateTime? _dob;
  XFile? _photo;
  String? _gender;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _phone.dispose();
    _dobText.dispose();
    super.dispose();
  }

  String _mobile() {
    final digits = _phone.text.trim();
    if (digits.isEmpty) return '';
    return _dial.code == '91' ? digits : '+${_dial.code}$digits';
  }

  Future<void> _pickDial() async {
    final picked = await showModalBottomSheet<_Dial>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _DialSheet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dial = picked;
      if (picked.code == '91' && _phone.text.length > 10) {
        _phone.text = _phone.text.substring(0, 10);
      }
    });
  }

  Future<void> _choosePhoto(ImageSource source) async {
    Navigator.pop(context);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (file != null && mounted) setState(() => _photo = file);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open that photo. Try another one.');
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: clubLine,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profile photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => _choosePhoto(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => _choosePhoto(ImageSource.gallery),
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(sheet);
                  setState(() => _photo = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} / ${date.month.toString().padLeft(2, '0')} / ${date.year}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year, now.month, now.day),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: authRed,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dob = picked;
      _dobText.text = _displayDate(picked);
    });
  }

  Future<void> _savePhoto() async {
    final photo = _photo;
    if (photo == null) return;
    final url = await PostsApi.instance.upload(photo);
    await PostsApi.instance.request(
      '/api/auth/me',
      method: 'PUT',
      body: {'profile_photo': url, 'profileImage': url},
    );
    await Session.updateDetails(profilePhoto: url);
  }

  Future<void> _join() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (!Session.emailVerified ||
        OtpApi.instance.emailVerificationToken.isEmpty) {
      setState(
        () => _error = 'Verify your email address first. Go back to sign in.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      FeedStartup.start();
      final profile = await OtpApi.instance.saveProfile(
        name: _name.text.trim(),
        city: _city.text.trim(),
        email: Session.email,
        gender: _gender!,
        mobile: _mobile(),
        dob: _dob == null ? '' : _isoDate(_dob!),
      );
      await Session.saveProfile(profile);
      await _savePhoto();
      FeedStartup.start();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text, {String? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: authRed,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9AA1AD),
            ),
          ),
      ],
    ),
  );

  InputDecoration _field({String? hint, Widget? prefix, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
        hintStyle: const TextStyle(
          color: Color(0xFF9AA1AD),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      );

  Widget _photoCard() {
    final avatar = CircleAvatar(
      radius: 30,
      backgroundColor: const Color(0xFFF3D6D4),
      child: ClipOval(
        child: SizedBox.square(
          dimension: 60,
          child: _photo == null
              ? const Icon(Icons.person_rounded, size: 32, color: authRed)
              : Image.file(File(_photo!.path), fit: BoxFit.cover),
        ),
      ),
    );
    return Material(
      color: const Color(0xFFFFF6F6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const ValueKey('signup-photo'),
        borderRadius: BorderRadius.circular(16),
        onTap: _saving ? null : _showPhotoOptions,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  avatar,
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: authRed,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _photo == null ? 'Add photo' : 'Change photo',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: clubInk,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Optional',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8E95A1),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Make it yours. Add a photo anytime.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: Color(0xFF8E95A1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: clubInk,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Complete your profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  height: 1.15,
                  color: clubInk,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Help us get to know you better.',
                style: TextStyle(
                  color: Color(0xFF8E95A1),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              _photoCard(),
              _label('Full name'),
              TextFormField(
                key: const ValueKey('signup-name'),
                controller: _name,
                readOnly: _saving,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: clubInk,
                ),
                decoration: _field(hint: 'Your full name').copyWith(
                  counterText: '',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your full name'
                    : null,
              ),
              _label('Gender'),
              FormField<String>(
                key: const ValueKey('signup-gender'),
                initialValue: _gender,
                validator: (value) =>
                    value == null ? 'Select your gender' : null,
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (final gender in ['Male', 'Female', 'Other']) ...[
                          if (gender != 'Male') const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              key: ValueKey('signup-gender-$gender'),
                              label: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  gender,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: field.value == gender
                                        ? authRed
                                        : clubInk,
                                  ),
                                ),
                              ),
                              showCheckmark: false,
                              selected: field.value == gender,
                              selectedColor: const Color(0xFFFFF4F3),
                              backgroundColor: Colors.white,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              labelPadding: EdgeInsets.zero,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: field.value == gender
                                    ? authRed
                                    : const Color(0xFFE4E4E4),
                                width: field.value == gender ? 1.4 : 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              onSelected: _saving
                                  ? null
                                  : (_) {
                                      _gender = gender;
                                      field.didChange(gender);
                                    },
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (field.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          field.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _label('Date of birth'),
              TextFormField(
                key: const ValueKey('signup-dob'),
                controller: _dobText,
                readOnly: true,
                onTap: _saving ? null : _pickDob,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: clubInk,
                ),
                decoration: _field(
                  hint: 'DD / MM / YYYY',
                  suffix: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: Color(0xFF8A8F98),
                  ),
                ),
                validator: (_) =>
                    _dob == null ? 'Select your date of birth' : null,
              ),
              _label('City', trailing: 'Optional'),
              CityField(
                controller: _city,
                readOnly: _saving,
                decoration: _field(hint: 'Search your city'),
              ),
              _label('Mobile number'),
              _PhoneField(
                dial: _dial,
                controller: _phone,
                readOnly: _saving,
                onPick: _saving ? null : _pickDial,
                validator: (value) {
                  final digits = (value ?? '').trim();
                  if (digits.isEmpty) return null;
                  if (_dial.code == '91') {
                    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits)
                        ? null
                        : 'Enter a valid 10-digit mobile number';
                  }
                  return RegExp(r'^\d{6,14}$').hasMatch(digits)
                      ? null
                      : 'Enter a valid mobile number';
                },
              ),
              _label('E-mail ID'),
              InputDecorator(
                decoration: _field(
                  suffix: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF22A55A),
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            color: Color(0xFF22A55A),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).copyWith(
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                ),
                child: Text(
                  Session.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: clubInk,
                  ),
                ),
              ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(top: 18),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: authRed, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 28),
              FilledButton(
                style: authButtonStyle().copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(
                      fontFamily: clubFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                onPressed: _saving ? null : _join,
                child: Text(
                  _saving ? 'Creating account...' : 'Join Highlanders',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.dial,
    required this.controller,
    required this.readOnly,
    required this.onPick,
    required this.validator,
  });
  final _Dial dial;
  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback? onPick;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: const ValueKey('signup-mobile'),
    controller: controller,
    readOnly: readOnly,
    keyboardType: TextInputType.phone,
    maxLength: dial.code == '91' ? 10 : 14,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: clubInk,
      letterSpacing: .4,
    ),
    decoration: InputDecoration(
      counterText: '',
      hintText: dial.code == '91' ? '98765 43210' : 'Mobile number',
      hintStyle: const TextStyle(
        color: Color(0xFF9AA1AD),
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      prefixIcon: InkWell(
        key: const ValueKey('signup-dial'),
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+${dial.code}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: clubInk,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xFF8A8F98),
              ),
            ],
          ),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    ),
    validator: validator,
  );
}

class _DialSheet extends StatefulWidget {
  const _DialSheet();
  @override
  State<_DialSheet> createState() => _DialSheetState();
}

class _DialSheetState extends State<_DialSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = _dials
        .where(
          (dial) =>
              query.isEmpty ||
              dial.name.toLowerCase().contains(query) ||
              dial.code.contains(query),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .62,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: clubLine,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Country code',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search country',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (_, index) {
                  final dial = matches[index];
                  return ListTile(
                    key: ValueKey('dial-${dial.name}'),
                    leading: Text(
                      dial.flag,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(
                      dial.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Text(
                      '+${dial.code}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: authMuted,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, dial),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
