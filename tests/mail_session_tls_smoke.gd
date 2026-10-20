extends SceneTree
## Actual Godot HTTPClient + loopback TLS server. No external services or tokens.
var checks: int = 0
var failures: int = 0
var listener := TCPServer.new()
var peers: Array[Dictionary] = []
var accepted: int = 0
var requests: int = 0
var results: Array[Dictionary] = []
var certificate: X509Certificate
var key: CryptoKey
var session: Node
var port: int = 43129
var bodies: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("MAIL_TLS " + label)
func _process(_delta: float) -> bool:
 if listener.is_connection_available():
  var tcp: StreamPeerTCP = listener.take_connection(); tcp.set_no_delay(true)
  var tls := StreamPeerTLS.new(); var error: Error=tls.accept_stream(tcp,TLSOptions.server(key,certificate))
  if error == OK: peers.append({"tls":tls,"tcp":tcp,"buffer":""}); accepted += 1
 for peer: Dictionary in peers:
  var tls: StreamPeerTLS=peer.tls
  if tls.get_status() not in [StreamPeerTLS.STATUS_CONNECTED,StreamPeerTLS.STATUS_HANDSHAKING]: continue
  tls.poll()
  if tls.get_status() != StreamPeerTLS.STATUS_CONNECTED: continue
  var count: int=tls.get_available_bytes()
  if count>0: peer.buffer += tls.get_data(count)[1].get_string_from_utf8()
  var split: int=str(peer.buffer).find("\r\n\r\n")
  if split<0: continue
  var headers: String=str(peer.buffer).substr(0,split);var length: int=0
  for line: String in headers.split("\r\n"):
   if line.to_lower().begins_with("content-length:"): length=int(line.get_slice(":",1).strip_edges())
  if str(peer.buffer).length()<split+4+length: continue
  bodies.append(str(peer.buffer).substr(split+4,length))
  peer.buffer=str(peer.buffer).substr(split+4+length)
  requests+=1
  var path: String=headers.get_slice(" ",1)
  var payload: String=JSON.stringify({"ok":true,"request":requests,"path":path})
  if path.ends_with("/chunked"):
   tls.put_data(("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: keep-alive\r\n\r\n%x\r\n%s\r\n0\r\n\r\n" % [payload.length(),payload]).to_utf8_buffer())
  elif path.ends_with("/drop"):
   tls.disconnect_from_stream()
  elif path.ends_with("/hold"):
   pass
  elif path.ends_with("/redirect"):
   tls.put_data("HTTP/1.1 302 Found\r\nLocation: https://example.com\r\nContent-Length: 0\r\nConnection: keep-alive\r\n\r\n".to_utf8_buffer())
  else:
   tls.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: keep-alive\r\n\r\n%s" % [payload.length(),payload]).to_utf8_buffer())
 return false
func response() -> Dictionary:
 var deadline: int=Time.get_ticks_msec()+5000
 while results.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
 if results.is_empty(): check(false,"response arrived before timeout"); return {}
 return results.pop_front()
func send(path: String,method: int=HTTPClient.METHOD_GET,body: String="") -> Error:
 return session.request("https://127.0.0.1/v1/mail/"+path,PackedStringArray(["Content-Type: application/json"]),method,body)
