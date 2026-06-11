import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

class SyncraProvider extends ChangeNotifier {
  late Box dataBox;
  late Box settingsBox;
  final NumberFormat numFormat = NumberFormat('#,##0.00', 'en_US');

  // --- CONFIGURACIÓN ---
  ThemeMode themeMode = ThemeMode.light;
  Color seedColor = const Color(0xFF29B6F6);
  String language = 'es';
  bool isLoading = true;

  // --- CONTROLADORES DE TEXTO GLOBALES ---
  final sueldoCtrl = TextEditingController();
  final nombreGastoCtrl = TextEditingController();
  final montoGastoCtrl = TextEditingController();
  final convMontoCtrl = TextEditingController();
  final spreadCtrl = TextEditingController(text: "3.0");
  final precioEnvioCtrl = TextEditingController();
  final pesoEnvioCtrl = TextEditingController();
  final proxyCostoCtrl = TextEditingController(text: "5.0");

  // --- TASAS DE CAMBIO ---
  Map<String, double> tasasCambio = {
    'USD': 1.0, 'BRL': 5.0, 'PEN': 3.7, 'EUR': 0.92, 
    'VES': 36.5, 'MXN': 17.5, 'JPY': 155.0
  };
  int ultimaActualizacionEpoch = 0;

  // --- VARIABLES PRESUPUESTO ---
  String monedaLocal = 'USD';
  String monedaRef = 'USD';
  List<Map<String, dynamic>> gastos = [];
  List<Map<String, dynamic>> bovedas = [];
  double balanceLocal = 0.0;
  double balanceEq = 0.0;

  // --- VARIABLES CONVERSOR ---
  bool applySpread = false;
  String monedaDe = 'USD';
  String monedaA = 'USD';
  double resultadoConversion = 0.0;

  // --- VARIABLES ENVÍOS ---
  String monedaProxy = 'USD';
  String origenEnvio = 'Japón';
  String destinoEnvio = 'Brasil';
  String monedaOrigenEnvio = 'USD';
  String monedaDestinoEnvio = 'USD';
  String desgloseEnvio = "Ingresa datos para calcular...";
  double totalEnvio = 0.0;
  List<Map<String, dynamic>> cotizaciones = [];

  final Map<String, Map<String, dynamic>> taxRules = {
    'Brasil': { 'limit': 50.0, 'under_limit_tax': 0.20, 'over_limit_tax': 0.60, 'state_tax_icms': 0.17 },
    'Perú': { 'limit': 200.0, 'under_limit_tax': 0.0, 'over_limit_tax': 0.22, 'state_tax_icms': 0.0 },
    'México': { 'limit': 50.0, 'under_limit_tax': 0.0, 'over_limit_tax': 0.19, 'state_tax_icms': 0.0 },
    'EE.UU.': { 'limit': 800.0, 'under_limit_tax': 0.0, 'over_limit_tax': 0.10, 'state_tax_icms': 0.0 },
    'Europa': { 'limit': 150.0, 'under_limit_tax': 0.21, 'over_limit_tax': 0.235, 'state_tax_icms': 0.0 },
    'Japón': { 'limit': 0.0, 'under_limit_tax': 0.10, 'over_limit_tax': 0.10, 'state_tax_icms': 0.0 },
    'Venezuela': { 'limit': 0.0, 'under_limit_tax': 0.30, 'over_limit_tax': 0.30, 'state_tax_icms': 0.0 },
  };

  SyncraProvider() { _init(); }

  Future<void> _init() async {
    dataBox = Hive.box('dataBox');
    settingsBox = Hive.box('settingsBox');
    _loadSettings();
    _cargarDatosLocales();
    await sincronizarUbicacionYTasas();
    isLoading = false;
    notifyListeners();
  }

  // --- MÉTODOS DE CONFIGURACIÓN ---
  void _loadSettings() {
    themeMode = (settingsBox.get('isDark', defaultValue: false)) ? ThemeMode.dark : ThemeMode.light;
    seedColor = Color(settingsBox.get('themeColor', defaultValue: 0xFF29B6F6));
    language = settingsBox.get('language', defaultValue: 'es');
  }

  void updateSettings(ThemeMode tm, Color color, String lang) {
    settingsBox.put('isDark', tm == ThemeMode.dark);
    settingsBox.put('themeColor', color.value);
    settingsBox.put('language', lang);
    themeMode = tm; seedColor = color; language = lang;
    notifyListeners();
  }

  void _guardarDatos() {
    dataBox.putAll({
      'sueldo': sueldoCtrl.text, 'monedaLocal': monedaLocal, 'monedaRef': monedaRef,
      'monedaDe': monedaDe, 'monedaA': monedaA, 'proxyCosto': proxyCostoCtrl.text,
      'monedaProxy': monedaProxy, 'destinoEnvio': destinoEnvio, 'monedaDestinoEnvio': monedaDestinoEnvio,
      'apply_spread': applySpread, 'spread_value': spreadCtrl.text, 'gastos_v2': gastos,
      'bovedas': bovedas, 'cotizaciones': cotizaciones
    });
  }

