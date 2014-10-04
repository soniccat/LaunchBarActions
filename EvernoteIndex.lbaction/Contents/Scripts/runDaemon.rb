require 'daemons'

options = {
			:backtrace => true,
			:dir_mode => :script,
			:log_output => true,
			:ARGV       => [ARGV[0],'--', Dir.pwd]
		}

Daemons.run('indexFileDaemonStart.rb', options)
