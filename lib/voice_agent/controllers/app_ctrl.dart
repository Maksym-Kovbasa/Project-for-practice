import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:livekit_components/livekit_components.dart' as components;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../exts.dart';

enum AppScreenState { welcome, agent }

enum AgentScreenState { visualizer, transcription }

class AppCtrl extends ChangeNotifier {
  static const uuid = Uuid();
  static final _logger = Logger('AppCtrl');

  // States
  AppScreenState appScreenState = AppScreenState.welcome;
  AgentScreenState agentScreenState = AgentScreenState.visualizer;

  //Test
  bool isUserCameEnabled = false;
  bool isScreenshareEnabled = false;

  final messageCtrl = TextEditingController();
  final messageFocusNode = FocusNode();

  late final sdk.Room room = sdk.Room(roomOptions: const sdk.RoomOptions(enableVisualizer: true));
  late final roomContext = components.RoomContext(room: room);
  late final sdk.Session session = _createSession(room: room);

  static sdk.Session _createSession({required sdk.Room room}) {
    // Development-only hardcoded credentials (optional).
    const hardcodedServerUrl = null; // e.g. 'wss://your-host'
    const hardcodedToken = null; // e.g. 'eyJ...'

    if (hardcodedServerUrl != null && hardcodedToken != null) {
      return sdk.Session.fromFixedTokenSource(
        sdk.LiteralTokenSource(
          serverUrl: hardcodedServerUrl,
          participantToken: hardcodedToken,
        ),
        options: sdk.SessionOptions(room: room),
      );
    }

    final sandboxId = dotenv.env['LIVEKIT_SANDBOX_ID']?.replaceAll('"', '');
    if (sandboxId == null || sandboxId.isEmpty) {
      throw StateError('LIVEKIT_SANDBOX_ID is not set and no hardcoded token is configured.');
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw StateError('No authenticated Firebase user found for agent session.');
    }

    final uid = firebaseUser.uid.trim();
    if (uid.isEmpty) {
      throw StateError('Authenticated user has an empty uid.');
    }

    final participantName = (firebaseUser.displayName?.trim().isNotEmpty ?? false)
        ? firebaseUser.displayName!.trim()
        : (firebaseUser.email?.split('@').first ?? 'user');

    final participantMetadata = jsonEncode({
      'uid': uid,
      if ((firebaseUser.email?.isNotEmpty ?? false)) 'email': firebaseUser.email,
      if ((firebaseUser.displayName?.isNotEmpty ?? false)) 'display_name': firebaseUser.displayName,
    });

    return sdk.Session.fromConfigurableTokenSource(
      sdk.SandboxTokenSource(sandboxId: sandboxId).cached(),
      tokenOptions: sdk.TokenRequestOptions(
        participantIdentity: uid,
        participantName: participantName,
        participantMetadata: participantMetadata,
        participantAttributes: {
          'user_id': uid,
          'uid': uid,
          if ((firebaseUser.email?.isNotEmpty ?? false)) 'email': firebaseUser.email!,
        },
        agentName: 'my-agent',
      ),
      options: sdk.SessionOptions(room: room),
    );
  }

  bool isSendButtonEnabled = false;
  bool isSessionStarting = false;
  bool _hasCleanedUp = false;
  final Map<String, List<String>> _profileFields = {};

  Map<String, List<String>> get profileFields =>
      Map<String, List<String>>.unmodifiable(_profileFields);

