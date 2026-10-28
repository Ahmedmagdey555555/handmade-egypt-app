'use client';
import { useState, useEffect } from 'react';
import { supabase } from '../../../lib/supabase';

export default function ShipmentsPage() {
  const [shipments, setShipments] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchShipments();
  }, []);

  const fetchShipments = async () => {
    const { data } = await supabase.from('merchant_shipments')
      .select('*, stores(name), merchant_shipment_items(*, products(title))')
      .order('created_at', { ascending: false });
    setShipments(data || []);
    setLoading(false);
  };

  const receiveShipment = async (id) => {
    if(!confirm('هل أنت متأكد من استلام الشحنة؟ سيتم إضافتها لمخزون المركز.')) return;
    
    const { error } = await supabase.rpc('receive_shipment', { shipment_uuid: id });
    if (error) {
      alert('خطأ: ' + error.message);
    } else {
      alert('تم استلام الشحنة بنجاح!');
      fetchShipments();
    }
  };

  if (loading) return <div style={{ padding: '40px' }}>جاري التحميل...</div>;

  return (
    <div style={{ padding: '40px' }}>
      <h1 style={{ marginBottom: '30px' }}>شحنات التجار</h1>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
        {shipments.length === 0 ? (
          <div style={{ background: 'white', padding: '20px', borderRadius: '8px', textAlign: 'center' }}>لا توجد شحنات حالياً</div>
        ) : shipments.map(s => (
          <div key={s.id} style={{ background: 'white', padding: '20px', borderRadius: '8px', boxShadow: '0 2px 8px rgba(0,0,0,0.05)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '15px' }}>
              <h3 style={{ margin: 0, color: '#B07D62' }}>شحنة من: {s.stores?.name}</h3>
              <span style={{ padding: '5px 10px', backgroundColor: s.status === 'received' ? '#e8f5e9' : '#fff3e0', color: s.status === 'received' ? 'green' : 'orange', borderRadius: '20px', fontSize: '12px', fontWeight: 'bold' }}>
                {s.status === 'received' ? 'تم الاستلام' : 'في الطريق'}
              </span>
            </div>
            
            <ul style={{ listStyleType: 'none', padding: 0, margin: '0 0 15px 0' }}>
              {s.merchant_shipment_items?.map(item => (
                <li key={item.id} style={{ padding: '8px 0', borderBottom: '1px solid #eee' }}>
                  <strong>{item.products?.title}</strong> - الكمية: {item.quantity}
                </li>
              ))}
            </ul>

            {s.status !== 'received' && (
              <button onClick={() => receiveShipment(s.id)} style={{ background: '#B07D62', color: 'white', border: 'none', padding: '10px 20px', borderRadius: '8px', cursor: 'pointer', fontWeight: 'bold', width: '100%' }}>
                تأكيد الاستلام وإضافة للمخزون
              </button>
            )}
          </div>
        ))}
      </div>
    </div>
  );
  }
