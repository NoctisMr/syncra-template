import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'providers/syncra_provider.dart';
import 'translations.dart';
import 'tabs/presupuesto_tab.dart';
import 'tabs/conversor_tab.dart';
import 'tabs/envios_tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settingsBox');
  await Hive.openBox('dataBox');
  
  // Inyectamos el Provider en la raíz de la app
  runApp(
    ChangeNotifierProvider(
      create: (_) => SyncraProvider(),
      child: const SyncraApp(),
    ),
  );
}

class SyncraApp extends StatelessWidget {
  const SyncraApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios del Provider
    final provider = context.watch<SyncraProvider>();

    if (provider.isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Syncra',
      debugShowCheckedModeBanner: false,
      themeMode: provider.themeMode,
      theme: ThemeData(
        useMaterial3: true, 
        colorScheme: ColorScheme.fromSeed(seedColor: provider.seedColor, brightness: Brightness.light)
      ),
      darkTheme: ThemeData(
        useMaterial3: true, 
        colorScheme: ColorScheme.fromSeed(seedColor: provider.seedColor, brightness: Brightness.dark)
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late PageController _pageController; 
  
  final List<Color> themeColors = [
    const Color(0xFF29B6F6), const Color(0xFF81C784), const Color(0xFFBA68C8),
    const Color(0xFFFF8A65), const Color(0xFFF06292), const Color(0xFF90A4AE),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _abrirAjustes() {
    final provider = context.read<SyncraProvider>();
    String t(String key) => i18n[provider.language]?[key] ?? key;

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        // Usamos Consumer para que el BottomSheet se actualice si cambian los ajustes
        return Consumer<SyncraProvider>(
          builder: (context, currentProvider, child) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('settings'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t('language'), style: const TextStyle(fontSize: 16)),
                      DropdownButton<String>(
                        value: currentProvider.language,
                        items: const [ 
                          DropdownMenuItem(value: 'es', child: Text("Español")), 
                          DropdownMenuItem(value: 'en', child: Text("English")),
                          DropdownMenuItem(value: 'pt', child: Text("Português (BR)"))
                        ],
                        onChanged: (val) {
                          currentProvider.updateSettings(currentProvider.themeMode, currentProvider.seedColor, val!);
                        },
                      )
                    ],
                  ),
                  SwitchListTile(
                    title: Text(t('dark_mode')), 
                    value: currentProvider.themeMode == ThemeMode.dark, 
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) { 
                      currentProvider.updateSettings(val ? ThemeMode.dark : ThemeMode.light, currentProvider.seedColor, currentProvider.language); 
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(t('theme_color'), style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: themeColors.map((color) => GestureDetector(
                        onTap: () {
                          currentProvider.updateSettings(currentProvider.themeMode, color, currentProvider.language);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12), width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle,
                            border: Border.all(color: currentProvider.seedColor == color ? Colors.black54 : Colors.transparent, width: 3),
                          ),
                        ),
                      )).toList(),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SyncraProvider>();
    String t(String key) => i18n[provider.language]?[key] ?? key;

    return Scaffold(
      appBar: AppBar(
        title: null, 
        elevation: 0, 
        backgroundColor: Colors.transparent, 
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0), 
            child: IconButton(icon: const Icon(Icons.palette), onPressed: _abrirAjustes)
          )
        ]
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: PageView(
          controller: _pageController, 
          physics: const ClampingScrollPhysics(), 
          onPageChanged: (index) { setState(() { _currentIndex = index; }); },
          children: const [ 
            // Las Tabs ya no necesitan recibir 20 parámetros. Solo se instancian.
            PresupuestoTab(),
            ConversorTab(),
            EnviosTab()
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, 
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: (index) { _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic); },
        items: [ 
          BottomNavigationBarItem(icon: const Icon(Icons.account_balance_wallet), label: t('budget')), 
          BottomNavigationBarItem(icon: const Icon(Icons.currency_exchange), label: t('converter')), 
          BottomNavigationBarItem(icon: const Icon(Icons.local_shipping), label: t('shipping')) 
        ],
      ),
    );
  }
}
