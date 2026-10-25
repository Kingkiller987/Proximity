import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_image_widgets.dart';

enum _InboxFilter { active, archived }

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  _InboxFilter _filter = _InboxFilter.active;

  void _openThreadSheet(BuildContext context, DmRequest thread) {
    final msgCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final current = widget.controller.acceptedDmThreads
                  .where((t) => t.id == thread.id)
                  .firstOrNull;
              if (current == null) {
                return const Center(child: Text('Conversation unavailable.'));
              }
              final peerName =
                  current.fromUserId == widget.controller.profile.id
                  ? current.toDisplayName
                  : current.fromDisplayName;
              final peerId = current.fromUserId == widget.controller.profile.id
                  ? current.toUserId
                  : current.fromUserId;

              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            peerName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            widget.controller.blockUser(
                              peerId,
                              label: peerName,
                            );
                            Navigator.of(ctx).pop();
                          },
                          icon: const Icon(Icons.block, size: 16),
                          label: const Text('Block'),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Request note: "${current.introMessage}"',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...current.messages.map((m) {
                            final isMe =
                                m.senderId == widget.controller.profile.id;
                            final sentTime = formatMessageTimestamp(
                              m.createdAt,
                              widget.controller.now,
                            );
                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppTheme.radarTeal.withAlpha(70)
                                      : Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    if (m.body.isNotEmpty) Text(m.body),
                                    if (m.attachment != null)
                                      ChatImageBubble(
                                        controller: widget.controller,
                                        attachment: m.attachment!,
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      sentTime,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Share EXIF-stripped photo',
                          onPressed: () {
                            widget.controller.sendDirectMessage(
                              current.id,
                              msgCtrl.text,
                              rawImageBytes: buildSampleCameraJpegBytes(),
                            );
                            msgCtrl.clear();
                          },
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 20,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: msgCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Write a direct message...',
                              isDense: true,
                            ),
                            onSubmitted: (_) {
                              if (widget.controller.sendDirectMessage(
                                current.id,
                                msgCtrl.text,
                              )) {
                                msgCtrl.clear();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () {
                            if (widget.controller.sendDirectMessage(
                              current.id,
                              msgCtrl.text,
                            )) {
                              msgCtrl.clear();
                            }
                          },
                          icon: const Icon(Icons.send_rounded, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, DmRequest thread) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Conversation Locally?'),
          content: const Text(
            'This will delete the conversation for you. The other participant will still keep their message history.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.controller.deleteConversationLocally(thread.id);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pending = widget.controller.pendingDmRequests;
        final accepted = widget.controller.acceptedDmThreads;
        final visibleThreads = _filter == _InboxFilter.active
            ? accepted.where((t) => !t.isArchived).toList()
            : accepted.where((t) => t.isArchived).toList();

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Inbox & Requests'),
                Text(
                  'No unsolicited DMs • Approve before chatting',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // Filter Toggle: [Active Messages | Archived]
              Row(
                children: <Widget>[
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('inbox-filter-active'),
                      label: const Center(
                        child: Text(
                          'Active Messages',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selected: _filter == _InboxFilter.active,
                      onSelected: (_) =>
                          setState(() => _filter = _InboxFilter.active),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('inbox-filter-archived'),
                      label: const Center(
                        child: Text(
                          'Archived',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selected: _filter == _InboxFilter.archived,
                      onSelected: (_) =>
                          setState(() => _filter = _InboxFilter.archived),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_filter == _InboxFilter.active) ...<Widget>[
                Text(
                  'MESSAGE REQUESTS (${pending.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (pending.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No pending message requests.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...pending.map((req) {
                    final incoming =
                        req.toUserId == widget.controller.profile.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.mark_chat_unread_outlined,
                                    size: 16,
                                    color: AppTheme.pulseMint,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      incoming
                                          ? 'From ${req.fromDisplayName}'
                                          : 'Sent to ${req.toDisplayName}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (incoming)
                                    IconButton(
                                      tooltip: 'Block sender',
                                      onPressed: () =>
                                          widget.controller.blockUser(
                                            req.fromUserId,
                                            label: req.fromDisplayName,
                                          ),
                                      icon: const Icon(Icons.block, size: 18),
                                    ),
                                ],
                              ),
                              if (incoming &&
                                  req.fromRealUsername != null) ...<Widget>[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Sender real profile: @${req.fromRealUsername}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.pulseMint,
                                        ),
                                      ),
                                      if (req.fromRealBio != null &&
                                          req.fromRealBio!.isNotEmpty)
                                        Text(
                                          req.fromRealBio!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                '"${req.introMessage}"',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                              if (incoming) ...<Widget>[
                                const SizedBox(height: 12),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () => widget.controller
                                            .respondToDmRequest(
                                              req.id,
                                              accept: true,
                                            ),
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('Accept'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => widget.controller
                                            .respondToDmRequest(
                                              req.id,
                                              accept: false,
                                            ),
                                        icon: const Icon(Icons.close, size: 16),
                                        label: const Text('Decline'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 20),
              ],
              Text(
                _filter == _InboxFilter.active
                    ? 'ACTIVE CONVERSATIONS (${visibleThreads.length})'
                    : 'ARCHIVED CONVERSATIONS (${visibleThreads.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (visibleThreads.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _filter == _InboxFilter.active
                          ? 'No active conversations. Accepted requests appear here.'
                          : 'No archived conversations.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ...visibleThreads.map((thread) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SwipeableConversationTile(
                      key: Key('inbox-thread-tile-${thread.id}'),
                      thread: thread,
                      currentUserId: widget.controller.profile.id,
                      onTap: () => _openThreadSheet(context, thread),
                      onPin: () => widget.controller.pinConversation(
                        thread.id,
                        !thread.isPinned,
                      ),
                      onArchive: () => widget.controller.archiveConversation(
                        thread.id,
                        !thread.isArchived,
                      ),
                      onDelete: () => _confirmDelete(context, thread),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _SwipeableConversationTile extends StatefulWidget {
  const _SwipeableConversationTile({
    super.key,
    required this.thread,
    required this.currentUserId,
    required this.onTap,
    required this.onPin,
    required this.onArchive,
    required this.onDelete,
  });

  final DmRequest thread;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  State<_SwipeableConversationTile> createState() =>
      _SwipeableConversationTileState();
}

class _SwipeableConversationTileState
    extends State<_SwipeableConversationTile> {
  double _dragOffset = 0.0;
  static const double _maxReveal = 180.0;

  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    final peerName = thread.fromUserId == widget.currentUserId
        ? thread.toDisplayName
        : thread.fromDisplayName;
    final lastText = thread.messages.isNotEmpty
        ? thread.messages.last.body
        : thread.introMessage;

    return Stack(
      children: <Widget>[
        // Background Action Rail
        Positioned.fill(
          child: Container(
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  key: Key('inbox-action-pin-${thread.id}'),
                  tooltip: thread.isPinned ? 'Unpin' : 'Pin',
                  icon: Icon(
                    thread.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: AppTheme.pulseMint,
                  ),
                  onPressed: () {
                    setState(() => _dragOffset = 0.0);
                    widget.onPin();
                  },
                ),
                IconButton(
                  key: Key('inbox-action-archive-${thread.id}'),
                  tooltip: thread.isArchived ? 'Unarchive' : 'Archive',
                  icon: Icon(
                    thread.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    color: Colors.lightBlueAccent,
                  ),
                  onPressed: () {
                    setState(() => _dragOffset = 0.0);
                    widget.onArchive();
                  },
                ),
                IconButton(
                  key: Key('inbox-action-delete-${thread.id}'),
                  tooltip: 'Delete Locally',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () {
                    setState(() => _dragOffset = 0.0);
                    widget.onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
        // Foreground Tile with gesture detection
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragOffset = (_dragOffset + details.primaryDelta!).clamp(
                -_maxReveal,
                0.0,
              );
            });
          },
          onHorizontalDragEnd: (details) {
            setState(() {
              if (_dragOffset < -60.0) {
                _dragOffset = -_maxReveal;
              } else {
                _dragOffset = 0.0;
              }
            });
          },
          onTap: () {
            if (_dragOffset < 0.0) {
              setState(() => _dragOffset = 0.0);
            } else {
              widget.onTap();
            }
          },
          child: Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.pulseMint.withAlpha(40),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: AppTheme.pulseMint,
                    size: 18,
                  ),
                ),
                title: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        peerName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (thread.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.push_pin,
                          key: Key('inbox-pinned-icon-${thread.id}'),
                          size: 14,
                          color: AppTheme.pulseMint,
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  lastText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
