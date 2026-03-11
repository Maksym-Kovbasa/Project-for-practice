import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:livekit_components/livekit_components.dart' as components;
import 'package:provider/provider.dart';

import '../controllers/app_ctrl.dart';
import '../support/agent_selector.dart';
import '../ui/color_pallette.dart';
import '../widgets/agent_layout_switcher.dart';
import '../widgets/camera_toggle_button.dart';
import '../widgets/message_bar.dart';
import 'links_screen.dart';
import 'remembered_data_screen.dart';

class AgentTrackView extends StatelessWidget {
  const AgentTrackView({super.key});

  @override
  Widget build(BuildContext context) => AgentParticipantSelector(
        builder: (ctx, agentParticipant) => Selector<components.ParticipantContext?, sdk.TrackPublication?>(
          selector: (ctx, agentCtx) {
            final videoTrack = agentCtx?.tracks.where((t) => t.kind == sdk.TrackType.VIDEO).firstOrNull;
            final audioTrack = agentCtx?.tracks.where((t) => t.kind == sdk.TrackType.AUDIO).firstOrNull;
            // Prioritize video track
            return videoTrack ?? audioTrack;
          },
          builder: (ctx, mediaTrack, child) => ChangeNotifierProvider<components.TrackReferenceContext?>.value(
            value:
                agentParticipant == null ? null : components.TrackReferenceContext(agentParticipant, pub: mediaTrack),
            child: Builder(
              builder: (ctx) => Container(
                // color: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 50),
                alignment: Alignment.center,
                child: Container(
                  // color: Colors.blue,
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: Builder(builder: (ctx) {
                    final trackReferenceContext = ctx.watch<components.TrackReferenceContext?>();
                    // Switch according to video or audio

                    if (trackReferenceContext?.isVideo ?? false) {
                      return const components.VideoTrackWidget();
                    }

                    return const components.AudioVisualizerWidget(
                      options: components.AudioVisualizerWidgetOptions(
                        barCount: 5,
                        width: 32,
                        minHeight: 32,
                        maxHeight: 320,
                        // color: Theme.of(ctx).colorScheme.primary,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      );
}

class FrontView extends StatelessWidget {
  final AgentScreenState screenState;

  const FrontView({
    super.key,
    required this.screenState,
  });

  @override
  Widget build(BuildContext context) => components.MediaDeviceContextBuilder(
        builder: (context, roomCtx, mediaDeviceCtx) => Row(
          spacing: 20,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Flexible(
              flex: 2,
              fit: FlexFit.tight,
              child: AgentTrackView(),
            ),
            if (screenState == AgentScreenState.transcription && mediaDeviceCtx.cameraOpened)
              Flexible(
                fit: FlexFit.tight,
                child: AnimatedOpacity(
                  opacity: (screenState == AgentScreenState.transcription && mediaDeviceCtx.cameraOpened) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
                    child: components.ParticipantSelector(
                      filter: (identifier) => identifier.isVideo && identifier.isLocal,
                      builder: (context, identifier) => components.VideoTrackWidget(
                        fit: sdk.VideoViewFit.cover,
                        noTrackBuilder: (ctx) => Container(color: Theme.of(ctx).cardColor),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class AgentScreen extends StatelessWidget {
  const AgentScreen({super.key});

  @override
  Widget build(BuildContext ctx) => Scaffold(
        backgroundColor: const Color(0xFFF8FBFF),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF2F7FF), Color(0xFFE3EBF7)],
            ),
          ),
          child: Selector<AppCtrl, AgentLayoutState>(
          selector: (ctx, appCtrl) => AgentLayoutState(
            isTranscriptionVisible: appCtrl.agentScreenState == AgentScreenState.transcription,
            isCameraVisible: appCtrl.isUserCameEnabled,
            isScreenshareVisible: appCtrl.isScreenshareEnabled,
          ),
          builder: (ctx, agentLayoutState, child) => SizedBox.expand(
            child: Stack(
              children: [
                AgentLayoutSwitcher(
                  layoutState: agentLayoutState,
                  // agentViewBuilder: (ctx) => AgentTrackView(),
                  buildAgentView: (ctx) => const AgentTrackView(),
                  buildCameraView: (ctx) => Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: components.MediaDeviceContextBuilder(
                      builder: (context, roomCtx, mediaDeviceCtx) => components.ParticipantSelector(
                        filter: (identifier) => identifier.isVideo && identifier.isLocal,
                        builder: (context, identifier) => Stack(
                          children: [
                            components.VideoTrackWidget(
                              fit: sdk.VideoViewFit.cover,
                              noTrackBuilder: (ctx) => Container(color: Theme.of(ctx).cardColor),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: CameraToggleButton(
                                onTap: () => mediaDeviceCtx.toggleCameraPosition(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  buildScreenShareView: (ctx) => Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                    child: const Text('Screenshare View'),
                  ),
                  transcriptionsBuilder: (ctx) => Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => ctx.read<AppCtrl>().messageFocusNode.unfocus(),
                          child: Consumer<sdk.Session>(
                            builder: (context, session, _) {
                              if (session.messages.isEmpty) {
                                return _AgentListeningPlaceholder(canListen: session.agent.canListen);
                              }
                              return components.ChatScrollView(
                                session: session,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                physics: const BouncingScrollPhysics(),
                                messageBuilder: (context, message) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _MessageBubble(message: message),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: max(0, MediaQuery.of(ctx).viewInsets.bottom - 80)),
                        child: Selector<AppCtrl, bool>(
                          selector: (ctx, appCtx) => appCtx.isSendButtonEnabled,
                          builder: (ctx, isSendEnabled, child) => MessageBar(
                            focusNode: ctx.read<AppCtrl>().messageFocusNode,
                            isSendEnabled: isSendEnabled,
                            controller: ctx.read<AppCtrl>().messageCtrl,
                            onSendTap: () => ctx.read<AppCtrl>().sendMessage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 26,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Selector<AppCtrl, Map<String, List<String>>>(
                        selector: (ctx, appCtrl) => appCtrl.profileFields,
                        builder: (ctx, fields, _) {
                          // Count all entries except the links array
                          final count = fields.keys.where((k) => k != 'recommended_links').length;
                          final theme = Theme.of(ctx);
                          final palette = theme.brightness == Brightness.light ? LKColorPaletteLight() : LKColorPaletteDark();
                          return ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              shape: const StadiumBorder(),
                              elevation: 2,
                              backgroundColor: count > 0 ? const Color(0xFFD6E4FF) : palette.bg2,
                              foregroundColor: count > 0 ? const Color(0xFF002CF2) : palette.fg0,
                            ),
                            icon: const Icon(Icons.storage_rounded),
                            label: Text(count > 0 ? 'Remembered ($count)' : 'Remembered'),
                            onPressed: count == 0
                                ? null
                                : () => Navigator.of(ctx).push(
                                      MaterialPageRoute(builder: (_) => const RememberedDataScreen()),
                                    ),
                          );
                        },
                      ),
                      Selector<AppCtrl, List<String>>(
                        selector: (ctx, appCtrl) => appCtrl.profileFields['recommended_links'] ?? [],
                        builder: (ctx, links, _) {
                          final theme = Theme.of(ctx);
                          final palette = theme.brightness == Brightness.light ? LKColorPaletteLight() : LKColorPaletteDark();
                          return ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              shape: const StadiumBorder(),
                              elevation: 2,
                              backgroundColor: links.isNotEmpty ? const Color(0xFFD6E4FF) : palette.bg2,
                              foregroundColor: links.isNotEmpty ? const Color(0xFF002CF2) : palette.fg0,
                            ),
                            icon: const Icon(Icons.link),
                            label: Text(links.isNotEmpty ? 'Links (${links.length})' : 'Links'),
                            onPressed: links.isEmpty
                                ? null
                                : () => Navigator.of(ctx).push(
                                      MaterialPageRoute(builder: (_) => const LinksScreen()),
                                    ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final sdk.ReceivedMessage message;

  bool get _isUserMessage => message.content is sdk.UserInput || message.content is sdk.UserTranscript;

  @override
  Widget build(BuildContext context) {
    final text = message.content.text.trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isUser = _isUserMessage;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final colorScheme = Theme.of(context).colorScheme;
    final background = isUser ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final foreground = isUser ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentListeningPlaceholder extends StatelessWidget {
  const _AgentListeningPlaceholder({required this.canListen});

  final bool canListen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq, size: 32, color: colorScheme.primary.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text(
            'Agent is listening',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (!canListen)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Start a conversation to see messages here.',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
