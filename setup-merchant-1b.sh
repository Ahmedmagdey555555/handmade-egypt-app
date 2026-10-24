#!/bin/bash
set -e

mkdir -p apps/merchant/lib/screens
mkdir -p apps/merchant/lib/widgets

# ============ widgets/main_nav.dart ============
cat > apps/merchant/lib/widgets/main_nav.dart << 'FILE_END'
import 'package:flutter/material.dart';
import '../screens/merchant_products_screen.dart';
import '../screens/merchant_orders_screen.dart';
import '../screens/merchant_profile_screen.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _index = 0;

  final _pages = const [
    MerchantProductsScreen(),
    MerchantOrdersScreen(),
    MerchantProfileScreen(),
  ];

  final _titles = ['منتجاتي', 'طلباتي', 'حسابي'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: const Color(0xFFB07D62),
        unselectedItemColor: Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'منتجاتي'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'طلباتي'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}
FILE_END

# ============ screens/merchant_products_screen.dart ============
cat > apps/merchant/lib/screens/merchant_products_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_edit_product_screen.dart';

class MerchantProductsScreen extends StatefulWidget {
  const MerchantProductsScreen({super.key});

  @override
  State<MerchantProductsScreen> createState() => _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  String? _storeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final store = await Supabase.instance.client.from('stores').select('id').eq('owner_id', uid).single();
      _storeId = store['id'];

      final data = await Supabase.instance.client
          .from('products')
          .select()
          .eq('store_id', _storeId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _products = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: const Text('متأكد إنك عايز تحذف المنتج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await Supabase.instance.client.from('products').delete().eq('id', id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddEditProductScreen(storeId: _storeId!)),
          );
          if (result == true) _load();
        },
        backgroundColor: const Color(0xFFB07D62),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة منتج', style: TextStyle(color: Colors.white)),
      ),
      body: _products.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 90, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('مفيش منتجات لسه', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              itemBuilder: (c, i) {
                final p = _products[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: p['image_url'] == null
                            ? Container(width: 70, height: 70, color: Colors.grey.shade200)
                            : CachedNetworkImage(imageUrl: p['image_url'], width: 70, height: 70, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('${p['price']} ج.م', style: const TextStyle(color: Color(0xFFB07D62), fontWeight: FontWeight.bold)),
                            Text('المخزون: ${p['stock'] ?? 0}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddEditProductScreen(storeId: _storeId!, existing: p)),
                          );
                          if (result == true) _load();
                        },
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      ),
                      IconButton(
                        onPressed: () => _delete(p['id']),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
FILE_END

# ============ screens/add_edit_product_screen.dart ============
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
    try {
      final data = await Supabase.instance.client.from('categories').select().order('name');
      if (!mounted) return;
      setState(() => _categories = data.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _newImage = File(picked.path));
  }

  Future<void> _save() async {
    if (_title.text.isEmpty || _price.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('من فضلك أكمل البيانات الأساسية')));
      return;
    }
    setState(() => _saving = true);
    try {
      String? imageUrl = _existingImageUrl;

      if (_newImage != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('products').upload(_newImage!.path, _newImage!);
        imageUrl = Supabase.instance.client.storage.from('products').getPublicUrl(fileName);
      }

      final data = {
        'store_id': widget.storeId,
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'price': double.tryParse(_price.text) ?? 0,
        'stock': int.tryParse(_stock.text) ?? 0,
        'warranty': _warranty.text.trim().isEmpty ? null : _warranty.text.trim(),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        title: Text(widget.existing == null ? 'إضافة منتج' : 'تعديل منتج'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
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
            Expanded(child: TextField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المخزون', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _warranty, decoration: const InputDecoration(labelText: 'الضمان (اختياري)', border: OutlineInputBorder())),
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

echo "setup-merchant-1b done"
