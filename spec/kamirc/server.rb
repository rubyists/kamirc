require_relative '../../lib/kamirc'
require_relative '../../lib/kamirc/server'

require 'pp'
require 'bacon'
require 'em-spec/bacon'

EventMachine.spec_backend = EventMachine::Spec::Bacon

server_options = KamIRC::Options.new(:server)
server_options.dsl do
  o "", :host, "localhost"
  o "", :ip, "127.0.0.1"
  o "", :port, "7777"
  o "", :creation_time, Time.now
  o "", :version, "KamIRC-0.1"
  o "", :servername, "servername"
  o "", :available_user_modes, "foo"
  o "", :available_channel_modes, "bar"
end

client_options = KamIRC::Options.new(:client)
client_options.dsl do
  o "", :host, "localhost"
  o "", :port, "7777"
  o "", :nick, "botnick"
  o "", :user, "botuser"
end

module KamIRC
  class SpecBot < Bot
    attr_reader :log

    def initialize(options)
      @log = []
      super
    end

    def dispatch(box)
      @log << box
    end
  end
end

EM.describe KamIRC::Server do
  server = KamIRC::Server.connect(server_options)

  it 'handles client connecting' do
    expected = [
      [KamIRC::RPL_WELCOME, ["Welcome to the Internet Relay Network botnick!botuser@iota"]],
      [KamIRC::RPL_YOURHOST, ["Your host is localhost, running version KamIRC-0.1"]],
      [KamIRC::RPL_CREATED, [/This server was created \w+ \w+ \d+ \d+ at \d+:\d+:\d+ \w+/]],
      [KamIRC::RPL_MYINFO, ["localhost", "KamIRC-0.1", "foo", "bar"]],
      [KamIRC::RPL_LUSERCLIENT, ["There are 1 users and 1 invisible on 1 servers"]],
      [KamIRC::RPL_LUSEROP, ["1", "operator(s) online"]],
      [KamIRC::RPL_LUSERUNKNOWN, ["1", "unknown connection(s)"]],
      [KamIRC::RPL_LUSERCHANNELS, ["0", "channels formed"]],
      [KamIRC::RPL_LUSERME, ["I have 1 clients and 1 servers"]],
    ]
    KamIRC::SpecBot.connect(client_options) do |bot|
      EM.add_periodic_timer(1){
        while expect = expected.shift
          expect_cmd, expect_params = expect
          box = bot.log.shift

          box.cmd.should == expect_cmd
          box.params.size.should == expect_params.size
          box.params.zip(expect_params).each do |left, right|
            right.should === left
          end
        end

        bot.log.clear
        done
      }
    end
  end
end
