#!/bin/bash
set -e

mkdir -p apps/merchant/lib/screens
mkdir -p apps/merchant/lib/widgets

# ============ 1. شاشة شحنات المركز (جديدة) ============
cat > apps/merchant/lib/screens/merchant_shipments_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantShipmentsScreen extends StatefulWidget {
  const MerchantShipmentsScreen({super.key});

  @override
  State<MerchantShipmentsScreen> createState() => _MerchantShipmentsScreenState();
}

class _MerchantShipmentsScreenState extends State<MerchantShipmentsScreen> {
  List<Map<String, dynamic>> _shipments = [];
  List<Map<String, dynamic>> _products = [];
  String? _storeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final store = await Supabase.instance.client.from('stores').select('id').eq('owner_id', uid).single();
      _storeId = store['id'];

      final ships = await Supabase.instance.client.from('merchant_shipments').select('*, merchant_shipment_items(*, products(title))').eq('store_id', _storeId!).order('created_at', ascending: false);
      final prods = await Supabase.instance.client.from('products').select().eq('store_id', _storeId!).gt('stock', 0);

      if (!mounted) return;
      setState(() {
        _shipments = ships.cast<Map<String, dynamic>>();
        _products = prods.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCreateShipment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 16, right: 16),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const Text('شحن منتجات للمركز', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('اختر المنتجات والكميات لشحنها للمركز (الفحص إجباري)', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _products.length,
                itemBuilder: (c, i) {
                  final p = _products[i];
                  return Card(
                    child: ListTile(
                      title: Text(p['title']),
                      subtitle: Text('المتاح عندي: ${p['stock']}'),
                      trailing: ElevatedButton(
                        onPressed: () => _showQuantityDialog(p),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB07D62)),
                        child: const Text('شحن', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuantityDialog(Map<String, dynamic> product) {
    final qty = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('شحن: ${product['title']}'),
        content: TextField(
          controller: qty,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final amount = int.tryParse(qty.text);
              if (amount == null || amount <= 0 || amount > (product['stock'] as int)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كمية غير صحيحة')));
                return;
              }
              
              try {
                // إنشاء شحنة
                final shipment = await Supabase.instance.client.from('merchant_shipments').insert({
                  'store_id': _storeId,
                  'status': 'pending'
                }).select().single();

                // إضافة العناصر
                await Supabase.instance.client.from('merchant_shipment_items').insert({
                  'shipment_id': shipment['id'],
                  'product_id': product['id'],
                  'quantity': amount,
                });

                // خصم من مخزون التاجر
                await Supabase.instance.client.from('products').update({
                  'stock': (product['stock'] as int) - amount
                }).eq('id', product['id']);

                if (!mounted) return;
                Navigator.pop(dialogContext);
                Navigator.pop(context); // إغلاق BottomSheet
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الشحنة بنجاح')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateShipment,
        backgroundColor: const Color(0xFFB07D62),
        icon: const Icon(Icons.local_shipping, color: Colors.white),
        label: const Text('شحنة جديدة', style: TextStyle(color: Colors.white)),
      ),
      body: _shipments.isEmpty 
        ? const Center(child: Text('لا توجد شحنات سابقة'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _shipments.length,
            itemBuilder: (c, i) {
              final s = _shipments[i];
              final isReceived = s['status'] == 'received';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('شحنة #${s['id'].toString().substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: isReceived ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(isReceived ? 'تم الاستلام' : 'في الطريق', style: TextStyle(color: isReceived ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const Divider(),
                      ...s['merchant_shipment_items'].map<Widget>((item) => Text('- ${item['products']['title']} (الكمية: ${item['quantity']})')).toList(),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
FILE_END

# ============ 2. تحديث شاشة منتجاتي (إظهار مخزون المركز) ============
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

      final data = await Supabase.instance.client.from('products').select().eq('store_id', _storeId!).order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _products = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditProductScreen(storeId: _storeId!)));
          if (result == true) _load();
        },
        backgroundColor: const Color(0xFFB07D62),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة منتج', style: TextStyle(color: Colors.white)),
      ),
      body: _products.isEmpty
          ? const Center(child: Text('مفيش منتجات لسه'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              itemBuilder: (c, i) {
                final p = _products[i];
                final merchantStock = p['stock'] ?? 0;
                final hubStock = p['hub_stock'] ?? 0;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      Row(
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
                                Text('عندي: $merchantStock | المركز: $hubStock', style: TextStyle(fontSize: 13, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          IconButton(onPressed: () async {
                            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditProductScreen(storeId: _storeId!, existing: p)));
                            if (result == true) _load();
                          }, icon: const Icon(Icons.edit_outlined, color: Colors.blue)),
                          IconButton(onPressed: () => _delete(p['id']), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                        ],
                      ),
                      if (hubStock == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.orange),
                                SizedBox(width: 8),
                                Expanded(child: Text('هذا المنتج غير متاح للبيع حتى يتم شحنه للمركز وفحصه.', style: TextStyle(fontSize: 11, color: Colors.orange))),
                              ],
                            ),
                          ),
                        )
                    ],
                  ),
                );
              },
            ),
    );
  }
}
FILE_END

# ============ 3. تحديث القايمة السفلية (إضافة صفحة الشحنات) ============
cat > apps/merchant/lib/widgets/main_nav.dart << 'FILE_END'
import 'package:flutter/material.dart';
import '../screens/merchant_products_screen.dart';
import '../screens/merchant_orders_screen.dart';
import '../screens/merchant_shipments_screen.dart';
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
    MerchantShipmentsScreen(),
    MerchantProfileScreen(),
  ];

  final _titles = ['منتجاتي', 'طلباتي', 'شحنات المركز', 'حسابي'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: const Color(0xFFB07D62),
        unselectedItemColor: Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'المنتجات'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'الطلبات'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), activeIcon: Icon(Icons.local_shipping), label: 'الشحنات'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}
FILE_END

echo "setup-merchant-2d done"
