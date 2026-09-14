import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const EditProfileScreen({
    super.key,
    this.profile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;

  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  File? _newAvatar;
  File? _newCover;

  bool _saving = false;
  bool _checkingUsername = false;
  bool? _usernameAvailable;
  String? _originalUsername;

  // ✅ Username availability
  String get _currentUsername => _usernameController.text.trim();
  bool get _usernameChanged =>
      _originalUsername != null && _originalUsername != _currentUsername;

  @override
  void initState() {
    super.initState();

    _originalUsername =
        widget.profile?['username']?.toString().toLowerCase() ?? '';

    _nameController = TextEditingController(
      text: widget.profile?['full_name']?.toString() ?? '',
    );

    _usernameController = TextEditingController(
      text: widget.profile?['username']?.toString() ?? '',
    );

    _bioController = TextEditingController(
      text: widget.profile?['bio']?.toString() ?? '',
    );

    // Real-time username check
    _usernameController.addListener(_onUsernameChanged);
    _bioController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onUsernameChanged);
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final u = _usernameController.text.trim().toLowerCase();
    if (u == _originalUsername) {
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
      return;
    }
    setState(() => _usernameAvailable = null);
    _checkUsername(u);
  }

  Future<void> _checkUsername(String username) async {
    if (username.isEmpty || username.length < 3) {
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
      return;
    }

    setState(() => _checkingUsername = true);

    try {
      final existing = await _supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _usernameAvailable = existing == null;
        _checkingUsername = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
    }
  }

  Future<void> pickAvatar() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image == null) return;
      if (!mounted) return;
      setState(() => _newAvatar = File(image.path));
    } catch (e) {
      if (!mounted) return;
      _showError('Could not select avatar: $e');
    }
  }

  Future<void> pickCover() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image == null) return;
      if (!mounted) return;
      setState(() => _newCover = File(image.path));
    } catch (e) {
      if (!mounted) return;
      _showError('Could not select cover: $e');
    }
  }

  Future<String> uploadImage(File file, String folder) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User is not logged in.');

    final ext = file.path.contains('.')
        ? file.path.split('.').last.toLowerCase()
        : 'jpg';

    final fileName =
        '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    final path = '$folder/$fileName';

    await _supabase.storage.from('post-images').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return _supabase.storage.from('post-images').getPublicUrl(path);
  }

  Future<void> saveProfile() async {
    final username = _usernameController.text.trim().toLowerCase();
    final fullName = _nameController.text.trim();
    final bio = _bioController.text.trim();

    if (username.isEmpty) {
      _showError('Username cannot be empty.');
      return;
    }

    final usernameRegex = RegExp(r'^[a-z0-9_]{3,20}$');
    if (!usernameRegex.hasMatch(username)) {
      _showError(
        'Username must be 3-20 characters and use only lowercase letters, numbers, and underscore.',
      );
      return;
    }

    if (_usernameChanged && _usernameAvailable == false) {
      _showError('That username is already taken. Try another.');
      return;
    }

    setState(() => _saving = true);

    try {
      String? avatarUrl;
      String? coverUrl;

      if (_newAvatar != null) {
        avatarUrl = await uploadImage(_newAvatar!, 'avatars');
      }
      if (_newCover != null) {
        coverUrl = await uploadImage(_newCover!, 'covers');
      }

      await _profileService.updateProfile(
        username: username,
        fullName: fullName,
        bio: bio,
        avatarUrl: avatarUrl,
        coverUrl: coverUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } on StorageException catch (e) {
      if (!mounted) return;
      _showError('Image upload failed: ${e.message}');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.code == '23505') {
        _showError('That username is already taken.');
      } else {
        _showError('Update failed: ${e.message}');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Update failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final oldAvatar = widget.profile?['avatar_url']?.toString();
    final oldCover = widget.profile?['cover_url']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // ✅ Save button in AppBar
          if (!_saving)
            TextButton(
              onPressed: saveProfile,
              child: const Text(
                'SAVE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // =====================================================
            // COVER PHOTO
            // =====================================================
            SizedBox(
              height: 190,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _newCover != null
                        ? Image.file(_newCover!, fit: BoxFit.cover)
                        : (oldCover != null && oldCover.isNotEmpty)
                            ? Image.network(
                                oldCover,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        _coverPlaceholder(),
                              )
                            : _coverPlaceholder(),
                  ),
                  // Overlay with camera icon
                  Positioned(
                    right: 15,
                    top: 15,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        onPressed: _saving ? null : pickCover,
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Cover remove option
                  if (_newCover != null || (oldCover != null && oldCover.isNotEmpty))
                    Positioned(
                      left: 15,
                      top: 15,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          tooltip: 'Remove cover',
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() => _newCover = null);
                                  // Note: for removing existing, we'd need backend support
                                },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // =====================================================
            // PROFILE AVATAR
            // =====================================================
            Transform.translate(
              offset: const Offset(0, -45),
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 62,
                      backgroundColor: Colors.blueGrey.shade100,
                      backgroundImage: _newAvatar != null
                          ? FileImage(_newAvatar!)
                          : (oldAvatar != null && oldAvatar.isNotEmpty)
                              ? NetworkImage(oldAvatar)
                              : null,
                      child: _newAvatar == null &&
                              (oldAvatar == null || oldAvatar.isEmpty)
                          ? const Icon(
                              Icons.person,
                              size: 65,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 5,
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: Colors.blue,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: _saving ? null : pickAvatar,
                        icon: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // =====================================================
            // FORM
            // =====================================================
            Transform.translate(
              offset: const Offset(0, -25),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Username
                    TextField(
                      controller: _usernameController,
                      enabled: !_saving,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixText: '@ ',
                        prefixIcon: const Icon(Icons.alternate_email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        // ✅ Username availability indicator
                        suffixIcon: _usernameChanged
                            ? _checkingUsername
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : _usernameAvailable == true
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : _usernameAvailable == false
                                        ? const Icon(
                                            Icons.cancel,
                                            color: Colors.red,
                                          )
                                        : null
                            : null,
                      ),
                    ),

                    // Username status text
                    if (_usernameChanged)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          _checkingUsername
                              ? 'Checking availability...'
                              : _usernameAvailable == true
                                  ? 'Username available'
                                  : _usernameAvailable == false
                                      ? 'Username already taken'
                                      : '',
                          style: TextStyle(
                            fontSize: 12,
                            color: _checkingUsername
                                ? Colors.grey
                                : _usernameAvailable == true
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Bio with counter
                    TextField(
                      controller: _bioController,
                      enabled: !_saving,
                      maxLines: 4,
                      maxLength: 160,
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        hintText: 'Tell people something about you...',
                        prefixIcon: const Icon(Icons.info_outline),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        counterText:
                            '${_bioController.text.length}/160',
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Save Button (also at bottom for convenience)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : saveProfile,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: Colors.blueGrey,
      child: const Center(
        child: Icon(
          Icons.image,
          size: 50,
          color: Colors.white70,
        ),
      ),
    );
  }
}
