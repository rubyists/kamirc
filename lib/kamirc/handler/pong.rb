module KamIRC
  class Pong < Handler
    def self.register(bot)
      bot.register(self, Box::Ping())
    end

    def call
      @bot.say 'PONG'
    end
  end
end
