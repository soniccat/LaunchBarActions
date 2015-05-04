require 'uri'
require "base64"
require 'json'
require 'time'
require './quizlet.rb'

authorizer = QuizletAuthorizer.new
performer = CommandPerformer.new(authorizer)
performer.authorizeIfNeeded()