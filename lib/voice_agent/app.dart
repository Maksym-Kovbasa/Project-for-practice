import 'package:flutter/material.dart';
import 'package:livekit_components/livekit_components.dart' as components;
import 'package:provider/provider.dart';

import 'controllers/app_ctrl.dart';
import 'screens/agent_screen.dart';
import 'ui/color_pallette.dart' show LKColorPaletteLight, LKColorPaletteDark;
import 'widgets/session_error_banner.dart';

AppCtrl? _appCtrl;

// Lazily create the controller so dotenv is already loaded by main().
AppCtrl get appCtrl => _appCtrl ??= AppCtrl();

class VoiceAssistantApp extends StatefulWidget {
  const VoiceAssistantApp({super.key});

  @override
  State<VoiceAssistantApp> createState() => _VoiceAssistantAppState();
}

class _VoiceAssistantAppState extends State<VoiceAssistantApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appCtrl.connect();
    });
  }

  @override
  void dispose() {
    _appCtrl?.dispose();
    _appCtrl = null;
    super.dispose();
  }

  ThemeData buildTheme({required bool isLight}) {
    final colorPallete = isLight ? LKColorPaletteLight() : LKColorPaletteDark();

    return ThemeData(
      useMaterial3: true,
      cardColor: colorPallete.bg2,
      scaffoldBackgroundColor: colorPallete.bg1,
      canvasColor: colorPallete.bg1,
      inputDecorationTheme: InputDecorationTheme(
        fillColor: colorPallete.bg2,
        hintStyle: TextStyle(
          color: colorPallete.fg4,
          fontSize: 14,
        ),
      ),
      buttonTheme: ButtonThemeData(
        disabledColor: Colors.red,
        colorScheme: ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white,
          surface: colorPallete.fgAccent,
        ),
      ),
      colorScheme: isLight
          ? const ColorScheme.light(
              primary: Colors.black,
              secondary: Colors.black,
              surface: Colors.white,
            )
          : const ColorScheme.dark(
              primary: Colors.white,
              secondary: Colors.white,
              surface: Colors.black,
            ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appCtrl),
          ChangeNotifierProvider.value(value: appCtrl.session),
          ChangeNotifierProvider.value(value: appCtrl.roomContext),
        ],
        child: components.SessionContext(
          session: appCtrl.session,
          child: MaterialApp(
            title: 'K Assistant',
            theme: buildTheme(isLight: true),
            darkTheme: buildTheme(isLight: false),
            home: Builder(
              builder: (ctx) => Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: const Stack(
                    children: [
                      AgentScreen(),
                      SessionErrorBanner(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
