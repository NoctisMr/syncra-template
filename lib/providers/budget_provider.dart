import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BudgetProvider extends ChangeNotifier {
  late Box dataBox;

    final sueldoCtrl = TextEditingController();
      final nombreGastoCtrl = TextEditingController();
        final montoGastoCtrl = TextEditingController();

          List<Map<String, dynamic>> gastos = [];
            List<Map<String, dynamic>> bovedas = [];
              double balanceLocal = 0.0;
                double balanceEq = 0.0;

                  // Variables inyectadas de forma reactiva
                    Map<String, double> _tasasCambio = {};
                      String _monedaLocal = 'USD';
                        String _monedaRef = 'USD';

                          BudgetProvider() {
                              dataBox = Hive.box('dataBox');
                                  _cargarDatosLocales();
                                    }

                                      void _cargarDatosLocales() {
                                          sueldoCtrl.text = dataBox.get('sueldo', defaultValue: "");
                                              var gV2 = dataBox.get('gastos_v2');
                                                  if (gV2 != null) gastos = List<Map<String, dynamic>>.from(gV2.map((e) => Map<String, dynamic>.from(e)));
                                                      var bov = dataBox.get('bovedas');
                                                          if (bov != null) bovedas = List<Map<String, dynamic>>.from(bov.map((e) => Map<String, dynamic>.from(e)));
                                                            }

                                                              void _guardarDatos() {
                                                                  dataBox.putAll({
                                                                        'sueldo': sueldoCtrl.text,
                                                                              'gastos_v2': gastos,
                                                                                    'bovedas': bovedas
                                                                                        });
                                                                                          }

                                                                                            // Se ejecuta automáticamente cuando AppSettingsProvider cambia sus tasas o país
                                                                                              void updateDependencies(Map<String, double> tasas, String local, String ref) {
                                                                                                  _tasasCambio = tasas;
                                                                                                      _monedaLocal = local;
                                                                                                          _monedaRef = ref;
                                                                                                              calcularPresupuesto();
                                                                                                                }

                                                                                                                  void calcularPresupuesto() {
                                                                                                                      if (_tasasCambio.isEmpty) return;
                                                                                                                          double sueldo = double.tryParse(sueldoCtrl.text) ?? 0.0;
                                                                                                                              double totalGastosLocales = 0.0;
                                                                                                                                  for (var item in gastos) {
                                                                                                                                        double montoOriginal = (item['monto_original'] ?? item['monto'] as num).toDouble();
                                                                                                                                              String monedaOrig = item['moneda_original'] ?? _monedaLocal;
                                                                                                                                                    double valorEnUsd = montoOriginal / (_tasasCambio[monedaOrig] ?? 1.0);
                                                                                                                                                          double valorLocalCalculado = valorEnUsd * (_tasasCambio[_monedaLocal] ?? 1.0);
                                                                                                                                                                item['monto'] = valorLocalCalculado; 
                                                                                                                                                                      totalGastosLocales += valorLocalCalculado;
                                                                                                                                                                          }
                                                                                                                                                                              double totalEnBovedas = bovedas.fold(0.0, (sum, b) => sum + (b['ahorrado_local'] as num).toDouble());
                                                                                                                                                                                  balanceLocal = sueldo - totalGastosLocales - totalEnBovedas;
                                                                                                                                                                                      balanceEq = (balanceLocal / (_tasasCambio[_monedaLocal] ?? 1.0)) * (_tasasCambio[_monedaRef] ?? 1.0);
                                                                                                                                                                                          _guardarDatos();
                                                                                                                                                                                              notifyListeners();
                                                                                                                                                                                                }

                                                                                                                                                                                                  void addGasto(Map<String, dynamic> gasto) { gastos.insert(0, gasto); calcularPresupuesto(); }
                                                                                                                                                                                                    void deleteGasto(String id) { gastos.removeWhere((e) => e['id'] == id); calcularPresupuesto(); }
                                                                                                                                                                                                      
                                                                                                                                                                                                        void addBoveda(String nombre, double objetivo, String divisa) {
                                                                                                                                                                                                            bovedas.add({'id': DateTime.now().millisecondsSinceEpoch.toString(), 'nombre': nombre, 'monto_objetivo': objetivo, 'moneda_objetivo': divisa, 'ahorrado_local': 0.0});
                                                                                                                                                                                                                calcularPresupuesto();
                                                                                                                                                                                                                  }
                                                                                                                                                                                                                    
                                                                                                                                                                                                                      void deleteBoveda(String id) { bovedas.removeWhere((e) => e['id'] == id); calcularPresupuesto(); }
                                                                                                                                                                                                                        
                                                                                                                                                                                                                          void gestionarBoveda(String id, double monto, bool esAporte) {
                                                                                                                                                                                                                              int index = bovedas.indexWhere((b) => b['id'] == id);
                                                                                                                                                                                                                                  if (index != -1) {
                                                                                                                                                                                                                                        if (esAporte) bovedas[index]['ahorrado_local'] += monto;
                                                                                                                                                                                                                                              else if (bovedas[index]['ahorrado_local'] >= monto) bovedas[index]['ahorrado_local'] -= monto;
                                                                                                                                                                                                                                                    calcularPresupuesto();
                                                                                                                                                                                                                                                        }
                                                                                                                                                                                                                                                          }
                                                                                                                                                                                                                                                          }
                                                                                                                                                                                                                                                          