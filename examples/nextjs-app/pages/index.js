export default function Home() {
  return (
    <div style={{ fontFamily: 'system-ui, -apple-system, sans-serif', maxWidth: 640, margin: '80px auto', padding: '0 20px' }}>
      <h1 style={{ fontSize: '2rem', marginBottom: 8 }}>Hello from TrueFoundry!</h1>
      <p style={{ color: '#555', fontSize: '1.1rem', lineHeight: 1.6 }}>
        This is a Next.js demo app deployed on TrueFoundry.
      </p>
      <div style={{ marginTop: 32, padding: 20, background: '#f5f5f5', borderRadius: 8 }}>
        <h2 style={{ fontSize: '1.1rem', marginTop: 0 }}>Deployment Info</h2>
        <ul style={{ listStyle: 'none', padding: 0, margin: 0, lineHeight: 2 }}>
          <li><strong>Runtime:</strong> Node.js + Next.js 14</li>
          <li><strong>Platform:</strong> TrueFoundry</li>
          <li><strong>Mode:</strong> Standalone</li>
        </ul>
      </div>
    </div>
  );
}
