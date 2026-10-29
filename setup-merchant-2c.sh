#!/bin/bash
set -e

mkdir -p apps/merchant/lib/screens

# ============ 1. تحديث صفحة إنشاء المتجر (بطاقة الهوية) ============
cat > apps/merchant/lib/screens/store_setup_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';
import 'terms_screen.dart';

class StoreSetupScreen extends StatefulWidget {
  const StoreSetupScreen({super.key});

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _phone = TextEditingController();
  final _idCard = TextEditingController();
  bool _loading = false;
  bool _termsAccepted = false;

  Future<void> _createStore() async {
    if (_name.text.isEmpty || _phone.text.isEmpty || _idCard.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('من فضلك أكمل البيانات الأساسية ورقم البطاقة')));
      return;
    }
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب الموافقة على الشروط والأحكام أولاً')));
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      
      await Supabase.instance.client.from('stores').insert({
        'owner_id': uid,
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'phone': _phone.text.trim(),
        'id_card_number': _idCard.text.trim(),
        'status': 'pending',
        'terms_accepted': true,
      });

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openTerms() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const TermsScreen()));
    if (result == true) setState(() => _termsAccepted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(title: const Text('إنشاء متجر')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('أهلاً بيك في Handmade!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('عشان نضمن جودة التجار، محتاجين رقم بطاقة الهوية.', style: TextStyle(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 30),
          TextField(controller: _name, decoration: InputDecoration(labelText: 'اسم المتجر', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.store))),
          const SizedBox(height: 16),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.phone))),
          const SizedBox(height: 16),
          TextField(controller: _idCard, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'رقم بطاقة الهوية', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.badge))),
          const SizedBox(height: 16),
          TextField(controller: _desc, maxLines: 4, decoration: InputDecoration(labelText: 'نبذة عن المتجر (اختياري)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.description))),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: CheckboxListTile(
              title: const Text('أوافق على الشروط والأحكام', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              value: _termsAccepted,
              activeColor: const Color(0xFFB07D62),
              onChanged: (v) {
                if (v == true && !_termsAccepted) _openTerms();
                else setState(() => _termsAccepted = v ?? false);
              },
            ),
          ),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: _loading ? null : _createStore,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB07D62), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _loading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('إرسال طلب فتح المتجر', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
FILE_END

# ============ 2. تحديث صفحة إضافة منتج (الضمان إجباري) ============
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
  File? _newImage;
  String? _existingImageUrl;
  bool _saving = false;
  List<Map<String, dynamic>> _categories = [];

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

echo "setup-merchant-2c done part 1"
