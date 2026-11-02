#!/bin/bash

echo "🚀 Starting Phase 3B: Bulk Actions, Coupons & Best Sellers..."

cd "$(dirname "$0")" || exit

# 1. تحديث شاشة المنتجات (إضافة التحديد المتعدد)
cat << 'EOF' > lib/screens/merchant_products_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantProductsScreen extends StatefulWidget {
  const MerchantProductsScreen({Key? key}) : super(key: key);

  @override
  State<MerchantProductsScreen> createState() => _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  
  // متغيرات التحديد المتعدد
  final Set<String> _selectedProductIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('products')
          .select()
          .eq('merchant_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _products = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  // دالة تحديد/إلغاء تحديد منتج
  void _toggleSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
        if (_selectedProductIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedProductIds.add(productId);
        _isSelectionMode = true;
      }
    });
  }

  // دالة تحديث حالة المنتجات (إخفاء/إظهار)
  Future<void> _bulkUpdateStatus(bool isAvailable) async {
    try {
      await _supabase
          .from('products')
          .update({'is_available': isAvailable})
          .inFilter('id', _selectedProductIds.toList());
      
      setState(() {
        _selectedProductIds.clear();
        _isSelectionMode = false;
      });
      _fetchProducts();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث حالة المنتجات بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      appBar: AppBar(
        title: Text(_isSelectionMode ? 'تم تحديد ${_selectedProductIds.length}' : 'منتجاتي', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFA67B5B),
        centerTitle: true,
        leading: _isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () {
                setState(() { _selectedProductIds.clear(); _isSelectionMode = false; });
              })
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFA67B5B)))
          : _products.isEmpty
              ? const Center(child: Text('مفيش منتجات لسه', style: TextStyle(color: Colors.grey, fontSize: 18)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _products.length,
                  itemBuilder: (context, index) => _buildProductCard(_products[index]),
                ),
      bottomNavigationBar: _isSelectionMode ? _buildBulkActionsBar() : null,
      floatingActionButton: !_isSelectionMode ? FloatingActionButton.extended(
        onPressed: () { /* Navigate to Add */ },
        backgroundColor: const Color(0xFFA67B5B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة منتج', style: TextStyle(color: Colors.white)),
      ) : null,
    );
  }

  Widget _buildBulkActionsBar() {
    return BottomAppBar(
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: () => _bulkUpdateStatus(true),
            icon: const Icon(Icons.visibility, color: Colors.green),
            label: const Text('إظهار', style: TextStyle(color: Colors.green)),
          ),
          TextButton.icon(
            onPressed: () => _bulkUpdateStatus(false),
            icon: const Icon(Icons.visibility_off, color: Colors.orange),
            label: const Text('إخفاء', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final int stock = product['stock'] ?? 0;
    final bool isLowStock = stock <= 3;
    final bool isSelected = _selectedProductIds.contains(product['id']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? const Color(0xFFA67B5B) : Colors.transparent, width: 2)),
      elevation: isSelected ? 4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => _toggleSelection(product['id']), // الضغط المطول للدخول في وضع التحديد
        onTap: _isSelectionMode ? () => _toggleSelection(product['id']) : null,
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSelectionMode)
                Checkbox(
                  value: isSelected,
                  activeColor: const Color(0xFFA67B5B),
                  onChanged: (_) => _toggleSelection(product['id']),
                ),
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                  image: product['image_url'] != null ? DecorationImage(image: NetworkImage(product['image_url']), fit: BoxFit.cover) : null,
                ),
              ),
            ],
          ),
          title: Text(product['name'] ?? 'منتج', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('المخزون: $stock ${isLowStock ? "⚠️" : ""}', style: TextStyle(color: isLowStock ? Colors.red : Colors.grey)),
        ),
      ),
    );
  }
}
EOF

# 2. إنشاء شاشة الكوبونات الجديدة
cat << 'EOF' > lib/screens/merchant_coupons_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MerchantCouponsScreen extends StatefulWidget {
  const MerchantCouponsScreen({Key? key}) : super(key: key);

  @override
  State<MerchantCouponsScreen> createState() => _MerchantCouponsScreenState();
}

class _MerchantCouponsScreenState extends State<MerchantCouponsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _coupons = [];

  @override
  void initState() {
    super.initState();
    _fetchCoupons();
  }

  Future<void> _fetchCoupons() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('coupons')
          .select()
          .eq('store_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _coupons = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _addCoupon(String code, double discount) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('coupons').insert({
        'store_id': user.id,
        'code': code.toUpperCase(),
        'discount_percentage': discount,
        'is_active': true,
      });
      _fetchCoupons();
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة الكوبون بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ (تأكد أن الكود غير مستخدم): $e')));
    }
  }

  void _showAddCouponSheet() {
    final codeController = TextEditingController();
    final discountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('إضافة كوبون خصم جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: codeController, decoration: const InputDecoration(labelText: 'كود الخصم (مثال: SALE10)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: discountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'نسبة الخصم %', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA67B5B), padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () {
                  final code = codeController.text.trim();
                  final discount = double.tryParse(discountController.text.trim()) ?? 0;
                  if (code.isNotEmpty && discount > 0) _addCoupon(code, discount);
                },
                child: const Text('حفظ الكوبون', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      appBar: AppBar(title: const Text('الكوبونات', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFFA67B5B)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFA67B5B)))
          : _coupons.isEmpty
              ? const Center(child: Text('لا توجد كوبونات', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _coupons.length,
                  itemBuilder: (context, index) {
                    final coupon = _coupons[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_offer, color: Color(0xFFA67B5B)),
                        title: Text(coupon['code'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('خصم ${coupon['discount_percentage']}%'),
                        trailing: Text(coupon['is_active'] == true ? 'نشط' : 'متوقف', style: TextStyle(color: coupon['is_active'] == true ? Colors.green : Colors.red)),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCouponSheet,
        backgroundColor: const Color(0xFFA67B5B),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
EOF

# 3. إضافة زرار الكوبونات في شاشة الحساب (MerchantProfileScreen)
# هنستخدم sed عشان نضيف الـ ListTile قبل زرار تسجيل الخروج
if [ -f "lib/screens/merchant_profile_screen.dart" ]; then
  # تأكد من وجود الـ import
  sed -i '' "1s/^/import 'merchant_coupons_screen.dart';\n/" lib/screens/merchant_profile_screen.dart
  
  # إضافة زرار الكوبونات (بنفترض إن فيه ListView أو Column)
  sed -i '' '/تسجيل الخروج/i\
  ListTile(\
    leading: const Icon(Icons.local_offer, color: Color(0xFFA67B5B)),\
    title: const Text("الكوبونات والخصومات", style: TextStyle(fontWeight: FontWeight.bold)),\
    trailing: const Icon(Icons.arrow_forward_ios, size: 16),\
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MerchantCouponsScreen())),\
  ),\
  ' lib/screens/merchant_profile_screen.dart
fi

echo "✅ Phase 3B Completed: Bulk Actions, Coupons Screen Added!"
