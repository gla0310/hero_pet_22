import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HeroPetApp());
}

class HeroPetApp extends StatelessWidget {
  const HeroPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hero pet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // دعم اللغة العربية واتجاه RTL في كل التطبيق (بما في ذلك DatePicker/TimePicker)
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }
}
