import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../translations.dart';
import '../providers/syncra_provider.dart';

class ConversorTab extends StatefulWidget {
  const ConversorTab({super.key});

  @override
  State<ConversorTab> createState() => _ConversorTabState();
}

class _ConversorTabState extends State<ConversorTab> {
  double _rotationAngle = 0.0;
  double _carritoTotal = 0.0;
  bool _isScanning = false;

  Future<void> _escanearPrecio(SyncraProvider provider, String t(String key)) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() => _isScanning = true);
      try {
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText = await textRecognizer.processImage(InputImage.fromFilePath(image.path));
        
        // RegEx para buscar patrones de precio (ej. 1500, 1,500.50, 1.500,00)
        RegExp exp = RegExp(r'(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?)');
        List<double> preciosEncontrados = [];

        for (TextBlock block in recognizedText.blocks) {
          for (TextLine line in block.lines) {
            final match = exp.firstMatch(line.text);
            if (match != null) {
              String numStr = match.group(0)!.replaceAll(',', '');
              double? val = double.tryParse(numStr);
              if (val != null && val > 0) preciosEncontrados.add(val);
            }
          }
        }
        
        textRecognizer.close();

        if (preciosEncontrados.isNotEmpty) {
          double mayorPrecio = preciosEncontrados.reduce((curr, next) => curr > next ? curr : next);
          if (mounted) _mostrarConfirmacionEscaneo(mayorPrecio, provider);
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('no_price_found'))));
        }
      } catch (e) {
        debugPrint("Error OCR: $e");
      }
      setState(() => _isScanning = false);
    }
  }

  void _mostrarConfirmacionEscaneo(double precioDetectado, SyncraProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Precio Detectado'),
        content: Text("Se detectó el valor: ${provider.numFormat.format(precioDetectado)} ${provider.monedaDe}\n¿Sumar al carrito?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              setState(() {
                _carritoTotal += precioDetectado;
                provider.convMontoCtrl.text = _carritoTotal.toStringAsFixed(2);
                provider.calcularConversion();
              });
              Navigator.pop(context);
            },
            child: const Text('Sumar'),
          )
        ],
      ),
    );
  }

  void _enrutarCarrito(SyncraProvider provider, String t(String key)) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('purchase_type'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.storefront, color: Colors.blue),
                title: Text(t('physical')),
                onTap: () {
                  Navigator.pop(context);
                  provider.montoGastoCtrl.text = _carritoTotal.toStringAsFixed(2);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Añade un nombre y confirma el gasto en la pestaña de Presupuesto')));
                  setState(() => _carritoTotal = 0.0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flight_takeoff, color: Colors.orange),
                title: Text(t('shipping_type')),
                onTap: () {
                  Navigator.pop(context);
                  provider.precioEnvioCtrl.text = _carritoTotal.toStringAsFixed(2);
                  provider.updateEnvioParams(mOrigen: provider.monedaDe);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Valor actualizado en la pestaña de Envíos. Ve allí para calcular aduanas.')));
                  setState(() => _carritoTotal = 0.0);
                },
              )
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SyncraProvider>();
    String t(String key) => i18n[provider.language]?[key] ?? key;

    double formulaTasa = (provider.tasasCambio[provider.monedaA] ?? 1.0) / (provider.tasasCambio[provider.monedaDe] ?? 1.0);
    bool isOutdated = provider.ultimaActualizacionEpoch > 0 && (DateTime.now().millisecondsSinceEpoch - provider.ultimaActualizacionEpoch > 86400000);
    String formattedDate = provider.ultimaActualizacionEpoch == 0 ? "---" : DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(provider.ultimaActualizacionEpoch));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Card(
            color: isOutdated ? Colors.red.withOpacity(0.1) : Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isOutdated ? Colors.redAccent.withOpacity(0.5) : Colors.transparent)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isOutdated ? Icons.warning_amber_rounded : Icons.history, size: 16, color: isOutdated ? Colors.redAccent : Theme.of(context).colorScheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Text(
                    isOutdated ? "${t('outdated_rates')} $formattedDate" : "${t('last_update')} $formattedDate",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isOutdated ? Colors.redAccent : Theme.of(context).colorScheme.onSecondaryContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t('quick_conv'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                      FilledButton.icon(
                        onPressed: _isScanning ? null : () => _escanearPrecio(provider, t),
                        icon: _isScanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt),
                        label: Text(t('scan_price')),
                        style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: provider.convMontoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: t('amount_to_convert'), border: const OutlineInputBorder()),
                          onChanged: (_) {
                            provider.calcularConversion();
                            setState(() => _carritoTotal = double.tryParse(provider.convMontoCtrl.text) ?? 0.0);
                          }
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.paste), color: Theme.of(context).colorScheme.primary, onPressed: () => provider.pegarNumeros(provider.convMontoCtrl, provider.calcularConversion))
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      DropdownButton<String>(
                        value: provider.monedaDe, 
                        items: provider.tasasCambio.keys.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(), 
                        onChanged: (val) { provider.setMonedasConversor(val!, provider.monedaA); }
                      ),
                      AnimatedRotation(
                        turns: _rotationAngle, duration: const Duration(milliseconds: 300),
                        child: IconButton(
                          icon: const Icon(Icons.swap_horiz, size: 36), 
                          color: Theme.of(context).colorScheme.primary, 
                          onPressed: () { 
                            setState(() => _rotationAngle += 0.5); 
                            provider.setMonedasConversor(provider.monedaA, provider.monedaDe); 
                          }
                        ),
                      ),
                      DropdownButton<String>(
                        value: provider.monedaA, 
                        items: provider.tasasCambio.keys.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(), 
                        onChanged: (val) { provider.setMonedasConversor(provider.monedaDe, val!); }
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Checkbox(value: provider.applySpread, onChanged: (val) => provider.toggleSpread(val ?? false)),
                        Text(t('apply_fee'), style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: provider.spreadCtrl, 
                            keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                            enabled: provider.applySpread, 
                            decoration: InputDecoration(labelText: t('bank_fee'), border: InputBorder.none), 
                            onChanged: (_) => provider.calcularConversion()
                          )
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                      child: Text("1 ${provider.monedaDe} = ${formulaTasa.toStringAsFixed(4)} ${provider.monedaA}", style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) => ScaleTransition(scale: animation, child: child),
                        child: Text("${provider.numFormat.format(provider.resultadoConversion)} ${provider.monedaA}", key: ValueKey<double>(provider.resultadoConversion), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                      ),
                      IconButton(icon: const Icon(Icons.copy), color: Theme.of(context).colorScheme.primary, onPressed: () => provider.copiarResultado(provider.resultadoConversion.toStringAsFixed(2), context))
                    ],
                  ),
                  if (_carritoTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: FilledButton.tonalIcon(
                        onPressed: () => _enrutarCarrito(provider, t),
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: Text("${t('process_cart')} (${provider.monedaDe})"),
                      ),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
