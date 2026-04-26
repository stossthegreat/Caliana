import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Bottom input dock — neutral surface so Caliana stays the hero.
///
/// Default state: snap-fridge | wide voice PILL (with mic in a chat-bubble)
/// | snap-food. The text input is collapsed behind a tiny keyboard toggle
/// in the top-right of the dock to free vertical real-estate for the hero.
///
/// Tapping the toggle slides the text pill in above the action row; while
/// it's open, the centre pill morphs from "Talk to Caliana" into a Send
/// button when the user has typed something.
class InputDock extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  final VoidCallback onFridge;
  final VoidCallback onMicTap;
  final VoidCallback onMicHoldStart;
  final VoidCallback onMicHoldEnd;
  final bool isRecording;
  final bool sendEnabled;

  const InputDock({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onCamera,
    required this.onFridge,
    required this.onMicTap,
    required this.onMicHoldStart,
    required this.onMicHoldEnd,
    this.isRecording = false,
    this.sendEnabled = true,
  });

  @override
  State<InputDock> createState() => _InputDockState();
}

class _InputDockState extends State<InputDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _hasText = false;
  bool _typing = false;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  void _toggleTyping() {
    HapticFeedback.lightImpact();
    setState(() => _typing = !_typing);
    if (_typing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focus.requestFocus();
      });
    } else {
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    widget.controller.removeListener(_onTextChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FC),
        border: Border(
          top: BorderSide(color: Color(0x14000000), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tiny "type instead" toggle, right-aligned.
              Align(
                alignment: Alignment.centerRight,
                child: _typeToggle(),
              ),
              // Optional collapsible text input.
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: _typing
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: _textField(),
                      )
                    : const SizedBox.shrink(),
              ),
              // Action row — three circular blue buttons. The middle one
              // is the mic FAB (bigger + pulsing). No labels — every
              // user knows what a mic, fridge, and camera icon mean.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _sideAction(
                    icon: Icons.kitchen_rounded,
                    onTap: widget.onFridge,
                  ),
                  const SizedBox(width: 28),
                  _micFab(),
                  const SizedBox(width: 28),
                  _sideAction(
                    icon: Icons.camera_alt_rounded,
                    onTap: widget.onCamera,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tiny pill-shaped toggle that opens/closes the text input.
  Widget _typeToggle() {
    return GestureDetector(
      onTap: _toggleTyping,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _typing
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _typing
                ? AppColors.primary.withValues(alpha: 0.30)
                : AppColors.surfaceBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _typing
                  ? Icons.keyboard_hide_rounded
                  : Icons.keyboard_alt_outlined,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 5),
            Text(
              _typing ? 'Hide' : 'Type',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Tell Caliana what you ate…',
          hintStyle: TextStyle(
            color: AppColors.textHint,
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        ),
        minLines: 1,
        maxLines: 4,
        onSubmitted: (_) {
          if (widget.sendEnabled) widget.onSend();
        },
      ),
    );
  }

  /// The hero mic FAB. Solid brand-blue circle, pulsing glow when idle,
  /// stronger glow + slight scale when recording. Mic icon (or stop /
  /// arrow-up for send) only — no text. Tap to start/stop a voice turn,
  /// long-press to hold-to-talk. Morphs into Send when typing.
  Widget _micFab() {
    final showSend = _typing && _hasText;
    return GestureDetector(
      onTap: () {
        if (showSend) {
          if (!widget.sendEnabled) return;
          HapticFeedback.mediumImpact();
          widget.onSend();
        } else {
          HapticFeedback.mediumImpact();
          widget.onMicTap();
        }
      },
      onLongPressStart: showSend
          ? null
          : (_) {
              HapticFeedback.mediumImpact();
              widget.onMicHoldStart();
            },
      onLongPressEnd: showSend
          ? null
          : (_) {
              HapticFeedback.lightImpact();
              widget.onMicHoldEnd();
            },
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, _) {
          final t = _pulseCtrl.value;
          final scale = widget.isRecording ? 1.06 : 1.0 + (t * 0.025);
          final glow = widget.isRecording ? 0.55 : 0.22 + (t * 0.22);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5A8AFF), Color(0xFF2F6BFF), Color(0xFF1F4FE0)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: glow),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                showSend
                    ? Icons.arrow_upward_rounded
                    : (widget.isRecording
                        ? Icons.stop_rounded
                        : Icons.mic_rounded),
                color: Colors.white,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Side action — circular blue gradient button matching the mic FAB,
  /// just smaller. No label — the icon is the affordance.
  Widget _sideAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5A8AFF), Color(0xFF2F6BFF)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
