import 'package:flutter/material.dart';

// A simple data model for a notification.
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final IconData icon;
  final DateTime timestamp;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.timestamp,
  });
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // A list of notifications. In a real app, this would come from a service or database.
  final List<NotificationModel> _notifications = [
    NotificationModel(
      id: '1',
      title: 'Low Battery Warning',
      body: 'Your vehicle battery is at 15%. Find a charging station soon.',
      icon: Icons.battery_alert_rounded,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    NotificationModel(
      id: '2',
      title: 'Setup Complete',
      body: 'Your vehicle profile has been successfully configured.',
      icon: Icons.check_circle_outline_rounded,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NotificationModel(
      id: '3',
      title: 'New Feature: AI Recommendations',
      body: 'Check out our new AI-powered charging station recommendations!',
      icon: Icons.auto_awesome_rounded,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  // Helper to format time since notification
  String _timeAgo(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return Dismissible(
                  key: Key(notification.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    // Store the notification before removing it to allow for 'undo'.
                    final removedNotification = _notifications[index];
                    setState(() {
                      _notifications.removeAt(index);
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${removedNotification.title} dismissed'),
                        action: SnackBarAction(
                          label: 'UNDO',
                          onPressed: () {
                            setState(() {
                              _notifications.insert(index, removedNotification);
                            });
                          },
                        ),
                      ),
                    );
                  },
                  background: _buildDismissibleBackground(),
                  child: _buildNotificationCard(notification),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Notifications',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissibleBackground() {
    return Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Delete',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Icon(Icons.delete_sweep_outlined, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getIconBackgroundColor(notification.icon),
          child: Icon(notification.icon, color: Colors.white, size: 24),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(notification.body),
        ),
        trailing: Text(
          _timeAgo(notification.timestamp),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getIconBackgroundColor(IconData icon) {
    if (icon == Icons.battery_alert_rounded) {
      return Colors.red.shade400;
    } else if (icon == Icons.check_circle_outline_rounded) {
      return Colors.green.shade400;
    } else if (icon == Icons.auto_awesome_rounded) {
      return Colors.blue.shade400;
    }
    return Colors.grey;
  }
}
