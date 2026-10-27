#!/bin/bash
set -e

mkdir -p admin/src/app/dashboard
mkdir -p admin/src/lib
mkdir -p admin/src/components

# ============ package.json ============
cat > admin/package.json << 'FILE_END'
{
  "name": "handmade-admin",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.39.0",
    "lucide-react": "^0.344.0",
    "next": "14.1.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/node": "^20.11.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "autoprefixer": "^10.4.17",
    "postcss": "^8.4.35",
    "tailwindcss": "^3.4.1",
    "typescript": "^5.3.3"
  }
}
FILE_END

# ============ next.config.mjs ============
cat > admin/next.config.mjs << 'FILE_END'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: false,
};
export default nextConfig;
FILE_END

# ============ tailwind.config.ts ============
cat > admin/tailwind.config.ts << 'FILE_END'
import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        brand: '#B07D62',
        dark: '#2C1810',
        cream: '#FAF7F2',
      },
    },
  },
  plugins: [],
};
export default config;
FILE_END

# ============ postcss.config.mjs ============
cat > admin/postcss.config.mjs << 'FILE_END'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
FILE_END

# ============ tsconfig.json ============
cat > admin/tsconfig.json << 'FILE_END'
{
  "compilerOptions": {
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
FILE_END

# ============ src/lib/supabase.ts ============
cat > admin/src/lib/supabase.ts << 'FILE_END'
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

export const supabase = createClient(supabaseUrl, supabaseKey);
FILE_END

# ============ src/app/globals.css ============
cat > admin/src/app/globals.css << 'FILE_END'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  background-color: #FAF7F2;
  color: #2C1810;
}
FILE_END

# ============ src/app/layout.tsx ============
cat > admin/src/app/layout.tsx << 'FILE_END'
import './globals.css'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Handmade Admin',
  description: 'لوحة تحكم متجر هاند ميد',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="ar" dir="rtl">
      <body>{children}</body>
    </html>
  )
}
FILE_END

# ============ src/app/page.tsx (Login) ============
cat > admin/src/app/page.tsx << 'FILE_END'
'use client';
import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const router = useRouter();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    const { data, error: authError } = await supabase.auth.signInWithPassword({ email, password });
    
    if (authError) {
      setError('خطأ في البريد أو كلمة المرور');
      setLoading(false);
      return;
    }

    const { data: roleData } = await supabase.from('user_roles').select('role').eq('id', data.user.id).single();
    
    if (roleData?.role !== 'admin') {
      setError('عذراً، هذا الحساب ليس لديه صلاحية الدخول للوحة التحكم');
      await supabase.auth.signOut();
      setLoading(false);
      return;
    }

    router.push('/dashboard');
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="bg-white p-8 rounded-2xl shadow-xl w-full max-w-md">
        <div className="text-center mb-8">
          <div className="w-20 h-20 bg-brand rounded-2xl mx-auto flex items-center justify-center mb-4">
            <span className="text-white text-4xl font-bold">H</span>
          </div>
          <h1 className="text-2xl font-bold text-dark">لوحة التحكم</h1>
          <p className="text-gray-500 mt-2">تسجيل دخول الأدمن</p>
        </div>
        
        {error && <div className="bg-red-50 text-red-500 p-3 rounded-lg mb-4 text-center text-sm">{error}</div>}

        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-sm font-bold mb-2">البريد الإلكتروني</label>
            <input 
              type="email" 
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full border p-3 rounded-lg focus:outline-none focus:border-brand"
              required 
            />
          </div>
          <div>
            <label className="block text-sm font-bold mb-2">كلمة المرور</label>
            <input 
              type="password" 
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full border p-3 rounded-lg focus:outline-none focus:border-brand"
              required 
            />
          </div>
          <button 
            type="submit" 
            disabled={loading}
            className="w-full bg-brand text-white font-bold py-3 rounded-lg hover:bg-opacity-90 transition"
          >
            {loading ? 'جاري الدخول...' : 'دخول'}
          </button>
        </form>
      </div>
    </div>
  );
}
FILE_END

