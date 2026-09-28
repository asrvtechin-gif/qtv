import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/orbital_camera_graphic.dart';
import '../widgets/qtv_logo.dart';
import '../widgets/google_sign_in_button.dart';
import '../services/firebase_service.dart';
import '../services/apk_download_helper.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      await FirebaseService().signInWithGoogle();
    } catch (e) {
      debugPrint('Sign in flow: $e');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _downloadApk() async {
    await ApkDownloadHelper.downloadApk();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.download_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 10),
              Text('Downloading QTV Android APK...'),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showTermsDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          content,
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF00E5FF)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktopWeb = screenSize.width >= 900;
    final isMobilePhone = screenSize.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF06070C),
      body: Stack(
        children: [
          Positioned(
            top: -screenSize.height * 0.15,
            left: screenSize.width * 0.05,
            width: screenSize.width * 0.5,
            height: screenSize.height * 0.6,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4C1D95).withValues(alpha: 0.35),
                    const Color(0xFF0284C7).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -screenSize.height * 0.15,
            right: screenSize.width * 0.05,
            width: screenSize.width * 0.5,
            height: screenSize.height * 0.6,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0F172A).withValues(alpha: 0.8),
                    const Color(0xFF0284C7).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: isDesktopWeb ? 1100 : (isMobilePhone ? 420 : 560),
                        ),
                        margin: EdgeInsets.symmetric(
                          horizontal: isDesktopWeb ? 32 : (isMobilePhone ? 16 : 28),
                          vertical: isDesktopWeb ? 40 : (isMobilePhone ? 16 : 28),
                        ),
                        child: isDesktopWeb
                            ? _buildDesktopTwoColumnLayout()
                            : _buildMobileSingleColumnLayout(isMobilePhone),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTwoColumnLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const QtvLogoWidget(fontSize: 54),

                const SizedBox(height: 24),

                const Text(
                  'Connect instantly with ultra-low latency, crystal-clear 1-on-1 video calls.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'No pins, no room codes, no hassle. Powered by WebRTC & Firebase Realtime Signaling.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 36),

                const Center(
                  child: OrbitalCameraGraphic(
                    size: 300,
                  ),
                ),

                const SizedBox(height: 36),

                const Row(
                  children: [
                    _FeatureChip(
                      icon: Icons.bolt_rounded,
                      label: 'Zero Latency WebRTC',
                    ),
                    SizedBox(width: 16),
                    _FeatureChip(
                      icon: Icons.security_rounded,
                      label: 'Encrypted Signaling',
                    ),
                    SizedBox(width: 16),
                    _FeatureChip(
                      icon: Icons.devices_rounded,
                      label: 'Cross-Platform',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E19).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 40,
                  spreadRadius: 8,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Get Started',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to join live 1-on-1 video streams',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 36),

                if (_isLoading)
                  Container(
                    height: 56,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00E5FF),
                        ),
                      ),
                    ),
                  )
                else
                  GoogleSignInButton(
                    onPressed: _handleGoogleSignIn,
                  ),

                const SizedBox(height: 18),

                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _downloadApk,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF102A24),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.8),
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.android_rounded,
                            color: Color(0xFF10B981),
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Download Android APK',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'By signing in, you agree to our ',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                    _InteractiveTextLink(
                      text: 'Terms',
                      onTap: () => _showTermsDialog(
                        context,
                        'Terms of Service',
                        'By using QTV, you agree to provide accurate information, follow safety guidelines, and respect other users during live video streaming sessions.',
                      ),
                    ),
                    const Text(
                      ' & ',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                    _InteractiveTextLink(
                      text: 'Privacy Policy',
                      onTap: () => _showTermsDialog(
                        context,
                        'Privacy Policy',
                        'Your privacy is protected. QTV uses encrypted connections for video calls and does not store unencrypted audio/video streams.',
                      ),
                    ),
                    const Text(
                      '.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileSingleColumnLayout(bool isMobilePhone) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: isMobilePhone ? 12 : 20),

        OrbitalCameraGraphic(
          size: isMobilePhone ? 190 : 240,
        ),

        SizedBox(height: isMobilePhone ? 24 : 32),

        QtvLogoWidget(fontSize: isMobilePhone ? 38 : 46),

        const SizedBox(height: 16),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            'Connect instantly with ultra-low latency, crystal-clear quality video calls. No pins, no hassle.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF94A3B8),
              fontSize: isMobilePhone ? 14 : 15,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),

        SizedBox(height: isMobilePhone ? 32 : 40),

        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              Container(
                height: 56,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00E5FF),
                    ),
                  ),
                ),
              )
            else
              GoogleSignInButton(
                onPressed: _handleGoogleSignIn,
              ),

            if (kIsWeb) ...[
              const SizedBox(height: 14),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _downloadApk,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF102A24),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.8),
                        width: 1.2,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.android_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Download Android APK',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'By signing in, you agree to our ',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                _InteractiveTextLink(
                  text: 'Terms',
                  onTap: () => _showTermsDialog(
                    context,
                    'Terms of Service',
                    'By using QTV, you agree to provide accurate information, follow safety guidelines, and respect other users during live video streaming sessions.',
                  ),
                ),
                const Text(
                  ' & ',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                _InteractiveTextLink(
                  text: 'Privacy Policy',
                  onTap: () => _showTermsDialog(
                    context,
                    'Privacy Policy',
                    'Your privacy is protected. QTV uses encrypted connections for video calls and does not store unencrypted audio/video streams.',
                  ),
                ),
                const Text(
                  '.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF00E5FF), size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveTextLink extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _InteractiveTextLink({
    required this.text,
    required this.onTap,
  });

  @override
  State<_InteractiveTextLink> createState() => _InteractiveTextLinkState();
}

class _InteractiveTextLinkState extends State<_InteractiveTextLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.text,
          style: TextStyle(
            color: _isHovered ? const Color(0xFF00E5FF) : const Color(0xFF818CF8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: const Color(0xFF00E5FF),
          ),
        ),
      ),
    );
  }
}
