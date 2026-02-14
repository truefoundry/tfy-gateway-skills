import { useState, useEffect, useRef } from 'react';

const API_URL = typeof window !== 'undefined'
  ? (process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000')
  : (process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000');

export default function Home() {
  const [parks, setParks] = useState([]);
  const [selectedPark, setSelectedPark] = useState(null);
  const [chatMessages, setChatMessages] = useState([
    { role: 'assistant', text: 'Hello! Ask me anything about national parks on the west coast near California.' }
  ]);
  const [chatInput, setChatInput] = useState('');
  const [loading, setLoading] = useState(false);
  const chatEndRef = useRef(null);

  useEffect(() => {
    fetch(`${API_URL}/api/parks`)
      .then(r => r.json())
      .then(data => setParks(data.parks || []))
      .catch(() => {});
  }, []);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chatMessages]);

  const sendMessage = async () => {
    if (!chatInput.trim() || loading) return;
    const msg = chatInput.trim();
    setChatInput('');
    setChatMessages(prev => [...prev, { role: 'user', text: msg }]);
    setLoading(true);
    try {
      const res = await fetch(`${API_URL}/api/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: msg }),
      });
      const data = await res.json();
      setChatMessages(prev => [...prev, { role: 'assistant', text: data.response }]);
    } catch {
      setChatMessages(prev => [...prev, { role: 'assistant', text: 'Sorry, I could not connect to the server.' }]);
    }
    setLoading(false);
  };

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#f0f4f3', fontFamily: "'Segoe UI', system-ui, -apple-system, sans-serif" }}>
      {/* Header */}
      <header style={{
        background: 'linear-gradient(135deg, #2d5016 0%, #4a7c29 50%, #2d5016 100%)',
        color: 'white', padding: '24px 32px', boxShadow: '0 2px 12px rgba(0,0,0,0.15)'
      }}>
        <h1 style={{ margin: 0, fontSize: '28px', fontWeight: 700, letterSpacing: '-0.5px' }}>
          National Parks Explorer
        </h1>
        <p style={{ margin: '6px 0 0', opacity: 0.85, fontSize: '15px' }}>
          Discover national parks on the west coast near California
        </p>
      </header>

      <div style={{ display: 'flex', maxWidth: '1400px', margin: '0 auto', gap: '24px', padding: '24px', minHeight: 'calc(100vh - 100px)' }}>
        {/* Parks Grid */}
        <div style={{ flex: 1, minWidth: 0 }}>
          {selectedPark ? (
            <div style={{
              background: 'white', borderRadius: '16px', padding: '32px',
              boxShadow: '0 1px 8px rgba(0,0,0,0.08)'
            }}>
              <button onClick={() => setSelectedPark(null)} style={{
                background: 'none', border: '1px solid #ccc', borderRadius: '8px',
                padding: '8px 16px', cursor: 'pointer', marginBottom: '16px', fontSize: '14px'
              }}>
                &larr; Back to all parks
              </button>
              <img src={selectedPark.image_url} alt={selectedPark.name} style={{
                width: '100%', height: '280px', objectFit: 'cover', borderRadius: '12px', marginBottom: '20px', backgroundColor: '#e8ede8'
              }} />
              <h2 style={{ margin: '0 0 8px', fontSize: '26px', color: '#1a3a0a' }}>{selectedPark.name}</h2>
              <p style={{ color: '#666', margin: '0 0 16px', fontSize: '14px' }}>{selectedPark.location}</p>
              <p style={{ lineHeight: 1.7, color: '#333', fontSize: '15px' }}>{selectedPark.description}</p>
              <div style={{ marginTop: '20px' }}>
                <h3 style={{ fontSize: '16px', color: '#2d5016', marginBottom: '10px' }}>Highlights</h3>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                  {selectedPark.highlights.map(h => (
                    <span key={h} style={{
                      background: '#e8f5e0', color: '#2d5016', padding: '6px 14px',
                      borderRadius: '20px', fontSize: '13px', fontWeight: 500
                    }}>{h}</span>
                  ))}
                </div>
              </div>
              <p style={{ marginTop: '20px', color: '#555', fontSize: '14px' }}>
                <strong>Best time to visit:</strong> {selectedPark.best_time_to_visit}
              </p>
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '20px' }}>
              {parks.map(park => (
                <div key={park.id} onClick={() => setSelectedPark(park)} style={{
                  background: 'white', borderRadius: '16px', overflow: 'hidden', cursor: 'pointer',
                  boxShadow: '0 1px 8px rgba(0,0,0,0.08)', transition: 'transform 0.2s, box-shadow 0.2s'
                }}
                onMouseEnter={e => { e.currentTarget.style.transform = 'translateY(-4px)'; e.currentTarget.style.boxShadow = '0 8px 24px rgba(0,0,0,0.12)'; }}
                onMouseLeave={e => { e.currentTarget.style.transform = 'none'; e.currentTarget.style.boxShadow = '0 1px 8px rgba(0,0,0,0.08)'; }}
                >
                  <img src={park.image_url} alt={park.name} style={{
                    width: '100%', height: '180px', objectFit: 'cover', backgroundColor: '#e8ede8'
                  }} />
                  <div style={{ padding: '18px 20px' }}>
                    <h3 style={{ margin: '0 0 6px', fontSize: '17px', color: '#1a3a0a' }}>{park.name}</h3>
                    <p style={{ margin: '0 0 10px', color: '#777', fontSize: '13px' }}>{park.location}</p>
                    <p style={{
                      margin: 0, color: '#555', fontSize: '14px', lineHeight: 1.5,
                      display: '-webkit-box', WebkitLineClamp: 3, WebkitBoxOrient: 'vertical', overflow: 'hidden'
                    }}>{park.description}</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Chat Panel */}
        <div style={{
          width: '380px', flexShrink: 0, background: 'white', borderRadius: '16px',
          boxShadow: '0 1px 8px rgba(0,0,0,0.08)', display: 'flex', flexDirection: 'column',
          overflow: 'hidden', maxHeight: 'calc(100vh - 148px)', position: 'sticky', top: '24px'
        }}>
          <div style={{
            padding: '18px 20px', borderBottom: '1px solid #eee',
            background: 'linear-gradient(135deg, #2d5016, #4a7c29)', color: 'white'
          }}>
            <h3 style={{ margin: 0, fontSize: '16px', fontWeight: 600 }}>Park Guide Chat</h3>
          </div>
          <div style={{ flex: 1, overflowY: 'auto', padding: '16px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {chatMessages.map((msg, i) => (
              <div key={i} style={{
                alignSelf: msg.role === 'user' ? 'flex-end' : 'flex-start',
                maxWidth: '85%',
                background: msg.role === 'user' ? '#2d5016' : '#f0f4f3',
                color: msg.role === 'user' ? 'white' : '#333',
                padding: '10px 16px', borderRadius: '14px', fontSize: '14px',
                lineHeight: 1.5, whiteSpace: 'pre-wrap'
              }}>
                {msg.text}
              </div>
            ))}
            {loading && (
              <div style={{ alignSelf: 'flex-start', color: '#999', fontSize: '14px', padding: '8px' }}>
                Thinking...
              </div>
            )}
            <div ref={chatEndRef} />
          </div>
          <div style={{ padding: '12px 16px', borderTop: '1px solid #eee', display: 'flex', gap: '8px' }}>
            <input
              value={chatInput}
              onChange={e => setChatInput(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && sendMessage()}
              placeholder="Ask about a park..."
              style={{
                flex: 1, padding: '10px 14px', borderRadius: '10px', border: '1px solid #ddd',
                fontSize: '14px', outline: 'none'
              }}
            />
            <button onClick={sendMessage} disabled={loading} style={{
              background: '#2d5016', color: 'white', border: 'none', borderRadius: '10px',
              padding: '10px 18px', cursor: 'pointer', fontSize: '14px', fontWeight: 600,
              opacity: loading ? 0.6 : 1
            }}>
              Send
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
