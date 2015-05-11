require 'net/http'
require 'net/https'
require 'json'

class AuthInfo

  attr_accessor :accessToken, :expiresIn, :userId, :createTime
  def initialize(token, expiresIn, userId, time = nil)
    @accessToken = token
    @expiresIn = expiresIn
    @userId = userId
    @createTime = time == nil ?  Time.now : time
  end

  def to_json(options = {})
    JSON.dump({
      'accessToken' => accessToken,
      'expiresIn' => expiresIn,
      'userId' => userId,
      'createTime' => createTime
    })
  end

  def self.from_json string
    data = JSON.load string
    return AuthInfo.new(data['accessToken'],
    data['expiresIn'],
    data['userId'],
    Time.parse(data['createTime']))
  end

  def authorized?
    result = accessToken != nil

    if result then
      result = !expired?
    end

    return result
  end

  def expired?
    return Time.now >= createTime + expiresIn
  end
end

class QuizletAuthorizer

  attr_accessor :clientIdKey, :secretKey, :redirectUrl, :appPath, :storeName, :authInfo
  def initialize
    @clientIdKey = "9zpZ2myVfS"
    @secretKey = "bPHS9xz2sCXWwq5ddcWswG"
    @redirectUrl = "http://gaolife.blogspot.ru"
    @appPath = "../OAuthAuthorizer.app/Contents/MacOS/OAuthAuthorizer"
    @storeName = "../../../authStore"
    @authInfo = loadAuthInfo()
  end

  def authorized?
    return authInfo ? authInfo.authorized?() : false
  end

  def authorizeInQuizlet
    result = requestAuthorize()

    if result.has_key? "code"
      @authInfo = requestAccessToken(result["code"])
      storeAuthInfo()
    end

    return authInfo
  end

  def requestAuthorize
    result = launchWebAuth()
    dict = {}
    if !result.start_with?("error:") && result.length > 0
      dict = get_params_from_uri(URI(result))
    end

    return dict
  end

  def launchWebAuth
    return `#{appPath} "#{authUrl()}"`
  end

  def authUrl
    return "https://quizlet.com/authorize?scope=write_set%20read&client_id=" + clientIdKey + "&response_type=code&state=" + randomCode().to_s + "&redirect_uri=" + redirectUrl
  end

  def randomCode
    return (Random.rand * 100000).round
  end

  def get_params_from_uri(uri)
    params = URI.decode_www_form(uri.query)
    dict = get_dict_from_values(params)
    return dict
  end

  def get_dict_from_values(params)
    dict = {}
    params.each do |v|
      dict[v[0]] = v[1]
    end
    return dict
  end

  def storeAuthInfo
    File.open(storeName, "w") {|f| f.write(JSON.dump(authInfo))}
  end

  def loadAuthInfo
    if File.exist? storeName
      result = File.open(storeName, "r"){|f|
        AuthInfo.from_json(f.read)}
    end
    return result
  end

  def requestAccessToken(code)
    curlString = curlTokenCommand(code)
    curlResult = `#{curlString}`
    dict = JSON.parse(curlResult)

    return AuthInfo.new(dict['access_token'], dict['expires_in'], dict['user_id'])
  end

  def authHeader
    return Base64.encode64(clientIdKey + ":" + secretKey)
  end

  def curlTokenCommand(code)
    return "curl -s -H \"Authorization: Basic " + authHeader() + "\" \"" + tokenUrl(code) + "\""
  end

  def tokenUrl(code)
    return "https://api.quizlet.com/oauth/token?grant_type=authorization_code&code=" + code + "&redirect_uri=http://gaolife.blogspot.ru"
  end

  def signCommand(command)
    command.auth = authInfo.accessToken
  end
end