  Future<bool> removeRecommendedLink(String url) async {
    final existing = _profileFields['recommended_links'];
    if (existing == null || existing.isEmpty) {
      return false;
    }
    final normalizedTarget = _normalizeRecommendationLink(url);
    final filtered = existing.where((item) {
      final itemUrl = _extractRecommendationUrl(item);
      return _normalizeRecommendationLink(itemUrl) != normalizedTarget;
    }).toList();
    if (filtered.length == existing.length) {
      return false;
    }
    if (filtered.isEmpty) {
      _profileFields.remove('recommended_links');
    } else {
      _profileFields['recommended_links'] = filtered;
    }
    notifyListeners();

    final agentIdentity = roomContext.agentParticipant?.identity;
    if (agentIdentity == null || room.localParticipant == null) {
      return false;
    }
    try {
      final response = await room.localParticipant!.performRpc(
        sdk.PerformRpcParams(
          destinationIdentity: agentIdentity,
          method: 'client.removeRecommendedLink',
          payload: jsonEncode({'url': url}),
        ),
      );
      return response == 'ok';
    } catch (error) {
      _logger.warning('Failed to remove recommended link from backend: $error');
      return false;
    }
  }

  AppCtrl() {
    final format = DateFormat('HH:mm:ss');
    // configure logs for debugging
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      debugPrint('${format.format(record.time)}: ${record.message}');
    });

    messageCtrl.addListener(() {
      final newValue = messageCtrl.text.isNotEmpty;
      if (newValue != isSendButtonEnabled) {
        isSendButtonEnabled = newValue;
        notifyListeners();
      }
    });

    room.registerRpcMethod('client.agentFieldUpdate', _handleAgentFieldUpdate);
    session.addListener(_handleSessionChange);
  }

  Future<void> cleanUp() async {
    if (_hasCleanedUp) return;
    _hasCleanedUp = true;

    session.removeListener(_handleSessionChange);
    room.unregisterRpcMethod('client.agentFieldUpdate');
    await session.dispose();
    await room.dispose();
    roomContext.dispose();
    messageCtrl.dispose();
    messageFocusNode.dispose();
  }

  @override
  void dispose() {
    unawaited(cleanUp());
    super.dispose();
  }

  void sendMessage() async {
    isSendButtonEnabled = false;

    final text = messageCtrl.text;
    messageCtrl.clear();
    notifyListeners();

    if (text.isEmpty) return;
    await session.sendText(text);
  }

  void toggleUserCamera(components.MediaDeviceContext? deviceCtx) {
    isUserCameEnabled = !isUserCameEnabled;
    isUserCameEnabled ? deviceCtx?.enableCamera() : deviceCtx?.disableCamera();
    notifyListeners();
  }

  void toggleScreenShare() {
    isScreenshareEnabled = !isScreenshareEnabled;
    notifyListeners();
  }

  void toggleAgentScreenMode() {
    agentScreenState =
        agentScreenState == AgentScreenState.visualizer ? AgentScreenState.transcription : AgentScreenState.visualizer;
    notifyListeners();
  }

  void connect() async {
    if (isSessionStarting) {
      _logger.fine('Connection attempt ignored: session already starting.');
      return;
    }

    _logger.info('Starting session connection...');
    isSessionStarting = true;
    notifyListeners();

    try {
      await session.start();
      if (session.connectionState == sdk.ConnectionState.connected) {
        appScreenState = AppScreenState.agent;
        notifyListeners();
      }
    } catch (error, stackTrace) {
      _logger.severe('Connection error: $error', error, stackTrace);
      appScreenState = AppScreenState.welcome;
      notifyListeners();
    } finally {
      if (isSessionStarting) {
        isSessionStarting = false;
        notifyListeners();
      }
    }
  }

  Future<void> disconnect() async {
    await session.end();
    appScreenState = AppScreenState.welcome;
    agentScreenState = AgentScreenState.visualizer;
    notifyListeners();
  }

  void _handleSessionChange() {
    final sdk.ConnectionState state = session.connectionState;
    AppScreenState? nextScreen;
    switch (state) {
      case sdk.ConnectionState.connected:
      case sdk.ConnectionState.reconnecting:
        nextScreen = AppScreenState.agent;
        break;
      case sdk.ConnectionState.disconnected:
        nextScreen = AppScreenState.welcome;
        break;
      case sdk.ConnectionState.connecting:
        nextScreen = null;
        break;
    }

    if (nextScreen != null && nextScreen != appScreenState) {
      appScreenState = nextScreen;
      notifyListeners();
    }
  }

  Future<String> _handleAgentFieldUpdate(sdk.RpcInvocationData data) async {
    try {
      final decoded = jsonDecode(data.payload);
      if (decoded is! Map<String, dynamic>) {
        return 'ignored: invalid payload';
      }
      final action = decoded['action']?.toString();
      if (action == 'profile_sync' || action == 'field_updated') {
        final fields = decoded['fields'];
        if (fields is Map<String, dynamic>) {
          final incoming = _coerceProfileFields(fields);
          if (action == 'profile_sync') {
            _profileFields
              ..clear()
              ..addAll(incoming);
          } else {
            _mergeProfileFields(incoming);
          }
        } else {
          final field = decoded['field']?.toString();
          final value = decoded['value']?.toString();
          if (field != null && field.isNotEmpty && value != null && value.isNotEmpty) {
            final existing = _profileFields[field] ?? <String>[];
            if (!existing.any((item) => item.toLowerCase() == value.toLowerCase())) {
              _profileFields[field] = [...existing, value];
            }
          }
        }
        notifyListeners();
      } else if (action == 'memory_cleared') {
        _profileFields.clear();
        notifyListeners();
      }
      return 'ok';
    } catch (error) {
      _logger.warning('Failed to process RPC payload: $error');
      return 'error: invalid payload';
    }
  }

  Map<String, List<String>> _coerceProfileFields(Map<String, dynamic> raw) {
    final result = <String, List<String>>{};
    raw.forEach((key, value) {
      if (value is List) {
        final values = value
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
        if (values.isNotEmpty) {
          result[key] = values;
        }
      } else if (value is String && value.trim().isNotEmpty) {
        result[key] = [value.trim()];
      }
    });
    return result;
  }

  void _mergeProfileFields(Map<String, List<String>> incoming) {
    incoming.forEach((key, values) {
      final existing = _profileFields[key] ?? <String>[];
      final seen = existing.map((item) => item.toLowerCase()).toSet();
      final merged = [...existing];
      for (final value in values) {
        final normalized = value.toLowerCase();
        if (seen.add(normalized)) {
          merged.add(value);
        }
      }
      _profileFields[key] = merged;
    });
  }

  
  Future<bool> requestProfileSync() async {
    final agentIdentity = roomContext.agentParticipant?.identity;
    if (agentIdentity == null || room.localParticipant == null) {
      return false;
    }
    try {
      final response = await room.localParticipant!.performRpc(
        sdk.PerformRpcParams(
          destinationIdentity: agentIdentity,
          method: 'client.requestProfileSync',
          payload: '{}',
        ),
      );
      return response == 'ok';
    } catch (error) {
      _logger.warning('Failed to request profile sync: $error');
      return false;
    }
  }
  static String _normalizeRecommendationLink(String rawLink) {
    final cleaned = _extractRecommendationUrl(rawLink).trim();
    if (cleaned.isEmpty) {
      return '';
    }
    if (RegExp(r'^(http|https)://', caseSensitive: false).hasMatch(cleaned)) {
      return cleaned;
    }
    return 'https://$cleaned';
  }

  static String _extractRecommendationUrl(String rawLink) {
    final cleaned = rawLink.trim();
    if (!cleaned.contains('|||')) {
      final match = RegExp(r'^(.*?)(?:,|\-|—)?\s*link\s+(.+)$', caseSensitive: false)
          .firstMatch(cleaned);
      if (match == null) {
        return cleaned;
      }
      final url = match.group(2)?.trim() ?? '';
      return url.isNotEmpty ? url : cleaned;
    }
    final parts = cleaned.split('|||');
    if (parts.length < 2) {
      return cleaned;
    }
    return parts.sublist(1).join('|||').trim();
  }

}

