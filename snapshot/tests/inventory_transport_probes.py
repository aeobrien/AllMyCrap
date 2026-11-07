"""Actual URLSession refusal tests against disposable loopback-only listeners."""
import json,os,subprocess,threading,time
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from tools.inventory_session.mailbox import canonical

def run(binary,root,ids,token):
 passed=[];sink_hits=[]
 class Sink(BaseHTTPRequestHandler):
  def log_message(self,*a):pass
  def do_POST(self):
   sink_hits.append(True);self.send_response(200);self.send_header('Content-Length','2');self.end_headers();self.wfile.write(b'{}')
 sink=ThreadingHTTPServer(('127.0.0.1',0),Sink);thread=threading.Thread(target=sink.serve_forever,daemon=True);thread.start()
 try:
  for mode in ('redirect','oversized','unauthorized'):
   origin_hits=[]
   class Origin(BaseHTTPRequestHandler):
    def log_message(self,*a):pass
    def do_POST(self):
     origin_hits.append(True)
     self.send_response({'redirect':307,'oversized':200,'unauthorized':401}[mode])
     if mode=='redirect':self.send_header('Location','http://127.0.0.1:'+str(sink.server_port)+'/sink')
     self.send_header('Content-Length',str(2*1024*1024+1) if mode=='oversized' else '0');self.end_headers()
   origin=ThreadingHTTPServer(('127.0.0.1',0),Origin);t=threading.Thread(target=origin.serve_forever,daemon=True);t.start()
   folder=root/mode;folder.mkdir();(folder/'config.json').write_bytes(canonical(dict(ids,endpoint='http://127.0.0.1:'+str(origin.server_port),token=token)));os.chmod(folder/'config.json',0o600)
   proc=None
   try:
    with (folder/'worker.log').open('w') as log:
     proc=subprocess.Popen([str(binary),str(folder)],stdout=log,stderr=log)
     def wait(path):
      end=time.monotonic()+8
      while not path.exists():
       assert proc.poll() is None,'transport probe worker exited'
       assert time.monotonic()<end,'transport probe timeout'
       time.sleep(.02)
      return json.loads(path.read_text())
     wait(folder/'ready.json');time.sleep(.5)
     state=None
     for sequence in range(1,31):
      (folder/'control.json').write_bytes(canonical({'sequence':sequence,'action':'inspect'}));state=wait(folder/f'control-{sequence}.json')['state']
      if state=='unavailable':break
      time.sleep(.1)
     assert origin_hits and state=='unavailable',mode+' was not refused';passed.append('URLSession refuses '+mode)
     assert not sink_hits,'redirect disclosed request to second listener'
     (folder/'control.json').write_bytes(canonical({'sequence':100,'action':'stop'}));wait(folder/'control-100.json');proc.wait(timeout=5);assert proc.returncode==0
   finally:
    if proc is not None and proc.poll() is None:
     proc.terminate()
     try:proc.wait(timeout=3)
     except subprocess.TimeoutExpired:proc.kill();proc.wait(timeout=3)
    origin.shutdown();t.join(timeout=3);origin.server_close()
  passed.append('redirect delivered no credential or body to sink')
 finally:sink.shutdown();thread.join(timeout=3);sink.server_close()
 return passed
