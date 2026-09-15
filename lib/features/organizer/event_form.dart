import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.slug});
  final String? slug;
  @override
  ConsumerState<EventFormScreen> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<EventFormScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      venue = TextEditingController(),
      city = TextEditingController(),
      newCategory = TextEditingController();
  bool initialized = false, busy = false, addingCategory = false;
  int? category;
  String status = 'draft';
  DateTime? starts, ends;
  XFile? cover;
  ApiFailure? failure;
  Event? existing;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    venue.dispose();
    city.dispose();
    newCategory.dispose();
    super.dispose();
  }

  void populate(Event e) {
    existing = e;
    title.text = e.title;
    description.text = e.description;
    venue.text = e.venue;
    city.text = e.city;
    category = e.categoryId;
    starts = e.startsAt;
    ends = e.endsAt;
    status = e.status;
    initialized = true;
  }

  Future<void> pickDate(bool start) async {
    final now = DateTime.now();
    final current = (start ? starts : ends) ?? now;
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 20),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final d = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      if (start) {
        starts = d;
      } else {
        ends = d;
      }
    });
  }

  Future<void> pickCover() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const ApiFailure('Kapak görseli en fazla 5 MB olabilir.');
      }
      if (mounted) {
        setState(() {
          cover = file;
          failure = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => failure = e is ApiFailure
              ? e
              : const ApiFailure(
                  'Görsel seçilemedi. Galeri izinlerini kontrol et.',
                ),
        );
      }
    }
  }

  Future<void> openCategoryPicker(List<Category> categories) async {
    if (busy) return;
    newCategory.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> createFromDialog() async {
              final name = newCategory.text.trim();
              if (name.isEmpty || addingCategory) return;
              setDialogState(() => addingCategory = true);
              try {
                final json = await ref.read(apiProvider).post(
                  '/organizer/event-categories',
                  {'name': name},
                );
                final created = Category.fromJson(object(json['data']));
                ref.invalidate(jsonProvider('/event-categories'));
                if (!mounted) return;
                setState(() {
                  category = created.id;
                  newCategory.clear();
                  addingCategory = false;
                  failure = null;
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                setDialogState(() => addingCategory = false);
                if (mounted) {
                  setState(() {
                    failure = e is ApiFailure
                        ? e
                        : const ApiFailure('Kategori eklenemedi.');
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Kategori seç'),
              content: SizedBox(
                width: double.maxFinite,
                height: 380,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: categories.isEmpty
                          ? const Center(child: Text('Henüz kategori yok.'))
                          : ListView.builder(
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final item = categories[index];
                                final selected = item.id == category;
                                return ListTile(
                                  dense: true,
                                  title: Text(item.name),
                                  trailing: selected
                                      ? const Icon(Icons.check)
                                      : null,
                                  selected: selected,
                                  onTap: () {
                                    setState(() {
                                      category = item.id;
                                      failure = null;
                                    });
                                    Navigator.pop(dialogContext);
                                  },
                                );
                              },
                            ),
                    ),
                    const Divider(),
                    Text(
                      'Yeni kategori ekle',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newCategory,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => createFromDialog(),
                      decoration: const InputDecoration(
                        hintText: 'Örn. Konferans',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: addingCategory ? null : createFromDialog,
                      child: Text(addingCategory ? 'Ekleniyor…' : 'Tür ekle'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Kapat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    final api = ref.read(apiProvider);
    final refreshData = ref.read(dataRevisionProvider.notifier).refresh;
    if (starts == null || ends == null || !ends!.isAfter(starts!)) {
      setState(
        () => failure = const ApiFailure(
          'Başlangıç ve bitiş seç. Bitiş başlangıçtan sonra olmalı.',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final payload = <String, dynamic>{
        'title': title.text.trim(),
        'description': description.text.trim(),
        'venue': venue.text.trim(),
        'city': city.text.trim(),
        'event_category_id': category,
        'starts_at': starts!.toUtc().toIso8601String(),
        'ends_at': ends!.toUtc().toIso8601String(),
        'status': status,
        if (widget.slug != null) '_method': 'PUT',
        if (cover != null)
          'cover': await MultipartFile.fromFile(
            cover!.path,
            filename: cover!.name,
          ),
      };
      final result = await api.post(
        '/organizer/events${widget.slug == null ? '' : '/${Uri.encodeComponent(widget.slug!)}'}',
        FormData.fromMap(payload),
      );
      refreshData();
      final slug = string(object(result['data'])['slug']);
      if (mounted) context.go(slug.isEmpty ? '/organizer' : '/organizer/$slug');
    } catch (e) {
      if (mounted) {
        setState(() {
          failure =
              e is ApiFailure ? e : const ApiFailure('Etkinlik kaydedilemedi.');
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: detailBar(context, 'Etkinlik formu'),
        body: widget.slug != null && !initialized
            ? AsyncView(
                value: ref.watch(
                  jsonProvider(
                    '/organizer/events/${Uri.encodeComponent(widget.slug!)}',
                  ),
                ),
                onRetry: () => ref.invalidate(
                  jsonProvider(
                    '/organizer/events/${Uri.encodeComponent(widget.slug!)}',
                  ),
                ),
                data: (j) {
                  populate(Event.fromJson(object(j['data'])));
                  return fields();
                },
              )
            : fields(),
      );
  Widget fields() => Form(
        key: form,
        child: PageBody(
          children: [
            const Heading('Bir buluşma tasarla.'),
            LabeledField(
              'Etkinlik adı',
              controller: title,
              validator: requiredText,
              errorText: failure?.fields['title'],
            ),
            LabeledField(
              'Açıklama',
              controller: description,
              validator: requiredText,
              maxLines: 3,
              errorText: failure?.fields['description'],
            ),
            LabeledField(
              'Konum / Mekân',
              controller: venue,
              validator: requiredText,
              errorText: failure?.fields['venue'],
            ),
            LabeledField(
              'Şehir',
              controller: city,
              validator: requiredText,
              errorText: failure?.fields['city'],
            ),
            AsyncView(
              value: ref.watch(jsonProvider('/event-categories')),
              onRetry: () => ref.invalidate(jsonProvider('/event-categories')),
              data: (j) {
                final categories =
                    objects(j['data']).map(Category.fromJson).toList();
                final selectedName = categories
                    .where((c) => c.id == category)
                    .map((c) => c.name)
                    .firstOrNull;
                return FormField<int>(
                  key: ValueKey('category-field-$category'),
                  validator: (_) =>
                      category == null ? 'Kategori seç.' : null,
                  builder: (state) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: busy
                              ? null
                              : () => openCategoryPicker(categories),
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Kategori',
                              errorText: state.errorText ??
                                  failure?.fields['event_category_id'],
                              suffixIcon: const Icon(Icons.arrow_drop_down),
                            ),
                            child: Text(
                              selectedName ?? 'Kategori seç',
                              style: TextStyle(
                                color: selectedName == null
                                    ? YerinColors.muted
                                    : YerinColors.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dokunarak listeden seç veya yeni tür ekle.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: busy ? null : () => pickDate(true),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                starts == null
                    ? 'Başlangıç tarihi ve saati'
                    : 'Başlangıç: ${dateLabel(starts)}',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : () => pickDate(false),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                ends == null
                    ? 'Bitiş tarihi ve saati'
                    : 'Bitiş: ${dateLabel(ends)}',
              ),
            ),
            if (failure?.fields['starts_at'] != null)
              Notice(failure!.fields['starts_at']!, error: true),
            if (failure?.fields['ends_at'] != null)
              Notice(failure!.fields['ends_at']!, error: true),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: busy ? null : pickCover,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                cover == null
                    ? 'Kapak görseli seç'
                    : 'Kapak görselini değiştir',
              ),
            ),
            if (cover != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(cover!.path),
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else if (existing != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: EventCover(existing!, height: 180),
              ),
            if (failure?.fields['cover'] != null)
              Notice(failure!.fields['cover']!, error: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: InputDecoration(
                labelText: 'Yayın durumu',
                errorText: failure?.fields['status'],
              ),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Taslak')),
                DropdownMenuItem(value: 'published', child: Text('Yayında')),
              ],
              onChanged: busy ? null : (v) => status = v!,
            ),
            if (failure != null) Notice(failure!.message, error: true),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Kaydediliyor…' : 'Etkinliği kaydet'),
            ),
          ],
        ),
      );
}
