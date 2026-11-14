import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Content-first audio progress & parameter slider with expanding hover thumb.
class AppSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final Color? inactiveColor;
  final double trackHeight;
  final String? semanticLabel;

  const AppSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.inactiveColor,
    this.trackHeight = 3.5,
    this.semanticLabel,
  });

  @override
  State<AppSlider> createState() => _AppSliderState();
}

class _AppSliderState extends State<AppSlider> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeColor = widget.activeColor ?? tokens.accent;
    final inactiveColor = widget.inactiveColor ?? const Color(0x33FFFFFF);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: widget.trackHeight,
          activeTrackColor: activeColor,
          inactiveTrackColor: inactiveColor,
          thumbColor: _isHovered ? Colors.white : activeColor,
          overlayColor: activeColor.withValues(alpha: 0.15),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: _isHovered ? 6.0 : 4.5,
            elevation: 2.0,
          ),
          trackShape: const RectangularSliderTrackShape(),
        ),
        child: Slider(
          value: widget.value.clamp(widget.min, widget.max),
          min: widget.min,
          max: widget.max,
          onChanged: widget.onChanged,
          onChangeStart: widget.onChangeStart,
          onChangeEnd: widget.onChangeEnd,
          semanticFormatterCallback: (val) =>
              widget.semanticLabel ?? '${(val * 100).toInt()}%',
        ),
      ),
    );
  }
}
