'use client';
import Link from 'next/link';

export default function DashboardLayout({ children }) {
  return (
    <div style={{ display: 'flex', minHeight: '100vh', direction: 'rtl' }}>
      <aside style={{ width: '250px', background: '#2C1810', color: 'white', padding: '20px' }}>
        <h2 style={{ color: '#B07D62', textAlign: 'center', marginBottom: '40px' }}>Handmade</h2>
        <nav style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
          <Link href="/dashboard" style={{ padding: '12px', color: 'white', textDecoration: 'none', borderRadius: '8px', background: '#3a231a' }}>الرئيسية</Link>
          <Link href="/dashboard/orders" style={{ padding: '12px', color: 'white', textDecoration: 'none', borderRadius: '8px', background: '#3a231a' }}>الطلبات</Link>
          <Link href="/dashboard/merchants" style={{ padding: '12px', color: 'white', textDecoration: 'none', borderRadius: '8px', background: '#3a231a' }}>التجار</Link>
          <Link href="/dashboard/products" style={{ padding: '12px', color: 'white', textDecoration: 'none', borderRadius: '8px', background: '#3a231a' }}>المنتجات</Link>
          <Link href="/dashboard/shipping" style={{ padding: '12px', color: 'white', textDecoration: 'none', borderRadius: '8px', background: '#3a231a' }}>شركات الشحن</Link>
        </nav>
      </aside>
      <main style={{ flex: 1, backgroundColor: '#FAF7F2' }}>
        {children}
      </main>
    </div>
  );
}
