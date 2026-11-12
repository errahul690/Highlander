import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../posts_api.dart';
import '../realtime_client.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/change_email_sheet.dart';
import '../widgets/city_field.dart';
import '../widgets/profile_form_header.dart';
import '../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _cityController;
  late TextEditingController _dobController;

  String _profilePhoto = '';
  String _selectedGender = 'Male';
  String _selectedPlayer = 'Alaeddine Ajaraie';
  DateTime? _dob;
  bool _uploadingPhoto = false;
  bool _saving = false;
  VerifiedEmailChange? _emailChange;

  Future<void> _changeEmail() async {
    final change = await showDialog<VerifiedEmailChange>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeEmailSheet(currentEmail: Session.email),
    );
    if (mounted && change != null) {
      setState(() {
        _emailChange = change;
        _emailController.text = change.email;
      });
    }
  }

  final List<String> _playerList = [
    'Alaeddine Ajaraie',
    'Michel Zabaco',
    'Parthib Gogoi',
    'Phalguni Singh',
    'Macarton Louis Nickson',
    'Mohammed Ali Bemammer',
    'Guillermo Fernandez',
    'Gurmeet Singh',
    'Asheer Akhtar',
    'Buanthanglun Samte',
  ];

  final List<String> _avatarPresets = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=300&q=80',
    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=300&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _dob = _parseDob(Session.dob);
    _nameController = TextEditingController(text: Session.name);
    _phoneController = TextEditingController(text: _phoneDigits(Session.phone));
    _emailController = TextEditingController(text: Session.email);
    _cityController = TextEditingController(text: Session.city);
    _dobController = TextEditingController(
      text: _dob == null ? Session.dob : _displayDate(_dob!),
    );

    _profilePhoto = Session.profilePhoto;

    if (Session.gender.isNotEmpty) _selectedGender = Session.gender;
    if (Session.favoritePlayer.isNotEmpty &&
        _playerList.contains(Session.favoritePlayer)) {
      _selectedPlayer = Session.favoritePlayer;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.pop(context); // close sheet
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _uploadingPhoto = true);
      try {
        final uploadedUrl = await PostsApi.instance.upload(file);
        if (uploadedUrl.isNotEmpty && mounted) {
          setState(() => _profilePhoto = uploadedUrl);
        }
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Photo upload failed. Please try again."),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not access image: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Change Profile Picture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2229),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF881A1A),
                  ),
                ),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => _pickPhoto(ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF881A1A),
                  ),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => _pickPhoto(ImageSource.gallery),
              ),
              const SizedBox(height: 10),
              const Text(
                'OR CHOOSE A HIGHLANDER AVATAR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A92A0),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _avatarPresets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (ctx, idx) {
                    final preset = _avatarPresets[idx];
                    final isSelected = _profilePhoto == preset;
                    return GestureDetector(
                      key: ValueKey('avatar-preset-$idx'),
                      onTap: () {
                        setState(() => _profilePhoto = preset);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF881A1A)
                                : Colors.grey.shade300,
                            width: isSelected ? 3 : 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            preset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} / ${date.month.toString().padLeft(2, '0')} / ${date.year}';

  String _phoneDigits(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length > 10) {
      digits = digits.substring(2);
    }
    return digits;
  }

  DateTime? _parseDob(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final iso = DateTime.tryParse(value);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final shown = RegExp(r'^(\d{1,2})\s*/\s*(\d{1,2})\s*/\s*(\d{4})$')
        .firstMatch(value);
    if (shown != null) {
      final day = int.parse(shown.group(1)!);
      final month = int.parse(shown.group(2)!);
      final year = int.parse(shown.group(3)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final words = value.split(RegExp(r'\s+'));
    if (words.length == 3) {
      final day = int.tryParse(words[0]);
      final month = months.indexOf(words[1]) + 1;
      final year = int.tryParse(words[2]);
      if (day != null && month > 0 && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  Future<void> _selectDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: authRed,
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E2229),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dob = DateTime(picked.year, picked.month, picked.day);
        _dobController.text = _displayDate(_dob!);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_saving || _uploadingPhoto) return;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final emailChanged = email != Session.email.trim().toLowerCase();
    if (emailChanged &&
        (_emailChange?.email != email ||
            _emailChange!.proof.isEmpty ||
            _emailChange!.currentEmailProof.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verify the new email with OTP before saving.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final newName = _nameController.text.trim();
    final newCity = _cityController.text.trim();
    final newDob = _dob == null ? _dobController.text.trim() : _isoDate(_dob!);

    try {
      if (Session.token.isEmpty)
        throw Exception('Please sign in again to save your profile.');
      final result = await PostsApi.instance.request(
        '/api/auth/me',
        method: 'PUT',
        body: {
          'full_name': newName,
          'city': newCity,
          'profile_photo': _profilePhoto,
          'profileImage': _profilePhoto,
          'gender': _selectedGender,
          'dob': newDob,
          'location': newCity,
          if (emailChanged) ...{
            'email': email,
            'emailVerificationToken': _emailChange!.proof,
            'currentEmailVerificationToken': _emailChange!.currentEmailProof,
          },
        },
      );
      final saved = result['data'];
      if (saved is! Map)
        throw Exception('Profile could not be saved. Please try again.');
      final savedPhoto =
          (saved['profile_photo'] ?? saved['profileImage'] ?? _profilePhoto)
              as String;
      await Session.updateDetails(
        name: saved['full_name'] as String? ?? newName,
        city: saved['city'] as String? ?? newCity,
        profilePhoto: savedPhoto,
        gender: _selectedGender,
        dob: newDob,
        favoritePlayer: _selectedPlayer,
        email: saved['email'] as String? ?? Session.email,
        emailVerified:
            saved['email_verified'] as bool? ?? Session.emailVerified,
      );
      RealtimeClient.instance.dispatchSettingsUpdate({
        'resource': 'posts',
        'action': 'profile-updated',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully! ✨'),
          backgroundColor: Color(0xFF1E2229),
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pop(context, true);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save profile: $err')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 7),
    child: Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: text == 'Gender' ? authRed : clubInk,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    ),
  );

  InputDecoration _field({String? hint, Widget? suffix}) =>
      profileFormField(hint: hint, suffix: suffix);

  @override
  Widget build(BuildContext context) {
    const fieldStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: clubInk,
    );
    return AuthTheme(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
      automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          foregroundColor: clubInk,
          surfaceTintColor: Colors.transparent,
          elevation: 0,

        ),
        body: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                ProfileFormHeader(
                  action: 'Edit',
                  coverSource: Session.coverPhoto,
                  photoKey: const ValueKey('edit-profile-photo'),
                  photoLabel: _profilePhoto.trim().isEmpty
                      ? 'Add photo'
                      : 'Change photo',
                  onPhotoTap: _saving || _uploadingPhoto
                      ? null
                      : _showPhotoOptions,
                  photo: _uploadingPhoto
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: authRed,
                          ),
                        )
                      : _profilePhoto.trim().isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          size: 72,
                          color: Color(0xFFF39DA6),
                        )
                      : UserAvatar(
                          image: _profilePhoto,
                          name: _nameController.text,
                          radius: 55,
                          backgroundColor: const Color(0xFFFCE0E2),
                          foregroundColor: authRed,
                        ),
                ),
                _label('Full name'),
                TextFormField(
                  key: const ValueKey('edit-profile-field-Full Name *'),
                  controller: _nameController,
                  readOnly: _saving,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  style: fieldStyle,
                  decoration: _field(hint: 'Enter your full name')
                      .copyWith(counterText: ''),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your full name'
                      : null,
                ),
                _label('Gender'),
                Row(
                  children: [
                    for (final gender in ['Male', 'Female', 'Other']) ...[
                      if (gender != 'Male') const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              gender,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: _selectedGender == gender
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontSize: 15,
                                color: _selectedGender == gender
                                    ? authRed
                                    : authMuted,
                              ),
                            ),
                          ),
                          showCheckmark: false,
                          selected: _selectedGender == gender,
                          selectedColor: const Color(0xFFFFF4F3),
                          backgroundColor: Colors.white,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelPadding: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          side: BorderSide(
                            color: _selectedGender == gender
                                ? authRed
                                : const Color(0xFFE4E4E4),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onSelected: _saving
                              ? null
                              : (_) => setState(() => _selectedGender = gender),
                        ),
                      ),
                    ],
                  ],
                ),
                _label('Date of birth'),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _saving ? null : _selectDob,
                  style: fieldStyle,
                  decoration: _field(
                    hint: 'DD / MM / YYYY',
                    suffix: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: Color(0xFF8A8F98),
                    ),
                  ),
                ),
                _label(
                  'Email address',
                  trailing: TextButton(
                    onPressed: _saving ? null : _changeEmail,
                    style: TextButton.styleFrom(
                      foregroundColor: authRed,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Change email',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextFormField(
                  key: const ValueKey('edit-profile-field-Email Address'),
                  controller: _emailController,
                  readOnly: true,
                  style: fieldStyle,
                  decoration:
                      _field(
                        suffix: _emailChange != null || !Session.emailVerified
                            ? null
                            : const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF22A55A),
                                      size: 15,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Verified',
                                      style: TextStyle(
                                        color: Color(0xFF22A55A),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ).copyWith(
                        fillColor: const Color(0xFFF0F1F3),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE7E9ED),
                          ),
                        ),
                        helperText: _emailChange == null
                            ? null
                            : 'OTP verified · Save to apply',
                        helperStyle: const TextStyle(
                          color: Color(0xFF22A55A),
                          fontSize: 12,
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                      ),
                ),
                _label('Mobile number'),
                TextFormField(
                  controller: _phoneController,
                  readOnly: _saving,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: fieldStyle,
                  decoration: _field(hint: 'Enter mobile number').copyWith(
                    counterText: '',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 8),
                      child: Text(
                        '+91',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: clubInk,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                  ),
                ),
                _label(
                  'City',
                  // trailing: const Text(
                  //   'Optional',
                  //   style: TextStyle(
                  //     fontSize: 13,
                  //     fontWeight: FontWeight.w500,
                  //     color: Color(0xFF9AA1AD),
                  //   ),
                  // ),
                ),
                CityField(
                  controller: _cityController,
                  readOnly: _saving,
                  decoration: _field(
                    hint: 'Search for your city',
                    suffix: const Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: authMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: authButtonStyle().copyWith(
                    minimumSize: const WidgetStatePropertyAll(
                      Size.fromHeight(52),
                    ),
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(
                        fontFamily: clubFontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  onPressed: _saving || _uploadingPhoto ? null : _saveProfile,
                  child: Text(
                    _saving ? 'Saving Profile...' : 'Save Profile Changes',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
