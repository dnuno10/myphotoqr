import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/payment_service.dart';
import '../../shared/widgets/album_backdrop.dart';
import '../../shared/widgets/app_dialogs.dart';
import '../../shared/widgets/color_fill_picker.dart';
import '../../shared/ui/color_fill.dart';
import '../../shared/widgets/logo_mark.dart';
import '../../shared/widgets/saas_surface.dart';

class CreateAlbumPage extends StatefulWidget {
  const CreateAlbumPage({super.key});

  @override
  State<CreateAlbumPage> createState() => _CreateAlbumPageState();
}

class _CreateAlbumPageState extends State<CreateAlbumPage> {
  final _paymentService = PaymentService();
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _eventTypeLabelCtrl = TextEditingController();
  final _themeEmojiCtrl = TextEditingController();
  ColorFillValue _themeColorFill = const ColorFillValue.solid(
    Color(0xFF111827),
  );
  ColorFillValue _themeBackgroundFill = const ColorFillValue.solid(
    Color(0xFFFFFFFF),
  );

  String _eventType = 'wedding';
  DateTime? _eventDate;
  bool _codeProtected = false;
  bool _loading = false;

  final _eventTypes = const [
    ('wedding', 'Wedding', '💍'),
    ('birthday', 'Birthday', '🎂'),
    ('graduation', 'Graduation', '🎓'),
    ('anniversary', 'Anniversary', '❤️'),
    ('baby_shower', 'Baby shower', '🍼'),
    ('corporate', 'Corporate', '🏢'),
    ('party', 'Party', '🎉'),
    ('travel', 'Travel', '✈️'),
    ('other', 'Other', '📸'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _codeCtrl.dispose();
    _eventTypeLabelCtrl.dispose();
    _themeEmojiCtrl.dispose();
    super.dispose();
  }

  Future<void> _continueToPayment() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    try {
      final draft = AlbumCheckoutDraft(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        eventType: _eventType,
        eventDate: _eventDate,
        eventLocation: _locationCtrl.text.trim(),
        themeColor: _themeColorFill.primaryHex,
        themeBackgroundColor: _themeBackgroundFill.primaryHex,
        themeColorMode: _themeColorFill.mode.name,
        themeColorGradient: _themeColorFill.gradientJson,
        themeBackgroundMode: _themeBackgroundFill.mode.name,
        themeBackgroundGradient: _themeBackgroundFill.gradientJson,
        themeEmoji: _themeEmojiCtrl.text.trim().isEmpty
            ? null
            : _themeEmojiCtrl.text.trim(),
        eventTypeLabel: _eventTypeLabelCtrl.text.trim().isEmpty
            ? null
            : _eventTypeLabelCtrl.text.trim(),
        codeProtected: _codeProtected,
        guestCode: _codeCtrl.text.trim(),
      );

      await _paymentService.startAlbumCheckout(draft);
    } catch (e) {
      if (!mounted) return;

      await showAppMessageDialog(
        context,
        title: 'Could not start checkout',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      initialDate: _eventDate ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Color(0xFF15151A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  String _formattedDate() {
    if (_eventDate == null) return 'Select date';

    final date = _eventDate!.toLocal().toString().substring(0, 10);
    return 'Date: $date';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SaasBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _CreateAlbumCard(
                  formKey: _formKey,
                  titleCtrl: _titleCtrl,
                  descCtrl: _descCtrl,
                  locationCtrl: _locationCtrl,
                  codeCtrl: _codeCtrl,
                  eventTypeLabelCtrl: _eventTypeLabelCtrl,
                  themeEmojiCtrl: _themeEmojiCtrl,
                  themeColorFill: _themeColorFill,
                  themeBackgroundFill: _themeBackgroundFill,
                  eventTypes: _eventTypes,
                  eventType: _eventType,
                  eventDateText: _formattedDate(),
                  codeProtected: _codeProtected,
                  loading: _loading,
                  onBack: () => context.go('/'),
                  onPickDate: _pickDate,
                  onCreate: _continueToPayment,
                  onPickThemeColor: () async {
                    final result = await showColorFillPickerDialog(
                      context,
                      title: 'Theme color',
                      initialValue: _themeColorFill,
                    );
                    if (result == null || !mounted) return;
                    setState(() => _themeColorFill = result);
                  },
                  onPickBackgroundColor: () async {
                    final result = await showColorFillPickerDialog(
                      context,
                      title: 'Background',
                      initialValue: _themeBackgroundFill,
                    );
                    if (result == null || !mounted) return;
                    setState(() => _themeBackgroundFill = result);
                  },
                  onEventTypeChanged: (value) {
                    setState(() => _eventType = value ?? 'other');
                  },
                  onCodeProtectedChanged: (value) {
                    setState(() => _codeProtected = value);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateAlbumCard extends StatelessWidget {
  const _CreateAlbumCard({
    required this.formKey,
    required this.titleCtrl,
    required this.descCtrl,
    required this.locationCtrl,
    required this.codeCtrl,
    required this.eventTypeLabelCtrl,
    required this.themeEmojiCtrl,
    required this.themeColorFill,
    required this.themeBackgroundFill,
    required this.eventTypes,
    required this.eventType,
    required this.eventDateText,
    required this.codeProtected,
    required this.loading,
    required this.onBack,
    required this.onPickDate,
    required this.onPickThemeColor,
    required this.onPickBackgroundColor,
    required this.onCreate,
    required this.onEventTypeChanged,
    required this.onCodeProtectedChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController locationCtrl;
  final TextEditingController codeCtrl;
  final TextEditingController eventTypeLabelCtrl;
  final TextEditingController themeEmojiCtrl;
  final ColorFillValue themeColorFill;
  final ColorFillValue themeBackgroundFill;
  final List<(String, String, String)> eventTypes;
  final String eventType;
  final String eventDateText;
  final bool codeProtected;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onPickDate;
  final Future<void> Function() onPickThemeColor;
  final Future<void> Function() onPickBackgroundColor;
  final VoidCallback onCreate;
  final ValueChanged<String?> onEventTypeChanged;
  final ValueChanged<bool> onCodeProtectedChanged;

  @override
  Widget build(BuildContext context) {
    return SaasSurface(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Row(
                    children: [
                      const LogoMark(size: 44),
                      const Spacer(),
                      _BackButton(onPressed: onBack),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'CREATE ALBUM',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.55,
                      color: Colors.black.withOpacity(0.46),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Create event album',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      color: Color(0xFF15151A),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Fill in your album details. Payment is required before the album is created.',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.45),
                      fontSize: 14.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _FieldLabel(label: 'EVENT NAME'),
                  const SizedBox(height: 8),
                  _AppTextFormField(
                    controller: titleCtrl,
                    hintText: 'Ex. Ana & Luis Wedding',
                    enabled: !loading,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter the event name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'EVENT TYPE'),
                  const SizedBox(height: 8),
                  _AppDropdownField(
                    value: eventType,
                    enabled: !loading,
                    items: eventTypes
                        .map(
                          (event) => DropdownMenuItem(
                            value: event.$1,
                            child: Text('${event.$3}  ${event.$2}'),
                          ),
                        )
                        .toList(),
                    onChanged: onEventTypeChanged,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'CUSTOM EVENT LABEL (OPTIONAL)'),
                  const SizedBox(height: 8),
                  _AppTextFormField(
                    controller: eventTypeLabelCtrl,
                    hintText: 'Ex. Civil wedding, XV, Baptism...',
                    enabled: !loading,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'THEME EMOJI (OPTIONAL)'),
                  const SizedBox(height: 8),
                  _AppTextFormField(
                    controller: themeEmojiCtrl,
                    hintText: 'Ex. 💍 🎉 📸',
                    enabled: !loading,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'THEME COLOR'),
                  const SizedBox(height: 8),
                  _ColorFillTile(
                    value: themeColorFill,
                    enabled: !loading,
                    onEdit: onPickThemeColor,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'BACKGROUND'),
                  const SizedBox(height: 8),
                  _ColorFillTile(
                    value: themeBackgroundFill,
                    enabled: !loading,
                    onEdit: onPickBackgroundColor,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'DESCRIPTION OR MESSAGE'),
                  const SizedBox(height: 8),
                  _AppTextFormField(
                    controller: descCtrl,
                    hintText: 'Message for your guests',
                    enabled: !loading,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'EVENT LOCATION'),
                  const SizedBox(height: 8),
                  _AppTextFormField(
                    controller: locationCtrl,
                    hintText: 'Ex. Garden, venue or city',
                    enabled: !loading,
                    prefixIcon: Icons.location_on_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'EVENT DATE'),
                  const SizedBox(height: 8),
                  _DateTile(
                    eventDateText: eventDateText,
                    selected: eventDateText != 'Select date',
                    enabled: !loading,
                    onTap: onPickDate,
                  ),
                  const SizedBox(height: 16),
                  _ProtectionTile(
                    value: codeProtected,
                    enabled: !loading,
                    onChanged: onCodeProtectedChanged,
                  ),
                  if (codeProtected) ...[
                    const SizedBox(height: 16),
                    const _FieldLabel(label: 'GUEST ACCESS CODE'),
                    const SizedBox(height: 8),
                    _AppTextFormField(
                      controller: codeCtrl,
                      hintText: 'Ex. 1234 or WEDDING2026',
                      enabled: !loading,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!loading) onCreate();
                      },
                      validator: (value) {
                        if (!codeProtected) return null;
                        if (value == null || value.trim().length < 4) {
                          return 'Minimum 4 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFECECF0), width: 1),
                ),
              ),
              child: _PrimaryButton(
                text: 'Create album for \$19.99',
                icon: Icons.diamond_outlined,
                loading: loading,
                onPressed: onCreate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.55,
        color: Colors.black.withOpacity(0.46),
      ),
    );
  }
}

class _AppTextFormField extends StatelessWidget {
  const _AppTextFormField({
    required this.controller,
    required this.hintText,
    required this.enabled,
    this.prefixIcon,
    this.maxLines = 1,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final IconData? prefixIcon;
  final int maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      cursorColor: Colors.black,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E1E24),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 20, color: Colors.black.withOpacity(0.45)),
      ),
    );
  }
}

class _AppDropdownField extends StatelessWidget {
  const _AppDropdownField({
    required this.value,
    required this.enabled,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      dropdownColor: Colors.white,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E1E24),
      ),
      decoration: const InputDecoration(),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.eventDateText,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String eventDateText;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: enabled ? onTap : null,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                eventDateText,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? const Color(0xFF1E1E24)
                      : Colors.black.withOpacity(0.30),
                ),
              ),
            ),
            Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: Colors.black.withOpacity(0.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorFillTile extends StatelessWidget {
  const _ColorFillTile({
    required this.value,
    required this.enabled,
    required this.onEdit,
  });

  final ColorFillValue value;
  final bool enabled;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final preview = value.mode == ColorFillMode.solid
        ? BoxDecoration(
            color: value.primaryColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA)),
            gradient: LinearGradient(
              begin: _angleToBeginEnd(value.gradient!.angleDegrees).$1,
              end: _angleToBeginEnd(value.gradient!.angleDegrees).$2,
              colors: value.gradient!.colors,
            ),
          );

    final onTap = enabled ? () => onEdit() : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFECECF0)),
          ),
          child: Row(
            children: [
              Container(width: 44, height: 34, decoration: preview),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.mode == ColorFillMode.solid
                      ? value.primaryHex
                      : 'Gradient: ${value.gradient!.colors.map(_colorToHex).join(' → ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.palette_outlined, size: 18),
                label: const Text('Pick'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(Alignment, Alignment) _angleToBeginEnd(double angleDegrees) {
  final a = (angleDegrees % 360) * (math.pi / 180.0);
  final dx = math.cos(a);
  final dy = math.sin(a);

  final begin = Alignment(-dx, -dy);
  final end = Alignment(dx, dy);
  return (begin, end);
}

String _colorToHex(Color color) {
  final value = color.value & 0x00FFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class _ProtectionTile extends StatelessWidget {
  const _ProtectionTile({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 22,
            color: Color(0xFF15151A),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Protect with access code',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15151A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Guests must enter a code before uploading.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: Colors.white,
            activeTrackColor: Colors.black,
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: const Text('Dashboard'),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF15151A),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    this.icon,
    required this.loading,
    required this.onPressed,
  });

  final String text;
  final IconData? icon;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 10),
                  ],
                  Text(text),
                ],
              ),
      ),
    );
  }
}