# ============ src/app/dashboard/layout.tsx ============
cat > admin/src/app/dashboard/layout.tsx << 'FILE_END'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useRouter, usePathname } from 'next/navigation';
import Link from 'next/link';
import { LayoutDashboard, ShoppingBag, Users, Store, MessageSquare, Settings, LogOut, FileEdit } from 'lucide-react';

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const checkUser = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        router.push('/');
      } else {
        setLoading(false);
      }
    };
    checkUser();
  }, [router]);

  const handleLogout = async () => {
    await supabase.auth.signOut();
    router.push('/');
  };

  const menu = [
    { name: 'الرئيسية', icon: <LayoutDashboard size={20} />, path: '/dashboard' },
    { name: 'الطلبات', icon: <ShoppingBag size={20} />, path: '/dashboard/orders' },
    { name: 'الطلبات المخصصة', icon: <FileEdit size={20} />, path: '/dashboard/custom-orders' },
    { name: 'التجار', icon: <Store size={20} />, path: '/dashboard/merchants' },
    { name: 'العملاء', icon: <Users size={20} />, path: '/dashboard/customers' },
    { name: 'المنتجات', icon: <ShoppingBag size={20} />, path: '/dashboard/products' },
    { name: 'الإعدادات', icon: <Settings size={20} />, path: '/dashboard/settings' },
  ];

  if (loading) return <div className="min-h-screen flex items-center justify-center">جاري التحميل...</div>;

  return (
    <div className="flex h-screen bg-cream">
      <aside className="w-64 bg-dark text-white flex flex-col">
        <div className="p-6 text-center border-b border-gray-700">
          <h1 className="text-2xl font-bold text-brand">Handmade</h1>
          <p className="text-xs text-gray-400 mt-1">لوحة التحكم</p>
        </div>
        <nav className="flex-1 p-4 space-y-2">
          {menu.map((item) => (
            <Link 
              key={item.path} 
              href={item.path}
              className={`flex items-center gap-3 p-3 rounded-lg transition ${pathname === item.path ? 'bg-brand text-white' : 'hover:bg-gray-800 text-gray-300'}`}
            >
              {item.icon}
              <span>{item.name}</span>
            </Link>
          ))}
        </nav>
        <div className="p-4 border-t border-gray-700">
          <button onClick={handleLogout} className="flex items-center gap-3 p-3 w-full text-red-400 hover:bg-gray-800 rounded-lg transition">
            <LogOut size={20} />
            <span>تسجيل الخروج</span>
          </button>
        </div>
      </aside>

      <main className="flex-1 overflow-y-auto p-8">
        {children}
      </main>
    </div>
  );
}
FILE_END

# ============ src/app/dashboard/page.tsx (Stats) ============
cat > admin/src/app/dashboard/page.tsx << 'FILE_END'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { ShoppingBag, Users, Store, DollarSign } from 'lucide-react';

export default function DashboardHome() {
  const [stats, setStats] = useState({ orders: 0, users: 0, merchants: 0, revenue: 0 });

  useEffect(() => {
    const fetchStats = async () => {
      const { count: ordersCount } = await supabase.from('orders').select('*', { count: 'exact', head: true });
      const { count: usersCount } = await supabase.from('user_profiles').select('*', { count: 'exact', head: true });
      const { count: merchantsCount } = await supabase.from('stores').select('*', { count: 'exact', head: true });
      
      const { data: orders } = await supabase.from('orders').select('total');
      const revenue = orders?.reduce((sum, order) => sum + Number(order.total), 0) || 0;

      setStats({
        orders: ordersCount || 0,
        users: usersCount || 0,
        merchants: merchantsCount || 0,
        revenue: revenue
      });
    };
    fetchStats();
  }, []);

  const cards = [
    { title: 'إجمالي الطلبات', value: stats.orders, icon: <ShoppingBag />, color: 'bg-blue-500' },
    { title: 'إجمالي الإيرادات', value: `${stats.revenue} ج.م`, icon: <DollarSign />, color: 'bg-green-500' },
    { title: 'عدد التجار', value: stats.merchants, icon: <Store />, color: 'bg-brand' },
    { title: 'العملاء', value: stats.users, icon: <Users />, color: 'bg-purple-500' },
  ];

  return (
    <div>
      <h1 className="text-3xl font-bold mb-8">نظرة عامة</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {cards.map((c, i) => (
          <div key={i} className="bg-white p-6 rounded-2xl shadow-sm flex items-center gap-4">
            <div className={`w-14 h-14 ${c.color} text-white rounded-xl flex items-center justify-center`}>
              {c.icon}
            </div>
            <div>
              <p className="text-gray-500 text-sm">{c.title}</p>
              <h2 className="text-2xl font-bold">{c.value}</h2>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
FILE_END

echo "setup-admin done"
