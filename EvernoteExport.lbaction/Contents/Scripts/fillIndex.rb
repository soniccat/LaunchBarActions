
require 'json'
require 'CGI'
require 'nokogiri'
require 'open-uri'
require 'daemons'
require 'daemons'
require 'unicode_utils'
require_relative 'evernotePath'

def restartServer
	#restart server
	options = {
		#:backtrace => true,
		#:dir_mode => :script,
		#:log_output => true,
		:ARGV       => ['restart','--', Dir.pwd]
	}

	Daemons.run('indexFileDaemon.rb', options)
end

def createIndex
	folderPath = evernotePath

	currentDir = Dir.pwd
	Dir.chdir(folderPath)

	indexStorage = {}

	files = Dir['./'+'*.html']
	files.each do |f|
		fillIndexFromFile(File.basename(f),indexStorage)
	end

	File.open("storedindex", "wb") {|f| Marshal.dump(indexStorage, f)}

	Dir.chdir(currentDir)
end

def fillIndexFromFile(fileName, indexStorage)

	string = File.open("./" + fileName, 'rb') { |file| file.read }
	doc = Nokogiri::HTML(string)
	doc.css('script').remove
	text  = doc.at('body').inner_text

	words = fileName.scan(/\p{Word}+/)
	words += text.scan(/\p{Word}+/)
	words = words.map {|s| UnicodeUtils.downcase(s)}

	wordsWithIndexes = words.zip(1..words.count)

	uniqWordsWithIndexes = {}
	wordsWithIndexes.each do |a|
		word = a[0]
		index = a[1]

		currentIndexes = uniqWordsWithIndexes[word]
		if currentIndexes == nil 
			currentIndexes = []
		end

		currentIndexes << index
		uniqWordsWithIndexes[word] = currentIndexes
	end

	uniqWordsWithIndexes.each_pair do |w,indexes|
		currentFileIndexesHash = indexStorage[w]
		if currentFileIndexesHash == nil
			currentFileIndexesHash = {}
		end

		currentFileIndexesHash[fileName] = indexes

		indexStorage[w] = currentFileIndexesHash
	end
end