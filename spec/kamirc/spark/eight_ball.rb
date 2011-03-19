require 'bacon'
Bacon.summary_on_exit

require_relative '../../../lib/kamirc/box'
require_relative '../../../lib/kamirc/spark'
require_relative '../../../lib/kamirc/spark/eight_ball'

describe KamIRC::Sparks::EightBall do
  bot = Struct.new(:nick, :privmsgs){
    def privmsg(target, msg)
      privmsgs << [target, msg]
    end
  }.new("mad", [])
  msg = KamIRC::Box::Privmsg(target: '#test', from_nick: 'mad')
  ball = KamIRC::Sparks::EightBall.new(bot, msg, {})

  it 'responds' do
    ball.call
    bot.privmsgs.size.should == 1
    bot.privmsgs.first.first.should == "#test"
    bot.privmsgs.first.last.should.not.be.empty
  end
end
