import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';

class OnboardingStep {
  const OnboardingStep({
    required this.title,
    required this.description,
    required this.targetTabIndex,
  });

  final String title;
  final String description;
  final int targetTabIndex;
}

class OnboardingOverlay extends StatefulWidget {
  const OnboardingOverlay({
    super.key,
    required this.controller,
    required this.targetKeys,
    this.onStepChanged,
  });

  final AppController controller;
  final List<GlobalKey> targetKeys;
  final ValueChanged<int>? onStepChanged;

  static const List<OnboardingStep> steps = <OnboardingStep>[
    OnboardingStep(
      title: 'Nearby Chats',
      description: 'Connect with people physically near you in real time. Proximity verification ensures conversations stay local.',
      targetTabIndex: 0,
    ),
    OnboardingStep(
      title: 'Explore Map',
      description: 'Discover active local events and landmarks around town. Filter by category, search keywords, and see distance.',
      targetTabIndex: 1,
    ),
    OnboardingStep(
      title: 'Host Events',
      description: 'Create temporary events with custom radiuses, schedules, and optional secret codes.',
      targetTabIndex: 2,
    ),
    OnboardingStep(
      title: 'Inbox & DMs',
      description: 'Send private messages and requests. Direct messages always use your public username for safety and accountability.',
      targetTabIndex: 3,
    ),
    OnboardingStep(
      title: 'Profile & Privacy',
      description: 'Control your visibility. Turn on Ghost Mode to browse quietly, or switch between Dark and Light themes anytime.',
      targetTabIndex: 4,
    ),
  ];

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  int _currentStep = 0;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTargetRect();
    });
  }

  @override
  void didUpdateWidget(covariant OnboardingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTargetRect();
    });
  }

  void _updateTargetRect() {
    if (!mounted) return;
    if (_currentStep < 0 || _currentStep >= widget.targetKeys.length) {
      if (_targetRect != null) {
        setState(() => _targetRect = null);
      }
      return;
    }

    final key = widget.targetKeys[_currentStep];
    final context = key.currentContext;
    if (context != null) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final size = renderBox.size;
        final offset = renderBox.localToGlobal(Offset.zero);
        final newRect = Rect.fromLTWH(
          offset.dx,
          offset.dy,
          size.width,
          size.height,
        );
        if (_targetRect != newRect) {
          setState(() {
            _targetRect = newRect;
          });
        }
        return;
      }
    }

    if (_targetRect != null) {
      setState(() => _targetRect = null);
    }
  }

  void _goToStep(int step) {
    if (step < 0 || step >= OnboardingOverlay.steps.length) return;
    setState(() {
      _currentStep = step;
      _targetRect = null;
    });
    widget.onStepChanged?.call(step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTargetRect();
    });
  }

  void _nextStep() {
    if (_currentStep < OnboardingOverlay.steps.length - 1) {
      _goToStep(_currentStep + 1);
    } else {
      _finish();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  void _skip() {
    widget.controller.skipOnboarding();
  }

  void _finish() {
    widget.controller.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final step = OnboardingOverlay.steps[_currentStep];
    final mediaQuery = MediaQuery.of(context);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          // Background dimmer with spotlight cutout
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                // If user taps the spotlight target cutout, advance step
                if (_targetRect != null &&
                    _targetRect!
                        .inflate(12.0)
                        .contains(details.globalPosition)) {
                  _nextStep();
                }
                // Otherwise absorb tap (non-target tap)
              },
              child: CustomPaint(
                painter: _SpotlightPainter(
                  targetRect: _targetRect,
                  overlayColor: Colors.black.withAlpha(190),
                ),
              ),
            ),
          ),

          // Skip button at top right
          Positioned(
            top: mediaQuery.padding.top + 16,
            right: 16,
            child: TextButton.icon(
              key: const Key('onboarding-skip-btn'),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0x66000000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              onPressed: _skip,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Skip Tutorial'),
            ),
          ),

          // Tutorial Instruction Card
          Positioned(
            left: 20,
            right: 20,
            bottom: mediaQuery.padding.bottom + 90,
            child: Card(
              key: const Key('onboarding-card'),
              color: Theme.of(context).colorScheme.surface,
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Step ${_currentStep + 1} of ${OnboardingOverlay.steps.length}',
                          key: const Key('onboarding-step-indicator'),
                          style: const TextStyle(
                            color: AppTheme.pulseMint,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        // Dots indicator
                        Row(
                          children: List.generate(
                            OnboardingOverlay.steps.length,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: index == _currentStep ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: index == _currentStep
                                    ? AppTheme.pulseMint
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.title,
                      key: const Key('onboarding-step-title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.description,
                      key: const Key('onboarding-step-body'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        if (_currentStep > 0)
                          OutlinedButton(
                            key: const Key('onboarding-back-btn'),
                            onPressed: _prevStep,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                            child: const Text('Back'),
                          )
                        else
                          const SizedBox.shrink(),
                        FilledButton.icon(
                          key: const Key('onboarding-next-btn'),
                          onPressed: _nextStep,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.pulseMint,
                            foregroundColor: Colors.black87,
                          ),
                          icon: Icon(
                            _currentStep == OnboardingOverlay.steps.length - 1
                                ? Icons.check
                                : Icons.arrow_forward,
                            size: 16,
                          ),
                          label: Text(
                            _currentStep == OnboardingOverlay.steps.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.targetRect,
    required this.overlayColor,
  });

  final Rect? targetRect;
  final Color overlayColor;
  static const double padding = 8.0;
  static const double borderRadius = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (targetRect == null) {
      canvas.drawPath(backgroundPath, Paint()..color = overlayColor);
      return;
    }

    final inflatedRect = targetRect!.inflate(padding);
    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(inflatedRect, Radius.circular(borderRadius)),
      );

    final combinedPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      holePath,
    );
    canvas.drawPath(combinedPath, Paint()..color = overlayColor);

    // Subtle glowing ring around the target cutout
    final borderPaint = Paint()
      ..color = AppTheme.pulseMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(inflatedRect, Radius.circular(borderRadius)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.overlayColor != overlayColor;
  }
}
