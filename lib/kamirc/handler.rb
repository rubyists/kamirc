class Handler
  def self.call(bot, msg, matches)
    new(bot, msg, matches).call
  end

  attr_reader :bot, :msg, :matches

  def initialize(bot, msg, matches)
    @bot, @msg, @matches = bot, msg, matches
  end

  def privmsg(msg)
    @bot.privmsg(msg)
  end

  def say(msg)
    @bot.say(msg)
  end
end
