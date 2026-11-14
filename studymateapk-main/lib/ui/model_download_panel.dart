import 'package:flutter/material.dart';

import '../services/model_manager.dart';

/// One card per model. The vision file belongs to its model, so it never shows up as a second chat model.
/// Uses the static [ModelManager] API and [modelCatalog].
class ModelDownloadPanel extends StatefulWidget {
  const ModelDownloadPanel({super.key, this.onChanged});

  /// Called after a model is downloaded, selected, or deleted.
  final VoidCallback? onChanged;

  @override
  State<ModelDownloadPanel> createState() => _ModelDownloadPanelState();
}

class _ModelDownloadPanelState extends State<ModelDownloadPanel> {
  final Map<String, bool> _installed = {};
  final Map<String, String> _status = {};
  final Map<String, String> _errors = {};
  String? _activeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final installed = <String, bool>{};
    for (final e in modelCatalog) {
      installed[e.id] = await ModelManager.isInstalled(e);
    }
    final active = await ModelManager.activeId();
    if (!mounted) return;
    setState(() {
      _installed
        ..clear()
        ..addAll(installed);
      _activeId = active;
      _loading = false;
    });
  }

  Future<void> _download(ModelEntry e) async {
    setState(() {
      _errors.remove(e.id);
      _status[e.id] = 'Starting...';
    });
    try {
      await ModelManager.download(e, (s) {
        if (mounted) setState(() => _status[e.id] = s);
      });
      await ModelManager.setActive(e.id);
      widget.onChanged?.call();
    } catch (err) {
      _errors[e.id] = err.toString().replaceFirst('Exception: ', '');
    } finally {
      await _refresh();
      if (mounted) setState(() => _status.remove(e.id));
    }
  }

  Future<void> _use(ModelEntry e) async {
    await ModelManager.setActive(e.id);
    widget.onChanged?.call();
    await _refresh();
  }

  Future<void> _delete(ModelEntry e) async {
    await ModelManager.delete(e);
    widget.onChanged?.call();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [for (final e in modelCatalog) _card(e)],
    );
  }

  Widget _card(ModelEntry e) {
    final installed = _installed[e.id] ?? false;
    final active = _activeId == e.id;
    final status = _status[e.id];
    final error = _errors[e.id];
    final busy = status != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.memory_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text(e.title, style: Theme.of(context).textTheme.titleMedium)),
              if (active && installed)
                const Chip(label: Text('Selected'))
              else if (installed)
                const Chip(label: Text('Installed')),
            ]),
            const SizedBox(height: 6),
            Text(e.summary),
            const SizedBox(height: 4),
            Text('${e.sizeText}  |  ${e.ramText}', style: Theme.of(context).textTheme.bodySmall),
            if (busy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text(status),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(spacing: 8, children: [
                if (installed && !active)
                  FilledButton(onPressed: busy ? null : () => _use(e), child: const Text('Use')),
                if (installed)
                  OutlinedButton(onPressed: busy ? null : () => _delete(e), child: const Text('Delete'))
                else
                  FilledButton(
                    onPressed: busy ? null : () => _download(e),
                    child: Text(error == null ? 'Download' : 'Retry'),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
