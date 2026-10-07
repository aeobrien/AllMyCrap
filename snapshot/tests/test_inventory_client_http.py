import json,threading,time,unittest,uuid
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from tools.inventory_session.mailbox import Fault,Mailbox,Server
from tools.inventory_session.client import Client
class HTTPTests(unittest.TestCase):
 def test_actual_role_refusals(self):
  ids={k:str(uuid.uuid4()) for k in ('device','store','client')};m=Mailbox(**ids,client_token='synthetic-client',worker_token='synthetic-worker');s=Server(m)
  try:
   with self.assertRaises(Fault) as e:Client(s.url,'synthetic-worker').post('hello',{})
   self.assertEqual((e.exception.status,e.exception.code),(401,'unauthorized'))
  finally:s.close()
 def test_client_total_body_deadline(self):
  class Slow(BaseHTTPRequestHandler):
   def log_message(self,*a):pass
   def do_POST(self):
    self.send_response(200);self.send_header('Content-Length','3');self.end_headers();self.wfile.write(b'{');self.wfile.flush();time.sleep(.4)
    try:self.wfile.write(b'} ')
    except OSError:pass
  s=ThreadingHTTPServer(('127.0.0.1',0),Slow);t=threading.Thread(target=s.serve_forever,daemon=True);t.start()
  try:
   began=time.monotonic()
   with self.assertRaises(Fault) as e:Client('http://127.0.0.1:'+str(s.server_port),'synthetic').post('hello',{},timeout=.1)
   self.assertEqual(e.exception.code,'deadline');self.assertLess(time.monotonic()-began,.35)
  finally:s.shutdown();t.join(timeout=2);s.server_close()
 def test_client_does_not_follow_redirect(self):
  hits=[]
  class Sink(BaseHTTPRequestHandler):
   def log_message(self,*a):pass
   def do_POST(self):hits.append(True);self.send_response(200);self.end_headers()
  sink=ThreadingHTTPServer(('127.0.0.1',0),Sink);st=threading.Thread(target=sink.serve_forever,daemon=True);st.start()
  class Redirect(BaseHTTPRequestHandler):
   def log_message(self,*a):pass
   def do_POST(self):self.send_response(307);self.send_header('Location','http://127.0.0.1:'+str(sink.server_port)+'/sink');self.send_header('Content-Length','0');self.end_headers()
  s=ThreadingHTTPServer(('127.0.0.1',0),Redirect);t=threading.Thread(target=s.serve_forever,daemon=True);t.start()
  try:
   with self.assertRaises(Fault):Client('http://127.0.0.1:'+str(s.server_port),'synthetic').post('hello',{})
   self.assertEqual(hits,[])
  finally:s.shutdown();t.join(timeout=2);s.server_close();sink.shutdown();st.join(timeout=2);sink.server_close()
if __name__=='__main__':unittest.main()
