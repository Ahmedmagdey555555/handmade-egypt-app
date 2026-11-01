#!/bin/bash
set -e

# ============ تحديث شاشة إضافة المنتج (إضافة وقت التحضير) ============
cat > apps/merchant/lib/screens/add_edit_product_screen.dart << 'FILE_END'
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AddEditProductScreen extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic>? existing;
  const AddEditProductScreen({super.key, required this.storeId, this.existing});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _warranty = TextEditingController();

  String? _categoryId;
  String _prepTime = 'فوري';
  File? _newImage;
  String? _existingImageUrl;
  bool _saving = false;
  List<Map<String, dynamic>> _categories = [];

  final List<String> _prepTimes = ['فوري', '3 أيام', '5 أيام', 'أسبوع'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.existing != null) {
      _title.text = widget.existing!['title'] ?? '';
      _desc.text = widget.existing!['description'] ?? '';
      _price.text = widget.existing!['price'].toString();
      _stock.text = widget.existing!['stock']?.toString() ?? '0';
      _warranty.text = widget.existing!['warranty'] ?? '';
      _categoryId = widget.existing!['category_id'];
      _prepTime = widget.existing!['preparation_time'] ?? 'فوري';
      _existingImageUrl = widget.existing!['image_url'];
    }
  }

  Future<void> _loadCategories() async {
    final data = await Supabase.instance.client.from('categories').select().order('name');
    if (mounted) setState(() => _categories = data.cast<Map<String, dynamic>>());
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1080);
    if (picked != null) setState(() => _newImage = File(picked.path));
  }

  Future<void> _save() async {
    if (_title.text.isEmpty || _price.text.isEmpty || _warranty.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الاسم والسعر والضمان إجباري')));
      return;
    }
    setState(() => _saving = true);
    try {
      String? imageUrl = _existingImageUrl;
      if (_newImage != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('products').upload(fileName, _newImage!);
        imageUrl = Supabase.instance.client.storage.from('products').getPublicUrl(fileName);
      }

      final data = {
        'store_id': widget.storeId,
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'price': double.tryParse(_price.text) ?? 0,
        'stock': int.tryParse(_stock.text) ?? 0,
        'warranty': _warranty.text.trim(),
        'preparation_time': _prepTime,
        'category_id': _categoryId,
        'image_url': imageUrl,
      };

      if (widget.existing == null) {
        await Supabase.instance.client.from('products').insert(data);
      } else {
        await Supabase.instance.client.from('products').update(data).eq('id', widget.existing!['id']);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(title: Text(widget.existing == null ? 'إضافة منتج' : 'تعديل منتج')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 200,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14)),
              child: _newImage != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_newImage!, fit: BoxFit.cover))
                  : _existingImageUrl != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: _existingImageUrl!, fit: BoxFit.cover))
                      : const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image, size: 50, color: Colors.grey), SizedBox(height: 8), Text('اضغط لاختيار صورة')])),
            ),
          ),
          const SizedBox(height: 20),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'اسم المنتج', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المخزون عندي', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _warranty, decoration: const InputDecoration(labelText: 'مدة الضمان (إجباري)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.shield))),
          const SizedBox(height: 12),
          
          // Dropdown وقت التحضير
          DropdownButtonFormField<String>(
            value: _prepTime,
            items: _prepTimes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _prepTime = v!),
            decoration: const InputDecoration(labelText: 'وقت التحضير', border: OutlineInputBorder(), prefixIcon: Icon(Icons.timer)),
          ),
          
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _categoryId,
            items: _categories.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']))).toList(),
            onChanged: (v) => setState(() => _categoryId = v),
            decoration: const InputDecoration(labelText: 'القسم', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB07D62), padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ المنتج'),
          ),
        ],
      ),
    );
  }
}
FILE_END

echo "setup-merchant-2e done"
