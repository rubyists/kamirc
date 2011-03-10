module KamIRC
  module Sparks
    class EndOfMotd < Spark
      def self.register(bot)
        bot.register(self, Box::Reply(cmd: '376'))
      end

      def call
        @bot.privmsg 'manveru', 'Reporting for duty'
      end
    end
  end
end
