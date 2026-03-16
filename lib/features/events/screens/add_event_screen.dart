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
  final _imageUrl = TextEditingController();
  String _category = 'konser';

  final _eventService = EventService();

  bool _loading = false;

  Future<void> _saveEvent() async {
    final title = _title.text.trim();
    final description = _description.text.trim();
    final location = _location.text.trim();
    final date = _date.text.trim();
    final imageUrl = _imageUrl.text.trim();

    if (title.isEmpty ||
        description.isEmpty ||
        location.isEmpty ||
        date.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldur.')),
      );
      return;
    }

    if (imageUrl.isNotEmpty &&
        !imageUrl.startsWith('http://') &&
        !imageUrl.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Görsel bağlantısı http:// veya https:// ile başlamalı.',
          ),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      await _eventService.addEvent(
        title: title,
        description: description,
        category: _category,
        location: location,
        date: date,
        imageUrl: imageUrl,
        createdBy: user.uid,
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
    _imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = widget.role == 'admin' || widget.role == 'moderator';
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFFF5F2ED)),
          Positioned(
            top: -150,
            left: -80,
            right: -80,
            child: Container(
              height: 320,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F766E), Color(0xFF255F85)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: canCreate
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton.filledTonal(
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Yeni Etkinlik',
                          style: textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Topluluğunu harekete geçirecek bir etkinlik oluştur.',
                          style: textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _title,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Etkinlik Başlığı',
                                    prefixIcon: Icon(Icons.stars_rounded),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _description,
                                  maxLines: 4,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  textInputAction: TextInputAction.newline,
                                  decoration: const InputDecoration(
                                    labelText: 'Açıklama',
                                    alignLabelWithHint: true,
                                    prefixIcon: Icon(Icons.article_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _category,
                                  decoration: const InputDecoration(
                                    labelText: 'Kategori',
                                    prefixIcon: Icon(Icons.sell_outlined),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'konser',
                                      child: Text('Konser'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'sinema',
                                      child: Text('Sinema'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'tiyatro',
                                      child: Text('Tiyatro'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'spor',
                                      child: Text('Spor'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'sanat',
                                      child: Text('Sanat'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'yemek',
                                      child: Text('Yemek'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'genel',
                                      child: Text('Genel'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _category = value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _imageUrl,
                                  keyboardType: TextInputType.url,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Görsel URL (opsiyonel)',
                                    hintText: 'https://...jpg',
                                    prefixIcon: Icon(Icons.image_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _location,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Konum',
                                    prefixIcon: Icon(Icons.place_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _date,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) =>
                                      _loading ? null : _saveEvent(),
                                  decoration: const InputDecoration(
                                    labelText: 'Tarih',
                                    hintText: 'Örn: 20 Mart 2026 - 18:00',
                                    prefixIcon: Icon(Icons.schedule_rounded),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _saveEvent,
                                    child: _loading
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Etkinliği Kaydet'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const Center(child: Text('Bu sayfaya erişim yetkin yok.')),
          ),
        ],
      ),
    );
  }
}
