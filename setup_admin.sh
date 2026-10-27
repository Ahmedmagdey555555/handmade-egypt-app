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
    "react-dom": "^18.2.0",
    "typescript": "^5.3.3",
    "@types/node": "^20.11.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0"
  }
}
EOF

cat > admin/next.config.js << 'EOF'
const nextConfig = { reactStrictMode: false, typescript: { ignoreBuildErrors: true }, eslint: { ignoreDuringBuilds: true } };
module.exports = nextConfig;
EOF

cat > admin/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "lib": ["dom", "dom.iterable", "esnext"], "allowJs": true, "skipLibCheck": true, "strict": false,
    "noEmit": true, "esModuleInterop": true, "module": "esnext", "moduleResolution": "bundler",
    "resolveJsonModule": true, "isolatedModules": true, "jsx": "preserve", "incremental": true,
    "plugins": [{ "name": "next" }], "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

cat > admin/src/lib/supabase.ts << 'EOF'
import { createClient } from '@supabase/supabase-js';
export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL || '',
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''
);
EOF

cat > admin/src/app/globals.css << 'EOF'
body { margin: 0; padding: 0; font-family: sans-serif; background-color: #FAF7F2; }
.container { max-width: 400px; margin: 80px auto; background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
input { width: 100%; padding: 12px; margin: 10px 0; border: 1px solid #ccc; border-radius: 8px; box-sizing: border-box; }
button { width: 100%; padding: 12px; background-color: #B07D62; color: white; border: none; border-radius: 8px; cursor: pointer; font-weight: bold; font-size: 16px; }
EOF

cat > admin/src/app/layout.tsx << 'EOF'
import './globals.css'
export const metadata = { title: 'Admin' }
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="ar" dir="rtl"><body>{children}</body></html>
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
    <div className="container">
      <h1 style={{ textAlign: 'center', color: '#2C1810' }}>لوحة التحكم</h1>
      {error && <p style={{ color: 'red', textAlign: 'center' }}>{error}</p>}
      <form onSubmit={handleLogin}>
        <input type="email" placeholder="البريد الإلكتروني" onChange={e => setEmail(e.target.value)} required />
        <input type="password" placeholder="كلمة المرور" onChange={e => setPassword(e.target.value)} required />
        <button type="submit">دخول</button>
      </form>
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
    <div style={{ padding: '40px' }}>
      <h1 style={{ color: '#2C1810' }}>نظرة عامة</h1>
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
EOF

echo "done"
