module KamIRC
  class Spark
    def self.call(bot, msg, matches)
      new(bot, msg, matches).call
    end

    attr_reader :bot, :msg, :matches

    def initialize(bot, msg, matches)
      @bot, @msg, @matches = bot, msg, matches
    end

    def target
      p msg: msg
      p bot: bot.nick
      target = msg.target == bot.nick ? msg.from : msg.target
    end

    def reply(text)
      @bot.privmsg(target, text)
    end

    def privmsg(target, text)
      @bot.privmsg(target, text)
    end

    def say(raw_command)
      @bot.say(raw_command)
    end
  end
end
