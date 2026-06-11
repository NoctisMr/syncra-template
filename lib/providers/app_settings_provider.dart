import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class AppSettingsProvider extends ChangeNotifier {
  late Box settingsBox;
    late Box dataBox;
      final NumberFormat numFormat = NumberFormat('#,##0.00', 'en_US');

        ThemeMode themeMode = ThemeMode.light;
          Color seedColor = const Color(0xFF29B6F6);
            String language = 'es';
              bool isLoading = true;

                // Tasas globales y geolocalización
                  Map<String, double> tasasCambio = {
                      'USD': 1.0, 'BRL': 5.0, 'PEN': 3.7, 'EUR': 0.92, 
                          'VES': 36.5, 'MXN': 17.5, 'JPY': 155.0
                            };
                              int ultimaActualizacionEpoch = 0;
                                String monedaLocal = 'USD';
                                  String monedaRef = 'USD';

                                    // Configuración de Spread Financiero Global
                                      bool applySpread = false;
                                        final spreadCtrl = TextEditingController(text: "3.0");

                                          AppSettingsProvider() { _init(); }

                                            Future<void> _init() async {
                                                settingsBox = Hive.box('settingsBox');
                                                    dataBox = Hive.box('dataBox');
                                                        _loadSettings();
                                                            await sincronizarUbicacionYTasas();
                                                                isLoading = false;
                                                                    notifyListeners();
                                                                      }

                                                                        void _loadSettings() {
                                                                            themeMode = (settingsBox.get('isDark', defaultValue: false)) ? ThemeMode.dark : ThemeMode.light;
                                                                                seedColor = Color(settingsBox.get('themeColor', defaultValue: 0xFF29B6F6));
                                                                                    language = settingsBox.get('language', defaultValue: 'es');
                                                                                        monedaLocal = dataBox.get('monedaLocal', defaultValue: "USD");
                                                                                            monedaRef = dataBox.get('monedaRef', defaultValue: "USD");
                                                                                                ultimaActualizacionEpoch = dataBox.get('ultima_actualizacion_epoch', defaultValue: 0);
                                                                                                    applySpread = dataBox.get('apply_spread', defaultValue: false);
                                                                                                        spreadCtrl.text = dataBox.get('spread_value', defaultValue: "3.0");

                                                                                                            Map<dynamic, dynamic>? tasasJson = dataBox.get('tasas_historial');
                                                                                                                if (tasasJson != null) {
                                                                                                                      tasasJson.forEach((key, value) { 
                                                                                                                              if (tasasCambio.containsKey(key.toString())) tasasCambio[key.toString()] = (value as num).toDouble(); 
                                                                                                                                    });
                                                                                                                                        }
                                                                                                                                          }

                                                                                                                                            void updateSettings(ThemeMode tm, Color color, String lang) {
                                                                                                                                                settingsBox.put('isDark', tm == ThemeMode.dark);
                                                                                                                                                    settingsBox.put('themeColor', color.value);
                                                                                                                                                        settingsBox.put('language', lang);
                                                                                                                                                            themeMode = tm; seedColor = color; language = lang;
                                                                                                                                                                notifyListeners();
                                                                                                                                                                  }

                                                                                                                                                                    void toggleSpread(bool val) {
                                                                                                                                                                        applySpread = val;
                                                                                                                                                                            dataBox.put('apply_spread', val);
                                                                                                                                                                                notifyListeners();
                                                                                                                                                                                  }

                                                                                                                                                                                    void updateSpreadValue(String val) {
                                                                                                                                                                                        dataBox.put('spread_value', val);
                                                                                                                                                                                            notifyListeners();
                                                                                                                                                                                              }

                                                                                                                                                                                                void setMonedaLocal(String moneda) { 
                                                                                                                                                                                                    monedaLocal = moneda; 
                                                                                                                                                                                                        dataBox.put('monedaLocal', moneda);
                                                                                                                                                                                                            notifyListeners(); 
                                                                                                                                                                                                              }

                                                                                                                                                                                                                Future<void> sincronizarUbicacionYTasas() async {
                                                                                                                                                                                                                    final headers = { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' };
                                                                                                                                                                                                                        String codigoPais = ""; String monedaDetectada = "USD"; String paisDetectado = "Otros";

                                                                                                                                                                                                                            try {
                                                                                                                                                                                                                                  final loc = await http.get(Uri.parse('https://ipapi.co/json/'), headers: headers).timeout(const Duration(seconds: 5));
                                                                                                                                                                                                                                        if (loc.statusCode == 200) {
                                                                                                                                                                                                                                                final locData = jsonDecode(loc.body);
                                                                                                                                                                                                                                                        codigoPais = locData['country_code'] ?? '';
                                                                                                                                                                                                                                                                if (tasasCambio.containsKey(locData['currency'] ?? 'USD')) monedaDetectada = locData['currency'];
                                                                                                                                                                                                                                                                        
                                                                                                                                                                                                                                                                                if (codigoPais == 'BR') paisDetectado = 'Brasil'; else if (codigoPais == 'PE') paisDetectado = 'Perú';
                                                                                                                                                                                                                                                                                        else if (codigoPais == 'MX') paisDetectado = 'México'; else if (codigoPais == 'US') paisDetectado = 'EE.UU.';
                                                                                                                                                                                                                                                                                                else if (codigoPais == 'JP') paisDetectado = 'Japón'; else if (codigoPais == 'VE') paisDetectado = 'Venezuela';
                                                                                                                                                                                                                                                                                                        else if (['ES','FR','DE','IT','NL'].contains(codigoPais)) paisDetectado = 'Europa';
                                                                                                                                                                                                                                                                                                              }
                                                                                                                                                                                                                                                                                                                  } catch (_) {}

                                                                                                                                                                                                                                                                                                                      try {
                                                                                                                                                                                                                                                                                                                            final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD'), headers: headers).timeout(const Duration(seconds: 6));
                                                                                                                                                                                                                                                                                                                                  if (res.statusCode == 200) {
                                                                                                                                                                                                                                                                                                                                          final rates = jsonDecode(res.body)['rates'] as Map<String, dynamic>;
                                                                                                                                                                                                                                                                                                                                                  for (var m in tasasCambio.keys) { if (rates.containsKey(m)) tasasCambio[m] = (rates[m] as num).toDouble(); }
                                                                                                                                                                                                                                                                                                                                                          ultimaActualizacionEpoch = DateTime.now().millisecondsSinceEpoch;
                                                                                                                                                                                                                                                                                                                                                                  dataBox.put('ultima_actualizacion_epoch', ultimaActualizacionEpoch);
                                                                                                                                                                                                                                                                                                                                                                          dataBox.put('tasas_historial', tasasCambio);
                                                                                                                                                                                                                                                                                                                                                                                  
                                                                                                                                                                                                                                                                                                                                                                                          String ultimoPais = dataBox.get('ultimo_pais_code', defaultValue: "");
                                                                                                                                                                                                                                                                                                                                                                                                  if (codigoPais.isNotEmpty && codigoPais != ultimoPais) {
                                                                                                                                                                                                                                                                                                                                                                                                            monedaLocal = monedaDetectada; 
                                                                                                                                                                                                                                                                                                                                                                                                                      dataBox.put('monedaLocal', monedaDetectada);
                                                                                                                                                                                                                                                                                                                                                                                                                                dataBox.put('ultimo_pais_code', codigoPais);
                                                                                                                                                                                                                                                                                                                                                                                                                                        }
                                                                                                                                                                                                                                                                                                                                                                                                                                                notifyListeners();
                                                                                                                                                                                                                                                                                                                                                                                                                                                      }
                                                                                                                                                                                                                                                                                                                                                                                                                                                          } catch (_) {}
                                                                                                                                                                                                                                                                                                                                                                                                                                                            }
                                                                                                                                                                                                                                                                                                                                                                                                                                                            }
                                                                                                                                                                                                                                                                                                                                                                                                                                                         