func run() -> void:
 create_timer(25.0).timeout.connect(func(): quit(1))
 if not OS.get_user_data_dir().contains("jade_mail_session_qa"): quit(2); return
 var crypto:=Crypto.new();key=crypto.generate_rsa(2048)
 certificate=crypto.generate_self_signed_certificate(key,"CN=jade-ascendant-player.jade-ascendant-studio.workers.dev,O=Loopback Fixture,C=US")
 check(certificate!=null,"fixture self-signed certificate created")
 for candidate: int in range(43129,43180):
  if listener.listen(candidate,"127.0.0.1")==OK: port=candidate; break
 check(listener.is_listening(),"loopback TLS listener starts")
 session=load("res://tests/fixtures/mail_session_probe.gd").new();session.certificate=certificate;session.port=port;root.add_child(session)
 session.request_completed.connect(func(result: int,code: int,headers: PackedStringArray,bytes: PackedByteArray):results.append({"result":result,"code":code,"headers":headers,"bytes":bytes}))
 check(send("list")==OK,"first request queued")
 check(send("list")==ERR_BUSY,"concurrent request refused")
 var data: Dictionary=await response()
 check(data.get("result")==HTTPRequest.RESULT_SUCCESS and data.get("code")==200,"real verified TLS GET succeeds")
 check(JSON.parse_string(data.get("bytes",PackedByteArray()).get_string_from_utf8()).path=="/v1/mail/list","actual server response is parsed")
 check(send("claim_batch",HTTPClient.METHOD_POST,'{"entries":[]}')==OK,"POST after GET queued")
 data=await response();check(data.get("code")==200,"POST completes")
 check(send("ack_batch",HTTPClient.METHOD_POST,'{"entries":[]}')==OK,"ACK after claim queued")
 data=await response();check(data.get("code")==200,"ACK completes")
 check(accepted==1 and session.connection_count==1 and session.reused_requests==2,"GET claim and ACK share one real TLS handshake")
 check(bodies[1]=='{"entries":[]}' and bodies[2]=='{"entries":[]}',"request body preserved on reused connection")
 check(send("chunked")==OK,"chunked request queued");data=await response()
 check(data.get("code")==200 and JSON.parse_string(data.get("bytes",PackedByteArray()).get_string_from_utf8()).ok==true,"chunked response fully drained before reuse")
 check(send("redirect")==OK,"redirect response requested");data=await response()
 check(data.get("code")==302 and accepted==1,"redirect surfaced without following another host")
 var before: int=requests
 check(send("drop",HTTPClient.METHOD_POST,'{"uncertain":true}')==OK,"uncertain POST queued");data=await response()
 check(data.get("result")!=HTTPRequest.RESULT_SUCCESS and requests==before+1,"uncertain POST failure never auto-replayed")
 session.cancel_request();await process_frame
 check(send("list")==OK,"request after close reconnects");data=await response()
 check(data.get("code")==200 and session.connection_count==2,"closed socket recovers with new verified connection")
 check(session.request("http://127.0.0.1/v1/mail/list",PackedStringArray())==ERR_INVALID_PARAMETER,"plain HTTP rejected")
 check(session.request("https://127.0.0.1/v1/player/register",PackedStringArray())==ERR_INVALID_PARAMETER,"transport restricted to mailbox route")
 session.body_size_limit=8
 check(send("list")==OK,"oversized response requested");data=await response()
 check(data.get("result")==HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED,"body-size limit enforced on reused TLS")
 session.body_size_limit=1048576;session.timeout=.1
 check(send("hold")==OK,"nonresponding request queued");data=await response()
 check(data.get("result")==HTTPRequest.RESULT_TIMEOUT,"network timeout completes without endless connecting")
 session.timeout=20.0
 # An unrelated CA must fail TLS. It must never produce a successful response.
 session.cancel_request();session.certificate=crypto.generate_self_signed_certificate(crypto.generate_rsa(2048),"CN=untrusted.local,O=Fixture,C=US")
 check(send("list")==OK,"untrusted TLS control queued");data=await response()
 check(data.get("result")==HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,"untrusted certificate is rejected")
 print("UNTRUSTED_CERT_REJECTED=PASS")
 session.queue_free();await process_frame
 for peer: Dictionary in peers: peer.tls.disconnect_from_stream();peer.tcp.disconnect_from_host()
 peers.clear();listener.stop()
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("MAIL_SESSION_TLS checks=",checks," failures=",failures,"; REAL_HTTPCLIENT_TLS; LOOPBACK_ONLY")
 call_deferred("quit",1 if failures else 0)
