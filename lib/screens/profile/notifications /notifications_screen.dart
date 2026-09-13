import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  List<Map<String, dynamic>> notifications = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final data =
          List<Map<String, dynamic>>.from(response);

      setState(() {
        notifications = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load notifications: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> markAsRead(
    Map<String, dynamic> notification,
  ) async {
    final id = notification['id']?.toString();

    if (id == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
          })
          .eq('id', id);

      setState(() {
        notification['is_read'] = true;
      });
    } catch (e) {
      debugPrint(
        'Mark notification as read error: $e',
      );
    }
  }

  Future<void> markAllAsRead() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
          })
          .eq('user_id', user.id)
          .eq('is_read', false);

      setState(() {
        for (final notification in notifications) {
          notification['is_read'] = true;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to mark notifications as read: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> deleteNotification(
    Map<String, dynamic> notification,
  ) async {
    final id = notification['id']?.toString();

    if (id == null) return;

    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', id);

      setState(() {
        notifications.remove(notification);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete notification: $e',
            ),
          ),
        );
      }
    }
  }

  String notificationIcon(String? type) {
    switch (type) {
      case 'follow':
        return '👤';

      case 'like':
        return '❤️';

      case 'comment':
        return '💬';

      case 'mention':
        return '🔔';

      default:
        return '🔔';
    }
  }

  Color notificationColor(String? type) {
    switch (type) {
      case 'follow':
        return Colors.blue;

      case 'like':
        return Colors.red;

      case 'comment':
        return Colors.green;

      default:
        return Colors.deepPurple;
    }
  }

  String formatTime(dynamic value) {
    if (value == null) return '';

    try {
      final date =
          DateTime.parse(value.toString()).toLocal();

      final now = DateTime.now();

      final difference = now.difference(date);

      if (difference.inSeconds < 60) {
        return 'Just now';
      }

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      }

      if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      }

      if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      }

      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  Future<void> refreshNotifications() async {
    await loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications
        .where(
          (notification) =>
              notification['is_read'] == false,
        )
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshNotifications,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : notifications.isEmpty
                ? ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 150),
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 15),
                      Center(
                        child: Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Your notifications will appear here.',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                    ),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification =
                          notifications[index];

                      final type =
                          notification['type']?.toString();

                      final message =
                          notification['message']
                                  ?.toString() ??
                              'You have a new notification';

                      final isRead =
                          notification['is_read'] == true;

                      return Dismissible(
                        key: ValueKey(
                          notification['id'],
                        ),
                        direction:
                            DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment:
                              Alignment.centerRight,
                          padding:
                              const EdgeInsets.only(
                            right: 20,
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) {
                          deleteNotification(
                            notification,
                          );
                        },
                        child: InkWell(
                          onTap: () {
                            if (!isRead) {
                              markAsRead(notification);
                            }
                          },
                          child: Container(
                            color: isRead
                                ? Colors.white
                                : const Color(0xFFEEF3FF),
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor:
                                      notificationColor(
                                    type,
                                  ).withOpacity(0.12),
                                  child: Text(
                                    notificationIcon(
                                      type,
                                    ),
                                    style:
                                        const TextStyle(
                                      fontSize: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isRead
                                              ? FontWeight.w400
                                              : FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      Text(
                                        formatTime(
                                          notification[
                                              'created_at'],
                                        ),
                                        style:
                                            const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 9,
                                    height: 9,
                                    margin:
                                        const EdgeInsets.only(
                                      top: 8,
                                      left: 8,
                                    ),
                                    decoration:
                                        const BoxDecoration(
                                      color: Colors.blue,
                                      shape:
                                          BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}