'use client';
import { useState, useEffect } from 'react';
import { supabase } from '../../../lib/supabase';

export default function SettingsPage() {
  const [settings, setSettings] = useState({});
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    fetchSettings();
  }, []);

  const fetchSettings = async () => {
    const { data } = await supabase.from('app_settings').select('*');
    const settingsObj = {};
    data?.forEach(item => { settingsObj[item.key] = item.value; });
    setSettings(settingsObj);
    setLoading(false);
  };

  const handleChange = (key, value) => {
    setSettings(prev => ({ ...prev, [key]: value }));
  };

  const saveSettings = async () => {
    setMsg('جاري الحفظ...');
    const updates = Object.keys(settings).map(key => ({
      key,
      value: settings[key]
    }));

    for (const item of updates) {
      await supabase.from('app_settings').upsert(item);
    }
    setMsg('تم حفظ الإعدادات بنجاح!');
  };

  if (loading) return <div style={{ padding: '40px' }}>جاري التحميل...</div>;

  return (
    <div style={{ padding: '40px' }}>
      <h1 style={{ marginBottom: '30px' }}>الإعدادات</h1>

      {msg && <div style={{ padding: '15px', backgroundColor: '#e3f2fd', color: '#0d47a1', borderRadius: '8px', marginBottom: '20px', fontWeight: 'bold' }}>{msg}</div>}

      <div style={{ background: 'white', padding: '20px', borderRadius: '8px', boxShadow: '0 2px 8px rgba(0,0,0,0.05)', display: 'flex', flexDirection: 'column', gap: '20px' }}>
        <div>
          <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>رقم الواتساب (بدون + أو 00)</label>
          <input type="text" value={settings['whatsapp_number'] || ''} onChange={e => handleChange('whatsapp_number', e.target.value)} style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #ccc' }} placeholder="مثال: 201012345678" />
        </div>
        <div>
          <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>رقم الدعم الفني</label>
          <input type="text" value={settings['support_phone'] || ''} onChange={e => handleChange('support_phone', e.target.value)} style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #ccc' }} placeholder="مثال: 01012345678" />
        </div>
        <button onClick={saveSettings} style={{ padding: '12px', background: '#B07D62', color: 'white', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: 'bold', fontSize: '16px' }}>حفظ الإعدادات</button>
      </div>
    </div>
  );
    }
