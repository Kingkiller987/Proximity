import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';

class ReportUserDialog extends StatefulWidget {
  const ReportUserDialog({
    super.key,
    required this.controller,
    required this.targetId,
    required this.targetLabel,
  });

  final AppController controller;
  final String targetId;
  final String targetLabel;

  static Future<bool?> show(
    BuildContext context, {
    required AppController controller,
    required String targetId,
    required String targetLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ReportUserDialog(
        controller: controller,
        targetId: targetId,
        targetLabel: targetLabel,
      ),
    );
  }

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  late final TextEditingController _explanationController;
  ReportReasonPreset _selectedPreset = ReportReasonPreset.spamming;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _explanationController = TextEditingController();
  }

  @override
  void dispose() {
    _explanationController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _explanationController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide an explanation for the report.';
      });
      return;
    }
    if (text.length < 5) {
      setState(() {
        _errorMessage = 'Explanation must be at least 5 characters.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final error = widget.controller.submitSafetyReport(
      targetId: widget.targetId,
      targetLabel: widget.targetLabel,
      preset: _selectedPreset,
      explanation: text,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = error;
      });
      return;
    }

    Navigator.of(context, rootNavigator: true).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Report submitted against ${widget.targetLabel}. Local demo ticket created.',
        ),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(Icons.flag_outlined, color: Colors.redAccent, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Report ${widget.targetLabel}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Prototype Demo Notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.expiryAmber.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.expiryAmber.withAlpha(80)),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppTheme.expiryAmber,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Demo Prototype: Reports are stored locally in app state for review.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.expiryAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Text(
              'Select a reason:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),

            // Radio Presets
            RadioGroup<ReportReasonPreset>(
              groupValue: _selectedPreset,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedPreset = val;
                    _errorMessage = null;
                  });
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ReportReasonPreset.values.map((preset) {
                  final keyName = 'report-preset-${preset.name.toLowerCase()}';
                  return RadioListTile<ReportReasonPreset>(
                    key: Key(keyName),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(preset.displayName),
                    value: preset,
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              'Explanation (required for all reasons):',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('report-explanation-field'),
              controller: _explanationController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'Describe the behavior (minimum 5 characters)...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _errorMessage!,
                  key: const Key('report-error-text'),
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('report-cancel-btn'),
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context, rootNavigator: true).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('report-submit-btn'),
          onPressed: _isSubmitting ? null : _handleSubmit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 16),
          label: const Text('Submit Report'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
