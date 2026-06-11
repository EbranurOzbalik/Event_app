import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/event_service.dart';

class AddEventScreen extends StatefulWidget {
  final String role;

  const AddEventScreen({super.key, required this.role});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _date = TextEditingController();

  bool _loading = false;

  Future<void> _saveEvent() async {
    final title = _title.text.trim();
    final description = _description.text.trim();
    final location = _location.text.trim();
    final date = _date.text.trim();

    if (title.isEmpty ||
        description.isEmpty ||
        location.isEmpty ||
        date.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldur.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      await EventService().addEvent(
        title: title,
        description: description,
        location: location,
        date: date,
        createdBy: user.uid,
        createdByRole: widget.role,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Etkinlik eklendi.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Etkinlik eklenemedi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = widget.role == 'admin' || widget.role == 'moderator';

    return Scaffold(
      appBar: AppBar(title: const Text('Etkinlik Ekle')),
      body: canCreate
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Etkinlik Başlığı',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _location,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Konum'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _date,
                    decoration: const InputDecoration(
                      labelText: 'Tarih',
                      hintText: 'Örn: 20 Mart 2026 - 18:00',
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _loading ? null : _saveEvent,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Etkinliği Kaydet'),
                  ),
                ],
              ),
            )
          : const Center(child: Text('Bu sayfaya erişim yetkin yok.')),
    );
  }
}
