import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/plans.dart';
import '../../services/payment_service.dart';
import '../../shared/ui/color_fill.dart';
import '../../shared/ui/safe_user_messages.dart';
import '../../shared/widgets/app_dialogs.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/color_fill_picker.dart';

const _ink = Color(0xFF15151A);
const _muted = Color(0xFF6A6A74);
const _line = Color(0xFFE5E7EB);
const _pink = Color(0xFFEC4899);
const _pinkStrong = Color(0xFFE11D48);
const _pinkTint = Color(0xFFFDF2F8);

class CreateAlbumPage extends StatefulWidget {
  const CreateAlbumPage({super.key, this.initialEventType, this.initialPlan});

  final String? initialEventType;
  final String? initialPlan;

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
    Color(0xFFEC4899),
  );
  ColorFillValue _themeBackgroundFill = const ColorFillValue.solid(
    Color(0xFFFAFAFB),
  );

  late String _eventType;
  late AlbumPlan _plan;
  DateTime? _eventDate;
  bool _codeProtected = false;
  bool _guestUploads = true;
  bool _moderation = false;
  bool _loading = false;
  bool _archive = false;

  static const _eventTypes = [
    ('wedding', 'Wedding', Icons.favorite_outline_rounded, Color(0xFF3B5BDB)),
    ('birthday', 'Birthday', Icons.card_giftcard_rounded, Color(0xFFE11D48)),
    (
      'baby_shower',
      'Baby Shower',
      Icons.child_friendly_outlined,
      Color(0xFF8B5CF6),
    ),
    (
      'anniversary',
      'Anniversary',
      Icons.favorite_border_rounded,
      Color(0xFFE11D48),
    ),
    ('graduation', 'Graduation', Icons.school_rounded, Color(0xFF2563EB)),
    (
      'corporate',
      'Corporate Event',
      Icons.business_center_rounded,
      Color(0xFF92400E),
    ),
    ('party', 'Party', Icons.celebration_outlined, Color(0xFFF59E0B)),
    ('travel', 'Travel', Icons.flight_takeoff_outlined, Color(0xFF0284C7)),
    ('other', 'Other', Icons.photo_camera_outlined, Color(0xFF52525B)),
  ];

  @override
  void initState() {
    super.initState();
    _eventType = _eventTypes.any((e) => e.$1 == widget.initialEventType)
        ? widget.initialEventType!
        : 'wedding';
    _plan = Plans.byId(widget.initialPlan ?? 'premium').plan;
  }

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
        plan: _plan,
        guestUploadsEnabled: _guestUploads,
        moderationEnabled: _moderation && _plan == AlbumPlan.premium,
        archiveAddOn: _archive,
      );

      await _paymentService.startAlbumCheckout(draft);
    } catch (e) {
      if (!mounted) return;

      await showAppMessageDialog(
        context,
        title: 'Could not start checkout',
        message: e is PaymentUserMessageException
            ? e.message
            : safeUserErrorMessage(
                e,
                fallback:
                    'We could not start checkout. Please try again in a moment.',
              ),
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
              onSurface: _ink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _pickThemeColor() async {
    final result = await showColorFillPickerDialog(
      context,
      title: 'Theme color',
      initialValue: _themeColorFill,
    );
    if (result == null || !mounted) return;
    setState(() => _themeColorFill = result);
  }

  Future<void> _pickBackground() async {
    final result = await showColorFillPickerDialog(
      context,
      title: 'Background',
      initialValue: _themeBackgroundFill,
    );
    if (result == null || !mounted) return;
    setState(() => _themeBackgroundFill = result);
  }

  void _setModeration(bool value) {
    if (_plan != AlbumPlan.premium) {
      setState(() => _plan = AlbumPlan.premium);
    }
    setState(() => _moderation = value);
  }

  void _setPlan(AlbumPlan plan) {
    setState(() {
      _plan = plan;
      if (plan != AlbumPlan.premium) _moderation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      current: ShellSection.create,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final gutter = constraints.maxWidth < 600 ? 16.0 : 32.0;

          final formSections = Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _detailsSection(),
                const SizedBox(height: 20),
                _styleSection(),
                const SizedBox(height: 20),
                _privacySection(),
              ],
            ),
          );

          final summary = _SummaryPanel(
            plan: _plan,
            archive: _archive,
            loading: _loading,
            onPlanChanged: _setPlan,
            onArchiveChanged: (v) => setState(() => _archive = v),
          );

          final payBar = _PayBar(
            plan: _plan,
            archive: _archive,
            loading: _loading,
            onCreate: _continueToPayment,
          );

          if (wide) {
            return Padding(
              padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: 24),
                      child: formSections,
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 380,
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: summary,
                          ),
                        ),
                        payBar,
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: 20),
                      formSections,
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFEDEDF1))),
                ),
                child: SafeArea(top: false, child: payBar),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          icon: Icons.event_outlined,
          title: 'Choose an event type',
          subtitle: 'Start with a template designed for your special occasion.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final e in _eventTypes)
                _EventTypeTile(
                  label: e.$2,
                  icon: e.$3,
                  color: e.$4,
                  selected: _eventType == e.$1,
                  onTap: _loading
                      ? null
                      : () => setState(() => _eventType = e.$1),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionCard(
          icon: Icons.description_outlined,
          title: 'Event details',
          subtitle: 'Basic information about your event.',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth >= 520;
              final width = twoCols
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _Field(
                      label: 'Event name',
                      required: true,
                      child: _textField(
                        controller: _titleCtrl,
                        hint: 'Ex. Ana & Luis Wedding',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter the event name'
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _Field(
                      label: 'Event date',
                      child: _DateTile(
                        date: _eventDate,
                        enabled: !_loading,
                        onTap: _pickDate,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _Field(
                      label: 'Location',
                      optional: true,
                      child: _textField(
                        controller: _locationCtrl,
                        hint: 'Ex. Garden, venue or city',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _Field(
                      label: 'Custom event label',
                      optional: true,
                      child: _textField(
                        controller: _eventTypeLabelCtrl,
                        hint: 'Ex. Civil wedding, XV, Baptism...',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _Field(
                      label: 'Description or message',
                      optional: true,
                      child: _textField(
                        controller: _descCtrl,
                        hint: 'Share a message with your guests...',
                        maxLines: 4,
                        action: TextInputAction.newline,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _styleSection() {
    return _SectionCard(
      icon: Icons.palette_outlined,
      title: 'Visual style',
      subtitle: "Make your album match your event's vibe.",
      child: LayoutBuilder(
        builder: (context, constraints) {
          final threeCols = constraints.maxWidth >= 640;
          final width = threeCols
              ? (constraints.maxWidth - 32) / 3
              : constraints.maxWidth;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: width,
                child: _Field(
                  label: 'Theme emoji',
                  optional: true,
                  child: _textField(
                    controller: _themeEmojiCtrl,
                    hint: '💍 🎉 📸',
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: _Field(
                  label: 'Theme color',
                  child: _ColorTile(
                    value: _themeColorFill,
                    enabled: !_loading,
                    onTap: _pickThemeColor,
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: _Field(
                  label: 'Background color',
                  child: _ColorTile(
                    value: _themeBackgroundFill,
                    enabled: !_loading,
                    onTap: _pickBackground,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _privacySection() {
    return _SectionCard(
      icon: Icons.lock_outline_rounded,
      title: 'Privacy & sharing',
      subtitle: 'Control who can view and add content to your album.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Album visibility',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              _VisibilityChoice(
                label: 'Public',
                hint: 'Anyone with link',
                selected: !_codeProtected,
                onTap: _loading
                    ? null
                    : () => setState(() => _codeProtected = false),
              ),
              _VisibilityChoice(
                label: 'Private',
                hint: 'Access code',
                selected: _codeProtected,
                onTap: _loading
                    ? null
                    : () => setState(() => _codeProtected = true),
              ),
            ],
          ),
          if (_codeProtected) ...[
            const SizedBox(height: 16),
            _Field(
              label: 'Guest access code',
              child: _textField(
                controller: _codeCtrl,
                hint: 'Ex. 1234 or WEDDING2026',
                action: TextInputAction.done,
                validator: (v) {
                  if (!_codeProtected) return null;
                  if (v == null || v.trim().length < 4) {
                    return 'Minimum 4 characters';
                  }
                  return null;
                },
              ),
            ),
          ],
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth >= 520;
              final width = twoCols
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _ToggleRow(
                      title: 'Allow guest uploads',
                      subtitle: 'Let guests add photos and videos',
                      value: _guestUploads,
                      onChanged: _loading
                          ? null
                          : (v) => setState(() => _guestUploads = v),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _ToggleRow(
                      title: 'Enable moderation',
                      subtitle: 'Approve photos before they appear',
                      badge: 'Premium',
                      value: _moderation && _plan == AlbumPlan.premium,
                      onChanged: _loading ? null : _setModeration,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputAction action = TextInputAction.next,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_loading,
      maxLines: maxLines,
      textInputAction: action,
      validator: validator,
      cursorColor: Colors.black,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: _ink,
      ),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: _border(_line),
        enabledBorder: _border(_line),
        focusedBorder: _border(_ink, 1.3),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEDF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: _pinkStrong, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 14, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.child,
    this.required = false,
    this.optional = false,
  });

  final String label;
  final Widget child;
  final bool required;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: _pinkStrong),
                ),
              if (optional)
                const TextSpan(
                  text: ' (optional)',
                  style: TextStyle(fontWeight: FontWeight.w500, color: _muted),
                ),
            ],
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _EventTypeTile extends StatelessWidget {
  const _EventTypeTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 118,
        height: 92,
        decoration: BoxDecoration(
          color: selected ? _pinkTint : const Color(0xFFFAFAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _pink : _line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.date,
    required this.enabled,
    required this.onTap,
  });

  final DateTime? date;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = date == null
        ? 'Select date'
        : date!.toLocal().toString().substring(0, 10);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: Colors.black.withOpacity(0.5),
            ),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: date == null ? Colors.black.withOpacity(0.3) : _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  const _ColorTile({
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final ColorFillValue value;
  final bool enabled;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final isSolid = value.mode == ColorFillMode.solid;
    final swatch = BoxDecoration(
      shape: BoxShape.circle,
      color: isSolid ? value.primaryColor : null,
      gradient: isSolid
          ? null
          : LinearGradient(
              begin: _angle(value.gradient!.angleDegrees).$1,
              end: _angle(value.gradient!.angleDegrees).$2,
              colors: value.gradient!.colors,
            ),
      border: Border.all(color: _line),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? () => onTap() : null,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Container(width: 26, height: 26, decoration: swatch),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isSolid ? value.primaryHex.toUpperCase() : 'Gradient',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            const Icon(Icons.palette_outlined, size: 18, color: _muted),
            const SizedBox(width: 4),
            const Text(
              'Pick',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  static (Alignment, Alignment) _angle(double degrees) {
    final a = (degrees % 360) * (math.pi / 180.0);
    return (
      Alignment(-math.cos(a), -math.sin(a)),
      Alignment(math.cos(a), math.sin(a)),
    );
  }
}

class _VisibilityChoice extends StatelessWidget {
  const _VisibilityChoice({
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hint;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _pinkTint : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _pink : _line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20,
              color: selected ? _pink : const Color(0xFFA1A1AA),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selected ? _pinkStrong : _ink,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '($hint)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? _pinkStrong : _muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.badge,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _pinkTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _pinkStrong,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12.5, color: _muted),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: _pink,
        ),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.plan,
    required this.archive,
    required this.loading,
    required this.onPlanChanged,
    required this.onArchiveChanged,
  });

  final AlbumPlan plan;
  final bool archive;
  final bool loading;
  final ValueChanged<AlbumPlan> onPlanChanged;
  final ValueChanged<bool> onArchiveChanged;

  @override
  Widget build(BuildContext context) {
    final info = Plans.byId(plan.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDEDF1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose your plan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 12),
              for (final p in Plans.all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlanOption(
                    info: p,
                    selected: p.plan == plan,
                    onTap: loading ? null : () => onPlanChanged(p.plan),
                  ),
                ),
              const SizedBox(height: 4),
              _ArchiveOption(
                selected: archive,
                onTap: loading ? null : () => onArchiveChanged(!archive),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDEDF1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.diamond_outlined,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "What's included",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final f in info.features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 19,
                        color: Color(0xFF22C55E),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3F3F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (archive) ...[
                const SizedBox(height: 2),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 19,
                      color: Color(0xFF6D28D9),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Permanent archive: your album stays in the cloud while you renew',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3F3F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ArchiveOption extends StatelessWidget {
  const _ArchiveOption({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF6D28D9);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5F3FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? purple : _line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 22,
              color: selected ? purple : const Color(0xFFA1A1AA),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add permanent archive',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Keep your event in the cloud without losing anything. '
                    'If you stop renewing, it is removed after a '
                    '${Plans.archiveGraceDays}-day grace period unless you export it.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Plans.archivePriceLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                const Text(
                  '/ year',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.plan,
    required this.archive,
    required this.loading,
    required this.onCreate,
  });

  final AlbumPlan plan;
  final bool archive;
  final bool loading;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final info = Plans.byId(plan.name);
    final total = info.price + (archive ? Plans.archivePrice : 0);
    final totalLabel = '\$${total.toStringAsFixed(2)}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                archive
                    ? '${info.name} + archive, then ${Plans.archivePriceLabel}/year'
                    : '${info.name} · one-time payment',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              totalLabel,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: loading ? null : onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0B0B10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 19),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Create album & pay $totalLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Secure payment powered by Stripe',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: _muted),
        ),
      ],
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final PlanInfo info;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _pinkTint : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _pink : _line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20,
              color: selected ? _pink : const Color(0xFFA1A1AA),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          info.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ),
                      if (info.popular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _pinkStrong,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Most popular',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${info.retentionDays} days in the cloud after the event',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
            Text(
              info.priceLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
