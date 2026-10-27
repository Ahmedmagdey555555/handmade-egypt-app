'use client';
import { useState, useEffect } from 'react';
import { supabase } from '../../../lib/supabase';

export default function ProductsPage() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchProducts();
  }, []);

  const fetchProducts = async () => {
    const { data, error } = await supabase.from('products').select('*, stores(name)').order('created_at', { ascending: false });
    if (!error) setProducts(data || []);
    setLoading(false);
  };

  const deleteProduct = async (id) => {
    if (confirm('هل أنت متأكد من حذف هذا المنتج؟')) {
      await supabase.from('products').delete().eq('id', id);
      fetchProducts();
    }
  };

  if (loading) return <div style={{ padding: '40px' }}>جاري التحميل...</div>;

  return (
    <div style={{ padding: '40px' }}>
      <h1 style={{ marginBottom: '30px' }}>المنتجات</h1>
      
      <div style={{ background: 'white', borderRadius: '8px', overflow: 'hidden', boxShadow: '0 2px 8px rgba(0,0,0,0.05)' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead style={{ background: '#f5f5f5', borderBottom: '1px solid #ddd' }}>
            <tr>
              <th style={{ padding: '15px', textAlign: 'right' }}>المنتج</th>
              <th style={{ padding: '15px', textAlign: 'right' }}>المتجر</th>
              <th style={{ padding: '15px', textAlign: 'right' }}>السعر</th>
              <th style={{ padding: '15px', textAlign: 'right' }}>المخزون</th>
              <th style={{ padding: '15px', textAlign: 'center' }}>إجراءات</th>
            </tr>
          </thead>
          <tbody>
            {products.length === 0 ? (
              <tr><td colSpan="5" style={{ padding: '20px', textAlign: 'center' }}>لا توجد منتجات</td></tr>
            ) : products.map(p => (
              <tr key={p.id} style={{ borderBottom: '1px solid #eee' }}>
                <td style={{ padding: '15px', fontWeight: 'bold' }}>{p.title}</td>
                <td style={{ padding: '15px' }}>{p.stores?.name || 'غير معروف'}</td>
                <td style={{ padding: '15px', color: '#B07D62', fontWeight: 'bold' }}>{p.price} ج.م</td>
                <td style={{ padding: '15px' }}>{p.stock}</td>
                <td style={{ padding: '15px', textAlign: 'center' }}>
                  <button onClick={() => deleteProduct(p.id)} style={{ background: '#ffebee', color: 'red', border: 'none', padding: '8px 15px', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold' }}>حذف</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
    }
