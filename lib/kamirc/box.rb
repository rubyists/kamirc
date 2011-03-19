module KamIRC
  module Box
    REGISTER = {}

    require_relative 'box/notice'
    require_relative 'box/privmsg'
    require_relative 'box/reply'
    require_relative 'box/ping'
    require_relative 'box/mode'
    require_relative 'box/nick'
    require_relative 'box/user'
    require_relative 'box/pong'
  end
end
