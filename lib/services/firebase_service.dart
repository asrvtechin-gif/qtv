import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class MatchResult {
  final String roomId;
  final bool isHost;
  final String peerName;

  MatchResult({
    required this.roomId,
    required this.isHost,
    required this.peerName,
  });
}

class RealChatMessage {
  final String sender;
  final String text;
  final bool isUser;

  RealChatMessage({
    required this.sender,
    required this.text,
    required this.isUser,
  });
}

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseDatabase get rtdb => FirebaseDatabase.instance;
  FirebaseAnalytics get analytics => FirebaseAnalytics.instance;

  StreamSubscription<DatabaseEvent>? _matchSubscription;

  User? get currentUser => auth.currentUser;
  String get myUid => currentUser?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
  String get myName => currentUser?.displayName ?? (auth.currentUser?.isAnonymous == true ? 'Guest User' : 'User');

  /// Initialize Firebase app & Analytics
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb) {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
    }
  }

  /// Sign In with Google (Web & Android supported)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        try {
          userCredential = await auth.signInWithPopup(googleProvider);
        } catch (popupError) {
          debugPrint('Google Sign-In popup error/blocked: $popupError');
          // Fallback to anonymous demo account if popup was blocked or failed
          return await _signInAnonymouslyFallback();
        }
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
        );
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) return null; // Canceled by user

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await auth.signInWithCredential(credential);
      }

      final User? user = userCredential.user;
      if (user != null) {
        await saveUserDetails(user);
        await registerPresence();
        await analytics.logLogin(loginMethod: 'google');
      }

      return userCredential;
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      return await _signInAnonymouslyFallback();
    }
  }

  /// Fallback anonymous sign-in for testing
  Future<UserCredential?> _signInAnonymouslyFallback() async {
    try {
      final UserCredential userCredential = await auth.signInAnonymously();
      final User? user = userCredential.user;
      if (user != null) {
        await saveUserDetails(user);
        await registerPresence();
        await analytics.logLogin(loginMethod: 'anonymous_demo');
      }
      return userCredential;
    } catch (e) {
      debugPrint('Anonymous fallback sign-in failed: $e');
      return null;
    }
  }

  /// Save comprehensive user profile details to Realtime Database (/users/{uid})
  Future<void> saveUserDetails(User user) async {
    try {
      final DatabaseReference userRef = rtdb.ref('users/${user.uid}');
      await userRef.update({
        'uid': user.uid,
        'displayName': user.displayName ?? (user.isAnonymous ? 'Guest User' : 'QTV User'),
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
        'platform': kIsWeb ? 'website' : 'android_app',
        'lastLoginTimestamp': ServerValue.timestamp,
        'status': 'online',
      });
    } catch (e) {
      debugPrint('Error saving user data to RTDB: $e');
    }
  }

  /// --- REAL-TIME PRESENCE & LIVE USERS COUNTER ---

  /// Register active presence in RTDB with automatic onDisconnect cleanup
  Future<void> registerPresence() async {
    final presenceRef = rtdb.ref('presence/$myUid');
    try {
      await presenceRef.set({
        'uid': myUid,
        'name': myName,
        'platform': kIsWeb ? 'website' : 'android_app',
        'status': 'online',
        'joinedAt': ServerValue.timestamp,
      });
      presenceRef.onDisconnect().remove();
    } catch (e) {
      debugPrint('Error registering presence: $e');
    }
  }

  /// Stream of live online user count
  Stream<int> getLiveUserCountStream() {
    return rtdb.ref('presence').onValue.map((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final Map data = event.snapshot.value as Map;
        return data.length;
      }
      return 1;
    });
  }

  /// --- STRICT 1-ON-1 RANDOM MATCHMAKING ---

  /// Find or create a strict 2-user 1-on-1 video call room
  Future<MatchResult> findOrCreate1v1Match({
    required Function(MatchResult match) onMatchFound,
  }) async {
    // Cancel previous match listener if any
    await _matchSubscription?.cancel();

    final queueRef = rtdb.ref('matchmaking_queue');
    final snapshot = await queueRef.get();

    String? peerUid;
    String? peerName;

    if (snapshot.exists && snapshot.value is Map) {
      final Map queueData = snapshot.value as Map;
      for (var entry in queueData.entries) {
        final String uidKey = entry.key.toString();
        if (uidKey != myUid) {
          final Map details = entry.value as Map;
          peerUid = uidKey;
          peerName = details['name']?.toString() ?? 'Remote User';
          break;
        }
      }
    }

    if (peerUid != null) {
      final String roomId = 'PAIR_${myUid.compareTo(peerUid) < 0 ? "${myUid}_$peerUid" : "${peerUid}_$myUid"}';
      
      await queueRef.child(peerUid).remove();
      await queueRef.child(myUid).remove();

      await rtdb.ref('matches/$peerUid').set({
        'roomId': roomId,
        'isHost': false,
        'peerName': myName,
      });

      final match = MatchResult(
        roomId: roomId,
        isHost: true,
        peerName: peerName ?? 'Remote User',
      );
      onMatchFound(match);
      return match;
    } else {
      await queueRef.child(myUid).set({
        'uid': myUid,
        'name': myName,
        'platform': kIsWeb ? 'website' : 'android_app',
        'timestamp': ServerValue.timestamp,
      });

      _matchSubscription = rtdb.ref('matches/$myUid').onValue.listen((event) {
        if (event.snapshot.exists && event.snapshot.value is Map) {
          final data = event.snapshot.value as Map;
          final match = MatchResult(
            roomId: data['roomId'],
            isHost: data['isHost'] ?? false,
            peerName: data['peerName'] ?? 'Remote User',
          );
          _matchSubscription?.cancel();
          rtdb.ref('matches/$myUid').remove();
          onMatchFound(match);
        }
      });

      final defaultRoom = MatchResult(
        roomId: 'PAIR_${myUid}_waiting',
        isHost: true,
        peerName: 'Waiting for peer...',
      );
      return defaultRoom;
    }
  }

  /// Remove user from matchmaking queue and cancel match listeners
  Future<void> removeFromQueue() async {
    try {
      await _matchSubscription?.cancel();
      _matchSubscription = null;
      await rtdb.ref('matchmaking_queue/$myUid').remove();
      await rtdb.ref('matches/$myUid').remove();
    } catch (e) {
      debugPrint('Error removing from queue: $e');
    }
  }

  /// Realtime Stream of Chat Messages for a Room
  Stream<List<RealChatMessage>> getChatMessagesStream(String roomId) {
    return rtdb.ref('rooms/$roomId/messages').onValue.map((event) {
      final List<RealChatMessage> list = [];
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final Map data = event.snapshot.value as Map;
        final sortedEntries = data.entries.toList()
          ..sort((a, b) {
            final valA = (a.value as Map)['timestamp'] ?? 0;
            final valB = (b.value as Map)['timestamp'] ?? 0;
            final tA = valA is int ? valA : 0;
            final tB = valB is int ? valB : 0;
            return tA.compareTo(tB);
          });

        for (var entry in sortedEntries) {
          final Map msg = entry.value as Map;
          final sender = msg['sender']?.toString() ?? 'User';
          final text = msg['text']?.toString() ?? '';
          final senderUid = msg['uid']?.toString() ?? '';
          list.add(RealChatMessage(
            sender: sender,
            text: text,
            isUser: senderUid == myUid,
          ));
        }
      }
      return list;
    });
  }

  /// Send a Live Chat Message in 1-on-1 RTDB Room
  Future<void> sendChatMessage(String roomId, String text) async {
    try {
      final msgRef = rtdb.ref('rooms/$roomId/messages').push();
      await msgRef.set({
        'sender': myName,
        'text': text,
        'timestamp': ServerValue.timestamp,
        'uid': myUid,
      });
    } catch (e) {
      debugPrint('Error sending chat message to RTDB: $e');
    }
  }

  /// End 1-on-1 Room
  Future<void> end1v1Room(String roomId) async {
    try {
      await removeFromQueue();
      await rtdb.ref('rooms/$roomId').remove();
      await analytics.logEvent(
        name: 'end_1v1_call',
        parameters: {'room_id': roomId},
      );
    } catch (e) {
      debugPrint('Error ending 1v1 room: $e');
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    await removeFromQueue();
    await rtdb.ref('presence/$myUid').remove();
    await auth.signOut();
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
  }
}
