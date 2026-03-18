import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:livekit_components/livekit_components.dart' as components;
import 'package:provider/provider.dart';

import '../controllers/app_ctrl.dart';
import '../support/agent_selector.dart';
import '../widgets/agent_layout_switcher.dart';
import '../widgets/camera_toggle_button.dart';

const String kAgentName = 'Kiefer';

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

                    return ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (Rect bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF002CF2),
                          Color(0x9A000000),
                        ],
                      ).createShader(bounds),
                      child: const components.AudioVisualizerWidget(
                        options: components.AudioVisualizerWidgetOptions(
                          barCount: 5,
                          width: 55,
                          minHeight: 55,
                          maxHeight: 320,
                          color: Color(0xFF000000),
                        ),
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
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFFF8FBFF),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF2F7FF), Color(0xFFE3EBF7)],
            ),
          ),
          child: OrientationBuilder(
            builder: (ctx, orientation) => Selector<AppCtrl, AgentLayoutState>(
              selector: (ctx, appCtrl) => AgentLayoutState(
                isTranscriptionVisible: appCtrl.agentScreenState == AgentScreenState.transcription,
                isCameraVisible: appCtrl.isUserCameEnabled,
                isScreenshareVisible: appCtrl.isScreenshareEnabled,
              ),
              builder: (ctx, agentLayoutState, child) => SizedBox.expand(
                child: Stack(
                  children: [
                    AgentLayoutSwitcher(
                      layoutMode:
                          orientation == Orientation.landscape ? AgentLayoutMode.landscape : AgentLayoutMode.portrait,
                      layoutState: agentLayoutState,
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
                      transcriptionsBuilder: (ctx) => orientation == Orientation.landscape
                          ? const _ChatPanelLandscape()
                          : const _ChatPanel(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: const [
            Expanded(
              child: _TranscriptionsCard(height: 430),
            ),
            SizedBox(height: 25),
            _ChatMessageBar(),
          ],
        ),
      ),
    );
  }
}

class _ChatPanelLandscape extends StatelessWidget {
  const _ChatPanelLandscape();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Expanded(
          child: _TranscriptionsCard(),
        ),
        SizedBox(height: 16),
        _ChatMessageBar(),
      ],
    );
  }
}

class _TranscriptionsCard extends StatelessWidget {
  const _TranscriptionsCard({this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    return Consumer<sdk.Session>(
      builder: (context, session, _) {
        final hasMessages = session.messages.isNotEmpty;
        return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      decoration: hasMessages
          ? BoxDecoration(
              color: const Color(0xFFDEF4FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30302F), width: 1),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Consumer<sdk.Session>(
            builder: (context, session, _) =>
                session.messages.isEmpty ? const SizedBox.shrink() : const _ProfilePanel(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => context.read<AppCtrl>().messageFocusNode.unfocus(),
              child: Consumer<sdk.Session>(
                builder: (context, session, _) {
                  if (session.messages.isEmpty) {
                    return const _AgentListeningPlaceholder();
                  }
                  return components.ChatScrollView(
                    session: session,
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    messageBuilder: (context, message) => Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                      child: _MessageBubble(message: message),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ProfileChip(
            dotColor: Color(0xFFFFFFFF),
            text: 'Your messages',
            textColor: Color(0xFFFFFFFF),
          ),
          SizedBox(height: 6),
          _ProfileChip(
            dotColor: Color(0xFF002CF2),
            text: 'Assistant: $kAgentName',
            textColor: Color(0xFFCCCCCC),
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final Color dotColor;
  final String text;
  final Color textColor;

  const _ProfileChip({
    required this.dotColor,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x464D5F54),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
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
    final alignment = Alignment.centerLeft;
    final background = isUser ? const Color(0xFFFFFFFF) : const Color(0xFF3D5A80);
    final foreground = isUser ? const Color(0xFF180000) : const Color(0xFFFFFFFF);

    return Align(
      alignment: alignment,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF30302F), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentListeningPlaceholder extends StatelessWidget {
  const _AgentListeningPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.graphic_eq, size: 32, color: Color(0xB33D5A80),),
          SizedBox(height: 12),
          Text(
            '$kAgentName is listening',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D2D2D),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChatMessageBar extends StatelessWidget {
  const _ChatMessageBar();

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: 60,
        child: Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 15, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFDEF4FF),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF30302F), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              offset: Offset(0, 12),
              blurRadius: 22,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Selector<AppCtrl, TextEditingController>(
                selector: (ctx, appCtrl) => appCtrl.messageCtrl,
                builder: (ctx, controller, _) => TextField(
                  controller: controller,
                  focusNode: ctx.read<AppCtrl>().messageFocusNode,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Message...',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF180000),
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Selector<AppCtrl, bool>(
              selector: (ctx, appCtx) => appCtx.isSendButtonEnabled,
              builder: (ctx, isSendEnabled, _) => GestureDetector(
                onTap: isSendEnabled ? () => ctx.read<AppCtrl>().sendMessage() : null,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D5A80),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.arrow_upward,
                    size: 20,
                    color: Colors.white,
                  ),
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
