#!/bin/bash
set -e

mkdir -p admin/src/app/dashboard
mkdir -p admin/src/lib

cat > admin/package.json << 'EOF'
{
  "name": "admin",
  "version": "1.0.0",
  "scripts": {
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.39.0",
    "next": "14.1.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  }
}
EOF

cat > admin/next.config.js << 'EOF'
const nextConfig = { reactStrictMode: false };
module.exports = nextConfig;
EOF

cat > admin/src/lib/supabase.ts << 'EOF'
import { createClient } from '@supabase/supabase-js';
export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL || '',
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''
);
EOF

cat > admin/src/app/layout.tsx << 'EOF'
export const metadata = { title: 'Admin' }
export default function RootLayout({ children }) {
  return <html lang="ar" dir="rtl"><body style={{ margin: 0, padding: 0, fontFamily: 'sans-serif' }}>{children}</body></html>
}
EOF

cat > admin/src/app/page.tsx << 'EOF'
'use client';
import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { useRouter } from 'next/navigation';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const router = useRouter();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return setError('خطأ في البيانات');
    
    const { data: role } = await supabase.from('user_roles').select('role').eq('id', data.user.id).single();
    if (role?.role !== 'admin') return setError('ليس لديك صلاحية');
    
    router.push('/dashboard');
  };

  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '100vh', backgroundColor: '#FAF7F2' }}>
      <div style={{ backgroundColor: '#fff', padding: '40px', borderRadius: '12px', boxShadow: '0 4px 12px rgba(0,0,0,0.1)', width: '100%', maxWidth: '400px' }}>
        <h1 style={{ textAlign: 'center', color: '#2C1810', marginBottom: '20px' }}>لوحة التحكم</h1>
        {error && <p style={{ color: 'red', textAlign: 'center' }}>{error}</p>}
        <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
          <input type="email" placeholder="البريد الإلكتروني" onChange={e => setEmail(e.target.value)} required style={{ padding: '12px', borderRadius: '8px', border: '1px solid #ccc' }} />
          <input type="password" placeholder="كلمة المرور" onChange={e => setPassword(e.target.value)} required style={{ padding: '12px', borderRadius: '8px', border: '1px solid #ccc' }} />
          <button type="submit" style={{ padding: '12px', backgroundColor: '#B07D62', color: 'white', border: 'none', borderRadius: '8px', fontWeight: 'bold', cursor: 'pointer' }}>دخول</button>
        </form>
      </div>
    </div>
  );
}
EOF

cat > admin/src/app/dashboard/page.tsx << 'EOF'
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
    <div style={{ padding: '40px', backgroundColor: '#FAF7F2', minHeight: '100vh' }}>
      <h1 style={{ color: '#2C1810', marginBottom: '30px' }}>نظرة عامة</h1>
      <div style={{ display: 'flex', gap: '20px' }}>
        <div style={{ backgroundColor: 'white', padding: '20px', borderRadius: '12px', flex: 1, boxShadow: '0 2px 8px rgba(0,0,0,0.05)' }}>
          <p style={{ color: '#666' }}>الطلبات</p>
          <h2 style={{ color: '#B07D62', fontSize: '32px' }}>{stats.orders}</h2>
        </div>
        <div style={{ backgroundColor: 'white', padding: '20px', borderRadius: '12px', flex: 1, boxShadow: '0 2px 8px rgba(0,0,0,0.05)' }}>
          <p style={{ color: '#666' }}>التجار</p>
          <h2 style={{ color: '#B07D62', fontSize: '32px' }}>{stats.merchants}</h2>
        </div>
      </div>
    </div>
  );
}
EOF

echo "done"
