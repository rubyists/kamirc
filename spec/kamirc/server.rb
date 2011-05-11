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
  o "", :port, 7777
  o "", :creation_time, Time.now
  o "", :version, "KamIRC-0.1"
  o "", :servername, "servername"
  o "", :motd_path, 'motd.txt'
  o "", :available_user_modes, "DOQRSZaghilopswz"
  o "", :available_channel_modes, "CFILMPQbcefgijklmnopqrstvz"
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
      [KamIRC::RPL_WELCOME, ["Welcome to the Internet Relay Network bot!bot@iota"]],
      [KamIRC::RPL_YOURHOST, ["Your host is localhost, running version KamIRC-0.1"]],
      [KamIRC::RPL_CREATED, [/This server was created \w+ \w+ \d+ \d+ at \d+:\d+:\d+ \w+/]],
      [KamIRC::RPL_MYINFO, ["localhost", "KamIRC-0.1", "DOQRSZaghilopswz", "CFILMPQbcefgijklmnopqrstvz"]],
      [KamIRC::RPL_LUSERCLIENT, ["There are 1 users and 1 invisible on 1 servers"]],
      [KamIRC::RPL_LUSEROP, ["1", "operator(s) online"]],
      [KamIRC::RPL_LUSERUNKNOWN, ["1", "unknown connection(s)"]],
      [KamIRC::RPL_LUSERCHANNELS, ["0", "channels formed"]],
      [KamIRC::RPL_LUSERME, ["I have 1 clients and 1 servers"]],
      [KamIRC::RPL_MOTDSTART, ["- localhost Message of the day - "]],
      [KamIRC::RPL_MOTD, [/^-\s*Welcome to KamIRC$/]],
      [KamIRC::RPL_ENDOFMOTD, ["End of /MOTD command"]],
    ]
    KamIRC::SpecBot.connect(port: 7777, nick: 'bot') do |bot|
      EM.add_timer(0.2){
        while expect = expected.shift
          expect_cmd, expect_params = expect
          box = bot.log.shift

          box.cmd.should == expect_cmd
          box.params.size.should == expect_params.size
          box.params.zip(expect_params).each do |left, right|
            right.should === left
          end
        end

        bot.quit("for no reason")
        EM.add_timer(0.2){
          bot.log.should == [KamIRC::Box::Quit(message: 'for no reason')]
          done
        }
      }
    end
  end

  it 'handles client joining and parting a channel' do
    KamIRC::SpecBot.connect(port: 7777, nick: 'bot') do |bot|
      EM.add_timer(0.2){
        bot.log.clear
        bot.say("JOIN #foo")

        EM.add_timer(0.2){
          bot.log.shift.should == KamIRC::Box::Join(channel: "#foo")
          bot.log.shift.should == KamIRC::Box::Reply(
            from: {hostname: "localhost"},
            target: "bot",
            cmd: KamIRC::RPL_NOTOPIC,
            params: ["#foo", "No topic is set"]
          )
          bot.log.shift.should == KamIRC::Box::Reply(
            from: {hostname: "localhost"},
            target: "bot",
            cmd: KamIRC::RPL_NAMREPLY,
            params: ["@", "#foo", "a bc def ghijk lmnopq rstuvwx @yz"]
          )
          bot.log.shift.should == KamIRC::Box::Reply(
            from: {hostname: "localhost"},
            target: "bot",
            cmd: KamIRC::RPL_ENDOFNAMES,
            params: ["#foo", "End of /NAMES list"]
          )
          bot.log.shift.should == KamIRC::Box::Join(channel: '#foo')

          bot.say("PART #foo")

          EM.add_timer(0.2){
            bot.log.shift.should == KamIRC::Box::Part(channel: '#foo')

            EM.add_timer(0.2){
              bot.quit("get me out of here")

              EM.add_timer(0.2){
                bot.log.should == [KamIRC::Box::Quit(message: 'get me out of here')]
                done
              }
            }
          }
        }
      }
    end
  end

  it 'clients can privmsg each other' do
    KamIRC::SpecBot.connect(port: 7777, nick: 'bot1') do |bot1|
      KamIRC::SpecBot.connect(port: 7777, nick: 'bot2') do |bot2|
        EM.add_timer(0.2){
          bot1.log.clear
          bot2.log.clear

          bot1.say("PRIVMSG bot2 :hi there")
          EM.add_timer(0.1){
            bot2.log.should == ""
          }
        }
      end
    end
  end
end
