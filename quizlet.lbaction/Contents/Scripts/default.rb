require 'uri'
require "base64"
require 'json'
require 'time'
require './quizlet.rb'

# Ideas
# keep at least 5 latest added words to change their definitions faster
# add option to add a definition for a word
# add option to show 10 random words from all sets

def actionItems(quizletApi)
  dict = quizletApi.getUserInfo
  
  sets = dict['sets'].sort {|b,a| a['created_date'] <=> b['created_date']}
  items = quizletSetsToItems(sets)
  
  items = [getCurrentSetItem(quizletApi)] + [getAllWordsItem()] + items
  return items
end

def handleLaunch(quizletApi)
  items = []
  if quizletApi.authorized? 
    items = actionItems(quizletApi)
  else 
    items.push(authItem())
  end
  
  return items
end

def getWords(quizletApi, setId, setTitle, word)
  setInfo = quizletApi.getWords(setId)
  resultItems = quizletTermsToItems(setInfo['terms'], setId, nil,  word)
  
  actionItems = []
  # Quizlet Api requires to send all terms and definitions again just to change the title of a set
  # Now I worry about a chance to lose a whole set just after renaming
  #
  #if word != nil
  #  actionItems += [getEditSetItem(setId, word)]
  #end
  actionItems += [getDeleteSetItem(setId,setTitle)]
  
  return resultItems + actionItems
end

def getAllWords(quizletApi, filter = nil, needAddItem = false, word = nil)
  sets = quizletApi.getAllWords()
  
  words = []
  actions = []
  
  if needAddItem && filter != nil
    if quizletApi.currentSet != nil
      actions += [getAddWordItem(quizletApi, word)]
    end
    
    actions += [getCreateSetItem(word)]
    actions += [getChangeItem(word)]
  end
  
  if quizletApi.hasLastCard?
    actions += [getLastCardItem(quizletApi.lastCard, word)]
  end
  
  sets.each do |s|
    words += quizletTermsToItems(s['terms'], s['id'], filter, word)
  end
  
  return actions + words.sort{|a,b| a['title'].casecmp b['title']}
end

def quizletTermsToItems(terms, setId, filter = nil, word = nil)
  resultItems = []
  terms.each do |v|
    needAddItem = filter == nil || v['term'].include?(filter)
    
    if needAddItem 
      item = {}
      title = v['term']
      id = v['id']
      
      item['title'] = title
      item['subtitle'] = v['definition']
      item['icon'] = 'word.png'
      item['children'] = [{'title' => v['definition']}]
      item['_id'] = v['id']
      item['_setId'] = setId
      
      if word != nil
        item['children'] += [getEditWordTermItem(title, setId, id, word), 
                             getEditWordDefinitionItem(title, setId, id, word)]
      end
      
      item['children'] += [getDeleteTermItem(title, setId, id)]
      
      resultItems.push(item)
    end
  end
  return resultItems
end

def setsToSelect(quizletApi)
  dict = quizletApi.getUserInfo
  sets = dict['sets'].sort {|b,a| a['created_date'] <=> b['created_date']}
  items = quizletSetsToItems(sets, 'setCurrentSetWithId')
end

def setCurrentSet(quizletApi, setItem)
  quizletApi.setCurrentSet({'title' => setItem['title'], 'id' => setItem['_setId']})
  return [getResultItem('Selected!')]
end

def addWord(quizletApi, phrase)
  word = phrase
  definition = 'unknown'
  
  if (word.include? ':')
    words = word.split(':')
    word = words[0]
    if words[1] != nil then definition = words[1] end
  end
  
  dict = quizletApi.addWord(word, definition)
  return [getResultItem('Added!')]
end

def createSet(quizletApi, title)
  dict = quizletApi.createSet(title)
  
  id = dict['id']
  quizletApi.setCurrentSet({'title' => title, 'id' => id})
  return [getResultItem('Created!')]
end

def editWordTerm(quizletApi, word)
  dict = quizletApi.getUserInfo
  
  sets = dict['sets'].sort {|b,a| a['created_date'] <=> b['created_date']}
  items = quizletSetsToItems(sets, 'set', word)
  
  items = [getAllWordsItem(word)] + items
  return items
