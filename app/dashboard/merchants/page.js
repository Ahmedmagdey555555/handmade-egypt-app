'use client';
import { useState, useEffect } from 'react';
import { supabase } from '../../../lib/supabase';

export default function MerchantsPage() {
  const [merchants, setMerchants] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchMerchants();
  }, []);

  const fetchMerchants = async () => {
    const { data } = await supabase.from('stores').select('*').order('created_at', { ascending: false });
    setMerchants(data || []);
    setLoading(false);
  };

  const updateStatus = async (id, status) => {
    await supabase.from('stores').update({ status }).eq('id', id);
    fetchMerchants();
  };

  if (loading) return <div style={{ padding: '40px' }}>جاري التحميل...</div>;

  return (
    <div style={{ padding: '40px' }}>
      <h1 style={{ marginBottom: '30px' }}>إدارة التجار</h1>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
        {merchants.map(m => (
          <div key={m.id} style={{ background: 'white', padding: '20px', borderRadius: '8px', boxShadow: '0 2px 8px rgba(0,0,0,0.05)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3 style={{ margin: '0 0 10px 0' }}>{m.name}</h3>
              <p style={{ margin: '5px 0' }}><strong>الهاتف:</strong> {m.phone || '-'}</p>
              <p style={{ margin: '5px 0' }}><strong>بطاقة الهوية:</strong> {m.id_card_number || 'لم يتم إدخالها'}</p>
              <p style={{ margin: '5px 0' }}>
                <strong>الحالة:</strong> 
                <span style={{ marginRight: '5px', color: m.status === 'active' ? 'green' : 'orange', fontWeight: 'bold' }}>
                  {m.status === 'active' ? 'نشط' : 'قيد المراجعة'}
                </span>
              </p>
            </div>
            <div style={{ display: 'flex', gap: '10px' }}>
              {m.status !== 'active' && (
                <button onClick={() => updateStatus(m.id, 'active')} style={{ background: '#e8f5e9', color: 'green', border: 'none', padding: '10px 20px', borderRadius: '8px', cursor: 'pointer', fontWeight: 'bold' }}>موافقة</button>
              )}
              {m.status === 'active' && (
                <button onClick={() => updateStatus(m.id, 'pending')} style={{ background: '#ffebee', color: 'red', border: 'none', padding: '10px 20px', borderRadius: '8px', cursor: 'pointer', fontWeight: 'bold' }}>إيقاف</button>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
