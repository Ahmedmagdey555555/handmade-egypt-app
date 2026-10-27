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
      <h1 style={{ textAlign: 'center' }}>لوحة التحكم</h1>
      {error && <p style={{ color: 'red', textAlign: 'center' }}>{error}</p>}
      <form onSubmit={handleLogin}>
        <input type="email" placeholder="البريد الإلكتروني" onChange={e => setEmail(e.target.value)} required />
        <input type="password" placeholder="كلمة المرور" onChange={e => setPassword(e.target.value)} required />
        <button type="submit">دخول</button>
      </form>
    </div>
  );
                                                                    }
