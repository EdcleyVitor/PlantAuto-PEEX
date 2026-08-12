import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/leitura_store.dart';
import '../services/plantacao_store.dart';
import '../services/settings_manager.dart';

class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsManager.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Configurações')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _TemaCard(),
              const SizedBox(height: 16),
              const _FonteCard(),
              const SizedBox(height: 16),
              const _IrrigacaoCard(),
              const SizedBox(height: 16),
              _ErrosCard(settings: settings),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _confirmarLimpar(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Limpar todos os dados'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'PlantAuto PEEX v1.0.0\n'
                  'Projeto PEEX - EETEPA · Santarém/PA\n'
                  'Desenvolvido por Edcley Vitor',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmarLimpar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar todos os dados?'),
        content: const Text(
            'Isso apaga plantas, configurações e o histórico de erros.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await SettingsManager.instance.limparTudo();
      await PlantacaoStore.instance.limpar();
      await LeituraStore.instance.limparTudo();
      await BluetoothService.instance.carregarPersistenciaGlobal();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados limpos')),
        );
      }
    }
  }
}

class _TemaCard extends StatelessWidget {
  const _TemaCard();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsManager.instance;
    final cores = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cores.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.palette_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Tema', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _OpcaoTema(
                    icone: Icons.brightness_auto,
                    rotulo: 'Sistema',
                    selecionado: settings.modoTema == 'system',
                    onTap: () => settings.setModoTema('system'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OpcaoTema(
                    icone: Icons.light_mode,
                    rotulo: 'Claro',
                    selecionado: settings.modoTema == 'light',
                    onTap: () => settings.setModoTema('light'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OpcaoTema(
                    icone: Icons.dark_mode,
                    rotulo: 'Escuro',
                    selecionado: settings.modoTema == 'dark',
                    onTap: () => settings.setModoTema('dark'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcaoTema extends StatelessWidget {
  const _OpcaoTema({
    required this.icone,
    required this.rotulo,
    required this.selecionado,
    required this.onTap,
  });
  final IconData icone;
  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selecionado
              ? cores.primary.withValues(alpha: 0.15)
              : cores.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selecionado ? cores.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icone, color: selecionado ? cores.primary : null),
            const SizedBox(height: 6),
            Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _FonteCard extends StatelessWidget {
  const _FonteCard();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsManager.instance;
    final cores = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cores.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.font_download_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Fonte', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: settings.fonte,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
              items: [
                for (final f in SettingsManager.fontesDisponiveis)
                  DropdownMenuItem(value: f, child: Text(f)),
              ],
              onChanged: (v) {
                if (v != null) settings.setFonte(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IrrigacaoCard extends StatelessWidget {
  const _IrrigacaoCard();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsManager.instance;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          SwitchListTile(
            value: settings.reconectarAuto,
            onChanged: settings.setReconectarAuto,
            title: const Text('Reconectar automaticamente'),
            subtitle: const Text('Tenta conectar de novo se a conexão cair'),
            secondary: const Icon(Icons.sync),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, size: 20),
                    const SizedBox(width: 8),
                    Text('Constante de irrigação',
                        style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      settings.constanteIrrigacao.toStringAsFixed(1),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Slider(
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  value: settings.constanteIrrigacao,
                  label: settings.constanteIrrigacao.toStringAsFixed(1),
                  onChanged: settings.setConstanteIrrigacao,
                ),
                Text(
                  'Ajusta o tempo de rega calculado pela fórmula.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrosCard extends StatelessWidget {
  const _ErrosCard({required this.settings});
  final SettingsManager settings;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cores.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, size: 20, color: cores.error),
                const SizedBox(width: 8),
                Text('Leitura de erros',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (settings.erros.isNotEmpty)
                  TextButton(
                    onPressed: settings.limparErros,
                    child: const Text('Limpar'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (settings.erros.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Nenhum erro registrado.',
                    style: Theme.of(context).textTheme.bodyMedium),
              )
            else
              for (final erro in settings.erros.take(15))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    erro,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
