'use client';
import { useState, useEffect } from 'react';
import { supabase } from '../../../lib/supabase';

export default function MerchantsPage() {
  const [merchants, setMerchants] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchMerchants = async () => {
      const { data, error } = await supabase.from('stores').select('*').order('created_at', { ascending: false });
      if (!error) setMerchants(data || []);
      setLoading(false);
    };
    fetchMerchants();
  }, []);

  if (loading) return <div style={{ padding: '40px' }}>جاري التحميل...</div>;

  return (
    <div style={{ padding: '40px' }}>
      <h1 style={{ marginBottom: '30px' }}>التجار (المتاجر)</h1>
      
      <div style={{ background: 'white', borderRadius: '8px', overflow: 'hidden', boxShadow: '0 2px 8px rgba(0,0,0,0.05)' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead style={{ background: '#f5f5f5', borderBottom: '1px solid #ddd' }}>
            <tr>
              <th style={{ padding: '15px', textAlign: 'right' }}>اسم المتجر</th>
              <th style={{ padding: '15px', textAlign: 'right' }}>رقم الهاتف</th>
              <th style={{ padding: '15px', textAlign: 'right' }}>حالة المتجر</th>
              <th style={{ padding: '15px', textAlign: 'right' }}>تاريخ الانضمام</th>
            </tr>
          </thead>
          <tbody>
            {merchants.length === 0 ? (
              <tr><td colSpan="4" style={{ padding: '20px', textAlign: 'center' }}>لا يوجد تجار مسجلين</td></tr>
            ) : merchants.map(m => (
              <tr key={m.id} style={{ borderBottom: '1px solid #eee' }}>
                <td style={{ padding: '15px', fontWeight: 'bold' }}>{m.name}</td>
                <td style={{ padding: '15px' }}>{m.phone || '-'}</td>
                <td style={{ padding: '15px' }}>
                  <span style={{ padding: '5px 10px', backgroundColor: m.status === 'active' ? '#e8f5e9' : '#fff3e0', color: m.status === 'active' ? 'green' : 'orange', borderRadius: '20px', fontSize: '12px', fontWeight: 'bold' }}>
                    {m.status === 'active' ? 'نشط' : 'قيد المراجعة'}
                  </span>
                </td>
                <td style={{ padding: '15px', direction: 'ltr', textAlign: 'right' }}>{new Date(m.created_at).toLocaleDateString('ar-EG')}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
    }
