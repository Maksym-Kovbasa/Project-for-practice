import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:livekit_components/livekit_components.dart' as components;
import 'package:provider/provider.dart';

import '../app.dart';
import '../controllers/app_ctrl.dart' show AppCtrl, AgentScreenState;
import '../screens/links_screen.dart';
import '../screens/remembered_data_screen.dart';

class ControlBar extends StatelessWidget {
  const ControlBar({super.key, this.iconTurns = 0});

  final int iconTurns;

  @override
  Widget build(BuildContext ctx) => Container(
        height: 60,
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDEF4FF),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF30302F)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 22,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            components.MediaDeviceContextBuilder(
              builder: (context, roomCtx, mediaDeviceCtx) {
                final appCtrl = context.read<AppCtrl>();
                final isMicEnabled = mediaDeviceCtx.microphoneOpened;
                return _PanelButton(
                  color: const Color(0xFF3D8059),
                  icon: isMicEnabled ? Icons.mic : Icons.mic_off,
                  iconTurns: iconTurns,
                  onTap: () {
                    final shouldEnable = !isMicEnabled;
                    if (shouldEnable) {
                      mediaDeviceCtx.enableMicrophone();
                    } else {
                      mediaDeviceCtx.disableMicrophone();
                    }
                    appCtrl.room.localParticipant?.setMicrophoneEnabled(shouldEnable);
                  },
                );
              },
            ),
            _PanelButton(
              color: const Color(0xFF3D5A80),
              icon: Icons.storage_rounded,
              iconTurns: iconTurns,
              onTap: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const RememberedDataScreen()),
              ),
            ),
            _PanelButton(
              color: const Color(0xFF3D5A80),
              icon: Icons.link,
              iconTurns: iconTurns,
              onTap: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const LinksScreen()),
              ),
            ),
            Selector<AppCtrl, AgentScreenState>(
              selector: (ctx, appCtx) => appCtx.agentScreenState,
              builder: (context, agentScreenState, child) => _PanelButton(
                color: const Color(0xFF3D5A80),
                icon: Icons.chat_bubble_rounded,
                iconTurns: iconTurns,
                width: 39,
                onTap: () => ctx.read<AppCtrl>().toggleAgentScreenMode(),
              ),
            ),
            Consumer2<AppCtrl, sdk.Session>(
              builder: (context, appCtrlState, session, _) {
                final isDisconnected = session.connectionState == sdk.ConnectionState.disconnected;
                return _PanelButton(
                  color: const Color(0xFFA62525),
                  icon: isDisconnected ? Icons.call : Icons.call_end,
                  iconTurns: iconTurns,
                  onTap: () => isDisconnected ? appCtrlState.connect() : appCtrlState.disconnect(),
                );
              },
            ),
          ],
        ),
      );
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.color,
    required this.icon,
    required this.onTap,
    this.iconTurns = 0,
    this.width = 40,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final int iconTurns;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: 40,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: RotatedBox(
              quarterTurns: iconTurns,
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
}
