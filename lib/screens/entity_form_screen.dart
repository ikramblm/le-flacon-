import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/schema.dart';
import '../models/schemas_data.dart';
import '../services/repository.dart';
import '../services/repository_scope.dart';
import '../services/session.dart';
import '../utils/formatters.dart';

/// Generic add/edit form, built entirely from a TableSchema: text fields,
/// dropdowns for refs and enums, date/time pickers, photo pickers, and
/// live-recomputed read-only fields (mirrors AppSheet's computed columns).
class EntityFormScreen extends StatefulWidget {
  final TableSchema schema;
  final Map<String, dynamic>? existing;
  final Map<String, dynamic>? presetValues;

  const EntityFormScreen({super.key, required this.schema, this.existing, this.presetValues});

  @override
  State<EntityFormScreen> createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _values;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<Map<String, dynamic>>> _refOptions = {};
  bool _optionsLoaded = false;
  bool _optionsLoading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _values = <String, dynamic>{};
    final existing = widget.existing;
    for (final f in widget.schema.fields) {
      dynamic v = existing?[f.name];
      v ??= widget.presetValues?[f.name];
      if (v == null) {
        if (f.type == FieldType.dateTime && f.name == 'date') {
          v = DateTime.now().toIso8601String();
        } else if (f.type == FieldType.enumType && f.enumValues != null && f.enumValues!.isNotEmpty) {
          v = f.enumValues!.first;
        } else if (f.type == FieldType.number || f.type == FieldType.price) {
          v = 0;
        } else if (f.name == 'utilisateur_id') {
          v = Session.instance.currentUserId;
        }
      }
      _values[f.name] = v;
      if (f.type == FieldType.text ||
          f.type == FieldType.phone ||
          f.type == FieldType.email ||
          f.type == FieldType.number ||
          f.type == FieldType.price) {
        _controllers[f.name] = TextEditingController(text: v == null ? '' : v.toString());
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions(Repository repo) async {
    if (_optionsLoaded || _optionsLoading) return;
    _optionsLoading = true;
    for (final f in widget.schema.refFields) {
      final refSchema = allSchemasOf(f.refTable!);
      if (refSchema == null) continue;
      final rows = await repo.getAll(refSchema);
      _refOptions[f.name] = rows;
    }
    if (widget.schema.recompute != null) {
      final updates = await widget.schema.recompute!(_values, repo);
      _applyUpdates(updates);
    }
    _optionsLoaded = true;
    if (mounted) setState(() {});
  }

  void _applyUpdates(Map<String, dynamic> updates) {
    updates.forEach((k, v) {
      _values[k] = v;
      final c = _controllers[k];
      if (c != null) c.text = v == null ? '' : v.toString();
    });
  }

  Future<void> _onFieldChanged(Repository repo) async {
    if (widget.schema.recompute == null) return;
    final updates = await widget.schema.recompute!(_values, repo);
    if (!mounted) return;
    setState(() => _applyUpdates(updates));
  }

  Future<void> _save(Repository repo) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{};
      for (final f in widget.schema.fields) {
        if (!f.isVisible(_values)) {
          data[f.name] = null;
          continue;
        }
        var v = _values[f.name];
        if (f.type == FieldType.number || f.type == FieldType.price) {
          v = v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
        }
        data[f.name] = v;
      }
      if (widget.existing != null) {
        final id = widget.existing![widget.schema.primaryKey].toString();
        await repo.updateRecord(widget.schema, id, data);
      } else {
        final id = await repo.generateId(widget.schema);
        data[widget.schema.primaryKey] = id;
        await repo.insertRecord(widget.schema, data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    if (!_optionsLoaded) {
      _loadOptions(repo);
    }

    final isEdit = widget.existing != null;
    final refCount = widget.schema.refFields.length;

    return Scaffold(
      appBar: AppBar(title: Text('${isEdit ? "Modifier" : "Ajouter"} — ${widget.schema.label}')),
      body: (!_optionsLoaded && refCount > 0)
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final f in widget.schema.fields.where((f) => f.isVisible(_values)))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildField(context, repo, f),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : () => _save(repo),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildField(BuildContext context, Repository repo, FieldDef f) {
    if (f.readOnly) {
      String display;
      final v = _values[f.name];
      if (f.type == FieldType.price) {
        display = formatPrice(v);
      } else if (f.type == FieldType.number) {
        display = formatNumber(v);
      } else {
        display = (v ?? '').toString();
      }
      return InputDecorator(
        decoration: InputDecoration(labelText: f.label),
        child: Text(display.isEmpty ? '—' : display),
      );
    }

    switch (f.type) {
      case FieldType.text:
        return TextFormField(
          controller: _controllers[f.name],
          maxLines: f.multiline ? 3 : 1,
          decoration: InputDecoration(labelText: f.label),
          validator: (v) => f.required && (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
          onChanged: (v) => _values[f.name] = v,
        );
      case FieldType.phone:
        return TextFormField(
          controller: _controllers[f.name],
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: f.label),
          validator: (v) => f.required && (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
          onChanged: (v) => _values[f.name] = v,
        );
      case FieldType.email:
        return TextFormField(
          controller: _controllers[f.name],
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: f.label),
          onChanged: (v) => _values[f.name] = v,
        );
      case FieldType.number:
      case FieldType.price:
        return TextFormField(
          controller: _controllers[f.name],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: f.label, suffixText: f.type == FieldType.price ? 'DA' : null),
          validator: (v) => f.required && (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
          onChanged: (v) {
            _values[f.name] = v;
            _onFieldChanged(repo);
          },
        );
      case FieldType.enumType:
        final current = f.enumValues!.contains(_values[f.name]) ? _values[f.name] as String? : f.enumValues!.first;
        return DropdownButtonFormField<String>(
          value: current,
          decoration: InputDecoration(labelText: f.label),
          items: f.enumValues!.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            setState(() => _values[f.name] = v);
            _onFieldChanged(repo);
          },
        );
      case FieldType.ref:
        final options = _refOptions[f.name] ?? [];
        final refSchema = allSchemasOf(f.refTable!)!;
        final currentId = _values[f.name]?.toString();
        final validValue = options.any((o) => o[refSchema.primaryKey].toString() == currentId) ? currentId : null;
        return DropdownButtonFormField<String?>(
          value: validValue,
          decoration: InputDecoration(labelText: f.label),
          items: [
            if (!f.required) const DropdownMenuItem<String?>(value: null, child: Text('— Aucun —')),
            ...options.map(
              (o) => DropdownMenuItem<String?>(
                value: o[refSchema.primaryKey].toString(),
                child: Text((o[refSchema.displayField] ?? '').toString(), overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          validator: (v) => f.required && (v == null || v.isEmpty) ? 'Champ requis' : null,
          onChanged: (v) {
            setState(() => _values[f.name] = v);
            _onFieldChanged(repo);
          },
        );
      case FieldType.date:
      case FieldType.dateTime:
        final v = _values[f.name];
        final dt = v == null ? null : DateTime.tryParse(v.toString());
        return InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dt ?? DateTime.now(),
              firstDate: DateTime(2015),
              lastDate: DateTime(2100),
            );
            if (picked == null) return;
            var result = picked;
            if (f.type == FieldType.dateTime) {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(dt ?? DateTime.now()),
              );
              if (time != null) {
                result = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
              }
            }
            setState(() => _values[f.name] = result.toIso8601String());
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: f.label, suffixIcon: const Icon(Icons.calendar_today_outlined)),
            child: Text(dt == null ? 'Choisir une date' : (f.type == FieldType.dateTime ? formatDateTime(v) : formatDate(v))),
          ),
        );
      case FieldType.photo:
        final path = _values[f.name]?.toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 6),
            if (path != null && path.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(path), height: 140, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_outlined),
              label: Text(path == null || path.isEmpty ? 'Choisir une photo' : 'Changer la photo'),
              onPressed: () async {
                final picker = ImagePicker();
                final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (img != null) setState(() => _values[f.name] = img.path);
              },
            ),
          ],
        );
    }
  }
}
