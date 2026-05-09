import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.nextLocation,
    this.navigateOnSuccess = true,
  });

  final String? nextLocation;
  final bool navigateOnSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService();

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _otpSent = false;
  bool _loading = false;

  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    _emailCtrl.dispose();
    _otpCtrl.dispose();

    super.dispose();
  }

  void _showToast({required String message, ToastType type = ToastType.info}) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    if (!mounted) return;

    final overlay = Overlay.of(context);

    _toastEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 28,
          right: 28,
          child: _TopRightToast(
            message: message,
            type: type,
            onClose: () {
              _toastTimer?.cancel();
              _toastEntry?.remove();
              _toastEntry = null;
            },
          ),
        );
      },
    );

    overlay.insert(_toastEntry!);

    _toastTimer = Timer(const Duration(seconds: 4), () {
      _toastEntry?.remove();
      _toastEntry = null;
    });
  }

  void _clearToast() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;
  }

  Future<void> _sendOtp() async {
    if (_loading) return;

    final email = _emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showToast(
        message: 'Please enter a valid email address.',
        type: ToastType.error,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    try {
      await _auth.sendOtp(email);

      if (!mounted) return;

      setState(() {
        _loading = false;
        _otpSent = true;
        _otpCtrl.clear();
      });

      _showToast(message: 'Code sent to your email.', type: ToastType.success);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showToast(
        message: 'We could not send the code. Please try again.',
        type: ToastType.error,
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_loading) return;

    final email = _emailCtrl.text.trim();
    final token = _otpCtrl.text.trim();

    if (token.length != 8) {
      _showToast(message: 'The code must be 8 digits.', type: ToastType.error);
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    try {
      await _auth.verifyOtp(email: email, token: token);

      if (!mounted) return;

      _clearToast();

      setState(() {
        _loading = false;
      });

      if (widget.navigateOnSuccess) {
        context.go('/');
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showToast(message: 'Incorrect or expired code.', type: ToastType.error);
    }
  }

  void _resetEmail() {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _otpSent = false;
      _otpCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _LoginBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: _AuthCard(
                    otpSent: _otpSent,
                    loading: _loading,
                    emailCtrl: _emailCtrl,
                    otpCtrl: _otpCtrl,
                    onSendOtp: _sendOtp,
                    onVerifyOtp: _verifyOtp,
                    onResetEmail: _resetEmail,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.otpSent,
    required this.loading,
    required this.emailCtrl,
    required this.otpCtrl,
    required this.onSendOtp,
    required this.onVerifyOtp,
    required this.onResetEmail,
  });

  final bool otpSent;
  final bool loading;
  final TextEditingController emailCtrl;
  final TextEditingController otpCtrl;
  final VoidCallback onSendOtp;
  final VoidCallback onVerifyOtp;
  final VoidCallback onResetEmail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(34, 34, 34, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AuthLogo(),
          const SizedBox(height: 18),
          Text(
            otpSent ? 'Verify your access' : 'Welcome back',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: Color(0xFF15151A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            otpSent
                ? 'Enter the 8-digit code we sent to your email'
                : 'Enter your email to access your account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 34),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              );
            },
            child: otpSent
                ? _OtpForm(
                    key: const ValueKey('otp-form'),
                    loading: loading,
                    emailCtrl: emailCtrl,
                    otpCtrl: otpCtrl,
                    onVerifyOtp: onVerifyOtp,
                    onResetEmail: onResetEmail,
                    onResendOtp: onSendOtp,
                  )
                : _EmailForm(
                    key: const ValueKey('email-form'),
                    loading: loading,
                    emailCtrl: emailCtrl,
                    onSendOtp: onSendOtp,
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmailForm extends StatelessWidget {
  const _EmailForm({
    super.key,
    required this.loading,
    required this.emailCtrl,
    required this.onSendOtp,
  });

  final bool loading;
  final TextEditingController emailCtrl;
  final VoidCallback onSendOtp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _AuthLabelRow(label: 'EMAIL', trailing: null),
        const SizedBox(height: 8),
        _AuthTextField(
          controller: emailCtrl,
          hintText: 'name@company.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          enabled: !loading,
          onSubmitted: (_) {
            if (!loading) onSendOtp();
          },
        ),
        const SizedBox(height: 28),
        _PrimaryAuthButton(
          text: 'Send code',
          loading: loading,
          onPressed: onSendOtp,
        ),
        const SizedBox(height: 24),
        const _SoftDivider(text: 'Secure email access'),
        const SizedBox(height: 20),
        Text(
          'No password needed. We will send you a temporary code to sign in.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: Colors.black.withOpacity(0.42),
          ),
        ),
      ],
    );
  }
}

class _OtpForm extends StatelessWidget {
  const _OtpForm({
    super.key,
    required this.loading,
    required this.emailCtrl,
    required this.otpCtrl,
    required this.onVerifyOtp,
    required this.onResetEmail,
    required this.onResendOtp,
  });

  final bool loading;
  final TextEditingController emailCtrl;
  final TextEditingController otpCtrl;
  final VoidCallback onVerifyOtp;
  final VoidCallback onResetEmail;
  final VoidCallback onResendOtp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AuthLabelRow(
          label: 'EMAIL',
          trailing: TextButton(
            onPressed: loading ? null : onResetEmail,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: const Color(0xFF6D5BD0),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Change email'),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 46,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: Text(
            emailCtrl.text.trim(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F1F25),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const _AuthLabelRow(label: 'VERIFICATION CODE', trailing: null),
        const SizedBox(height: 10),
        PinCodeTextField(
          appContext: context,
          controller: otpCtrl,
          autoDisposeControllers: false,
          length: 8,
          enabled: !loading,
          keyboardType: TextInputType.number,
          animationType: AnimationType.fade,
          enableActiveFill: true,
          autoFocus: true,
          cursorColor: const Color(0xFF111111),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF141414),
          ),
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(9),
            fieldHeight: 48,
            fieldWidth: 38,
            activeFillColor: Colors.white,
            selectedFillColor: Colors.white,
            inactiveFillColor: Colors.white,
            activeColor: const Color(0xFF111111),
            selectedColor: const Color(0xFF6D5BD0),
            inactiveColor: const Color(0xFFE5E5EA),
            disabledColor: const Color(0xFFE5E5EA),
            borderWidth: 1.2,
          ),
          onChanged: (_) {},
          onCompleted: (_) {
            if (!loading) onVerifyOtp();
          },
        ),
        const SizedBox(height: 22),
        _PrimaryAuthButton(
          text: 'Verify code',
          loading: loading,
          onPressed: onVerifyOtp,
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Didn’t receive the code?',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.46),
              ),
            ),
            TextButton(
              onPressed: loading ? null : onResendOtp,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6D5BD0),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Resend'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuthLogo extends StatelessWidget {
  const _AuthLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Image.asset(
          'assets/img/logo.png',
          height: 140,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _AuthLabelRow extends StatelessWidget {
  const _AuthLabelRow({required this.label, required this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.55,
            color: Colors.black.withOpacity(0.46),
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.hintText,
    required this.keyboardType,
    required this.textInputAction,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        cursorColor: Colors.black,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E1E24),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.28),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFF111111), width: 1.3),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
          ),
        ),
      ),
    );
  }
}

