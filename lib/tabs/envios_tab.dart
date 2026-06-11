import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../translations.dart';
import '../providers/syncra_provider.dart';

class EnviosTab extends StatelessWidget {
  const EnviosTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SyncraProvider>();
    String t(String key) => i18n[provider.language]?[key] ?? key;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t('customs'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 4, 
                        child: TextField(
                          controller: provider.precioEnvioCtrl, 
                          keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                          decoration: InputDecoration(labelText: t('price'), border: const OutlineInputBorder()), 
                          onChanged: (_) => provider.calcularEnvio()
                        )
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3, 
                        child: DropdownButtonFormField<String>(
                          isExpanded: true, 
                          value: provider.monedaOrigenEnvio, 
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)), 
                          items: provider.tasasCambio.keys.map((String val) => DropdownMenuItem(value: val, child: Text(val))).toList(), 
                          onChanged: (val) { provider.updateEnvioParams(mOrigen: val!); }
                        )
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4, 
                        child: TextField(
                          controller: provider.pesoEnvioCtrl, 
                          keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                          decoration: InputDecoration(labelText: t('weight'), border: const OutlineInputBorder()), 
                          onChanged: (_) => provider.calcularEnvio()
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true, value: provider.origenEnvio, decoration: InputDecoration(labelText: t('origin')),
                    items: ['Japón', 'China', 'EE.UU.', 'Europa', 'Nacional'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                    onChanged: (val) { provider.updateEnvioParams(origen: val!); },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2, 
                        child: TextField(
                          controller: provider.proxyCostoCtrl, 
                          keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                          decoration: InputDecoration(labelText: t('proxy_cost'), border: const UnderlineInputBorder()), 
                          onChanged: (_) => provider.calcularEnvio()
                        )
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1, 
                        child: DropdownButton<String>(
                          isExpanded: true, 
                          value: provider.monedaProxy, 
                          items: provider.tasasCambio.keys.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(), 
                          onChanged: (val) { provider.updateEnvioParams(mProxy: val!); }
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true, value: provider.destinoEnvio, decoration: InputDecoration(labelText: t('destination')),
                          items: ['Brasil', 'Perú', 'México', 'EE.UU.', 'Europa', 'Japón', 'Venezuela', 'Otros'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                          onChanged: (val) { provider.updateEnvioParams(destino: val!); },
                        )
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: provider.monedaDestinoEnvio, 
                        items: provider.tasasCambio.keys.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(), 
                        onChanged: (val) { provider.updateEnvioParams(mDestino: val!); }
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // CONTROLES DE SPREAD
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: provider.applySpread,
                          onChanged: (val) => provider.toggleSpread(val ?? false),
                        ),
                        Text(t('apply_fee'), style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: provider.spreadCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            enabled: provider.applySpread,
                            decoration: InputDecoration(labelText: t('bank_fee'), border: InputBorder.none),
                            onChanged: (_) => provider.calcularEnvio(),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(provider.desgloseEnvio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          "${provider.numFormat.format(provider.totalEnvio)} ${provider.monedaDestinoEnvio}", 
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary), 
                          overflow: TextOverflow.ellipsis
                        )
                      ),
                      IconButton(icon: const Icon(Icons.copy), color: Theme.of(context).colorScheme.primary, onPressed: () => provider.copiarResultado(provider.totalEnvio.toStringAsFixed(2), context))
                    ],
                  ),
                  if (provider.totalEnvio > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: FilledButton.tonalIcon(
                        onPressed: provider.guardarCotizacion,
                        icon: const Icon(Icons.bookmark_add),
                        label: Text(t('save_quote')),
                      ),
                    )
                ],
              ),
            ),
          ),

          // LISTA DE COTIZACIONES GUARDADAS
          if (provider.cotizaciones.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(t('saved_quotes'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ...provider.cotizaciones.map((cot) {
              return Dismissible(
                key: Key(cot['id']),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  provider.eliminarCotizacion(cot['id']);
                  HapticFeedback.mediumImpact();
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                  elevation: 0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text("${cot['origen']} ➔ ${cot['destino']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${cot['fecha']} • Peso: ${cot['peso']}kg"),
                    trailing: Text("${provider.numFormat.format(cot['total'])} ${cot['moneda']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary)),
                  ),
                ),
              );
            }),
          ]
        ],
      ),
    );
  }
}