  void _cargarDatosLocales() {
    sueldoCtrl.text = dataBox.get('sueldo', defaultValue: "");
    monedaLocal = dataBox.get('monedaLocal', defaultValue: "USD");
    monedaRef = dataBox.get('monedaRef', defaultValue: "USD");
    monedaDe = dataBox.get('monedaDe', defaultValue: "USD");
    monedaA = dataBox.get('monedaA', defaultValue: "USD");
    proxyCostoCtrl.text = dataBox.get('proxyCosto', defaultValue: "5.0");
    monedaProxy = dataBox.get('monedaProxy', defaultValue: "USD");
    destinoEnvio = dataBox.get('destinoEnvio', defaultValue: "Brasil");
    monedaDestinoEnvio = dataBox.get('monedaDestinoEnvio', defaultValue: "USD");
    ultimaActualizacionEpoch = dataBox.get('ultima_actualizacion_epoch', defaultValue: 0);
    applySpread = dataBox.get('apply_spread', defaultValue: false);
    spreadCtrl.text = dataBox.get('spread_value', defaultValue: "3.0");

    var gV2 = dataBox.get('gastos_v2');
    if (gV2 != null) gastos = List<Map<String, dynamic>>.from(gV2.map((e) => Map<String, dynamic>.from(e)));

    var bov = dataBox.get('bovedas');
    if (bov != null) bovedas = List<Map<String, dynamic>>.from(bov.map((e) => Map<String, dynamic>.from(e)));

    var cot = dataBox.get('cotizaciones');
    if (cot != null) cotizaciones = List<Map<String, dynamic>>.from(cot.map((e) => Map<String, dynamic>.from(e)));

    Map<dynamic, dynamic>? tasasJson = dataBox.get('tasas_historial');
    if (tasasJson != null) {
      tasasJson.forEach((key, value) { if (tasasCambio.containsKey(key.toString())) tasasCambio[key.toString()] = (value as num).toDouble(); });
    }
    recalcularTodo();
  }

