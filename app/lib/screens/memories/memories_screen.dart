import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/memory.dart';
import '../../services/api_exception.dart';
import '../../theme/app_theme.dart';
import 'memories_controller.dart';

/// What marlix remembers (wireframes docs/diagrams/wireframes/screens/05a-memory.png
/// and 05b-memory-edit.png): the person can read, edit and delete every memory.
class MemoriesScreen extends ConsumerWidget {
  const MemoriesScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const MemoriesScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(memoriesControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lo que marlix sabe de mí', style: AppText.title),
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: switch (memories) {
          AsyncData(:final value) => _MemoryList(memories: value),
          AsyncError() => _LoadFailed(
            onRetry: () => ref.read(memoriesControllerProvider.notifier).reload(),
          ),
          _ => const Center(child: CircularProgressIndicator(color: AppColors.tanDark)),
        },
      ),
    );
  }
}

class _MemoryList extends ConsumerWidget {
  const _MemoryList({required this.memories});

  final List<Memory> memories;

  Future<void> _edit(BuildContext context, WidgetRef ref, Memory memory) async {
    final fact = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (_) => _EditSheet(memory: memory),
    );
    if (fact == null || !context.mounted) return;
    await _run(context, () => ref.read(memoriesControllerProvider.notifier).edit(memory, fact));
  }

  Future<void> _removeAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar todo lo que sabe?', style: AppText.title),
        content: const Text(
          'marlix va a olvidar todo lo que recuerda de vos. No se puede deshacer.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.crisis),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(context, () => ref.read(memoriesControllerProvider.notifier).removeAll());
  }

  /// Tells the person when the backend refused, instead of failing silently.
  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on ApiException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_describe(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Text(
                memories.isEmpty
                    ? 'Todavía no recuerdo nada de vos. Mientras conversemos, voy guardando lo '
                          'importante y lo vas a ver acá.'
                    : 'Esto es lo que recuerdo de nuestras conversaciones. Podés editarlo o '
                          'borrarlo cuando quieras; lo borrado ya no lo uso.',
                style: AppText.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              for (final memory in memories) ...[
                _MemoryCard(
                  memory: memory,
                  onEdit: () => _edit(context, ref, memory),
                  onDelete: () => _run(
                    context,
                    () => ref.read(memoriesControllerProvider.notifier).remove(memory),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        if (memories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OutlinedButton(
              onPressed: () => _removeAll(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.crisis,
                side: const BorderSide(color: AppColors.crisis, width: 2),
                textStyle: AppText.button,
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              child: const Text('Borrar todo lo que sabe'),
            ),
          ),
      ],
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.memory, required this.onEdit, required this.onDelete});

  final Memory memory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.line, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(memory.fact, style: AppText.body),
              ),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: 'Editar recuerdo',
              icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: 'Borrar recuerdo',
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No pude cargar lo que recuerdo. Revisá tu conexión e intentá de nuevo.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

/// Wireframe 05b. It only returns the new text; the list sends it, so a
/// failure leaves the list as it was.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.memory});

  final Memory memory;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  /// The backend's limit (docs/api-contract.md#patch-v1memoriesid).
  static const maxLength = 500;

  late final _text = TextEditingController(text: widget.memory.fact);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: ListenableBuilder(
        listenable: _text,
        builder: (context, _) {
          final fact = _text.text.trim();
          final canSave = fact.isNotEmpty && fact != widget.memory.fact;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Editar recuerdo', style: AppText.title),
              const SizedBox(height: 16),
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                maxLength: maxLength,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.body,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.line, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.tanDark, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: canSave ? () => Navigator.of(context).pop(fact) : null,
                style: FilledButton.styleFrom(
                  textStyle: AppText.button,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Guardar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _describe(ApiException error) => switch (error) {
  NetworkException() ||
  ApiTimeoutException() => 'No hay conexión. Revisá tu internet e intentá de nuevo.',
  NotFoundException() => 'Ese recuerdo ya no existe.',
  ValidationException() => 'Ese texto no se puede guardar. Probá con otro.',
  _ => 'No se pudo completar. Intentá de nuevo en un momento.',
};
