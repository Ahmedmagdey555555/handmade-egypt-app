#!/bin/bash
set -e

mkdir -p apps/customer/lib/screens

# ============ checkout_screen.dart ============
cat > apps/customer/lib/screens/checkout_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/cart_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _couponCode = TextEditingController();
  
  String _payment = 'vodafone';
  String? _governorate;
  double _deliveryFee = 0;
  double _freeAbove = 750;
  bool _loading = false;
  
  double _walletBalance = 0;
  bool _useWallet = false;
  
  double _discount = 0;
  String _couponMsg = '';
  
  final List<Map<String, dynamic>> _zones = [];
  final List<Map<String, dynamic>> _methods = [
    {'key': 'vodafone', 'name': 'فودافون كاش', 'icon': 'VF', 'enabled': true},
    {'key': 'etisalat', 'name': 'إتصالات كاش', 'icon': 'ET', 'enabled': true},
    {'key': 'instapay', 'name': 'إنستاباي', 'icon': 'IP', 'enabled': false},
    {'key': 'card', 'name': 'بطاقة بنكية', 'icon': 'CD', 'enabled': false},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await Supabase.instance.client.from('delivery_zones').select().eq('is_active', true).order('governorate');
      final settings = await Supabase.instance.client.from('app_settings').select().eq('key', 'free_delivery_threshold').maybeSingle();
      final uid = Supabase.instance.client.auth.currentUser?.id;
      
      if (uid != null) {
        final wallet = await Supabase.instance.client.from('customer_wallets').select().eq('user_id', uid).maybeSingle();
        if (wallet != null) _walletBalance = (wallet['balance'] as num?)?.toDouble() ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _zones.addAll(data.cast<Map<String, dynamic>>());
        if (settings != null && settings['value'] != null) _freeAbove = double.tryParse(settings['value'].toString()) ?? 750;
      });
    } catch (_) {}
  }

  void _onGovernorateChanged(String? gov) {
    if (gov == null) return;
    final zone = _zones.firstWhere((z) => z['governorate'] == gov, orElse: () => {});
    setState(() {
      _governorate = gov;
      _deliveryFee = (zone['fee'] as num?)?.toDouble() ?? 0;
    });
  }

  double _calculateDelivery(double cartTotal) {
    if (cartTotal >= _freeAbove) return 0;
    return _deliveryFee;
  }

  Future<void> _applyCoupon() async {
    if (_couponCode.text.isEmpty) return;
    setState(() => _couponMsg = 'جاري التحقق...');
    
    final data = await Supabase.instance.client.from('coupons').select().eq('code', _couponCode.text.trim()).eq('is_active', true).maybeSingle();
    
    if (data == null) {
      setState(() { _discount = 0; _couponMsg = 'كود غير صحيح أو منتهي'; });
      return;
    }
    
    final cartTotal = context.read<CartProvider>().total;
    final minAmount = (data['min_order_amount'] as num?)?.toDouble() ?? 0;
    
    if (cartTotal < minAmount) {
      setState(() { _discount = 0; _couponMsg = 'الحد الأدنى للطلب ${minAmount.toStringAsFixed(0)} ج.م'; });
      return;
    }

    setState(() {
      if (data['discount_type'] == 'percentage') {
        _discount = cartTotal * ((data['discount_value'] as num) / 100);
      } else {
        _discount = (data['discount_value'] as num).toDouble();
      }
      _couponMsg = 'تم تطبيق خصم ${_discount.toStringAsFixed(0)} ج.م';
    });
  }

  Future<void> _submit() async {
    if (_address.text.isEmpty || _phone.text.isEmpty || _governorate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('من فضلك أكمل كل البيانات')));
      return;
    }
    setState(() => _loading = true);
    try {
      final cart = context.read<CartProvider>();
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final delivery = _calculateDelivery(cart.total);
      final walletUsed = _useWallet ? (_walletBalance > (cart.total + delivery - _discount) ? (cart.total + delivery - _discount) : _walletBalance) : 0;
      final finalTotal = cart.total + delivery - _discount - walletUsed;

      if (walletUsed > 0) {
        await Supabase.instance.client.from('wallet_transactions').insert({
          'user_id': uid, 'amount': walletUsed, 'type': 'debit', 'description': 'خصم من المحفظة لصالح طلب'
        });
        await Supabase.instance.client.from('customer_wallets').update({
          'balance': _walletBalance - walletUsed
        }).eq('user_id', uid);
      }

      final orderData = await Supabase.instance.client.from('orders').insert({
        'customer_id': uid,
        'store_id': cart.items.values.first.product.storeId,
        'total': finalTotal,
        'status': 'pending',
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
        'governorate': _governorate,
        'delivery_fee': delivery,
      }).select().single();

      for (final item in cart.items.values) {
        await Supabase.instance.client.from('order_items').insert({
          'order_id': orderData['id'],
          'product_id': item.product.id,
          'qty': item.quantity,
          'price': item.product.price,
        });
      }

      if (!mounted) return;
      cart.clear();
      _showSuccessDialog();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('تم الطلب بنجاح'),
        content: const Text('سيتم التواصل معاك لتأكيد الطلب.'),
        actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); Navigator.pop(context); }, child: const Text('تمام'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final delivery = _calculateDelivery(cart.total);
    final walletUsed = _useWallet ? (_walletBalance > (cart.total + delivery - _discount) ? (cart.total + delivery - _discount) : _walletBalance) : 0;
    final finalTotal = cart.total + delivery - _discount - walletUsed;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(title: const Text('إتمام الطلب'), backgroundColor: const Color(0xFFB07D62), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('بيانات التوصيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _governorate,
            items: _zones.map((z) => DropdownMenuItem<String>(value: z['governorate'] as String, child: Text(z['governorate'] as String))).toList(),
            onChanged: _onGovernorateChanged,
            decoration: InputDecoration(labelText: 'المحافظة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.location_city_outlined)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _address,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'العنوان بالتفصيل', 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.phone_outlined))),
          
          const SizedBox(height: 24),
          const Text('كود الخصم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _couponCode, decoration: const InputDecoration(hintText: 'أدخل الكود', border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              ElevatedButton(onPressed: _applyCoupon, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB07D62), padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('تطبيق', style: TextStyle(color: Colors.white))),
            ],
          ),
          if (_couponMsg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_couponMsg, style: TextStyle(color: _discount > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),

          const SizedBox(height: 24),
          const Text('طريقة الدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ..._methods.map((m) {
            final enabled = m['enabled'] as bool;
            final selected = _payment == m['key'];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? const Color(0xFFB07D62) : Colors.grey.shade300, width: selected ? 2 : 1)),
              child: ListTile(
                enabled: enabled,
                onTap: enabled ? () => setState(() => _payment = m['key'] as String) : null,
                leading: Text(m['icon'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB07D62))),
                title: Text(m['name'] as String, style: TextStyle(fontWeight: FontWeight.w600, color: enabled ? Colors.black : Colors.grey)),
                trailing: !enabled ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Text('قريبًا', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))) : Radio<String>(value: m['key'] as String, groupValue: _payment, activeColor: const Color(0xFFB07D62), onChanged: (v) => setState(() => _payment = v ?? 'vodafone')),
              ),
            );
          }),

          if (_walletBalance > 0) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)),
              child: SwitchListTile(
                title: const Text('استخدام رصيد المحفظة', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('رصيدك: ${_walletBalance.toStringAsFixed(0)} ج.م'),
                value: _useWallet,
                activeColor: Colors.green,
                onChanged: (v) => setState(() => _useWallet = v),
              ),
            ),
          ],

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFB07D62).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('المنتجات', style: TextStyle(fontSize: 15)), Text('${cart.total.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))]),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('التوصيل', style: TextStyle(fontSize: 15)), Text(delivery == 0 ? 'مجاني' : '${delivery.toStringAsFixed(0)} ج.م', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: delivery == 0 ? Colors.green : Colors.black))]),
                if (_discount > 0) ...[
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الخصم', style: TextStyle(fontSize: 15, color: Colors.green)), Text('- ${_discount.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.green))]),
                ],
                if (walletUsed > 0) ...[
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('من المحفظة', style: TextStyle(fontSize: 15, color: Colors.blue)), Text('- ${walletUsed.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blue))]),
                ],
                const Divider(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), Text('${finalTotal.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFB07D62)))]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB07D62), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _loading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('تأكيد الطلب', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
FILE_END
