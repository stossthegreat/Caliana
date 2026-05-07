import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'caliana_avatar.dart';

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
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
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
              // Action row — fridge stays at the left edge, camera at
              // the right edge. The voice pill sits in the middle but
              // only takes ~half the row width — flanked by Spacers
              // instead of Expanded so it never eats the whole bar.
              // Slight upward offset on the pill so it reads as
              // elevated above the side icons ("press me").
              SizedBox(
                height: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _sideAction(
                      icon: Icons.kitchen_rounded,
                      onTap: widget.onFridge,
                    ),
                    const Spacer(),
                    Transform.translate(
                      offset: const Offset(0, -6),
                      child: _voicePill(),
                    ),
                    const Spacer(),
                    _sideAction(
                      icon: Icons.camera_alt_rounded,
                      onTap: widget.onCamera,
                    ),
                  ],
                ),
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

  /// The voice pill — centre hero. Brand-blue, rounded-rectangle (not a
  /// circle), pulsing glow when idle, scales + intense glow when
  /// recording. Mic icon centred. No text. Smaller than the original
  /// 64pt monster so the dock leaves room for the chat above.
  Widget _voicePill() {
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
          // Stronger idle pulse so the FAB always reads "press me".
          final scale = widget.isRecording
              ? 1.07
              : 1.0 + (t * 0.045);
          final glow =
              widget.isRecording ? 0.65 : 0.32 + (t * 0.32);
          return Transform.scale(
            scale: scale,
            child: Container(
              height: 56,
              width: 172,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF5A8AFF),
                    Color(0xFF2F6BFF),
                    Color(0xFF1F4FE0),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: glow),
                    blurRadius: 28,
                    spreadRadius: 2.5,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: showSend
                    ? const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 28)
                    : widget.isRecording
                        ? const Icon(Icons.stop_rounded,
                            color: Colors.white, size: 28)
                        : const _PressMeFace(),
              ),
            ),
          );
        },
      ),
    );
  }

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
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5A8AFF), Color(0xFF2F6BFF)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Caliana's face inside the mic FAB. Larger than the chat avatar
/// (the FAB is the hero of the dock), no extra ring (the pill itself
/// frames her), with a tiny mic glyph in the bottom-right so the
/// affordance is unmistakable: "tap her, talk to her".
class _PressMeFace extends StatelessWidget {
  const _PressMeFace();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: Image.asset(
              'assets/caliana.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.55),
              width: 44,
              height: 44,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic_rounded,
                size: 11,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