class _PrimaryAuthButton extends StatelessWidget {
  const _PrimaryAuthButton({
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  final String text;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        clipBehavior: Clip.antiAlias,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
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
            : Text(text),
      ),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFFECECF0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.black.withOpacity(0.38),
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFFECECF0))),
      ],
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/img/login-background.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        Positioned.fill(
          child: Container(color: Colors.white.withOpacity(0.38)),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.22, -0.16),
                radius: 1.08,
                colors: [
                  Colors.white.withOpacity(0.02),
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.42),
                ],
                stops: [0.0, 0.52, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum ToastType { success, error, info }

class _TopRightToast extends StatelessWidget {
  const _TopRightToast({
    required this.message,
    required this.type,
    required this.onClose,
  });

  final String message;
  final ToastType type;
  final VoidCallback onClose;

  Color get _accent {
    switch (type) {
      case ToastType.success:
        return const Color(0xFF12B76A);
      case ToastType.error:
        return const Color(0xFFF04438);
      case ToastType.info:
        return const Color(0xFF111827);
    }
  }

  IconData get _icon {
    switch (type) {
      case ToastType.success:
        return Icons.check_rounded;
      case ToastType.error:
        return Icons.close_rounded;
      case ToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 18, end: 0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(offset: Offset(value, 0), child: child);
        },
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5EA)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: _accent, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17171C),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
