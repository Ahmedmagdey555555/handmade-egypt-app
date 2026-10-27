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
      <h1>نظرة عامة</h1>
      <div style={{ display: 'flex', gap: '20px' }}>
        <div style={{ background: 'white', padding: '20px', borderRadius: '8px', flex: 1 }}>
          <p>الطلبات</p>
          <h2 style={{ color: '#B07D62' }}>{stats.orders}</h2>
        </div>
        <div style={{ background: 'white', padding: '20px', borderRadius: '8px', flex: 1 }}>
          <p>التجار</p>
          <h2 style={{ color: '#B07D62' }}>{stats.merchants}</h2>
        </div>
      </div>
    </div>
  );
}
