import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key, required this.controller});

  final AppController controller;

  void _openThreadSheet(BuildContext context, DmRequest thread) {
    final msgCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final current = controller.acceptedDmThreads
                  .where((t) => t.id == thread.id)
                  .firstOrNull;
              if (current == null) {
                return const Center(child: Text('Conversation unavailable.'));
              }
              final peerName = current.fromUserId == controller.profile.id
                  ? current.toDisplayName
                  : current.fromDisplayName;
              final peerId = current.fromUserId == controller.profile.id
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
                            controller.blockUser(peerId, label: peerName);
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
                              color: AppTheme.darkCard,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Request note: "${current.introMessage}"',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          ...current.messages.map((m) {
                            final isMe = m.senderId == controller.profile.id;
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
                                      ? AppTheme.radarTeal.withValues(
                                          alpha: 0.28,
                                        )
                                      : AppTheme.darkCard,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(m.body),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: msgCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Write a direct message...',
                              isDense: true,
                            ),
                            onSubmitted: (_) {
                              if (controller.sendDirectMessage(
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
                            if (controller.sendDirectMessage(
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

  @override
  Widget build(BuildContext context) {
    final pending = controller.pendingDmRequests;
    final accepted = controller.acceptedDmThreads;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Inbox & Requests'),
            Text(
              'No unsolicited DMs • Approve before chatting',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'MESSAGE REQUESTS (${pending.length})',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No pending message requests.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...pending.map((req) {
              final incoming = req.toUserId == controller.profile.id;
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
                                onPressed: () => controller.blockUser(
                                  req.fromUserId,
                                  label: req.fromDisplayName,
                                ),
                                icon: const Icon(Icons.block, size: 18),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '"${req.introMessage}"',
                          style: const TextStyle(color: Color(0xFFE2E8F0)),
                        ),
                        if (incoming) ...<Widget>[
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => controller
                                      .respondToDmRequest(req.id, accept: true),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Accept'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      controller.respondToDmRequest(
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
          Text(
            'ACTIVE CONVERSATIONS (${accepted.length})',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          if (accepted.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Accepted requests appear here.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...accepted.map((thread) {
              final peerName = thread.fromUserId == controller.profile.id
                  ? thread.toDisplayName
                  : thread.fromDisplayName;
              final lastText = thread.messages.isNotEmpty
                  ? thread.messages.last.body
                  : thread.introMessage;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    onTap: () => _openThreadSheet(context, thread),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.pulseMint.withValues(
                        alpha: 0.2,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: AppTheme.pulseMint,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      peerName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      lastText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