class QuizletCommand

  attr_accessor :command, :auth, :method, :formArgs
  def initialize(command, method = "GET")
    @command = command
    @method = method
    @formArgs = []
  end

  def run
    File.open("../../../outputQuizlet", "at") {|f| f.write("\n");f.write(curlCommand())}
    uri = URI(URI::encode(command))

    res = nil
    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      request = createRequest(uri)
      res = http.request request

      if res.code.to_i.between?(200,299)
        res = res.body
      end
    end

    File.open("../../../outputQuizlet", "at") do |f|
      f.write("\n");
      
      if (res.is_a?(Net::HTTPResponse))
      f.write(res.code)
      f.write(res.body)

      elsif (res.is_a?(String))
      f.write(res)
      end
    end

    return res
  end

  def createRequest(uri)
    if method == "GET"
      request = Net::HTTP::Get.new(uri)
    elsif method == "POST"
      request = Net::HTTP::Post.new(uri)
    elsif method == "DELETE"
      request = Net::HTTP::Delete.new(uri)
    elsif method == "PUT"
      request = Net::HTTP::Put.new(uri)
    end

    request['Authorization:'] = 'Bearer ' + auth

    if formArgs.count > 0
      request.set_form formArgs, 'multipart/form-data'
    end

    return request
  end

  def curlCommand
    result = "curl -s " + " -X " + method + " " + formArgString() + " " + curlAuthHeader() + " \"" + command + "\""
    return result
  end

  def curlAuthHeader
    return auth != nil ? "-H \"Authorization: Bearer " + auth + "\"" : ""
  end

  def formArgString
    string = ""
    formArgs.each do |a|
      string += " -F \"" + a.to_json + "\" "
    end
    return string
  end

  def addFormArg(arg)
    formArgs.push(arg)
  end
end

class CommandPerformer
  attr_accessor :authorizer
  def initialize(authorizer)
    @authorizer = authorizer
  end

  def authorized?
    return authorizer.authorized?()
  end

  def authInfo
    return authorizer.authInfo
  end

  def run(cmd, isRepeat = false, logging = false)
    authorizeIfNeeded

    authorizer.signCommand(cmd)
    result = cmd.run

    if logging
      File.open("../../../outputQuizlet", "at") {|f| f.write(result)}
    end

    if result.is_a?(String)
      result = JSON.parse(result) if result != nil && result.length > 2
    end

    if result.is_a?(Hash) && isTokenInvalid(result) && isRepeat == false
      authorizer.authorizeInQuizlet()
      result = run(cmd, true)
    end

    return result
  end

  def authorizeIfNeeded
    if !authorizer.authorized?()
      authorizer.authorizeInQuizlet()
    end
  end

  def isTokenInvalid(result)
    code = httpCode(result)
    return code == 401
  end

  def httpCode(dict)
    return dict["http_code"]
  end
end

class Card
  attr_accessor :setId, :cardId, :term, :definition
  def initialize(setId, cardId, term, definition)
    @setId = setId
    @cardId = cardId
    @term = term
    @definition = definition
  end

  def to_json(options = {})
    JSON.dump({
      'setId' => setId,
      'cardId' => cardId,
      'term' => term,
      'definition' => definition
    })
  end

  def self.from_json string
    data = JSON.load string
    return Card.new(data['setId'],
    data['cardId'],
    data['term'],
    data['definition'])
  end
end

