'use client';
import { useState, useEffect } from 'react';
import { supabase } from '../../../lib/supabase';

export default function ShippingPage() {
  const [companies, setCompanies] = useState([]);
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [msg, setMsg] = useState('جاري التحميل...');

  useEffect(() => {
    fetchCompanies();
  }, []);

  const fetchCompanies = async () => {
    // 1. نشوف هل المفتاح واصل ولا لأ
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
    if (!supabaseUrl) {
      setMsg('❌ خطأ: مفاتيح Supabase غير موجودة في إعدادات Vercel!');
      return;
    }

    setMsg('✅ جاري الاتصال بـ: ' + supabaseUrl);

    // 2. نجرب نجيب البيانات
    const { data, error } = await supabase.from('shipping_companies').select('*');
    
    if (error) {
      setMsg('❌ خطأ في القراءة: ' + error.message);
    } else {
      setMsg('✅ تم الاتصال. عدد الشركات في الداتابيز: ' + data.length);
      setCompanies(data || []);
    }
  };

  const addCompany = async (e) => {
    e.preventDefault();
    if (!name) return;
    setMsg('جاري الإضافة...');
    
    const { error } = await supabase.from('shipping_companies').insert([{ name, phone }]);
    
    if (error) {
      setMsg('❌ خطأ في الإضافة: ' + error.message);
    } else {
      setMsg('✅ تمت الإضافة بنجاح!');
      setName('');
      setPhone('');
      fetchCompanies();
    }
  };

  return (
    <div style={{ padding: '40px' }}>
      <h1 style={{ marginBottom: '30px' }}>شركات الشحن</h1>
      
      {/* مربع التشخيص */}
      <div style={{ padding: '15px', backgroundColor: '#e3f2fd', color: '#0d47a1', borderRadius: '8px', marginBottom: '20px', fontWeight: 'bold', direction: 'ltr', textAlign: 'left' }}>
        {msg}
      </div>

      <div style={{ background: 'white', padding: '20px', borderRadius: '8px', marginBottom: '20px', boxShadow: '0 2px 8px rgba(0,0,0,0.05)' }}>
        <h3 style={{ marginBottom: '15px' }}>إضافة شركة جديدة</h3>
        <form onSubmit={addCompany} style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
          <input type="text" placeholder="اسم الشركة" value={name} onChange={e => setName(e.target.value)} style={{ padding: '10px', borderRadius: '4px', border: '1px solid #ccc', flex: 1, minWidth: '200px' }} required />
          <input type="text" placeholder="رقم الهاتف (اختياري)" value={phone} onChange={e => setPhone(e.target.value)} style={{ padding: '10px', borderRadius: '4px', border: '1px solid #ccc', flex: 1, minWidth: '200px' }} />
          <button type="submit" style={{ padding: '10px 20px', background: '#B07D62', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold' }}>إضافة</button>
        </form>
      </div>

      <div style={{ background: 'white', borderRadius: '8px', overflow: 'hidden', boxShadow: '0 2px 8px rgba(0,0,0,0.05)' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead style={{ background: '#f5f5f5', borderBottom: '1px solid #ddd' }}>
            <tr>
              <th style={{ padding: '15px', textAlign: 'right' }}>اسم الشركة</th>
              <th style={{ padding: '15px', textAlign: 'right' }}>رقم الهاتف</th>
            </tr>
          </thead>
          <tbody>
            {companies.length === 0 ? (
              <tr><td colSpan="2" style={{ padding: '20px', textAlign: 'center' }}>لا توجد شركات مضافة</td></tr>
            ) : companies.map(c => (
              <tr key={c.id} style={{ borderBottom: '1px solid #eee' }}>
                <td style={{ padding: '15px', fontWeight: 'bold' }}>{c.name}</td>
                <td style={{ padding: '15px' }}>{c.phone || '-'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
