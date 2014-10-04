require 'json'
require 'CGI'
require 'drb/drb'
require 'daemons'
require_relative 'evernotePath'

SERVER_URI="druby://localhost:8787"

DRb.start_service

server = DRbObject.new_with_uri(SERVER_URI)
#results = server.dataForWord(ARGV[0])
server.unloadIndex
#p results