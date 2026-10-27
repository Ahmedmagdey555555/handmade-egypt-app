import './globals.css'

export const metadata = {
  title: 'لوحة التحكم',
}

export default function RootLayout({ children }) {
  return (
    <html lang="ar" dir="rtl">
      <body>{children}</body>
    </html>
  )
}
