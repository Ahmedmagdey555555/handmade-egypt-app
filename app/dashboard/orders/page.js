'use client';
import { useState, useEffect } from 'react';
import { supabase } from '../../../lib/supabase';

export default function OrdersPage() {
  const [orders, setOrders] = useState([]);
  const [companies, setCompanies] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    const { data: comps } = await supabase.from('shipping_companies').select('*');
    setCompanies(comps || []);

    const { data: ords } = await supabase.from('orders').select('*, shipping_companies(name)').order('created_at', { ascending: false });
    setOrders(ords || []);
    setLoading(false);
  };

  const assignShipping = async (orderId, companyId) => {
    await supabase.from('orders').update({ shipping_company_id: companyId }).eq('id', orderId);
    fetchData();
  };

  if (loading) return <div style={{ padding: '40px' }}>جاري التحميل...</div>;

  return (
    <div style={{ padding: '40px' }}>
      <h1 style={{ marginBottom: '30px' }}>الطلبات</h1>
      <div style={{ background: 'white', borderRadius: '8px', overflow: 'hidden', boxShadow: '0 2px 8px rgba(0,0,0,0.05)' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead style={{ background: '#f5f5f5', borderBottom: '1px solid #ddd' }}>
            <tr>
              <th style={{ padding: '15px', textAlign: 'right' }}>كود الطلب</th>
              <th style={{ padding: '15px', textAlign: 'right' }}>الإجمالي</th>
              <th style={{ padding: '15px', textAlign: 'right' }}>الحالة</th>
              <th style={{ padding: '15px', textAlign: 'right' }}>شركة الشحن</th>
            </tr>
          </thead>
          <tbody>
            {orders.length === 0 ? (
              <tr><td colSpan="4" style={{ padding: '20px', textAlign: 'center' }}>لا توجد طلبات حالياً</td></tr>
            ) : orders.map(order => (
              <tr key={order.id} style={{ borderBottom: '1px solid #eee' }}>
                <td style={{ padding: '15px', fontWeight: 'bold' }}>{order.order_number || order.id.slice(0, 8)}</td>
                <td style={{ padding: '15px' }}>{order.total} ج.م</td>
                <td style={{ padding: '15px' }}>{order.status}</td>
                <td style={{ padding: '15px' }}>
                  <select 
                    value={order.shipping_company_id || ''} 
                    onChange={(e) => assignShipping(order.id, e.target.value)}
                    style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ccc' }}
                  >
                    <option value="">اختر شركة</option>
                    {companies.map(c => (
                      <option key={c.id} value={c.id}>{c.name}</option>
                    ))}
                  </select>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
    }
