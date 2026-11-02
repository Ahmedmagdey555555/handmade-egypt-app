#!/bin/bash

echo "🚀 Starting Phase 3C: Shipments QR & Tracking..."

cd "$(dirname "$0")" || exit

# إضافة مكتبة الـ QR
if ! grep -q "qr_flutter" pubspec.yaml; then
  sed -i '' '/dependencies:/a\
  qr_flutter: ^4.1.0
  ' pubspec.yaml
fi

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
            QrImageView(
              data: trackingCode,
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 16),
            Text('كود التتبع: $trackingCode', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('اعرض هذا الباركود لموظف المركز لاستلام الشحنة', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  // دالة وهمية لإنشاء شحنة جديدة (ممكن تطورها بعدين عشان تختار المنتجات)
  Future<void> _createMockShipment() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final code = 'SHP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      await _supabase.from('merchant_shipments').insert({
        'merchant_id': user.id,
        'tracking_code': code,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      _fetchShipments();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الشحنة بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
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
        onPressed: _createMockShipment,
        backgroundColor: const Color(0xFFA67B5B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('شحنة جديدة', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
EOF

echo "✅ Phase 3C Completed: QR Code & Shipment Tracking!"
