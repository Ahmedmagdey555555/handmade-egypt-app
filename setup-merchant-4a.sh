#!/bin/bash

echo "🚀 Starting Phase 4A: Functional Ship to Hub..."

cd "$(dirname "$0")" || exit

# تحديث شاشة شحنات المركز
cat << 'EOF' > lib/screens/merchant_shipments_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

class MerchantShipmentsScreen extends StatefulWidget {
  const MerchantShipmentsScreen({Key? key}) : super(key: key);

  @override
  State<MerchantShipmentsScreen> createState() => _MerchantShipmentsScreenState();
}

class _MerchantShipmentsScreenState extends State<MerchantShipmentsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _shipments = [];

  @override
  void initState() {
    super.initState();
    _fetchShipments();
  }

  Future<void> _fetchShipments() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('merchant_shipments')
          .select()
          .eq('merchant_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _shipments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  void _showQRCode(String trackingCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('باركود الشحنة', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: trackingCode, version: QrVersions.auto, size: 200.0),
            const SizedBox(height: 16),
            Text('كود التتبع: $trackingCode', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('اعرض هذا الباركود لموظف المركز لاستلام الشحنة', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  // شاشة اختيار المنتجات لشحنها
  Future<void> _showCreateShipmentSheet() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // جلب منتجات التاجر
    final productsRes = await _supabase.from('products').select().eq('merchant_id', user.id);
    final List<Map<String, dynamic>> products = List<Map<String, dynamic>>.from(productsRes);

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ليس لديك منتجات لشحنها')));
      return;
    }

    Map<String, int> selectedQuantities = {};

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('شحن منتجات للمركز', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('اختر المنتجات والكميات لشحنها للمركز (الفحص إجباري)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final p = products[index];
                        final int currentMerchantStock = p['stock'] ?? 0;
                        return CheckboxListTile(
                          title: Text(p['name'] ?? 'منتج'),
                          subtitle: Text('المخزون عندك: $currentMerchantStock'),
                          value: selectedQuantities.containsKey(p['id']),
                          activeColor: const Color(0xFFA67B5B),
                          onChanged: (bool? val) {
                            setStateSheet(() {
                              if (val == true) {
                                selectedQuantities[p['id']] = 1; // افتراضي قطعة واحدة
                              } else {
                                selectedQuantities.remove(p['id']);
                              }
                            });
                          },
                          secondary: selectedQuantities.containsKey(p['id'])
                              ? SizedBox(
                                  width: 60,
                                  child: TextFormField(
                                    initialValue: '1',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(isDense: true, labelText: 'الكمية'),
                                    onChanged: (v) {
                                      final q = int.tryParse(v) ?? 1;
                                      selectedQuantities[p['id']] = q;
                                    },
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA67B5B), padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () async {
                        if (selectedQuantities.isEmpty) return;
                        
                        // إنشاء الشحنة
                        final code = 'SHP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                        final shipmentRes = await _supabase.from('merchant_shipments').insert({
                          'merchant_id': user.id,
                          'tracking_code': code,
                          'status': 'pending',
                        }).select().single();

                        final shipmentId = shipmentRes['id'];

                        // إضافة المنتجات للشحنة وتحديث المخزون
                        for (var entry in selectedQuantities.entries) {
                          // 1. إضافة في جدول تفاصيل الشحنة
                          await _supabase.from('shipment_items').insert({
                            'shipment_id': shipmentId,
                            'product_id': entry.key,
                            'quantity': entry.value,
                          });
                          
                          // 2. خصم الكمية من مخزون التاجر
                          final currentStock = products.firstWhere((element) => element['id'] == entry.key)['stock'] ?? 0;
                          await _supabase.from('products').update({'stock': currentStock - entry.value}).eq('id', entry.key);
                        }

                        if (mounted) Navigator.pop(context);
                        _fetchShipments();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الشحنة بنجاح')));
                      },
                      child: const Text('تأكيد الشحن للمركز', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      appBar: AppBar(title: const Text('شحنات المركز', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFFA67B5B), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFA67B5B)))
          : _shipments.isEmpty
              ? const Center(child: Text('لا توجد شحنات سابقة', style: TextStyle(color: Colors.grey, fontSize: 18)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _shipments.length,
                  itemBuilder: (context, index) {
                    final shipment = _shipments[index];
                    final status = shipment['status'] ?? 'pending';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping, color: Color(0xFFA67B5B), size: 32),
                        title: Text('شحنة #${shipment['tracking_code'] ?? 'غير محدد'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          status == 'pending' ? 'قيد الانتظار' : status == 'received' ? 'تم الاستلام بالمركز' : 'تم التوصيل',
                          style: TextStyle(color: status == 'pending' ? Colors.orange : Colors.green),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.qr_code, size: 30, color: Color(0xFFA67B5B)),
                          onPressed: () => _showQRCode(shipment['tracking_code'] ?? 'ERROR'),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateShipmentSheet,
        backgroundColor: const Color(0xFFA67B5B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('شحنة جديدة', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
EOF

echo "✅ Phase 4A Completed: Functional Ship to Hub Screen!"
