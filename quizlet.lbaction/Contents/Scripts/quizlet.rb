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
    @appPath = "/Applications/OAuthAuthorizer.app/Contents/MacOS/OAuthAuthorizer"
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
    File.open("../../../outputQuizlet", "a") {|f| f.write(curlCommand())}
    return `#{curlCommand()}`
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
      string += " -F \"" + a + "\" "
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
      File.open("../../../outputQuizlet", "wt") {|f| f.write(result)}
    end
    
    result = JSON.parse(result) if result != nil && result.length > 2
    
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

class QuizletApi
  attr_accessor :performer, :currentSet, :storeName
  
  def initialize(performer)
    @storeName = "../../../quizletCurrentSet"
    
    @performer = performer
    @currentSet = loadCurrentSet()
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
    cmd = QuizletCommand.new("https://api.quizlet.com/2.0/sets/" + currentSet['id'].to_s + "/terms?term=" + word + "&definition="+definition, "POST")
    result = performer.run(cmd)
    return result
  end
  
  def createSet(title)
    cmd = QuizletCommand.new('https://api.quizlet.com/2.0/sets?title=' + title, 'POST')
    
    # Quizlet API forces us to send at least two pairs of words and definitions to create a set
    cmd.addFormArg("terms[]=word1")
    cmd.addFormArg("definitions[]=def1")
    cmd.addFormArg("terms[]=word2")
    cmd.addFormArg("definitions[]=def2")
    cmd.addFormArg("lang_terms=en")
    cmd.addFormArg("lang_definitions=en")
    
    result = performer.run(cmd)
    return result
  end
  
  def editTerm(setId, termId, newTerm)
    cmd = QuizletCommand.new('https://api.quizlet.com/2.0/sets/' + setId.to_s + "/terms/" + termId.to_s + "?term=" + newTerm, 'PUT')
    result = performer.run(cmd)
    return result
  end
  
  def editDefinition(setId, termId, newTerm)
    cmd = QuizletCommand.new('https://api.quizlet.com/2.0/sets/' + setId.to_s + "/terms/" + termId.to_s + "?definition=" + newTerm, 'PUT')
    result = performer.run(cmd)
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
    return result
  end
  
  def deleteSet(setId)
    cmd = QuizletCommand.new('https://api.quizlet.com/2.0/sets/' + setId.to_s, 'DELETE')
    result = performer.run(cmd)
    return result
  end
  
  def setCurrentSet(set)
    @currentSet = set
    storeCurrentSet()
  end
  
  def storeCurrentSet
    if currentSet != nil
      File.open(storeName, "wt") do |f|
        f.write currentSet.to_json
      end
    else
      if File.exist? storeName
        File.delete(storeName)
      end
    end
  end
  
  def loadCurrentSet
    if File.exist? storeName
      @currentSet = File.open(storeName, "rt") do |f|
        JSON.parse(f.read)
      end
    end
  end
  
end