    Future<void> sincronizarUbicacionYTasas() async {
    // Aquí mantenemos tu lógica exacta de geolocalización y er-api
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
        
        String ultimoPais = dataBox.get('ultimo_pais_code', defaultValue: "");
        if (codigoPais.isNotEmpty && codigoPais != ultimoPais) {
          monedaLocal = monedaDetectada; monedaDe = monedaDetectada; 
          destinoEnvio = paisDetectado; monedaDestinoEnvio = monedaDetectada;
          dataBox.put('ultimo_pais_code', codigoPais);
        }
        recalcularTodo();
      }
    } catch (_) {}
  }

  void recalcularTodo() {
    calcularPresupuesto();
    calcularConversion();
    calcularEnvio();
  }

  // --- LÓGICA PRESUPUESTO ---
  void calcularPresupuesto() {
    double sueldo = double.tryParse(sueldoCtrl.text) ?? 0.0;
    double totalGastosLocales = 0.0;
    for (var item in gastos) {
      double montoOriginal = (item['monto_original'] ?? item['monto'] as num).toDouble();
      String monedaOrig = item['moneda_original'] ?? monedaLocal;
      double valorEnUsd = montoOriginal / (tasasCambio[monedaOrig] ?? 1.0);
      double valorLocalCalculado = valorEnUsd * (tasasCambio[monedaLocal] ?? 1.0);
      item['monto'] = valorLocalCalculado; totalGastosLocales += valorLocalCalculado;
    }
    double totalEnBovedas = bovedas.fold(0.0, (sum, b) => sum + (b['ahorrado_local'] as num).toDouble());
    balanceLocal = sueldo - totalGastosLocales - totalEnBovedas;
    balanceEq = (balanceLocal / (tasasCambio[monedaLocal] ?? 1.0)) * (tasasCambio[monedaRef] ?? 1.0);
    _guardarDatos();
    notifyListeners();
  }

  void setMonedaLocal(String moneda) { monedaLocal = moneda; calcularPresupuesto(); }
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

  // --- LÓGICA CONVERSOR ---
  void toggleSpread(bool val) { applySpread = val; recalcularTodo(); }
  
  void setMonedasConversor(String de, String a) { monedaDe = de; monedaA = a; calcularConversion(); }

  void calcularConversion() {
    double monto = double.tryParse(convMontoCtrl.text) ?? 0.0;
    double montoUsd = monto / (tasasCambio[monedaDe] ?? 1.0);
    double conversionBase = montoUsd * (tasasCambio[monedaA] ?? 1.0);
    double spreadPercent = double.tryParse(spreadCtrl.text) ?? 0.0;
    resultadoConversion = (applySpread && spreadPercent > 0) ? conversionBase * (1 + (spreadPercent / 100)) : conversionBase;
    _guardarDatos();
    notifyListeners();
  }

  // --- LÓGICA ENVÍOS ---
  void updateEnvioParams({String? mProxy, String? origen, String? destino, String? mOrigen, String? mDestino}) {
    if (mProxy != null) monedaProxy = mProxy;
    if (origen != null) origenEnvio = origen;
    if (destino != null) destinoEnvio = destino;
    if (mOrigen != null) monedaOrigenEnvio = mOrigen;
    if (mDestino != null) monedaDestinoEnvio = mDestino;
    calcularEnvio();
  }

  void calcularEnvio() {
    double precioOrigen = double.tryParse(precioEnvioCtrl.text) ?? 0.0;
    double pesoKg = double.tryParse(pesoEnvioCtrl.text) ?? 0.0;
    double costoProxyInput = double.tryParse(proxyCostoCtrl.text) ?? 0.0;

    if (precioOrigen == 0 && pesoKg == 0) {
      desgloseEnvio = "Ingresa datos para calcular..."; totalEnvio = 0.0;
      notifyListeners(); return;
    }

    double precioUsd = precioOrigen / (tasasCambio[monedaOrigenEnvio] ?? 1.0);
    double proxyFeeUsd = costoProxyInput / (tasasCambio[monedaProxy] ?? 1.0);
    double costoEnvioUsd = 0.0;
    
    if (origenEnvio == 'Nacional') costoEnvioUsd = 4.0 + (pesoKg * 2.5);
    else if (origenEnvio == 'China') costoEnvioUsd = 3.0 + (pesoKg * 15.0);
    else if (origenEnvio == 'EE.UU.') costoEnvioUsd = 12.0 + (pesoKg * 9.0);
    else if (origenEnvio == 'Japón') costoEnvioUsd = 15.0 + (pesoKg * 22.0);
    else if (origenEnvio == 'Europa') costoEnvioUsd = 14.0 + (pesoKg * 18.0);

    double baseCif = precioUsd + costoEnvioUsd + proxyFeeUsd;
    var rule = taxRules[destinoEnvio] ?? { 'limit': 0.0, 'under_limit_tax': 0.30, 'over_limit_tax': 0.30, 'state_tax_icms': 0.0 };
    double baseTaxRate = precioUsd <= rule['limit'] ? rule['under_limit_tax'] : rule['over_limit_tax'];
    double federalTaxUsd = baseCif * baseTaxRate;
    double baseWithFederal = baseCif + federalTaxUsd;
    
    double impuestoUsd = rule['state_tax_icms'] > 0 ? (baseWithFederal / (1 - rule['state_tax_icms'])) - baseCif : federalTaxUsd;
    double totalUsd = baseCif + impuestoUsd;
    double spreadPercent = double.tryParse(spreadCtrl.text) ?? 0.0;
    
    double totalBaseFinal = totalUsd * (tasasCambio[monedaDestinoEnvio] ?? 1.0);
    totalEnvio = (applySpread && spreadPercent > 0) ? totalBaseFinal * (1 + (spreadPercent / 100)) : totalBaseFinal;
    
    desgloseEnvio = "Valor (USD): \$${numFormat.format(precioUsd)}\nFlete: \$${numFormat.format(costoEnvioUsd)}"
        "${proxyFeeUsd > 0 ? ' | Proxy: \$${numFormat.format(proxyFeeUsd)}' : ''}"
        "${impuestoUsd > 0 ? ' | Aduana: \$${numFormat.format(impuestoUsd)}' : ''}"
        "${applySpread && spreadPercent > 0 ? '\n+ Comisión Bancaria: $spreadPercent%' : ''}";
    
    _guardarDatos();
    notifyListeners();
  }

    void guardarCotizacion() {
    if (totalEnvio <= 0) return;
    cotizaciones.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), 
      'fecha': DateFormat('dd/MM HH:mm').format(DateTime.now()),
      'origen': origenEnvio, 'destino': destinoEnvio, 
      'peso': pesoEnvioCtrl.text.isEmpty ? "0" : pesoEnvioCtrl.text,
      'total': totalEnvio, 'moneda': monedaDestinoEnvio
    });
    _guardarDatos();
    notifyListeners();
  }

  void eliminarCotizacion(String id) {
    cotizaciones.removeWhere((e) => e['id'] == id);
    _guardarDatos();
    notifyListeners();
  }

  // --- UTILIDADES ---
  Future<void> pegarNumeros(TextEditingController ctrl, VoidCallback onDone) async {
    ClipboardData? data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null) {
      String numeros = data.text!.replaceAll(RegExp(r'[^0-9.]'), '');
      if (numeros.isNotEmpty) { ctrl.text = numeros; onDone(); }
    }
  }

  Future<void> copiarResultado(String num, BuildContext context) async {
    if (num.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: num));
      HapticFeedback.lightImpact();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado')));
    }
  }
}
