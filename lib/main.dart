import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 👈 FIX

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

  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  File? _newAvatar;
  File? _newCover;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.profile?['full_name']?.toString() ?? '',
    );

    _usernameController = TextEditingController(
      text: widget.profile?['username']?.toString() ?? '',
    );

    _bioController = TextEditingController(
      text: widget.profile?['bio']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ============================================================
  // IMAGE PICKING
  // ============================================================

  Future<void> pickAvatar() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (image == null) return;
      if (!mounted) return;

      setState(() {
        _newAvatar = File(image.path);
      });
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

      setState(() {
        _newCover = File(image.path);
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Could not select cover: $e');
    }
  }

  // ============================================================
  // IMAGE UPLOAD
  // ============================================================

  Future<String> uploadImage(File file, String folder) async {
    final supabase = _profileService.supabase;
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final extension = file.path.contains('.')
        ? file.path.split('.').last.toLowerCase()
        : 'jpg';

    final fileName =
        '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final path = '$folder/$fileName';

    await supabase.storage.from('post-images').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return supabase.storage.from('post-images').getPublicUrl(path);
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> saveProfile() async {
    final username = _usernameController.text.trim();
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

      // 23505 = duplicate key (username taken)
      if (e.code == '23505') {
        _showError('That username is already taken.');
      } else if (e.code == 'PGRST116' || e.code == '42501') {
        _showError(
          'Permission denied. Check your Supabase RLS policies.',
        );
      } else {
        _showError('Update failed: ${e.message}');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError('Auth error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showError('Update failed: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

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
                                    (context, error, stackTrace) {
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
                                },
                              )
                            : Container(
                                color: Colors.blueGrey,
                                child: const Center(
                                  child: Icon(
                                    Icons.image,
                                    size: 50,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                  ),

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
                  children: [
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
                      ),
                    ),

                    const SizedBox(height: 16),

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
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : saveProfile,
                        style: ElevatedButton.styleFrom(
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
}
