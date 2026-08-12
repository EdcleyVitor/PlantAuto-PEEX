import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothService;
import '../services/bluetooth_service.dart';

class ConectividadeScreen extends StatelessWidget {
  const ConectividadeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bt = BluetoothService.instance;
    return ListenableBuilder(
      listenable: bt,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Conectividade'),
            actions: [
              IconButton(
                tooltip: 'Desconectar todos',
                onPressed: bt.isConnected ? bt.desconectarTudo : null,
                icon: const Icon(Icons.link_off),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusCard(bt: bt),
              const SizedBox(height: 12),
              if (bt.conectadosAtivos.isNotEmpty) ...[
                for (final disp in bt.conectadosAtivos)
                  _DispositivoCard(disp: disp, bt: bt),
                const SizedBox(height: 12),
              ],
              _ScanCard(bt: bt),
              const SizedBox(height: 12),
              _LogCard(bt: bt),
            ],
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.bt});
  final BluetoothService bt;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final n = bt.conectadosAtivos.length;
    final cor = n > 0
        ? cores.secondary
        : bt.adapterState == BluetoothAdapterState.on
            ? cores.primary
            : Colors.orange;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cor.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              n > 0 ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: cor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n > 0 ? '$n ESP32 conectado${n > 1 ? 's' : ''}' : 'Sem conexões',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bt.conectadosAtivos.isNotEmpty
                        ? bt.conectadosAtivos.map((d) => d.nome).join(' · ')
                        : 'Use "Conectar" ou "Conectar Todos"',
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DispositivoCard extends StatelessWidget {
  const _DispositivoCard({required this.disp, required this.bt});
  final DispositivoConectado disp;
  final BluetoothService bt;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cores.secondary.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cores.secondary.withValues(alpha: 0.2),
                  child: Icon(Icons.memory, color: cores.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(disp.nome,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      if (disp.versaoFirmwareTexto != null)
                        Text(
                          'Firmware ${disp.versaoFirmwareTexto}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary),
                        ),
                      Text(
                        disp.ultimaLeitura ?? 'Aguardando dados...',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (disp.mlRainAtivo)
                  Tooltip(
                    message: 'Verificar clima: espera chuva antes de regar',
                    child: Icon(
                      Icons.umbrella_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                const SizedBox(width: 8),
                _StatusEmoji(disp: disp),
              ],
            ),
            const SizedBox(height: 12),
            if (disp.problemas.isNotEmpty) ...[
              _ProblemasLinha(disp: disp, bt: bt),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => bt.lerUmidade(disp),
                    icon: const Icon(Icons.water_drop_outlined, size: 18),
                    label: const Text('Ler Umidade'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => bt.pedirHistorico(disp),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Histórico'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => bt.desconectar(disp),
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Desconectar este ESP32'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A rega é automática: o ESP32 irriga sozinho conforme a planta. '
              'O app serve para administrar e coletar dados.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cores.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusEmoji extends StatelessWidget {
  const _StatusEmoji({required this.disp});
  final DispositivoConectado disp;

  // 🌱 tudo bem / ⚠️ com problemas / ❌ sem conexão
  String get _emoji {
    if (!disp.conectado) return '❌';
    return disp.problemas.isNotEmpty ? '⚠️' : '🌱';
  }

  String get _texto {
    if (!disp.conectado) return 'Sem conexão';
    return disp.problemas.isNotEmpty
        ? '${disp.problemas.length} problema${disp.problemas.length > 1 ? 's' : ''}'
        : 'Tudo bem';
  }

  @override
  Widget build(BuildContext context) {
    final cor = disp.problemas.isNotEmpty
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.tertiary;
    return Tooltip(
      message: _texto,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 22)),
          Text(
            disp.problemas.isNotEmpty ? '⚠️' : 'ok',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: cor),
          ),
        ],
      ),
    );
  }
}

class _ProblemasLinha extends StatelessWidget {
  const _ProblemasLinha({required this.disp, required this.bt});
  final DispositivoConectado disp;
  final BluetoothService bt;

  void _verProblemas(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Problemas detectados'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final p in disp.problemas.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber, color: Colors.orange),
                  title: Text(p.rotulo),
                  subtitle: Text(
                    '${p.mensagem}\n${p.tempo.day.toString().padLeft(2, '0')}/${p.tempo.month.toString().padLeft(2, '0')} '
                    '${p.tempo.hour.toString().padLeft(2, '0')}:${p.tempo.minute.toString().padLeft(2, '0')}',
                  ),
                  isThreeLine: true,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              bt.limparErrosFirmware(disp);
              Navigator.pop(context);
            },
            child: const Text('Limpar log'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _verProblemas(context),
      icon: const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
      label: Text('${disp.problemas.length} problema'
          '${disp.problemas.length > 1 ? 's' : ''} detectado'
          '${disp.problemas.length > 1 ? 's' : ''}'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(40),
        foregroundColor: Colors.orange,
        side: const BorderSide(color: Colors.orange),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.bt});
  final BluetoothService bt;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Dispositivos',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: bt.isScanning ? bt.stopScan : bt.startScan,
                  icon: Icon(bt.isScanning ? Icons.stop : Icons.search),
                  label: Text(bt.isScanning ? 'Parar' : 'Escanear'),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Somente PEEX'),
              subtitle: const Text('Mostra só os ESP32 do projeto'),
              value: bt.soMostrarPeeX,
              onChanged: (v) => bt.soMostrarPeeX = v,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: bt.conectarTodos,
              icon: const Icon(Icons.bluetooth_connected),
              label: const Text('Conectar Todos'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),
            if (bt.isScanning)
              const LinearProgressIndicator(minHeight: 3),
            if (bt.isScanning) const SizedBox(height: 12),
            if (bt.descobertosVisiveis.isEmpty && !bt.isScanning)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  bt.soMostrarPeeX
                      ? 'Nenhum dispositivo PEEX encontrado.\nLigue o ESP32 e verifique o filtro.'
                      : 'Nenhum dispositivo encontrado.\nVerifique se os ESP32 estão ligados.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            for (final d in bt.descobertosVisiveis)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: cores.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.memory, color: cores.primary),
                ),
                title: Text(
                  d.platformName.isNotEmpty
                      ? d.platformName
                      : 'ESP32 desconhecido',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(d.remoteId.str),
                trailing: bt.conectados.any((c) => c.id == d.remoteId.str &&
                        c.conectado)
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.add_circle_outline),
                onTap: () {
                  if (bt.conectados.any((c) => c.id == d.remoteId.str)) {
                    final c = bt.conectados.firstWhere(
                        (c) => c.id == d.remoteId.str);
                    if (c.conectado) {
                      bt.desconectar(c);
                    } else {
                      bt.conectar(d);
                    }
                  } else {
                    bt.conectar(d);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.bt});
  final BluetoothService bt;

  @override
  Widget build(BuildContext context) {
    final logs = <String>[];
    for (final d in bt.conectados) {
      for (final linha in d.log) {
        logs.add('${d.nome}: $linha');
      }
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comunicação',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Nenhuma atividade ainda.',
                    style: Theme.of(context).textTheme.bodyMedium),
              )
            else
              for (final linha in logs.take(30))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    linha,
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
