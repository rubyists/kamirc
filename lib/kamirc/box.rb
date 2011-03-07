module KamIRC
  module Box
    REGISTER = {}

    require_relative 'box/notice'
    require_relative 'box/privmsg'
    require_relative 'box/reply'
    require_relative 'box/ping'
    require_relative 'box/mode'
  end
end
