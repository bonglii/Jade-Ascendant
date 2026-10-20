extends "res://scripts/network/mail_https_session.gd"
var certificate: X509Certificate
var port: int = 43129
func _port() -> int: return port
func _verified_tls() -> TLSOptions: return TLSOptions.client(certificate, HOST)
func _allowed_target(host: String) -> bool: return host == "127.0.0.1"
