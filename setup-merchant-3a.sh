#!/bin/bash

echo "🚀 Starting Phase 3A (Revised): Quick Dashboard & Low Stock Alert..."

cd "$(dirname "$0")" || exit

# تحديث شاشة المنتجات لإضافة لوحة التحكم وتنبيه المخزون
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

  // متغيرات لوحة التحكم
  int _pendingOrdersCount = 0;
  double _walletBalance = 0.0;
  int _totalProductsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. جلب المنتجات
      final productsResponse = await _supabase
          .from('products')
          .select()
          .eq('merchant_id', user.id)
          .order('created_at', ascending: false);

      // 2. جلب عدد الطلبات المعلقة (Pending)
      final ordersResponse = await _supabase
          .from('orders')
          .select('id')
          .eq('merchant_id', user.id)
          .eq('status', 'pending');

      // 3. جلب رصيد المحفظة من جدول المتاجر
      final storeResponse = await _supabase
          .from('stores')
          .select('wallet_balance')
          .eq('merchant_id', user.id)
          .maybeSingle();

      setState(() {
        _products = List<Map<String, dynamic>>.from(productsResponse);
        _totalProductsCount = _products.length;
        _pendingOrdersCount = ordersResponse.length;
        _walletBalance = (storeResponse?['wallet_balance'] ?? 0.0).toDouble();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      appBar: AppBar(
        title: const Text('منتجاتي', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFA67B5B),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFA67B5B)))
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              color: const Color(0xFFA67B5B),
              child: Column(
                children: [
                  _buildDashboardHeader(),
                  Expanded(
                    child: _products.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              return _buildProductCard(_products[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to AddEditProductScreen
        },
        backgroundColor: const Color(0xFFA67B5B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة منتج', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // === لوحة التحكم السريعة ===
  Widget _buildDashboardHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard(
            title: 'طلبات معلقة',
            value: '$_pendingOrdersCount',
            icon: Icons.pending_actions,
            color: Colors.orange,
          ),
          _buildStatCard(
            title: 'رصيد المحفظة',
            value: '$_walletBalance ج.م',
            icon: Icons.account_balance_wallet,
            color: Colors.green,
          ),
          _buildStatCard(
            title: 'إجمالي المنتجات',
            value: '$_totalProductsCount',
            icon: Icons.inventory,
            color: const Color(0xFFA67B5B),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('مفيش منتجات لسه', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final int stock = product['stock'] ?? 0;
    final bool isLowStock = stock <= 3; // شرط تنبيه المخزون

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
            image: product['image_url'] != null
                ? DecorationImage(image: NetworkImage(product['image_url']), fit: BoxFit.cover)
                : null,
          ),
          child: product['image_url'] == null ? const Icon(Icons.image, color: Colors.grey) : null,
        ),
        title: Text(
          product['name'] ?? 'منتج بدون اسم',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('السعر: ${product['price']} ج.م', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('المخزون: $stock', style: TextStyle(color: isLowStock ? Colors.red : Colors.grey)),
                if (isLowStock) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Text(
                      'كمية قليلة',
                      style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Color(0xFFA67B5B)),
          onPressed: () {
            // Navigate to Edit
          },
        ),
      ),
    );
  }
}
EOF

echo "✅ Phase 3A (Revised) Completed: Quick Dashboard & Low Stock Alert added!"
