module KamIRC
  module Sparks
    class Join < Spark
      def self.register(bot)
        bot.register(self, Box::Privmsg(target: bot.nick, from: /manveru/, text: /^join\s+(?<channels>.*)/))
      end

      def call
        matches[:text][:channels].split.each do |channel|
          bot.say("JOIN #{channel}")
        end
      end
    end
  end
end
