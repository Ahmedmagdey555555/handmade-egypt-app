'use client';
import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';

export default function Dashboard() {
  const [stats, setStats] = useState({ orders: 0, merchants: 0 });
  
  useEffect(() => {
    supabase.from('orders').select('*', { count: 'exact', head: true }).then(res => setStats(prev => ({ ...prev, orders: res.count || 0 })));
    supabase.from('stores').select('*', { count: 'exact', head: true }).then(res => setStats(prev => ({ ...prev, merchants: res.count || 0 })));
  }, []);

  return (
    <div style={{ padding: '40px' }}>
      <h1 style={{ marginBottom: '30px' }}>نظرة عامة</h1>
      <div style={{ display: 'flex', gap: '20px' }}>
        <div style={{ backgroundColor: 'white', padding: '20px', borderRadius: '8px', flex: 1 }}>
          <p style={{ color: '#666' }}>الطلبات</p>
          <h2 style={{ color: '#B07D62', fontSize: '32px' }}>{stats.orders}</h2>
        </div>
        <div style={{ backgroundColor: 'white', padding: '20px', borderRadius: '8px', flex: 1 }}>
          <p style={{ color: '#666' }}>التجار</p>
          <h2 style={{ color: '#B07D62', fontSize: '32px' }}>{stats.merchants}</h2>
        </div>
      </div>
    </div>
  );
                }
