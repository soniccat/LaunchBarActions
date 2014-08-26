
require 'drb/drb'
require 'logger'
require 'time'
require_relative 'evernotePath'

# The URI for the server to connect to
URI="druby://localhost:8787"

class IndexFileDaemon

	attr_accessor :indexHash, :lg, :lastRequestDate

	def initialize
		folderPath = evernotePath
		@indexHash = loadIndexHash(folderPath)

		file = File.open(ARGV[0] + '/' + 'logfile.log', File::WRONLY | File::APPEND | File::CREAT)
		@lg = Logger.new(file)

		@lastRequestDate = Time.now.to_i
		@lg.info('initialize') { "Initializing" }
	end

	def search(searchString, requestDate)
		if requestDate.to_i < @lastRequestDate
			@lg.info('search') { "request is old #{searchString}" }
			return []
		end

		@lastRequestDate = Time.now.to_i
		currentRequestDate = @lastRequestDate

		@lg.info('search') { "search started #{searchString}" }

		folderPath = evernotePath
		intersectedFiles, resultFileHash = hashSearch(searchString,@indexHash, currentRequestDate)

		if currentRequestDate == @lastRequestDate
			results = buildResultArray(intersectedFiles, resultFileHash, folderPath)
			@lg.info('search') { "search finished #{searchString}" }
		else
			@lg.info('search') { "search stopped #{searchString}" }
		end

		return results
	end

 #private

	def loadIndexHash(folderPath)
		indexHash = nil
		indexPath = folderPath + "/storedindex"

		if File.exist?(indexPath)
			indexHash = File.open(indexPath, "rb") {|f| Marshal.load(f)}
		end

		return indexHash
	end

	def hashSearch(searchString, indexHash, currentRequestDate)
		searchWords = searchString.scan(/\p{Word}+/)

		#get indexes for typed words
		resultFileHash = {}
		lastWordFileHash = {}
		intersectedFiles = nil

		searchWords.each_index do |i|
			if currentRequestDate == @lastRequestDate
				w = searchWords[i]

				#think about last word as about /^word/ regular expression
				if i == searchWords.count - 1
					indexHash.each_pair do |word,files|
						if /#{w}/i =~ word
							lastWordFileHash[word] = files
						end
					end
				else
					h = indexHash[w]
					if h != nil 
						resultFileHash[w] = h
						intersectedFiles = h.keys
					end
				end
			end

		end if indexHash

		resultFileHash.each_value do |v|
			if currentRequestDate == @lastRequestDate
				if intersectedFiles == nil 
					intersectedFiles = v.keys
				else
					#keep files which have all words before the last one
					intersectedFiles &= v.keys
				end
			end
		end

		if currentRequestDate == @lastRequestDate

			#for the last word we get all files and intersect
			allFilesForLastWord = []
			lastWordFileHash.each_value do |v|
				allFilesForLastWord += v.keys
			end

			allFilesForLastWord = allFilesForLastWord.uniq

			if intersectedFiles
				intersectedFiles &= allFilesForLastWord
			else
				intersectedFiles = allFilesForLastWord
			end

			resultFileHash = resultFileHash.merge(lastWordFileHash)

			resultFileHash.each_pair do |k,v|
				resultFileHash[k] = v.select {|k,v| intersectedFiles.index(k) != nil}
			end 
		end

		return [intersectedFiles, resultFileHash]
	end

	def buildResultArray(intersectedFiles, resultFileHash, folderPath)
		results = []

		#sum matches, build items
		if intersectedFiles != nil
			intersectedFiles.each do |f|

				matches = 0

				resultFileHash.each_value do |v|
					if v[f]
						matches += v[f].count
					end
				end

				item = {}
				item[:filePath] = folderPath + '/' + f
				item[:matches] = matches
				results << item
			end

		end

		#sort by matches count
		results = results.sort do |dict1, dict2|
			numberOfMatchies1 = dict1[:matches]
			numberOfMatchies2 = dict2[:matches]

			numberOfMatchies2 - numberOfMatchies1
		end

		return results
	end

end

# The object that handles requests on the server
FRONT_OBJECT=IndexFileDaemon.new

$SAFE = 1   # disable eval() and friends

DRb.start_service(URI, FRONT_OBJECT)
# Wait for the drb server thread to finish before exiting.
DRb.thread.join
