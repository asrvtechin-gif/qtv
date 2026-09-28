import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/firebase_service.dart';
import '../services/webrtc_service.dart';
import '../services/apk_download_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final WebRtcSignalingService _webrtcService = WebRtcSignalingService();

  // Call & Pair State
  bool _isCallActive = false;
  bool _isSearchingPeer = false;
  bool _isBuffering = false;
  bool _hasLocalCameraStream = false;
  String _currentRoomId = 'PAIR_waiting';
  String _peerName = 'Remote User';

  // Live Users & Realtime Chat Streams
  int _liveUserCount = 1;
  StreamSubscription<int>? _presenceSubscription;
  StreamSubscription<List<RealChatMessage>>? _chatSubscription;
  List<RealChatMessage> _realMessages = [];

  // Collapsible Chat & Unread Badge Counter
  bool _isChatOpen = false;
  int _unreadMessageCount = 0;

  // Timer State
  Timer? _callTimer;
  int _secondsElapsed = 0;

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initLivePresenceAndWebRtc();
  }

  Future<void> _initLivePresenceAndWebRtc() async {
    // 1. Register presence & listen to live online user count
    await _firebaseService.registerPresence();
    _presenceSubscription = _firebaseService.getLiveUserCountStream().listen((count) {
      if (mounted) {
        setState(() {
          _liveUserCount = count < 1 ? 1 : count;
        });
      }
    });

    // 2. Initialize WebRTC local camera stream
    await _webrtcService.initializeRenderers();
    await _requestMediaPermissions();

    _listenToRealChat(_currentRoomId);
  }

  Future<void> _requestMediaPermissions() async {
    final stream = await _webrtcService.openUserMedia();
    if (mounted) {
      setState(() {
        _hasLocalCameraStream = stream != null;
      });
    }
  }

  void _listenToRealChat(String roomId) {
    _chatSubscription?.cancel();
    _chatSubscription = _firebaseService.getChatMessagesStream(roomId).listen((messages) {
      if (!mounted) return;

      if (messages.length > _realMessages.length) {
        final newMsgs = messages.sublist(_realMessages.length);
        int incomingCount = newMsgs.where((m) => !m.isUser).length;

        if (incomingCount > 0 && !_isChatOpen) {
          setState(() {
            _unreadMessageCount += incomingCount;
          });
        }
      }

      setState(() {
        _realMessages = messages;
      });
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _presenceSubscription?.cancel();
    _chatSubscription?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    _webrtcService.dispose();
    super.dispose();
  }

  void _startTimer() {
    _callTimer?.cancel();
    _secondsElapsed = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _stopTimer() {
    _callTimer?.cancel();
  }

  String _formatTimer(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  // --- MATCHMAKING HANDLERS ---

  void _onStartPressed() async {
    if (!_hasLocalCameraStream) {
      await _requestMediaPermissions();
    }

    setState(() {
      _isSearchingPeer = true;
      _isBuffering = false;
      _isCallActive = false;
    });

    await _firebaseService.findOrCreate1v1Match(
      onMatchFound: (MatchResult match) async {
        if (!mounted) return;

        setState(() {
          _currentRoomId = match.roomId;
          _peerName = match.peerName;
          _isSearchingPeer = false;
          _isBuffering = true;
        });
        _listenToRealChat(match.roomId);

        // Establish WebRTC video stream on dynamic match.roomId
        if (match.isHost) {
          await _webrtcService.createRoom(match.roomId);
        } else {
          await _webrtcService.joinRoom(match.roomId);
        }

        if (mounted) {
          setState(() {
            _isBuffering = false;
            _isCallActive = true;
          });
          _startTimer();
        }
      },
    );
  }

  void _onNextPressed() async {
    if (!_isCallActive && !_isSearchingPeer && !_isBuffering) return;

    final String oldRoom = _currentRoomId;

    setState(() {
      _isCallActive = false;
      _isBuffering = false;
      _isSearchingPeer = true;
      _realMessages.clear();
      _unreadMessageCount = 0;
    });

    await _webrtcService.hangUp(oldRoom);
    await _firebaseService.removeFromQueue();

    _onStartPressed();
  }

  void _onEndPressed() async {
    if (!_isCallActive && !_isSearchingPeer && !_isBuffering) return;

    final String oldRoom = _currentRoomId;

    setState(() {
      _isCallActive = false;
      _isSearchingPeer = false;
      _isBuffering = false;
      _realMessages.clear();
      _unreadMessageCount = 0;
    });
    _stopTimer();

    await _webrtcService.hangUp(oldRoom);
    await _firebaseService.end1v1Room(oldRoom);
  }

  void _switchCamera() async {
    await _webrtcService.switchCamera();
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
      if (_isChatOpen) {
        _unreadMessageCount = 0;
      }
    });
  }

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();
    await _firebaseService.sendChatMessage(_currentRoomId, text);
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 900;
    final isTablet = screenSize.width >= 600 && screenSize.width < 900;
    final isMobile = screenSize.width < 600;
    final isSmallMobile = screenSize.width < 380;

    return Scaffold(
      backgroundColor: const Color(0xFF07080E),
      body: SafeArea(
        child: Center(
          child: Container(
            width: (isDesktop || isTablet) ? screenSize.width : double.infinity,
            height: (isDesktop || isTablet) ? screenSize.height : double.infinity,
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1280 : (isTablet ? 760 : double.infinity),
              maxHeight: isDesktop ? 840 : double.infinity,
            ),
            margin: isDesktop
                ? const EdgeInsets.all(16)
                : (isTablet ? const EdgeInsets.all(12) : EdgeInsets.zero),
            decoration: (isDesktop || isTablet)
                ? BoxDecoration(
                    color: const Color(0xFF0B0E19),
                    borderRadius: BorderRadius.circular(isDesktop ? 24 : 18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ],
                  )
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular((isDesktop || isTablet) ? (isDesktop ? 24 : 18) : 0),
              child: Stack(
                children: [
                  // 1. Expanded Remote Video View (Full screen / Full card)
                  _buildRemoteVideoBackground(),

                  // 2. Gradient Overlay for UI Contrast
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black54,
                            Colors.transparent,
                            Colors.black38,
                            Colors.black87,
                          ],
                          stops: [0.0, 0.25, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // 3. Top Header Bar
                  Positioned(
                    top: isMobile ? 12 : 16,
                    left: isMobile ? 12 : 20,
                    right: isMobile ? 12 : 20,
                    child: _buildTopHeaderBar(isDesktop, isMobile, isSmallMobile),
                  ),

                  // 4. Picture-in-Picture (PiP) Local WebRTC Camera Overlay
                  Positioned(
                    top: isMobile ? 64 : 76,
                    right: isMobile ? 12 : 20,
                    child: _buildPipLocalCamera(isDesktop, isMobile, isSmallMobile),
                  ),

                  // 5. Floating Collapsible Chat Drawer Pane
                  if (_isChatOpen)
                    Positioned(
                      bottom: isMobile ? 138 : 156,
                      left: isDesktop ? 24 : (isTablet ? 20 : 12),
                      width: isDesktop ? 380 : (isTablet ? 340 : (screenSize.width - 24)),
                      child: _buildLiveChatBox(screenSize),
                    ),

                  // 6. Main Action Controls & Media Bar
                  Positioned(
                    bottom: isMobile ? 12 : 20,
                    left: isDesktop ? 24 : (isTablet ? 20 : 12),
                    right: isDesktop ? 24 : (isTablet ? 20 : 12),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 680 : double.infinity,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Main Action Buttons (Start, Next, SINGLE End Button)
                            _buildActionButtonsRow(isMobile, isSmallMobile),

                            SizedBox(height: isMobile ? 10 : 14),

                            // Bottom Media Bar
                            _buildBottomMediaBar(isMobile),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI BUILDER METHODS ---

  Widget _buildRemoteVideoBackground() {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isCallActive && _webrtcService.remoteRenderer.srcObject != null)
            RTCVideoView(
              _webrtcService.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2D1B4E), Color(0xFF1E1035), Color(0xFF0F081D)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: const Color(0xFF3B2368),
                      child: Text(
                        _peerName.isNotEmpty ? _peerName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isCallActive ? '$_peerName (1-on-1 Connected)' : 'QTV Live Video',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!_isCallActive && !_isSearchingPeer && !_isBuffering)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Text(
                  'Tap START to match 1-on-1 with an online user',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          if (_isSearchingPeer)
            Container(
              color: Colors.black.withValues(alpha: 0.65),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                        strokeWidth: 3.5,
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Finding active 1-on-1 online user...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isBuffering)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                        strokeWidth: 4,
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Connecting live video stream...',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopHeaderBar(bool isDesktop, bool isMobile, bool isSmallMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'QTV',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallMobile ? 22 : (isMobile ? 24 : 28),
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(width: isMobile ? 6 : 10),

            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 10,
                vertical: isMobile ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$_liveUserCount Live',
                    style: TextStyle(
                      color: const Color(0xFF00E5FF),
                      fontSize: isSmallMobile ? 11 : 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kIsWeb && !isSmallMobile) ...[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _downloadApk,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 12,
                      vertical: isMobile ? 5 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.android_rounded, color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Download APK',
                          style: TextStyle(
                            color: const Color(0xFF10B981),
                            fontSize: isMobile ? 11 : 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 6 : 10),
            ],

            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : 12,
                vertical: isMobile ? 5 : 7,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _isCallActive ? const Color(0xFF22C55E) : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTimer(_secondsElapsed),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallMobile ? 12 : 14,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPipLocalCamera(bool isDesktop, bool isMobile, bool isSmallMobile) {
    final double width = isDesktop ? 160 : (isSmallMobile ? 90 : (isMobile ? 100 : 130));
    final double height = isDesktop ? 210 : (isSmallMobile ? 120 : (isMobile ? 135 : 170));

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white30, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            if (_hasLocalCameraStream)
              RTCVideoView(
                _webrtcService.localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _requestMediaPermissions,
                  child: Container(
                    color: const Color(0xFF181824),
                    padding: const EdgeInsets.all(6),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam_off_rounded, color: Color(0xFF00E5FF), size: 24),
                        SizedBox(height: 4),
                        Text(
                          'Allow Camera',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveChatBox(Size screenSize) {
    final double maxChatHeight = (screenSize.height * 0.32).clamp(120.0, 220.0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF110E20).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.chat_bubble_rounded,
                    color: Color(0xFF00E5FF),
                    size: 15,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'LIVE CHAT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _toggleChat,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          SizedBox(
            height: maxChatHeight,
            child: _realMessages.isEmpty
                ? const Center(
                    child: Text(
                      'No chat messages yet',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: _realMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _realMessages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${msg.sender}: ',
                                style: TextStyle(
                                  color: msg.isUser
                                      ? const Color(0xFF00E5FF)
                                      : const Color(0xFFA855F7),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              TextSpan(
                                text: msg.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 8),

          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF231E33),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Message $_peerName...',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Action Row: Start, Next, SINGLE End Button
  Widget _buildActionButtonsRow(bool isMobile, bool isSmallMobile) {
    final bool isNextEndEnabled = _isCallActive || _isSearchingPeer || _isBuffering;
    final double buttonHeight = isMobile ? 46.0 : 52.0;

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Start',
            backgroundColor: const Color(0xFF8B5CF6),
            textColor: Colors.white,
            isEnabled: true,
            height: buttonHeight,
            fontSize: isSmallMobile ? 14 : 16,
            onPressed: _onStartPressed,
          ),
        ),

        SizedBox(width: isSmallMobile ? 8 : 12),

        Expanded(
          child: _ActionButton(
            label: 'Next',
            backgroundColor: const Color(0xFF1E1B2E),
            textColor: Colors.white,
            borderColor: isNextEndEnabled ? const Color(0xFF00E5FF) : Colors.white24,
            isEnabled: isNextEndEnabled,
            height: buttonHeight,
            fontSize: isSmallMobile ? 14 : 16,
            onPressed: _onNextPressed,
          ),
        ),

        SizedBox(width: isSmallMobile ? 8 : 12),

        // SINGLE End Call Button across the interface
        Expanded(
          child: _ActionButton(
            label: 'End',
            backgroundColor: const Color(0xFFEF4444),
            textColor: Colors.white,
            isEnabled: isNextEndEnabled,
            height: buttonHeight,
            fontSize: isSmallMobile ? 14 : 16,
            onPressed: _onEndPressed,
          ),
        ),
      ],
    );
  }

  /// Bottom Media Bar (Camera Switch, Live Chat Toggle, Participants Count)
  Widget _buildBottomMediaBar(bool isMobile) {
    return Container(
      height: isMobile ? 56 : 64,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0C1B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Switch Camera (Front <-> Rear Camera)
          _MediaIconButton(
            icon: Icons.cameraswitch_rounded,
            backgroundColor: const Color(0xFF8B5CF6),
            iconColor: Colors.white,
            onTap: _switchCamera,
          ),

          // Collapsible Chat Toggle Button with Unread Message Count Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              _MediaIconButton(
                icon: Icons.chat_bubble_rounded,
                backgroundColor: _isChatOpen
                    ? const Color(0xFF00E5FF)
                    : const Color(0xFF221F33),
                iconColor: _isChatOpen ? Colors.black : Colors.white,
                onTap: _toggleChat,
              ),
              if (_unreadMessageCount > 0 && !_isChatOpen)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        '$_unreadMessageCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Participants / Live Users Online
          _MediaIconButton(
            icon: Icons.people_alt_rounded,
            backgroundColor: const Color(0xFF221F33),
            iconColor: Colors.white,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$_liveUserCount Live Users Online in QTV'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final bool isEnabled;
  final double height;
  final double fontSize;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    required this.isEnabled,
    this.height = 52.0,
    this.fontSize = 16.0,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isEnabled;

    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: active ? widget.onPressed : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: active ? 1.0 : 0.35,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.borderColor ?? Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                if (active && _isHovered)
                  BoxShadow(
                    color: widget.backgroundColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaIconButton extends StatefulWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _MediaIconButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_MediaIconButton> createState() => _MediaIconButtonState();
}

class _MediaIconButtonState extends State<_MediaIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: widget.backgroundColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: widget.iconColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}
