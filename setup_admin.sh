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
    "lucide-react": "^0.344.0",
    "next": "14.1.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "typescript": "^5.3.3",
    "@types/node": "^20.11.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0"
  },
  "devDependencies": {
    "autoprefixer": "^10.4.17",
    "postcss": "^8.4.35",
    "tailwindcss": "^3.4.1"
  }
}
EOF

cat > admin/next.config.mjs << 'EOF'
const nextConfig = { reactStrictMode: false, typescript: { ignoreBuildErrors: true }, eslint: { ignoreDuringBuilds: true } };
export default nextConfig;
EOF

cat > admin/postcss.config.mjs << 'EOF'
export default { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF

cat > admin/tailwind.config.js << 'EOF'
module.exports = {
  content: ["./src/app/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: { extend: { colors: { brand: '#B07D62', dark: '#2C1810', cream: '#FAF7F2' } } },
  plugins: [],
};
EOF

cat > admin/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "lib": ["dom", "dom.iterable", "esnext"], "allowJs": true, "skipLibCheck": true, "strict": true,
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
@tailwind base;
@tailwind components;
@tailwind utilities;
body { background-color: #FAF7F2; color: #2C1810; }
EOF

cat > admin/src/app/layout.tsx << 'EOF'
import './globals.css'
export const metadata = { title: 'Handmade Admin' }
export default function RootLayout({ children }) {
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

  const handleLogin = async (e) => {
    e.preventDefault();
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return setError('خطأ في البيانات');
    
    const { data: role } = await supabase.from('user_roles').select('role').eq('id', data.user.id).single();
    if (role?.role !== 'admin') return setError('ليس لديك صلاحية');
    
    router.push('/dashboard');
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="bg-white p-8 rounded-2xl shadow-xl w-full max-w-md">
        <h1 className="text-2xl font-bold text-center mb-6">لوحة التحكم</h1>
        {error && <p className="text-red-500 text-center mb-4">{error}</p>}
        <form onSubmit={handleLogin} className="space-y-4">
          <input type="email" placeholder="البريد الإلكتروني" onChange={e => setEmail(e.target.value)} className="w-full border p-3 rounded-lg" required />
          <input type="password" placeholder="كلمة المرور" onChange={e => setPassword(e.target.value)} className="w-full border p-3 rounded-lg" required />
          <button type="submit" className="w-full bg-brand text-white font-bold py-3 rounded-lg">دخول</button>
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
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-8">نظرة عامة</h1>
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-white p-6 rounded-xl shadow-sm">
          <p className="text-gray-500">الطلبات</p>
          <p className="text-3xl font-bold">{stats.orders}</p>
        </div>
        <div className="bg-white p-6 rounded-xl shadow-sm">
          <p className="text-gray-500">التجار</p>
          <p className="text-3xl font-bold">{stats.merchants}</p>
        </div>
      </div>
    </div>
  );
}
EOF

echo "done"
