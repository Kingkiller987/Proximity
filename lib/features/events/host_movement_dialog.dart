import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';
import 'event_member_picker_sheet.dart';

class HostMovementDialog extends StatefulWidget {
  const HostMovementDialog({
    super.key,
    required this.controller,
    required this.eventId,
  });

  final AppController controller;
  final String eventId;

  static Future<void> show(
    BuildContext context, {
    required AppController controller,
    required String eventId,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          HostMovementDialog(controller: controller, eventId: eventId),
    );
  }

  @override
  State<HostMovementDialog> createState() => _HostMovementDialogState();
}

class _HostMovementDialogState extends State<HostMovementDialog> {
  @override
  Widget build(BuildContext context) {
    final event = widget.controller.eventById(widget.eventId);
    if (event == null || event.isEnded) {
      return AlertDialog(
        title: const Text('Event Not Active'),
        content: const Text('This event is no longer active.'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              widget.controller.dismissHostMovementPrompt(widget.eventId);
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: const Text('Dismiss'),
          ),
        ],
      );
    }

    final hasAccurateFix = widget.controller.hasFreshAccurateLocation;
    final currentLoc = widget.controller.currentLocation;

    return AlertDialog(
      key: const Key('host-movement-dialog'),
      title: const Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: AppTheme.expiryAmber),
          SizedBox(width: 8),
          Expanded(child: Text('Host Departure Detected')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'You have moved outside the event boundary for "${event.title}".',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Your current location: ${currentLoc.areaName}.\nChoose how you would like to proceed with this event.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (!hasAccurateFix) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.5),
                  ),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orangeAccent,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Accurate GPS fix required to move event.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        // Action 4: Cancel / Dismiss
        TextButton(
          key: const Key('host-move-action-cancel'),
          onPressed: () {
            widget.controller.dismissHostMovementPrompt(widget.eventId);
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: Text(
            'Dismiss',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        // Action 3: End Event (Requires confirmation)
        TextButton(
          key: const Key('host-move-action-end'),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx2) => AlertDialog(
                title: const Text('End Event?'),
                content: Text(
                  'Are you sure you want to end "${event.title}"? Attendees will no longer be able to discover or participate in this event.',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(ctx2).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    key: const Key('confirm-end-event-btn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    onPressed: () => Navigator.of(ctx2).pop(true),
                    child: const Text('End Event'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              widget.controller.endEvent(event.id);
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            }
          },
          child: const Text(
            'End Event',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
        // Action 2: Transfer Ownership (Searchable member picker)
        TextButton(
          key: const Key('host-move-action-transfer'),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            EventMemberPickerSheet.show(
              context,
              controller: widget.controller,
              eventId: event.id,
              onTransferInitiated: (nomineeId, nomineeName) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Ownership transfer nomination sent to $nomineeName.',
                    ),
                  ),
                );
              },
            );
          },
          child: const Text('Transfer Ownership'),
        ),
        // Action 1: Move Event (Destination preview and confirmation)
        ElevatedButton(
          key: const Key('host-move-action-move'),
          onPressed: hasAccurateFix
              ? () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx2) => AlertDialog(
                      title: const Text('Move Event to Current Location?'),
                      content: Text(
                        'Event "${event.title}" will be relocated to:\n\n'
                        '• Destination: ${currentLoc.areaName}\n'
                        '• Latitude: ${currentLoc.latitude.toStringAsFixed(4)}\n'
                        '• Longitude: ${currentLoc.longitude.toStringAsFixed(4)}\n\n'
                        'Attendees will be notified of the updated location. Chat history and expiration are preserved.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(ctx2).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          key: const Key('confirm-move-event-btn'),
                          onPressed: () => Navigator.of(ctx2).pop(true),
                          child: const Text('Confirm Move'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    widget.controller.moveEventLocation(event.id, currentLoc);
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  }
                }
              : null,
          child: const Text('Move Event Here'),
        ),
      ],
    );
  }
}
