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
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '100vh' }}>
      <div style={{ backgroundColor: 'white', padding: '40px', borderRadius: '12px', boxShadow: '0 4px 12px rgba(0,0,0,0.1)', width: '100%', maxWidth: '400px' }}>
        <h1 style={{ textAlign: 'center', marginBottom: '20px' }}>لوحة التحكم</h1>
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
