#!/usr/bin/env ruby

require 'json'
require 'CGI'
require 'drb/drb'
require 'daemons'
require_relative 'evernotePath'

# The URI to connect to
SERVER_URI="druby://localhost:8787"

def handleInputString(searchString)
	#handle options
	optionIndex = searchString.index('--')
	optionsString = ""

	if optionIndex != nil
		optionsString = searchString[optionIndex+2..-1]
		searchString = searchString[0..optionIndex-1]
	end

	$showDebug = optionsString.index('d') != nil
	return searchString
end

def buildItemsFromArray(array)
	items = []
	array.each do | dict |
		item = {}
		item['title'] = File.basename(dict[:filePath])
		item['subtitle'] = dict[:matches].to_s + " matches"
		item['path'] = dict[:filePath] 

		items << item
	end

	return items
end

def search(searchString)

	results = nil
	if (searchString.length <= 1)
		return []
	end

	begin
		results = searchOnServer(searchString)

	rescue
		#maybe server wasn't launched
		options = {
			:backtrace => true,
			#:dir_mode => :script,
			:log_output => true,
			:dir_mode => :normal,
			:dir => "./../../../",
			:ARGV       => ['restart','--', Dir.pwd]
		}

		p "Launching daemon, please wait a few seconds and type again"
		Daemons.run('indexFileDaemonStart.rb', options)

		begin
			results = searchOnServer(searchString)
		rescue
		end
	end

	return results;
end

def searchOnServer(searchString)
	DRb.start_service

	server = DRbObject.new_with_uri(SERVER_URI)
	results = server.search(searchString, Time.now.to_i)
	return results
end

searchString = ARGV[0]
searchString = handleInputString(searchString)

startTime = Time.now
items = []

results = search(searchString)

if results == nil
	item = {}
	item['title'] = "Can't connect to the process"
	items.push(item)
end

finishTime = Time.now
timeIntervale = finishTime - startTime

if ($showDebug && results != nil)
	item = {}
	item['title'] = "scanning takes #{timeIntervale} seconds #{results.count} results"
	items.push(item)
end

items += buildItemsFromArray(results) if results != nil

if items.count == 0
	item = {}
	item['title'] = "no matches"
	items.push(item)
end

puts items.to_json
