# The URI for the server to connect to
require_relative 'IndexFileDaemon'

DAEMON_URI = "druby://localhost:8787"
DAEMON = IndexFileDaemon.new

$SAFE = 1   # disable eval() and friends

DRb.start_service
#server = DRb.fetch_server(DAEMON_URI)
#p server

#if server == nil 
	DRb.start_service(DAEMON_URI, DAEMON)
	# Wait for the drb server thread to finish before exiting.
	DRb.thread.join
#end
