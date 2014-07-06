#!/usr/bin/env ruby

require 'io/console'
require 'CGI'

str = ARGV[0]
args = str.split("||")

wordsString = args[0] + ", " + args[1] + ", " + args[2]
selectedIndex = args[3]
selectedWord = args[selectedIndex.to_i]

#copy selected word
IO.popen('pbcopy', 'w') { |f| f << selectedWord }

#show all words
wordsString = CGI::escape(wordsString)
value = `open \"x-launchbar:large-type?string=#{wordsString}\"`
