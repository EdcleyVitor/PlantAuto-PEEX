import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'services/bluetooth_service.dart';
import 'services/plantacao_store.dart';
import 'services/settings_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsManager.instance.carregar();
  await PlantacaoStore.instance.carregar();
  BluetoothService.instance.init();
  BluetoothService.instance.carregarPersistenciaGlobal();
  runApp(const PlantAutoApp());
}

class PlantAutoApp extends StatelessWidget {
  const PlantAutoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsManager.instance,
      builder: (context, _) {
        final settings = SettingsManager.instance;
        return MaterialApp(
          title: 'PlantAuto PEEX',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: _buildTheme(Brightness.light, settings.fonte),
          darkTheme: _buildTheme(Brightness.dark, settings.fonte),
          home: const HomeScreen(),
        );
      },
    );
  }

  TextTheme _aplicarFonte(TextTheme base, String fonte) {
    switch (fonte) {
      case 'Poppins':
        return GoogleFonts.poppinsTextTheme(base);
      case 'Roboto':
        return GoogleFonts.robotoTextTheme(base);
      case 'Montserrat':
        return GoogleFonts.montserratTextTheme(base);
      case 'Lora':
        return GoogleFonts.loraTextTheme(base);
      case 'Playfair Display':
        return GoogleFonts.playfairDisplayTextTheme(base);
      default:
        return base;
    }
  }

  ThemeData _buildTheme(Brightness brightness, String fonte) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: brightness,
    ).copyWith(
      primary: isDark ? const Color(0xFF43A047) : const Color(0xFF2E7D32),
      secondary: isDark ? const Color(0xFF1E88E5) : const Color(0xFF1565C0),
    );
    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
    return base.copyWith(
      textTheme: _aplicarFonte(base.textTheme, fonte),
    );
  }
}
