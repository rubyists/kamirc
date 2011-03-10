module KamIRC
  module Sparks
    class Set < Spark
      def self.register(bot)
        bot.register self, Box::Privmsg(from_nick: 'manveru', text: /^\.set\s+(?<key>\S+)\s+(?<value>.+)$/)
        bot.register self, Box::Privmsg(from_nick: 'manveru', target: bot.nick, text: /^set\s+(?<key>\S+)\s+(?<value>.+)$/)
      end

      def call
        text = matches[:text]
        key, value = text[:key], text[:value]

        if option = bot.options.get(key)
          bot.options[key] = value
          reply "Set %p = %p" % [key, bot.options[key]]
        else
          reply "No option for %p" % [key]
        end
      end
    end
  end
end
