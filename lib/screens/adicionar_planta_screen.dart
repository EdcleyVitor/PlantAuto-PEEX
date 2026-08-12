import 'package:flutter/material.dart';
import '../models/planta.dart';
import '../services/plantacao_store.dart';

class AdicionarPlantaScreen extends StatefulWidget {
  const AdicionarPlantaScreen({super.key});

  @override
  State<AdicionarPlantaScreen> createState() => _AdicionarPlantaScreenState();
}

class _AdicionarPlantaScreenState extends State<AdicionarPlantaScreen> {
  final _nomeController = TextEditingController();
  int _umidadeIdeal = 70;
  double _fatorPlanta = 1.0;
  int _regaInicio = 60;
  int _regaFim = 75;

  static const _fatores = [
    (rotulo: 'Mínima', valor: 0.5, descricao: 'Requer pouca água'),
    (rotulo: 'Média', valor: 1.0, descricao: 'Quantidade padrão'),
    (rotulo: 'Frequente', valor: 1.5, descricao: 'Requer muita água'),
  ];

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o nome da planta')),
      );
      return;
    }
    final planta = Planta(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nome: nome,
      umidadeIdeal: _umidadeIdeal,
      fatorPlanta: _fatorPlanta,
      regaInicio: _regaInicio,
      regaFim: _regaFim,
      dataAdicionada: DateTime.now(),
    );
    await PlantacaoStore.instance.adicionar(planta);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Planta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Nome da planta',
              hintText: 'Ex: Hortelã',
              prefixIcon: const Icon(Icons.grass),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Umidade ideal do solo',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Valor que o sensor deve indicar para o solo úmido',
              style: Theme.of(context).textTheme.bodySmall),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 0,
                  max: 100,
                  divisions: 20,
                  value: _umidadeIdeal.toDouble(),
                  label: '$_umidadeIdeal%',
                  onChanged: (v) =>
                      setState(() => _umidadeIdeal = v.round()),
                ),
              ),
              CircleAvatar(
                backgroundColor: cores.primary.withValues(alpha: 0.15),
                child: Text(
                  '$_umidadeIdeal%',
                  style: TextStyle(
                    color: cores.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Nível de irrigação',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final fator in _fatores)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              color: _fatorPlanta == fator.valor
                  ? cores.primary.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _fatorPlanta == fator.valor
                      ? cores.primary
                      : Colors.transparent,
                ),
              ),
              child: RadioListTile<double>(
                value: fator.valor,
                groupValue: _fatorPlanta,
                onChanged: (v) =>
                    setState(() => _fatorPlanta = v ?? 1.0),
                title: Text(fator.rotulo,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(fator.descricao),
                secondary: const Icon(Icons.water_drop_outlined),
              ),
            ),
          const SizedBox(height: 24),
          Text('Limites de rega',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('O sistema liga quando o solo fica abaixo do primeiro valor e '
              'desliga quando passa acima do segundo.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text('Regar quando umidade <',
              style: Theme.of(context).textTheme.bodySmall),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 5,
                  max: 95,
                  divisions: 18,
                  value: _regaInicio.toDouble(),
                  label: '$_regaInicio%',
                  onChanged: (v) => setState(() => _regaInicio = v.round()),
                ),
              ),
              CircleAvatar(
                backgroundColor: cores.primary.withValues(alpha: 0.15),
                child: Text(
                  '$_regaInicio%',
                  style: TextStyle(
                    color: cores.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          Text('Desligar quando umidade >',
              style: Theme.of(context).textTheme.bodySmall),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 10,
                  max: 100,
                  divisions: 18,
                  value: _regaFim.toDouble(),
                  label: '$_regaFim%',
                  onChanged: (v) => setState(() => _regaFim = v.round()),
                ),
              ),
              CircleAvatar(
                backgroundColor: cores.primary.withValues(alpha: 0.15),
                child: Text(
                  '$_regaFim%',
                  style: TextStyle(
                    color: cores.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _salvar,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar Planta'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
