#!/usr/bin/env ruby

require 'json'
require 'CGI'

#get search folder
homeFolder = `echo ~/`
homeFolder = homeFolder[0..-2]

exportPath = ""

containersPath = "#{homeFolder}/Library/Group Containers/"
files = Dir.entries(containersPath)
files.each do |f|
	if f.end_with?("com.evernote.Evernote")
		exportPath = containersPath + f + "/Evernote/evernoteExport"
	end
end

if exportPath == nil || exportPath.length == 0
	item = {}
	item['title'] = "Can't build path to a search folder"
	items.push(item)
	return item
end

folderPath = exportPath
searchString = ARGV[0]

optionIndex = searchString.index('--')
optionsString = ""

if optionIndex != nil
	optionsString = searchString[optionIndex+2..-1]
	searchString = searchString[0..optionIndex-1]
end

$showDebug = optionsString.index('d') != nil


#seach
startTime = Time.now
results = []


resultStrings = Dir[folderPath+'/'+'*.html'].inject(Hash.new(0)){ |result, item| result.update(item => File.read(item).scan(/#{searchString}/i).size) }
resultStrings.each do |k, v|
	if v > 0
		item = {}
		item[:filePath] = k
		item[:matches] = v
		results << item
	end 
end

#sort by matches count
results = results.sort do |dict1, dict2|
	numberOfMatchies1 = dict1[:matches]
	numberOfMatchies2 = dict2[:matches]

	numberOfMatchies2 - numberOfMatchies1
end

finishTime = Time.now
timeIntervale = finishTime - startTime

#convert to response
items = []

if ($showDebug)
	item = {}
	item['title'] = "scanning takes #{timeIntervale} seconds"
	items.push(item)
end

results.each do | dict |

	item = {}
	item['title'] = File.basename(dict[:filePath])
	item['subtitle'] = dict[:matches].to_s + " matches"
	item['path'] = dict[:filePath] 

	items.push(item)
end

if items.count == 0
	item = {}
	item['title'] = "no matches"
	items.push(item)
end

puts items.to_json



