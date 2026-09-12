import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

    /// Current logged-in user's profile
      Future<Map<String, dynamic>?> getMyProfile() async {
          final user = _supabase.auth.currentUser;

              if (user == null) {
                    return null;
                        }

                            final response = await _supabase
                                    .from('profiles')
                                            .select()
                                                    .eq('id', user.id)
                                                            .maybeSingle();

                                                                return response;
                                                                  }

                                                                    /// Get any user's profile by ID
                                                                      Future<Map<String, dynamic>?> getProfile(String userId) async {
                                                                          final response = await _supabase
                                                                                  .from('profiles')
                                                                                          .select()
                                                                                                  .eq('id', userId)
                                                                                                          .maybeSingle();

                                                                                                              return response;
                                                                                                                }

                                                                                                                  /// Create profile for a new user
                                                                                                                    Future<void> createProfile({
                                                                                                                        required String username,
                                                                                                                            String? fullName,
                                                                                                                                String? bio,
                                                                                                                                    String? avatarUrl,
                                                                                                                                        String? coverUrl,
                                                                                                                                          }) async {
                                                                                                                                              final user = _supabase.auth.currentUser;

                                                                                                                                                  if (user == null) {
                                                                                                                                                        throw Exception('User is not logged in.');
                                                                                                                                                            }

                                                                                                                                                                await _supabase.from('profiles').insert({
                                                                                                                                                                      'id': user.id,
                                                                                                                                                                            'username': username,
                                                                                                                                                                                  'full_name': fullName ?? '',
                                                                                                                                                                                        'bio': bio ?? '',
                                                                                                                                                                                              'avatar_url': avatarUrl,
                                                                                                                                                                                                    'cover_url': coverUrl,
                                                                                                                                                                                                        });
                                                                                                                                                                                                          }

                                                                                                                                                                                                            /// Update current user's profile
                                                                                                                                                                                                              Future<void> updateProfile({
                                                                                                                                                                                                                  String? username,
                                                                                                                                                                                                                      String? fullName,
                                                                                                                                                                                                                          String? bio,
                                                                                                                                                                                                                              String? avatarUrl,
                                                                                                                                                                                                                                  String? coverUrl,
                                                                                                                                                                                                                                    }) async {
                                                                                                                                                                                                                                        final user = _supabase.auth.currentUser;

                                                                                                                                                                                                                                            if (user == null) {
                                                                                                                                                                                                                                                  throw Exception('User is not logged in.');
                                                                                                                                                                                                                                                      }

                                                                                                                                                                                                                                                          final Map<String, dynamic> updates = {};
                                                                                                                                                                                                                                                              if (username != null) {
                                                                                                                                                                                                                                                                    updates['username'] = username;
                                                                                                                                                                                                                                                                        }

                                                                                                                                                                                                                                                                            if (fullName != null) {
                                                                                                                                                                                                                                                                                  updates['full_name'] = fullName;
                                                                                                                                                                                                                                                                                      }

                                                                                                                                                                                                                                                                                          if (bio != null) {
                                                                                                                                                                                                                                                                                                updates['bio'] = bio;
                                                                                                                                                                                                                                                                                                    }

                                                                                                                                                                                                                                                                                                        if (avatarUrl != null) {
                                                                                                                                                                                                                                                                                                              updates['avatar_url'] = avatarUrl;
                                                                                                                                                                                                                                                                                                                  }

                                                                                                                                                                                                                                                                                                                      if (coverUrl != null) {
                                                                                                                                                                                                                                                                                                                            updates['cover_url'] = coverUrl;
                                                                                                                                                                                                                                                                                                                                }

                                                                                                                                                                                                                                                                                                                                    updates['updated_at'] = DateTime.now().toIso8601String();

                                                                                                                                                                                                                                                                                                                                        await _supabase
                                                                                                                                                                                                                                                                                                                                                .from('profiles')
                                                                                                                                                                                                                                                                                                                                                        .update(updates)
                                                                                                                                                                                                                                                                                                                                                                .eq('id', user.id);
                                                                                                                                                                                                                                                                                                                                                                  }
                                                                                                                                                                                                                                                                                                                                                                  }