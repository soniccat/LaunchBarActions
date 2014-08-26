def evernotePath
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

	return exportPath
end