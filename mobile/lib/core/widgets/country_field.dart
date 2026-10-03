import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../utils/countries.dart';

/// Selector de país + prefijo telefónico mediante hoja inferior buscable.
class CountryDialField extends StatelessWidget {
  const CountryDialField({super.key, required this.pais, required this.onChanged});

  final Country pais;
  final ValueChanged<Country> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: Radii.brMd,
      onTap: () async {
        final elegido = await showModalBottomSheet<Country>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _SelectorPaises(),
        );
        if (elegido != null) onChanged(elegido);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.sm, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pais.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(pais.dialCode, style: Theme.of(context).textTheme.bodyLarge),
            const Icon(Icons.expand_more_rounded, size: 18),
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.only(left: Gap.sm),
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorPaises extends StatefulWidget {
  const _SelectorPaises();

  @override
  State<_SelectorPaises> createState() => _SelectorPaisesState();
}

class _SelectorPaisesState extends State<_SelectorPaises> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final lista = Countries.all
        .where((c) =>
            c.name.toLowerCase().contains(_busqueda.toLowerCase()) ||
            c.dialCode.contains(_busqueda))
        .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(
          left: Gap.xl,
          right: Gap.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Text('Selecciona tu país', style: Theme.of(context).textTheme.titleLarge),
            Gap.h16,
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar país o prefijo',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
            Gap.h8,
            Expanded(
              child: ListView.builder(
                itemCount: lista.length,
                itemBuilder: (_, i) {
                  final c = lista[i];
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                    title: Text(c.name),
                    subtitle: Text('${c.dialCode} · ${c.currency}'),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
