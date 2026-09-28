import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';

class WebRtcSignalingService {
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  StreamSubscription<DatabaseEvent>? _answerSubscription;
  StreamSubscription<DatabaseEvent>? _iceSubscription;

  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun3.l.google.com:19302',
          'stun:stun4.l.google.com:19302',
          'stun:stun.services.mozilla.com',
          'stun:global.stun.twilio.com:3478',
        ]
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  /// Initialize video renderers
  Future<void> initializeRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  /// Open camera and microphone media stream (Mobile Web and Desktop Compatible)
  Future<MediaStream?> openUserMedia() async {
    if (_localStream != null) {
      return _localStream;
    }

    // Flexible constraints compatible with all Mobile Chrome, Mobile Safari & Desktop devices
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
        'optional': [],
      }
    };

    try {
      final stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localStream = stream;
      localRenderer.srcObject = _localStream;
      return stream;
    } catch (e) {
      debugPrint('Flexible getUserMedia failed, retrying basic constraints: $e');
      try {
        // Fallback for strict mobile web devices
        final basicConstraints = {'audio': true, 'video': true};
        final stream = await navigator.mediaDevices.getUserMedia(basicConstraints);
        _localStream = stream;
        localRenderer.srcObject = _localStream;
        return stream;
      } catch (err) {
        debugPrint('Error opening user camera/mic: $err');
        return null;
      }
    }
  }

  /// Switch Camera (Front <-> Rear Camera)
  Future<void> switchCamera() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      try {
        final videoTrack = _localStream!.getVideoTracks()[0];
        await Helper.switchCamera(videoTrack);
      } catch (e) {
        debugPrint('Error switching camera: $e');
      }
    }
  }

  /// Start a WebRTC video call room (Host / Caller) with unique roomId
  Future<void> createRoom(String roomId) async {
    final String roomPath = 'rooms/$roomId';
    final DatabaseReference roomRef = _rtdb.ref(roomPath);

    if (_localStream == null) {
      await openUserMedia();
    }

    _peerConnection = await createPeerConnection(_configuration);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await _peerConnection?.addTrack(track, _localStream!);
      }
    }

    final offerCandidatesRef = roomRef.child('offerCandidates');
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      offerCandidatesRef.push().set({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
      }
    };

    final RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await roomRef.child('offer').set({
      'type': offer.type,
      'sdp': offer.sdp,
    });

    _answerSubscription = roomRef.child('answer').onValue.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data != null && _peerConnection != null) {
        final String? sdp = data['sdp'];
        final String? type = data['type'];
        if (sdp != null && type != null) {
          final answer = RTCSessionDescription(sdp, type);
          await _peerConnection!.setRemoteDescription(answer);
        }
      }
    });

    _iceSubscription = roomRef.child('answerCandidates').onChildAdded.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data != null && _peerConnection != null) {
        final candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
      }
    });
  }

  /// Join an existing WebRTC video call room with unique roomId
  Future<void> joinRoom(String roomId) async {
    final String roomPath = 'rooms/$roomId';
    final DatabaseReference roomRef = _rtdb.ref(roomPath);

    final snapshot = await roomRef.child('offer').get();
    if (!snapshot.exists) {
      debugPrint('Room offer does not exist yet for $roomId. Retrying createRoom...');
      await createRoom(roomId);
      return;
    }

    final data = snapshot.value as Map;
    final String sdp = data['sdp'];
    final String type = data['type'];

    if (_localStream == null) {
      await openUserMedia();
    }

    _peerConnection = await createPeerConnection(_configuration);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await _peerConnection?.addTrack(track, _localStream!);
      }
    }

    final answerCandidatesRef = roomRef.child('answerCandidates');
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      answerCandidatesRef.push().set({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
      }
    };

    final offer = RTCSessionDescription(sdp, type);
    await _peerConnection!.setRemoteDescription(offer);

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await roomRef.child('answer').set({
      'type': answer.type,
      'sdp': answer.sdp,
    });

    _iceSubscription = roomRef.child('offerCandidates').onChildAdded.listen((event) async {
      final candData = event.snapshot.value as Map?;
      if (candData != null && _peerConnection != null) {
        final candidate = RTCIceCandidate(
          candData['candidate'],
          candData['sdpMid'],
          candData['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
      }
    });
  }

  /// Mute / Unmute Microphone
  void toggleMic(bool isMuted) {
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !isMuted;
      }
    }
  }

  /// Toggle Camera Video On / Off
  void toggleCamera(bool isOff) {
    if (_localStream != null) {
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = !isOff;
      }
    }
  }

  /// Hang Up & Dispose Peer Connection
  Future<void> hangUp(String roomId) async {
    await _answerSubscription?.cancel();
    await _iceSubscription?.cancel();
    _answerSubscription = null;
    _iceSubscription = null;

    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _peerConnection = null;

    remoteRenderer.srcObject = null;

    try {
      await _rtdb.ref('rooms/$roomId').remove();
    } catch (e) {
      debugPrint('Error clearing room signaling data: $e');
    }
  }

  /// Fully dispose renderers & local streams on app exit
  Future<void> dispose() async {
    await _answerSubscription?.cancel();
    await _iceSubscription?.cancel();

    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    await _localStream?.dispose();
    _localStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }
}
