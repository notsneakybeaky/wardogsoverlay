import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import './modules/mainpage/pages/drawing_screen_page.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();

  WindowOptions windowOptions = WindowOptions(
    fullScreen: true,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  //Code for hotkey globally without window having to be focused
  HotKey showWindow = HotKey(
    key: PhysicalKeyboardKey.keyQ,
    modifiers: [HotKeyModifier.alt],
    scope: HotKeyScope.system, // Set as inapp-wide hotkey.
  );
  await hotKeyManager.register(
    showWindow,
    keyDownHandler: (showWindow) async {
      var _focused = await windowManager.isVisible();
      if (_focused == false) {
        windowManager.show();
      } else {
        windowManager.hide();
      }
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wardoggie overlaii (furries are weird)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0x80202020), // 0x80 = 50% opacity, 202020 = light black
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(), // sharp square corners
          ),
        ),
      ),
      home: DrawingScreenPage(),
    );
  }
}