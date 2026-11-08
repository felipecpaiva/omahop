import http.server, socketserver, sys, threading, json, zlib, struct, os
PAGES=os.path.join(os.path.dirname(os.path.abspath(__file__)),'pages')
LOG={}
def png(r,g,b,w=200,h=200):
    raw=b''.join(b'\x00'+bytes([r,g,b])*w for _ in range(h))
    def ch(t,d): c=struct.pack('>I',len(d))+t+d; return c+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+ch(b'IDAT',zlib.compress(raw))+ch(b'IEND',b'')
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_GET(self):
        p=self.path.split('?')[0]
        LOG[p]=LOG.get(p,0)+1
        if p=='/_log':
            b=json.dumps(LOG).encode(); self.send_response(200); self.end_headers(); self.wfile.write(b); return
        if p=='/red.png': b=png(255,0,0); ct='image/png'
        else:
            f=os.path.join(PAGES,p.lstrip('/'))
            if not os.path.isfile(f): self.send_response(404); self.end_headers(); return
            b=open(f,'rb').read(); ct='text/html'
        self.send_response(200); self.send_header('Content-Type',ct)
        if p=='/csp.html': self.send_header('Content-Security-Policy',"default-src 'self' 'unsafe-inline'; img-src 'self'")
        self.send_header('Cache-Control','no-store'); self.end_headers(); self.wfile.write(b)
class T(socketserver.ThreadingMixIn,http.server.HTTPServer): daemon_threads=True
for port in (8801,8802):
    threading.Thread(target=T(('127.0.0.1',port),H).serve_forever,daemon=True).start()
threading.Event().wait()
