import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';

class EventMemberPickerSheet extends StatefulWidget {
  const EventMemberPickerSheet({
    super.key,
    required this.controller,
    required this.eventId,
    required this.onTransferInitiated,
  });

  final AppController controller;
  final String eventId;
  final void Function(String nomineeUserId, String nomineeDisplayName)
  onTransferInitiated;

  static Future<void> show(
    BuildContext context, {
    required AppController controller,
    required String eventId,
    required void Function(String nomineeUserId, String nomineeDisplayName)
    onTransferInitiated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.78,
        child: EventMemberPickerSheet(
          controller: controller,
          eventId: eventId,
          onTransferInitiated: onTransferInitiated,
        ),
      ),
    );
  }

  @override
  State<EventMemberPickerSheet> createState() => _EventMemberPickerSheetState();
}

class _EventMemberPickerSheetState extends State<EventMemberPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSelectMember(
    BuildContext context,
    String userId,
    PublicIdentityProjection projection,
    ProximityEvent event,
  ) async {
    // 1. Confirm with the host
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirm Ownership Transfer'),
        content: Text(
          'Are you sure you want to nominate ${projection.displayName} as the new host of "${event.title}"?\n\nThe nominee must independently accept and satisfy venue location checks.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-nomination-btn'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Confirm Transfer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 2. Revalidate eligibility immediately before transfer
    final currentEvent = widget.controller.eventById(widget.eventId);
    if (currentEvent == null || currentEvent.isEnded) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Transfer failed: Event is no longer active or was ended.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final latestParticipants = widget.controller.eventParticipantIds(
      widget.eventId,
    );
    if (!latestParticipants.contains(userId)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transfer failed: ${projection.displayName} has left the event.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {});
      return;
    }

    if (widget.controller.blockedUserIds.contains(userId)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot transfer event ownership to a blocked attendee.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 3. Initiate transfer
    final err = widget.controller.initiateEventHostTransfer(
      widget.eventId,
      userId,
    );
    if (err != null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
      );
    } else {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close sheet
      widget.onTransferInitiated(userId, projection.displayName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.controller.eventById(widget.eventId);
    if (event == null) {
      return const Center(child: Text('Event not found.'));
    }

    final allParticipants = widget.controller
        .eventParticipantIds(event.id)
        .where((id) => id != widget.controller.profile.id)
        .where((id) => !widget.controller.blockedUserIds.contains(id))
        .toList();

    final query = _searchQuery.trim().toLowerCase();
    final filtered = allParticipants.where((userId) {
      if (query.isEmpty) return true;
      final proj = widget.controller.publicProjectionForUser(userId);
      return proj.displayName.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header with visible close X button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Transfer Ownership',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                key: const Key('close-member-picker-btn'),
                icon: const Icon(Icons.close),
                tooltip: 'Close without transferring',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            'Select an attendee to nominate as the new host of "${event.title}".',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            key: const Key('member-picker-search-field'),
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search attendees by name...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),

          // Attendee List / Empty States
          Expanded(
            child: allParticipants.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No other attendees have joined this event yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No attendees match "$_searchQuery".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final userId = filtered[idx];
                      final projection = widget.controller
                          .publicProjectionForUser(userId);
                      final hasAvatar =
                          !projection.isAnonymous &&
                          projection.avatarBytes != null &&
                          projection.avatarBytes!.isNotEmpty;

                      return ListTile(
                        key: Key('member-picker-item-$userId'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.pulseMint.withAlpha(35),
                          backgroundImage: hasAvatar
                              ? MemoryImage(projection.avatarBytes!)
                              : null,
                          child: !hasAvatar
                              ? Icon(
                                  projection.isAnonymous
                                      ? Icons.person
                                      : Icons.person_outline,
                                  size: 18,
                                  color: projection.isAnonymous
                                      ? Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                      : AppTheme.pulseMint,
                                )
                              : null,
                        ),
                        title: Text(
                          projection.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          projection.isAnonymous
                              ? 'Anonymous Attendee'
                              : 'Attendee',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        trailing: FilledButton.tonal(
                          key: Key('select-nominee-btn-$userId'),
                          onPressed: () => _handleSelectMember(
                            context,
                            userId,
                            projection,
                            event,
                          ),
                          child: const Text('Select'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