end

def editWordTermConfirm(quizletApi, setId, id, word)
  dict = quizletApi.editTerm(setId, id, word)
  return [getResultItem('Changed!')]
end

def editWordDefinitionConfirm(quizletApi, setId, id, word)
  dict = quizletApi.editDefinition(setId, id, word)
  return [getResultItem('Changed!')]
end

def deleteTerm(quizletApi, setId, id)
  dict = quizletApi.deleteTerm(setId, id)
  return [getResultItem('Deleted!')]
end

def deleteSet(quizletApi, setId)
  dict = quizletApi.deleteSet(setId)
  return [getResultItem('Deleted!')]
end

def editSet(quizletApi, setId, word)
  quizletApi.editSet(setId, word)
  return [getResultItem('Changed!')]
end

# ==== getting items

def authItem
  item = {}
  item['title'] = 'Select To Authorize'
  item['action'] = 'authorize.rb'
  item['icon'] = 'setDefaultSet.png'
  return item
end

def quizletSetsToItems(sets, action = 'set', word = nil)
  resultItems = []
  sets.each do |s|
    item = {}
    item['title'] = s['title']
    item['action'] = "default.rb"
    item['actionReturnsItems'] = true
    item['_setId'] = s['id']
    item['_act'] = action
    item['_word'] = word
    item['icon'] = 'set.png'
    resultItems.push(item)
  end
  return resultItems
end

def getAllWordsItem(word = nil)
  item = {}
  item['title'] = 'All Words'
  item['action'] = "default.rb"
  item['actionReturnsItems'] = true
  item['_act'] = "allWords"
  item['_word'] = word
  item['icon'] = 'allWords.png'
  return item
end

def getCurrentSetItem(quizletApi)
  hasSelectedSet = quizletApi.currentSet != nil
  
  item = {}
  item['title'] = hasSelectedSet ? "Current Set: " + quizletApi.currentSet['title'] : "No Current Set"
  item['action'] = "default.rb"
  item['actionReturnsItems'] = true
  item['_act'] = "setCurrentSet"
  item['icon'] = 'setDefaultSet.png'
  return item
end

def getResultItem(name)
  item = {}
  item['title'] = name
  item['action'] = "default.rb"
  item['actionReturnsItems'] = true
  item['_act'] = "launch"
  item['icon'] = 'done.png'
  return item
end

def getChangeItem(word)
  item = {}
  item['title'] = 'Change Term/Definition further'
  item['action'] = "default.rb"
  item['actionReturnsItems'] = true
  item['_act'] = "editWordTerm"
  item['_word'] = word
  item['icon'] = 'edit.png'
  return item
end

def getCreateSetItem(title)
  item = {}
  item['title'] = 'Create Set "' + title +'"'
  item['action'] = "default.rb"
  item['actionReturnsItems'] = true
  item['_act'] = "createSet"
  item['_title'] = title
  item['icon'] = 'add.png'
  return item
end

def getAddWordItem(quizletApi, word)
  item = {}
  item['title'] = 'Add word to ' + quizletApi.currentSet['title']
  item['action'] = "default.rb"
  item['actionReturnsItems'] = true
  item['_act'] = "addWord"
  item['_word'] = word
  item['icon'] = 'add.png'
  return item
end

def getEditWordTermItem(currentWord, setId, termId, newWord)
  item = {}
  item['title'] = 'Change word to ' + newWord
  item['action'] = "default.rb"
  item['actionReturnsItems'] = true
  item['_act'] = "editWordTermConfirm"
  item['_word'] = newWord
  item['_setId'] = setId
  item['_termId'] = termId
  item['icon'] = 'edit.png'
  return item
end

def getEditWordDefinitionItem(currentWord, setId, termId, newWord)
  item = {}
  item['title'] = 'Change definition to ' + newWord
  item['action'] = "default.rb"
  item['actionReturnsItems'] = true
  item['_act'] = "editWordDefinitionConfirm"
  item['_word'] = newWord
  item['_setId'] = setId
  item['_termId'] = termId
  item['icon'] = 'edit.png'
  return item
end