class QuizletApi
  attr_accessor :performer, :currentSet, :lastCard, :currentSetStoreName, :lastCardStoreName
  def initialize(performer)
    @currentSetStoreName = "../../../quizletCurrentSet"
    @lastCardStoreName = "../../../quizletCurrentWord"

    @performer = performer
    @currentSet = loadCurrentSet()
    @lastCard = loadLastCard()
  end

  def authorized?
    return performer.authorized?()
  end

  def getUserInfo
    performer.authorizeIfNeeded()

    dict = {}
    if performer.authInfo != nil
      cmd = QuizletCommand.new("https://api.quizlet.com/2.0/users/" + performer.authInfo.userId)
      return performer.run(cmd)
    end

    return dict
  end

  def getWords(setId)
    cmd = QuizletCommand.new("https://api.quizlet.com/2.0/sets/" + setId.to_s)
    return performer.run(cmd)
  end

  def getAllWords()
    cmd = QuizletCommand.new("https://api.quizlet.com/2.0/users/" + performer.authInfo.userId + "/sets")
    result = performer.run(cmd)
    return result
  end

  def addWord(word, definition)
    setId = currentSet['id']
    cmd = QuizletCommand.new("https://api.quizlet.com/2.0/sets/" + setId.to_s + "/terms?term=" + word + "&definition="+definition, "POST")
    result = performer.run(cmd)

    cardId = result['id']
    createLastCard(setId, cardId, word, definition)
    storeLastCard()

    return result
  end

  def createSet(title)
    cmd = QuizletCommand.new('https://api.quizlet.com/2.0/sets?title=' + title, 'POST')

    # Quizlet API forces us to send at least two pairs of words and definitions to create a set
    cmd.addFormArg(['terms[]','word1'])
    cmd.addFormArg(['definitions[]','def1'])
    cmd.addFormArg(['terms[]','word2'])
    cmd.addFormArg(['definitions[]','def2'])
    cmd.addFormArg(['lang_terms','en'])
    cmd.addFormArg(['lang_definitions','en'])

    result = performer.run(cmd)
    return result
  end

  def editTerm(setId, termId, newTerm)
    cmd = QuizletCommand.new('https://api.quizlet.com/2.0/sets/' + setId.to_s + "/terms/" + termId.to_s + "?term=" + newTerm, 'PUT')
    result = performer.run(cmd)

    if hasLastCard? && lastCard.cardId == termId
      lastCard.term = newTerm
      storeLastCard()
    end

    return result
  end

  def editDefinition(setId, termId, newDefinition)
    cmd = QuizletCommand.new('https://api.quizlet.com/2.0/sets/' + setId.to_s + "/terms/" + termId.to_s + "?definition=" + newDefinition, 'PUT')
    result = performer.run(cmd)

    if hasLastCard? && lastCard.cardId == termId
      lastCard.definition = newDefinition
      storeLastCard()
    end

    return result
  end

  def editSet(setId, newTitle)
    cmd = QuizletCommand.new('https://api.quizlet.com/2.0/sets/' + setId.to_s + "/?title=" + newTitle, 'PUT')
    result = performer.run(cmd)
    return result
  end

  def deleteTerm(setId, termId)
    cmd = QuizletCommand.new('https://api.quizlet.com/2.0/sets/' + setId.to_s + "/terms/" + termId.to_s, 'DELETE')
    result = performer.run(cmd)

    if (hasLastCard? && lastCard.cardId == termId)
      deleteLastCard()
    end

    return result
  end

  def deleteSet(setId)
    cmd = QuizletCommand.new('https://api.quizlet.com/2.0/sets/' + setId.to_s, 'DELETE')
    result = performer.run(cmd)

    if (currentSet != nil && currentSet['id'] == setId)
      deleteCurrentSet()
    end

    return result
  end

  #TODO: add separate arguments for id and title and write getters only for them
  def setCurrentSet(set)
    @currentSet = set
    storeCurrentSet()
  end

  def storeCurrentSet
    File.open(currentSetStoreName, "wt") do |f|
      f.write currentSet.to_json
    end
  end

  def deleteCurrentSet
    if File.exist? currentSetStoreName
      File.delete(currentSetStoreName)
    end
  end

  def loadCurrentSet
    if File.exist? currentSetStoreName
      @currentSet = File.open(currentSetStoreName, "rt") do |f|
        JSON.parse(f.read)
      end
    end
  end

  def loadLastCard
    result = nil
    if File.exist? lastCardStoreName
      result = File.open(lastCardStoreName, "rt") do |f|
        Card.from_json(f.read)
      end
    end
    return result
  end

  def createLastCard(setId, cardId, term, definition)
    @lastCard = Card.new(setId, cardId, term, definition)
  end

  def storeLastCard()
    File.open(lastCardStoreName, "w") {|f| f.write(JSON.dump(lastCard))}
  end

  def deleteLastCard
    if File.exist? lastCardStoreName
      File.delete(lastCardStoreName)
    end
  end

  def hasLastCard?
    return lastCard != nil
  end

end