import 'package:flutter/material.dart';

import '../ui/color_fill.dart';

Future<ColorFillValue?> showColorFillPickerDialog(
  BuildContext context, {
  required String title,
  required ColorFillValue initialValue,
}) {
  return showDialog<ColorFillValue>(
    context: context,
    builder: (context) =>
        _ColorFillPickerDialog(title: title, initialValue: initialValue),
  );
}

class _ColorFillPickerDialog extends StatefulWidget {
  const _ColorFillPickerDialog({
    required this.title,
    required this.initialValue,
  });

  final String title;
  final ColorFillValue initialValue;

  @override
  State<_ColorFillPickerDialog> createState() => _ColorFillPickerDialogState();
}

class _ColorFillPickerDialogState extends State<_ColorFillPickerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  late HSVColor _solidHsv;

  late HSVColor _gradientHsvA;
  late HSVColor _gradientHsvB;
  int _activeStop = 0;
  double _angle = 90;

  final _hexCtrl = TextEditingController();
  final _hexA = TextEditingController();
  final _hexB = TextEditingController();

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    final init = widget.initialValue;
    if (init.mode == ColorFillMode.gradient) {
      _tabController.index = 1;
    }

    _solidHsv = HSVColor.fromColor(init.primaryColor);

    final grad = init.mode == ColorFillMode.gradient
        ? init.gradient!
        : LinearGradientSpec(
            angleDegrees: 90,
            colors: [init.primaryColor, init.primaryColor],
          );

    _angle = grad.angleDegrees;
    _gradientHsvA = HSVColor.fromColor(grad.colors[0]);
    _gradientHsvB = HSVColor.fromColor(grad.colors[1]);

    _syncHex();
    _tabController.addListener(_syncHex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hexCtrl.dispose();
    _hexA.dispose();
    _hexB.dispose();
    super.dispose();
  }

  void _syncHex() {
    _hexCtrl.text = colorToHex(_solidHsv.toColor());
    _hexA.text = colorToHex(_gradientHsvA.toColor());
    _hexB.text = colorToHex(_gradientHsvB.toColor());
  }

  void _setSolidFromHex(String value) {
    final color = hexToColor(value);
    if (color == null) return;
    setState(() => _solidHsv = HSVColor.fromColor(color));
    _syncHex();
  }

  void _setGradientStopFromHex(int stop, String value) {
    final color = hexToColor(value);
    if (color == null) return;
    setState(() {
      if (stop == 0) {
        _gradientHsvA = HSVColor.fromColor(color);
      } else {
        _gradientHsvB = HSVColor.fromColor(color);
      }
    });
    _syncHex();
  }

  ColorFillValue _value() {
    if (_tabController.index == 0) {
      return ColorFillValue.solid(_solidHsv.toColor());
    }

    return ColorFillValue.gradient(
      LinearGradientSpec(
        angleDegrees: _angle,
        colors: [_gradientHsvA.toColor(), _gradientHsvB.toColor()],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = _value();
    final isGradient = _tabController.index == 1;

    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Solid color'),
                Tab(text: 'Gradient'),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 320,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _SolidPicker(
                    hsv: _solidHsv,
                    onChanged: (next) {
                      setState(() => _solidHsv = next);
                      _syncHex();
                    },
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Keep the gradient tab within the fixed 320px height by
                      // shrinking the SV square. The rest can scroll if needed.
                      const reserved =
                          252.0; // preview + chips + paddings + angle + sliders
                      final svHeight = (constraints.maxHeight - reserved).clamp(
                        64.0,
                        220.0,
                      );

                      return _GradientPicker(
                        angle: _angle,
                        activeStop: _activeStop,
                        a: _gradientHsvA,
                        b: _gradientHsvB,
                        svHeight: svHeight,
                        onAngleChanged: (v) => setState(() => _angle = v),
                        onActiveStopChanged: (v) =>
                            setState(() => _activeStop = v),
                        onChanged: (stop, next) {
                          setState(() {
                            if (stop == 0) {
                              _gradientHsvA = next;
                            } else {
                              _gradientHsvB = next;
                            }
                          });
                          _syncHex();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ColorDot(color: value.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: isGradient
                        ? (_activeStop == 0 ? _hexA : _hexB)
                        : _hexCtrl,
                    decoration: InputDecoration(
                      labelText: isGradient
                          ? (_activeStop == 0 ? 'Color A' : 'Color B')
                          : 'Hex',
                    ),
                    onChanged: (v) {
                      if (isGradient) {
                        _setGradientStopFromHex(_activeStop, v);
                      } else {
                        _setSolidFromHex(v);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_value()),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SolidPicker extends StatefulWidget {
  const _SolidPicker({
    required this.hsv,
    required this.onChanged,
    this.svHeight = 220,
  });

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;
  final double svHeight;

  @override
  State<_SolidPicker> createState() => _SolidPickerState();
}

class _SolidPickerState extends State<_SolidPicker> {
  void _updateHue(double hue) {
    widget.onChanged(widget.hsv.withHue(hue.clamp(0, 360)));
  }

  void _updateSV(Offset localPosition, Size size) {
    final s = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final v = (1 - (localPosition.dy / size.height)).clamp(0.0, 1.0);
    widget.onChanged(widget.hsv.withSaturation(s).withValue(v));
  }

  @override
  Widget build(BuildContext context) {
    final hsv = widget.hsv;
    final hueColor = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();

    return Column(
      children: [
        // SV square.
        SizedBox(
          height: widget.svHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, widget.svHeight);
              final handle = Offset(
                hsv.saturation * size.width,
                (1 - hsv.value) * size.height,
              );

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (d) => _updateSV(d.localPosition, size),
                onPanUpdate: (d) => _updateSV(d.localPosition, size),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [Colors.white, hueColor],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: handle.dx - 10,
                      top: handle.dy - 10,
                      child: _Handle(color: hsv.toColor()),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        _HueSlider(hue: hsv.hue, onChanged: _updateHue),
      ],
    );
  }
}

class _GradientPicker extends StatelessWidget {
  const _GradientPicker({
    required this.angle,
    required this.activeStop,
    required this.a,
    required this.b,
    required this.svHeight,
    required this.onAngleChanged,
    required this.onActiveStopChanged,
    required this.onChanged,
  });

  final double angle;
  final int activeStop;
  final HSVColor a;
  final HSVColor b;
  final double svHeight;
  final ValueChanged<double> onAngleChanged;
  final ValueChanged<int> onActiveStopChanged;
  final void Function(int stop, HSVColor hsv) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = [a.toColor(), b.toColor()];
    final beginEnd = angleToBeginEnd(angle);

    final hsv = activeStop == 0 ? a : b;

    return SingleChildScrollView(
      // Avoid overflow on small viewports / large text scale.
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: beginEnd.$1,
                end: beginEnd.$2,
                colors: colors,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StopChip(
                  label: 'A',
                  color: colors[0],
                  selected: activeStop == 0,
                  onTap: () => onActiveStopChanged(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StopChip(
                  label: 'B',
                  color: colors[1],
                  selected: activeStop == 1,
                  onTap: () => onActiveStopChanged(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SolidPicker(
            hsv: hsv,
            svHeight: svHeight,
            onChanged: (next) => onChanged(activeStop, next),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Angle'),
              Expanded(
                child: Slider(
                  value: angle.clamp(0, 360),
                  min: 0,
                  max: 360,
                  divisions: 36,
                  label: '${angle.round()}°',
                  onChanged: onAngleChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Container(
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ],
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackShape: const _NoTrack(),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: hue.clamp(0, 360),
            min: 0,
            max: 360,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _NoTrack extends SliderTrackShape {
  const _NoTrack();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 2;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    bool isDiscrete = false,
    bool isEnabled = false,
    Offset? secondaryOffset,
  }) {}
}

class _Handle extends StatelessWidget {
  const _Handle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.18)),
        boxShadow: const [BoxShadow(color: Color(0x20000000), blurRadius: 8)],
      ),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.black.withOpacity(0.12)),
      ),
    );
  }
}

class _StopChip extends StatelessWidget {
  const _StopChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.black.withOpacity(0.05)
              : const Color(0xFFF8F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.black : const Color(0xFFECECF0),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            _ColorDot(color: color),
            const SizedBox(width: 10),
            Text(
              'Color $label',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
