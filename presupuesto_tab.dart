import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../translations.dart';
import '../providers/syncra_provider.dart';

class PresupuestoTab extends StatefulWidget {
  const PresupuestoTab({super.key});

  @override
  State<PresupuestoTab> createState() => _PresupuestoTabState();
}

class _PresupuestoTabState extends State<PresupuestoTab> {
  int touhedChartIndex = -1;
  String categoriaSeleccionada = 'cat_others';
  String? monedaGastoSeleccionada;

  final List<Map<String, dynamic>> categoriesConfig = [
    {'id': 'cat_shopping', 'color': 0xFF29B6F6, 'icon': Icons.shopping_bag},
    {'id': 'cat_services', 'color': 0xFFFF8A65, 'icon': Icons.bolt},
    {'id': 'cat_subs', 'color': 0xFFBA68C8, 'icon': Icons.subscriptions},
    {'id': 'cat_food', 'color': 0xFF81C784, 'icon': Icons.restaurant},
    {'id': 'cat_others', 'color': 0xFF90A4AE, 'icon': Icons.category},
  ];

  List<PieChartSectionData> _generateChartSections(SyncraProvider provider, double sueldoTotal, String t(String key)) {
    if (sueldoTotal == 0 && provider.gastos.isEmpty && provider.bovedas.isEmpty) return [];

    Map<String, double> sumasPorCategoria = {};
    for (var g in provider.gastos) {
      sumasPorCategoria[g['categoria']] = (sumasPorCategoria[g['categoria']] ?? 0.0) + (g['monto'] as num).toDouble();
    }

    List<PieChartSectionData> sections = [];
    int indexCounter = 0;

    sumasPorCategoria.forEach((catId, montoSumado) {
      final isTouched = indexCounter == touhedChartIndex;
      final catConfig = categoriesConfig.firstWhere((c) => c['id'] == catId, orElse: () => {'color': 0xFF90A4AE});
      sections.add(PieChartSectionData(
        color: Color(catConfig['color']),
        value: montoSumado,
        title: sueldoTotal > 0 ? '${((montoSumado / sueldoTotal) * 100).toStringAsFixed(0)}%' : '',
        radius: isTouched ? 50.0 : 40.0,
        titleStyle: TextStyle(fontSize: isTouched ? 16.0 : 12.0, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      indexCounter++;
    });

    double totalBovedas = provider.bovedas.fold(0.0, (sum, b) => sum + (b['ahorrado_local'] as num).toDouble());
    if (totalBovedas > 0) {
      final isTouched = indexCounter == touhedChartIndex;
      sections.add(PieChartSectionData(
        color: Colors.amber.shade600,
        value: totalBovedas,
        title: '',
        radius: isTouched ? 50.0 : 40.0,
      ));
      indexCounter++;
    }

    if (provider.balanceLocal > 0) {
      final isTouched = indexCounter == touhedChartIndex;
      sections.add(PieChartSectionData(
        color: Theme.of(context).colorScheme.primaryContainer,
        value: provider.balanceLocal,
        title: t('available'),
        radius: isTouched ? 50.0 : 40.0,
        titleStyle: TextStyle(fontSize: isTouched ? 14 : 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer),
      ));
    }
    return sections;
  }

  void _mostrarDialogoBoveda(SyncraProvider provider, String t(String key), {String? id, bool esAporte = true}) {
    TextEditingController amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(id == null ? t('create_vault') : (esAporte ? t('add_funds') : t('withdraw'))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (id == null) TextField(controller: provider.nombreGastoCtrl, decoration: InputDecoration(labelText: t('name'))),
            TextField(
              controller: amountCtrl, 
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: "${t('amount')} (${provider.monedaLocal})"),
            ),
            if (id == null) DropdownButtonFormField<String>(
              value: provider.monedaLocal,
              decoration: const InputDecoration(labelText: 'Divisa Objetivo'),
              items: provider.tasasCambio.keys.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => monedaGastoSeleccionada = val,
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              double? amount = double.tryParse(amountCtrl.text);
              if (amount != null && amount > 0) {
                if (id == null && provider.nombreGastoCtrl.text.isNotEmpty) {
                  provider.addBoveda(provider.nombreGastoCtrl.text, amount, monedaGastoSeleccionada ?? provider.monedaLocal);
                  provider.nombreGastoCtrl.clear();
                } else if (id != null) {
                  provider.gestionarBoveda(id, amount, esAporte);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Confirmar'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AQUÍ ES DONDE SUCEDE LA MAGIA
    final provider = context.watch<SyncraProvider>();
    String t(String key) => i18n[provider.language]?[key] ?? key;

    double sueldo = double.tryParse(provider.sueldoCtrl.text) ?? 0.0;
    bool hasData = sueldo > 0 || provider.gastos.isNotEmpty || provider.bovedas.isNotEmpty;
    String currentMonedaGasto = monedaGastoSeleccionada ?? provider.monedaLocal;
    if (!provider.tasasCambio.containsKey(currentMonedaGasto)) currentMonedaGasto = provider.monedaLocal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t('local_curr'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: provider.monedaLocal,
                        items: provider.tasasCambio.keys.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                        onChanged: (val) { provider.setMonedaLocal(val!); },
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: provider.sueldoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: t('base_salary'), border: const OutlineInputBorder()),
                  onChanged: (_) => provider.calcularPresupuesto(),
                ),
              ),
              IconButton(icon: const Icon(Icons.paste), color: Theme.of(context).colorScheme.primary, onPressed: () => provider.pegarNumeros(provider.sueldoCtrl, provider.calcularPresupuesto))
            ],
          ),
          const SizedBox(height: 20),
          if (hasData)
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(PieChartData(
                    pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                          touhedChartIndex = -1; return;
                        }
                        touhedChartIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    }),
                    borderData: FlBorderData(show: false), sectionsSpace: 3, centerSpaceRadius: 65,
                    sections: _generateChartSections(provider, sueldo, t),
                  )),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t('net_balance'), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text(
                        provider.numFormat.format(provider.balanceLocal),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: provider.balanceLocal >= 0 ? Theme.of(context).colorScheme.primary : Colors.red),
                      ),
                      Text(provider.monedaLocal, style: const TextStyle(fontSize: 10)),
                      if (provider.monedaLocal != 'USD') ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(6)),
                          child: Text("~ \$${provider.numFormat.format(provider.balanceEq)} USD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        )
                      ]
                    ],
                  )
                ],
              ),
            ),
                    const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('vaults'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              IconButton(icon: const Icon(Icons.add_box, color: Colors.amber), onPressed: () => _mostrarDialogoBoveda(provider, t)),
            ],
          ),
          if (provider.bovedas.isNotEmpty)
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: provider.bovedas.length,
                itemBuilder: (context, index) {
                  var b = provider.bovedas[index];
                  double ahorradoEnUsd = b['ahorrado_local'] / (provider.tasasCambio[provider.monedaLocal] ?? 1.0);
                  double ahorradoEnDivisaObjetivo = ahorradoEnUsd * (provider.tasasCambio[b['moneda_objetivo']] ?? 1.0);
                  double progreso = (ahorradoEnDivisaObjetivo / b['monto_objetivo']).clamp(0.0, 1.0);

                  return Container(
                    width: 200, margin: const EdgeInsets.only(right: 12),
                    child: Card(
                      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(b['nombre'], style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                GestureDetector(
                                  onTap: () => provider.deleteBoveda(b['id']),
                                  child: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: progreso, backgroundColor: Colors.black12, color: Colors.amber),
                            const SizedBox(height: 4),
                            Text("${(progreso * 100).toStringAsFixed(1)}% de ${provider.numFormat.format(b['monto_objetivo'])} ${b['moneda_objetivo']}", style: const TextStyle(fontSize: 10)),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${provider.numFormat.format(b['ahorrado_local'])} ${provider.monedaLocal}", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                                Row(
                                  children: [
                                    GestureDetector(onTap: () => _mostrarDialogoBoveda(provider, t, id: b['id'], esAporte: false), child: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 24)),
                                    const SizedBox(width: 4),
                                    GestureDetector(onTap: () => _mostrarDialogoBoveda(provider, t, id: b['id'], esAporte: true), child: const Icon(Icons.add_circle, color: Colors.green, size: 24)),
                                  ],
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('add_expense'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categoriesConfig.map((cat) {
                        bool isSelected = categoriaSeleccionada == cat['id'];
                        return GestureDetector(
                          onTap: () => setState(() => categoriaSeleccionada = cat['id']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? Color(cat['color']).withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? Color(cat['color']) : Colors.grey.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(cat['icon'], size: 16, color: Color(cat['color'])),
                                if (isSelected) ...[ const SizedBox(width: 4), Text(t(cat['id']), style: TextStyle(fontSize: 12, color: Color(cat['color']), fontWeight: FontWeight.bold)) ]
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(flex: 3, child: TextField(controller: provider.nombreGastoCtrl, decoration: InputDecoration(hintText: t('name'), border: const UnderlineInputBorder()))),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: TextField(controller: provider.montoGastoCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(hintText: t('amount'), border: const UnderlineInputBorder()))),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: currentMonedaGasto,
                          decoration: const InputDecoration(border: UnderlineInputBorder(), contentPadding: EdgeInsets.zero),
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                          items: provider.tasasCambio.keys.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                          onChanged: (val) => setState(() => monedaGastoSeleccionada = val),
                        )
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, size: 36),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () {
                          String nombre = provider.nombreGastoCtrl.text.trim();
                          double? monto = double.tryParse(provider.montoGastoCtrl.text.trim());
                          if (nombre.isNotEmpty && monto != null && monto > 0) {
                            provider.addGasto({
                              'id': DateTime.now().millisecondsSinceEpoch.toString(),
                              'nombre': nombre,
                              'monto_original': monto,
                              'moneda_original': currentMonedaGasto,
                              'monto': monto,
                              'categoria': categoriaSeleccionada
                            });
                            provider.nombreGastoCtrl.clear(); provider.montoGastoCtrl.clear();
                          }
                        },
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...provider.gastos.map((gasto) {
            final catConfig = categoriesConfig.firstWhere((c) => c['id'] == gasto['categoria'], orElse: () => categoriesConfig.last);
            double montoOriginal = (gasto['monto_original'] ?? gasto['monto'] as num).toDouble();
            String monedaOrig = gasto['moneda_original'] ?? provider.monedaLocal;
            bool esExtranjero = monedaOrig != provider.monedaLocal;

            return Dismissible(
              key: Key(gasto['id']),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (direction) { provider.deleteGasto(gasto['id']); HapticFeedback.mediumImpact(); },
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), elevation: 0,
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Color(catConfig['color']).withOpacity(0.2), child: Icon(catConfig['icon'], color: Color(catConfig['color']), size: 20)),
                  title: Text(gasto['nombre'], style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(t(gasto['categoria']), style: const TextStyle(fontSize: 11)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("${provider.numFormat.format(montoOriginal)} $monedaOrig", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (esExtranjero) Text("~ ${provider.numFormat.format(gasto['monto'])} ${provider.monedaLocal}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
