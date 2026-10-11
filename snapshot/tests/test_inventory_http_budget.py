"""Synthetic sockets only: complete request deadlines must resist slow headers and bodies."""
import socket, threading, time, unittest, uuid
from tools.inventory_session.mailbox import Mailbox, Server
from tools.inventory_session.client import Client

class RequestBudgetTests(unittest.TestCase):
 def exercise(self, prefix, trickle):
  ids={key:str(uuid.uuid4()) for key in ('device','store','client')}
  mailbox=Mailbox(**ids,client_token='synthetic-client',worker_token='synthetic-worker',clock=lambda:1.)
  binding=dict(ids,scope=str(uuid.uuid4()))
  mailbox.dispatch('/worker/hello',binding,'Bearer synthetic-worker')
  server=Server(mailbox);held=[];senders=[];stop=threading.Event()
  def drip(connection):
   while not stop.wait(.04):
    try:connection.sendall(b' ')
    except OSError:return
  try:
   client=Client(server.url,'synthetic-client')
   self.assertEqual(client.post('hello',{}),binding)
   for _ in range(8):
    connection=socket.create_connection(('127.0.0.1',server.http.server_port),timeout=1)
    connection.sendall(prefix);held.append(connection)
    if trickle:
     sender=threading.Thread(target=drip,args=(connection,),daemon=True);sender.start();senders.append(sender)
   # More than the server's three-second WHOLE request deadline, even with progress.
   time.sleep(3.5)
   for connection in held:
    connection.settimeout(.2)
    try:self.assertEqual(connection.recv(4096),b'','expired connection remains open')
    except (ConnectionResetError,BrokenPipeError):pass
   self.assertEqual(client.post('hello',{},timeout=1),binding,'slots must be recovered for legitimate clients')
   self.assertEqual(mailbox.rows,{})
  finally:
   stop.set()
   for connection in held:connection.close()
   for sender in senders:sender.join(timeout=1)
   server.close()
 def test_incomplete_request_headers_release_all_slots(self):
  self.exercise(b'POST /client/hello HTTP/1.1\r\n',False)
 def test_trickling_headers_do_not_extend_total_deadline(self):
  self.exercise(b'POST /client/hello HTTP/1.1\r\nX-Synthetic: ',True)
 def test_trickling_body_does_not_extend_total_deadline(self):
  self.exercise(b'POST /client/hello HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: 1000\r\nAuthorization: Bearer synthetic-client\r\n\r\n',True)
if __name__=='__main__':unittest.main()