def getDeleteTermItem(term, setId, termId)
  item = {}
  item['title'] = 'Delete ' + term
  item['action'] = "default.rb"
  item['actionReturnsItems'] = true
  item['_act'] = "deleteTerm"
  item['_setId'] = setId
  item['_termId'] = termId
  item['icon'] = 'delete.png'
  return item
end

def getEditSetItem(setId, newWord)
  item = {}
  item['title'] = 'Change title to ' + newWord
  item['action'] = "default.rb"
  item['actionReturnsItems'] = true
  item['_act'] = "editSetTitle"
  item['_word'] = newWord
  item['_setId'] = setId
  item['icon'] = 'edit.png'
  return item
end

def getDeleteSetItem(setId, setTitle)
  item = {}
  item['title'] = 'Delete Set ' + setTitle
  item['icon'] = 'delete.png'
  
  child = {}
  child['title'] = 'Select to confirm'
  child['action'] = "default.rb"
  child['actionReturnsItems'] = true
  child['_act'] = "deleteSet"
  child['_setId'] = setId
  child['icon'] = 'delete.png'
  
  item['children'] = [child]
  return item
end

def getLastCardItem(card, word)
  #TODO: we should parse data to our objects and work only with them
  jsonItem = {'id' => card.cardId, 'term' => card.term, 'definition' => card.definition}
  item = quizletTermsToItems([jsonItem], card.setId, nil, word)[0]
  item['title'] = 'Last word: ' + card.term
  
  return item
end

# ====

def handleArgs(arg, quizletApi)
  act = arg['_act']
  items = []
  
  if act == 'launch' 
    items = handleLaunch(quizletApi)
  
  elsif act == "set"
    items = getWords(quizletApi, arg["_setId"], arg["title"], arg['_word'])
    
  elsif act == "allWords"
    items = getAllWords(quizletApi, arg['_filter'], true, arg['_word'])
    
  elsif act == "setCurrentSet"
    items = setsToSelect(quizletApi)
    
  elsif act == "setCurrentSetWithId"
    items = setCurrentSet(quizletApi, arg)
    
  elsif act == "addWord"
    items = addWord(quizletApi, arg['_word'])
    
  elsif act == "createSet"
    items = createSet(quizletApi, arg['_title'])
    
  elsif act == "editWordTerm"
    items = editWordTerm(quizletApi, arg['_word'])
    
  elsif act == "editWordTermConfirm"
    items = editWordTermConfirm(quizletApi, arg['_setId'], arg['_termId'], arg['_word'])
    
  elsif act == "editWordDefinitionConfirm"
    items = editWordDefinitionConfirm(quizletApi, arg['_setId'], arg['_termId'], arg['_word'])
    
  elsif act == "deleteTerm"
    items = deleteTerm(quizletApi, arg['_setId'], arg['_termId'])
    
  elsif act == "deleteSet"
    items = deleteSet(quizletApi, arg['_setId'])
    
  elsif act == "editSetTitle"
    items = editSet(quizletApi, arg['_setId'], arg['_word'])
    
  else 
    item = {}
    item['title'] = "Unknown Command: " + act
    item['action'] = "default.rb"
    item['actionReturnsItems'] = true
    
    items.push(item)
  end
  
  return items
end

authorizer = QuizletAuthorizer.new
performer = CommandPerformer.new(authorizer)
quizletApi = QuizletApi.new(performer)

items = []

if ARGV.length > 0
  begin
    
    items = handleArgs(JSON.parse(ARGV[0]), quizletApi)
  rescue JSON::ParserError => e
    
    #File.open("../../../outputQuizlet2", "a") {|f| f.write(e.backtrace)}
    
    str = ARGV[0]
    if str.start_with? 'set '
      #TODO: search for sets
    
    elsif str.start_with? 'ed '
      cmdLen = 'ed '.length
      word = str[cmdLen,str.length-cmdLen]
      items = handleArgs({'_act'=>'editWordTerm', '_word'=>word}, quizletApi)

    elsif
      items = handleArgs({'_act'=>'allWords', '_filter'=>str, '_word'=>str}, quizletApi)
    end
  end
else 
  items = handleArgs({'_act'=>'launch'}, quizletApi)
end

puts items.to_json
