'use client';
import { useState, useEffect } from 'react';
import { supabase } from '../../../lib/supabase';

export default function CustomOrdersPage() {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchOrders();
  }, []);

  const fetchOrders = async () => {
    const { data } = await supabase.from('custom_orders').select('*').order('created_at', { ascending: false });
    setOrders(data || []);
    setLoading(false);
  };

  const updateStatus = async (id, status) => {
    await supabase.from('custom_orders').update({ status }).eq('id', id);
    fetchOrders();
  };

  if (loading) return <div style={{ padding: '40px' }}>جاري التحميل...</div>;

  return (
    <div style={{ padding: '40px' }}>
      <h1 style={{ marginBottom: '30px' }}>الطلبات المخصصة</h1>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
        {orders.length === 0 ? (
          <div style={{ background: 'white', padding: '20px', borderRadius: '8px', textAlign: 'center' }}>لا توجد طلبات مخصصة</div>
        ) : orders.map(o => (
          <div key={o.id} style={{ background: 'white', padding: '20px', borderRadius: '8px', boxShadow: '0 2px 8px rgba(0,0,0,0.05)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '15px' }}>
              <h3 style={{ color: '#B07D62', margin: 0 }}>طلب #{o.id.slice(0, 6)}</h3>
              <select 
                value={o.status} 
                onChange={(e) => updateStatus(o.id, e.target.value)}
                style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ccc' }}
              >
                <option value="pending">قيد المراجعة</option>
                <option value="accepted">تم القبول</option>
                <option value="rejected">مرفوض</option>
              </select>
            </div>
            <p><strong>الوصف:</strong> {o.description}</p>
            <p><strong>الميزانية:</strong> {o.budget ? `${o.budget} ج.م` : 'غير محددة'}</p>
            <p><strong>نوع المنتج:</strong> {o.product_type}</p>
            <p><strong>وقت التسليم:</strong> {o.delivery_time || 'غير محدد'}</p>
          </div>
        ))}
      </div>
    </div>
  );
                  }
