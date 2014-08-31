
require 'json'
require 'CGI'
require 'nokogiri'
require 'open-uri'
require 'daemons'
require 'daemons'
require 'unicode_utils'
require 'lingua/stemmer'
require_relative 'indexFileDaemon'
require_relative 'evernotePath'

def restartServer
	#restart server
	options = {
		#:backtrace => true,
		#:dir_mode => :script,
		#:log_output => true,
		:dir_mode => :normal,
		:dir => "./../../../",
		:ARGV       => ['restart','--', Dir.pwd]
	}

	Daemons.run('indexFileDaemonStart.rb', options)
end

def wordCoundForFilesDict(filesDict)
	count = 0
	filesDict.each_value do |v|
		count += v.count
	end

	return count
end

def createIndex
	folderPath = evernotePath

	currentDir = Dir.pwd
	Dir.chdir(folderPath)

	indexStorage = {}

	files = Dir['./'+'*.html']
	files.each do |f|
		fileName = File.basename(f)
		fillIndexFromFile(File.basename(f),indexStorage) if fileName != "index.html"
	end

	#filtering
	indexStorage.delete_if {|key, value| IndexFileDaemon.needFilterWord(key) }  

=begin
	testStorage = {}
	indexStorage.each_pair do |k,v|
		testStorage[k] = v.count #wordCoundForFilesDict(v)
	end

	testStorage = testStorage.sort_by {|k,v| v}

	testStorage.each do |v|
		puts "#{v[0]}: #{v[1]}"
	end
=end

	File.open("storedindex", "wb") {|f| Marshal.dump(indexStorage, f)}

	Dir.chdir(currentDir)
end

def fillIndexFromFile(fileName, indexStorage)

	string = File.open("./" + fileName, 'rb') { |file| file.read }
	doc = Nokogiri::HTML(string)
	doc.css('script').remove
	text  = doc.at('body').inner_text

	words = fileName.scan(/\p{Word}+/)
	words.delete("html")

	words += text.scan(/\p{Word}+/)

	ruStemmer = Lingua::Stemmer.new(:language => "ru")
	enStemmer = Lingua::Stemmer.new(:language => "en")

	words = words.map do |s| 
		nstr = UnicodeUtils.downcase(s)
		nstr = ruStemmer.stem(nstr)
		nstr = enStemmer.stem(nstr)
	end

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