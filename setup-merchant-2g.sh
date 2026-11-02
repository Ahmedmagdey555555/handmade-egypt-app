#!/bin/bash

echo "🚀 Starting Phase 2G: Adding Gift Message & Variants to Merchant Orders..."

# تأكد إنك في المسار الصح
cd "$(dirname "$0")" || exit

cat << 'EOF' > lib/screens/merchant_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({Key? key}) : super(key: key);

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      // بنجيب الطلبات ومعاها تفاصيل المنتجات (order_items)
      final response = await _supabase
          .from('orders')
          .select('*, order_items(*, products(name, image_url))')
          .order('created_at', ascending: false);

      setState(() {
        _orders = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الطلبات: $e')),
      );
    }
  }

  // دالة لتغيير حالة الطلب
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _supabase.from('orders').update({'status': newStatus}).eq('id', orderId);
      _fetchOrders(); // تحديث القائمة بعد التغيير
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث حالة الطلب بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في التحديث: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0), // اللون البيج بتاعك
      appBar: AppBar(
        title: const Text('طلباتي', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFA67B5B), // اللون البني بتاعك
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFA67B5B)))
          : _orders.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return _buildOrderCard(order);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('مفيش طلبات لسه', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final List<dynamic> items = order['order_items'] ?? [];
    final String status = order['status'] ?? 'pending';
    final String giftMessage = order['gift_message'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رقم الطلب والتاريخ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('طلب #${order['id'].toString().substring(0, 8)}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(order['created_at'])),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 20),

            // تفاصيل المنتجات
            ...items.map((item) {
              final product = item['products'];
              final variants = item['variants']; // الخيارات
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade200,
                            image: product['image_url'] != null 
                                ? DecorationImage(image: NetworkImage(product['image_url']), fit: BoxFit.cover)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product['name'] ?? 'منتج', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('الكمية: ${item['quantity']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // عرض الـ Variants (الخيارات) لو موجودة
                    if (variants != null && variants.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0, right: 62.0), // إزاحة عشان تيجي تحت المنتج
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: (variants as Map<String, dynamic>).entries.map((entry) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                '${entry.key}: ${entry.value}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),

            // عرض تفاصيل الهدية لو موجودة
            if (giftMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8.0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0), // لون برتقالي/بيج فاتح جداً
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.card_giftcard, color: Color(0xFFE65100), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'رسالة الهدية:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100), fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(giftMessage, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(height: 24),

            // الجزء السفلي: الإجمالي وتغيير الحالة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الإجمالي: ${order['total_amount']} ج.م',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFA67B5B)),
                ),
                // Dropdown لتغيير الحالة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: ['pending', 'processing', 'shipped', 'delivered', 'cancelled'].contains(status) ? status : 'pending',
                      icon: const Icon(Icons.arrow_drop_down),
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      onChanged: (String? newValue) {
                        if (newValue != null && newValue != status) {
                          _updateOrderStatus(order['id'], newValue);
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                        DropdownMenuItem(value: 'processing', child: Text('قيد التجهيز')),
                        DropdownMenuItem(value: 'shipped', child: Text('تم الشحن')),
                        DropdownMenuItem(value: 'delivered', child: Text('تم التوصيل')),
                        DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
EOF

echo "✅ Phase 2G Completed: MerchantOrdersScreen updated with Gift & Variants!"
