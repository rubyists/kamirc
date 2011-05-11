require_relative '../../lib/kamirc/parser'
require_relative '../../lib/kamirc/box'

require 'bacon'
Bacon.summary_on_exit

module SpecParser
  def parse(str)
    parser = KamIRC::Message.new
    parser.parse(str)
  rescue Parslet::ParseFailed => error
    puts
    puts error, parser.root.error_tree
    raise(error)
  end
end

describe KamIRC::Box do
  extend SpecParser

  it 'boxes NOTICE' do
    msg = parse(":pratchett.freenode.net NOTICE * :*** Looking up your hostname...")
    box = KamIRC::Box::Notice.from_message(msg)
    box.from.should == {server: 'pratchett.freenode.net'}
    box.cmd.should == 'NOTICE'
    box.target.should == '*'
    box.text.should == '*** Looking up your hostname...'
  end

  it 'unboxes NOTICE' do
    original = ":pratchett.freenode.net NOTICE * :*** Looking up your hostname..."
    parsed = parse(":pratchett.freenode.net NOTICE * :*** Looking up your hostname...")
    box = KamIRC::Box::Notice.from_message(parsed)
    msg = box.to_message
    msg.should == original
  end

  describe KamIRC::Box::Reply do
    extend SpecParser

    def reply(cmd, vars)
      reply = KamIRC::Box::Reply(
        from: {hostname: 'host'},
        target: 'target',
        cmd: cmd,
        vars: vars
      )
    end

    it 'unboxes RPL_WELCOME' do
      msg = parse(":host 001 target manveru :Welcome to the Internet Relay Network anick!auser@ahost")
      box = KamIRC::Box::Reply.from_message(msg)

      box.should == KamIRC::Box::Reply(
        from: {hostname: 'host'},
        target: 'target',
        cmd: KamIRC::RPL_WELCOME,
        vars: {},
        params: ["manveru", "Welcome to the Internet Relay Network anick!auser@ahost"],
      )
    end

    it 'unboxes ERR_NOSUCHNICK' do
      msg = parse(":host 401 target manveru :No such nick/channel")
      box = KamIRC::Box::Reply.from_message(msg)

      box.should == KamIRC::Box::Reply(
        from: {hostname: 'host'},
        target: 'target',
        cmd: KamIRC::ERR_NOSUCHNICK,
        vars: {},
        params: ["manveru", "No such nick/channel"],
      )
    end

    it 'boxes ERR_NOSUCHNICK' do
      reply(KamIRC::ERR_NOSUCHNICK, nick: 'manveru').
        to_message.should == ":host 401 target manveru :No such nick/channel"
    end

    it 'boxes ERR_NOSUCHSERVER' do
      reply(KamIRC::ERR_NOSUCHSERVER, server_name: 'someserver').
        to_message.should == ":host 402 target someserver :No such server"
    end
  end
end
