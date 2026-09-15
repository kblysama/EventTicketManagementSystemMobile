import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';

Future<void> showTicketTypeForm(
  BuildContext context,
  String slug,
  TicketType? type,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TicketTypeForm(slug: slug, type: type),
    );

String? nonNegativeInteger(String? text) =>
    int.tryParse(text?.trim() ?? '') == null || int.parse(text!.trim()) < 0
        ? 'Sıfır veya pozitif tam sayı gir.'
        : null;
String? positiveInteger(String? text) =>
    nonNegativeInteger(text) ??
    (int.parse(text!.trim()) < 1 ? 'En az 1 olmalı.' : null);

class TicketTypeForm extends ConsumerStatefulWidget {
  const TicketTypeForm({super.key, required this.slug, this.type});
  final String slug;
  final TicketType? type;
  @override
  ConsumerState<TicketTypeForm> createState() => _TicketTypeFormState();
}

class _TicketTypeFormState extends ConsumerState<TicketTypeForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.type?.name);
  late final description = TextEditingController(
    text: widget.type?.description,
  );
  late final price = TextEditingController(
    text: widget.type?.price.toString() ?? '0',
  );
  late final capacity = TextEditingController(
    text: widget.type?.capacity.toString(),
  );
  late String status = widget.type?.saleStatus ?? 'on_sale';
  bool busy = false;
  ApiFailure? failure;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    capacity.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    final refreshData = ref.read(dataRevisionProvider.notifier).refresh;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final payload = {
        'name': name.text.trim(),
        'description': description.text.trim(),
        'price': int.parse(price.text.trim()),
        'capacity': int.parse(capacity.text.trim()),
        'sale_status': status,
      };
      final path =
          '/organizer/events/${Uri.encodeComponent(widget.slug)}/ticket-types';
      if (widget.type == null) {
        await ref.read(apiProvider).post(path, payload);
      } else {
        await ref.read(apiProvider).put('$path/${widget.type!.id}', payload);
      }
      refreshData();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          failure = e is ApiFailure
              ? e
              : const ApiFailure('Bilet tipi kaydedilemedi.');
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Heading(
                  widget.type == null
                      ? 'Bilet tipi ekle'
                      : 'Bilet tipini düzenle',
                ),
                LabeledField(
                  'Ad',
                  controller: name,
                  validator: requiredText,
                  errorText: failure?.fields['name'],
                ),
                LabeledField(
                  'Açıklama',
                  controller: description,
                  errorText: failure?.fields['description'],
                ),
                LabeledField(
                  'Fiyat (tam TL)',
                  controller: price,
                  validator: nonNegativeInteger,
                  keyboardType: TextInputType.number,
                  errorText: failure?.fields['price'],
                ),
                LabeledField(
                  'Kapasite',
                  controller: capacity,
                  validator: positiveInteger,
                  keyboardType: TextInputType.number,
                  errorText: failure?.fields['capacity'],
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(
                    labelText: 'Satış durumu',
                    errorText: failure?.fields['sale_status'],
                  ),
                  items: const [
                    DropdownMenuItem(value: 'on_sale', child: Text('Satışta')),
                    DropdownMenuItem(
                        value: 'paused', child: Text('Durduruldu')),
                  ],
                  onChanged: busy ? null : (v) => setState(() => status = v!),
                ),
                if (failure != null) Notice(failure!.message, error: true),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Kaydediliyor…' : 'Kaydet'),
                ),
              ],
            ),
          ),
        ),
      );
}
