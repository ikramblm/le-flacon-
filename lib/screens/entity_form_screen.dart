import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  bool _generatingInvoice = false;

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
      final String savedId;
      if (widget.existing != null) {
        savedId = widget.existing![widget.schema.primaryKey].toString();
        await repo.updateRecord(widget.schema, savedId, data);
      } else {
        savedId = await repo.generateId(widget.schema);
        data[widget.schema.primaryKey] = savedId;
        await repo.insertRecord(widget.schema, data);
      }
      // Pops the saved record's id (rather than a bare `true`) so a caller
      // that opened this form to create a new ref on the fly — see the
      // "+ Nouveau ..." option below — can select it immediately.
      if (mounted) Navigator.of(context).pop(savedId);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Display name of whatever the ref field [fieldName] currently points
  /// to, looked up from the already-loaded options for that field.
  String _refDisplayName(String fieldName) {
    final id = _values[fieldName]?.toString();
    if (id == null || id.isEmpty) return '—';
    final f = widget.schema.fieldByName(fieldName);
    final refTable = f?.refTable;
    if (refTable == null) return '—';
    final refSchema = allSchemasOf(refTable);
    if (refSchema == null) return '—';
    final options = _refOptions[fieldName] ?? const [];
    final matches = options.where((o) => o[refSchema.primaryKey].toString() == id);
    if (matches.isEmpty) return '—';
    return (matches.first[refSchema.displayField] ?? '—').toString();
  }

  pw.Widget _invoiceCell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  Future<Uint8List> _buildInvoicePdf() async {
    final doc = pw.Document();
    final client = _refDisplayName('client_id');
    final bouteille = _refDisplayName('bouteille_id');
    final type = _values['type_produit']?.toString() ?? '';
    final produit = type == 'Mélange personnalisé' ? _refDisplayName('melange_id') : _refDisplayName('recette_id');
    final dateValue = _values['date'];
    final date = (dateValue == null || dateValue.toString().isEmpty) ? '—' : formatDateTime(dateValue);
    final total = formatPrice(_values['total']);
    final invoiceNumber = (widget.existing?[widget.schema.primaryKey] ?? '—').toString();

    doc.addPage(
      pw.Page(
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Le Flacon', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Text('Gestion de parfumerie', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              pw.SizedBox(height: 24),
              pw.Text('Facture', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('N° $invoiceNumber'),
              pw.SizedBox(height: 16),
              pw.Text('Client : $client'),
              pw.Text('Date : $date'),
              pw.SizedBox(height: 24),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
                children: [
                  pw.TableRow(children: [_invoiceCell('Description', bold: true), _invoiceCell('Détail', bold: true)]),
                  pw.TableRow(children: [_invoiceCell('Produit'), _invoiceCell(produit)]),
                  pw.TableRow(children: [_invoiceCell('Bouteille'), _invoiceCell(bouteille)]),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Total : $total', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  Future<void> _shareInvoice() async {
    setState(() => _generatingInvoice = true);
    try {
      final bytes = await _buildInvoicePdf();
      await Printing.layoutPdf(onLayout: (format) async => bytes, name: 'facture_le_flacon.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de générer la facture.')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingInvoice = false);
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
                  if (widget.schema.tableName == 'vente') ...[
                    OutlinedButton.icon(
                      icon: _generatingInvoice
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Générer la facture (PDF)'),
                      onPressed: _generatingInvoice ? null : _shareInvoice,
                    ),
                    const SizedBox(height: 14),
                  ],
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
        const newOptionValue = '__new__';
        final options = _refOptions[f.name] ?? [];
        final refSchema = allSchemasOf(f.refTable!)!;
        final currentId = _values[f.name]?.toString();
        final validValue = options.any((o) => o[refSchema.primaryKey].toString() == currentId) ? currentId : null;
        return DropdownButtonFormField<String?>(
          value: validValue,
          decoration: InputDecoration(labelText: f.label),
          items: [
            DropdownMenuItem<String?>(
              value: newOptionValue,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Nouveau ${refSchema.label.toLowerCase()}',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (!f.required) const DropdownMenuItem<String?>(value: null, child: Text('— Aucun —')),
            ...options.map(
              (o) => DropdownMenuItem<String?>(
                value: o[refSchema.primaryKey].toString(),
                child: Text((o[refSchema.displayField] ?? '').toString(), overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          validator: (v) => f.required && (v == null || v.isEmpty) ? 'Champ requis' : null,
          onChanged: (v) async {
            if (v == newOptionValue) {
              final newId = await Navigator.push<String?>(
                context,
                MaterialPageRoute(builder: (_) => EntityFormScreen(schema: refSchema)),
              );
              if (newId == null) return;
              final rows = await repo.getAll(refSchema);
              if (!mounted) return;
              setState(() {
                _refOptions[f.name] = rows;
                _values[f.name] = newId;
              });
              _onFieldChanged(repo);
              return;
            }
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
