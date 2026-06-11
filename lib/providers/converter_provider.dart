import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ConverterProvider extends ChangeNotifier {
  late Box dataBox;
    final convMontoCtrl = TextEditingController();

      String monedaDe = 'USD';
        String monedaA = 'USD';
          double resultadoConversion = 0.0;

            Map<String, double> _tasasCambio = {};
              bool _applySpread = false;
                double _spreadPercent = 0.0;

                  ConverterProvider() {
                      dataBox = Hive.box('dataBox');
                          _cargarDatosLocales();
                            }

                              void _cargarDatosLocales() {
                                  monedaDe = dataBox.get('monedaDe', defaultValue: "USD");
                                      monedaA = dataBox.get('monedaA', defaultValue: "USD");
                                        }

                                          void _guardarDatos() {
                                              dataBox.putAll({'monedaDe': monedaDe, 'monedaA': monedaA});
                                                }

                                                  void updateDependencies(Map<String, double> tasas, bool applySpread, double spreadPercent) {
                                                      _tasasCambio = tasas;
                                                          _applySpread = applySpread;
                                                              _spreadPercent = spreadPercent;
                                                                  calcularConversion();
                                                                    }

                                                                      void setMonedasConversor(String de, String a) { monedaDe = de; monedaA = a; calcularConversion(); }

                                                                        void calcularConversion() {
                                                                            if (_tasasCambio.isEmpty) return;
                                                                                double monto = double.tryParse(convMontoCtrl.text) ?? 0.0;
                                                                                    double montoUsd = monto / (_tasasCambio[monedaDe] ?? 1.0);
                                                                                        double conversionBase = montoUsd * (_tasasCambio[monedaA] ?? 1.0);
                                                                                            resultadoConversion = (_applySpread && _spreadPercent > 0) ? conversionBase * (1 + (_spreadPercent / 100)) : conversionBase;
                                                                                                _guardarDatos();
                                                                                                    notifyListeners();
                                                                                                      }

                                                                                                        Future<void> copiarResultado(String num, BuildContext context) async {
                                                                                                            if (num.isNotEmpty) {
                                                                                                                  await Clipboard.setData(ClipboardData(text: num));
                                                                                                                        HapticFeedback.lightImpact();
                                                                                                                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado')));
                                                                                                                                  }
                                                                                                                                    }
                                                                                                                                    }
                                                                                                                                    