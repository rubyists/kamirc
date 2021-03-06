require_relative '../../lib/kamirc/parser'

require 'bacon'
Bacon.summary_on_exit

describe KamIRC::MessageParser do
  parser = KamIRC::MessageParser.new

  it 'parses nickname' do
    parser.nickname.parse('a').should == 'a'
    parser.nickname.parse('manveru').should == 'manveru'

    lambda{
      parser.nickname.parse('somethingtoolongtofit')
    }.should.raise(Parslet::ParseFailed).
      message.should == "Don't know what to do with ofit at line 1 char 18."
  end

  it 'parses user' do
    parser.user.parse("~manveru").should == '~manveru'
  end

  it 'parses host' do
    parser.host.parse('b08s28ur.corenetworks.net').should == 'b08s28ur.corenetworks.net'
  end

  it 'parses hostname' do
    parser.hostname.parse('calvino.freenode.net').should == 'calvino.freenode.net'
  end

  it 'parses prefix user' do
    parser.prefix.parse("manveru!~manveru@b08s28ur.corenetworks.net").should == {
      user: "manveru!~manveru@b08s28ur.corenetworks.net"
    }
  end

  it 'parses prefix server' do
    parser.prefix.parse("calvino.freenode.net").should == {
      server: "calvino.freenode.net"
    }
  end

  it 'parses prefix_server' do
    parser.prefix_server.parse("calvino.freenode.net").should == "calvino.freenode.net"
  end

  it 'parses prefix_user' do
    parser.prefix_user.parse("bougyman!bougyman@pdpc/supporter/gold/bougyman").should == "bougyman!bougyman@pdpc/supporter/gold/bougyman"
  end
end

describe KamIRC::Message do
  def parse(str)
    parser = KamIRC::Message.new
    parser.parse(str)
  rescue Parslet::ParseFailed => error
    puts
    puts error, parser.root.error_tree
    raise(error)
  end

  it 'parses PASS' do
    msg = parse("PASS something")
    msg.should == {
      cmd: 'PASS',
      params: ['something'],
    }
  end

  it 'parses NICK' do
    msg = parse('NICK someone')
    msg.should == {
      cmd: 'NICK',
      params: ['someone'],
    }
  end

  it 'parses USER' do
    msg = parse('USER someone 0 * :Someone Else')
    msg.should == {
      cmd: 'USER',
      params: ['someone', '0', '*', 'Someone Else'],
    }
  end

  it 'parses PING' do
    msg = parse("PING :calvino.freenode.net")
    msg.should == {
      cmd: 'PING',
      params: ['calvino.freenode.net']
    }
  end

  it 'parses MODE' do
    msg = parse(":manverbot!bot@iota MODE manverbot :+i")
    msg.should == {
      user: "manverbot!bot@iota",
      cmd: 'MODE',
      params: ["manverbot", "+i"]
    }
  end

  it 'parses NOTICE' do
    msg = parse(":pratchett.freenode.net NOTICE * :*** Looking up your hostname...")

    msg[:server].should == "pratchett.freenode.net"
    msg[:cmd].should == 'NOTICE'
    msg[:params].should == ['*', "*** Looking up your hostname..."]
  end

  it 'parses 001 RPL_WELCOME' do
    msg = parse(":hitchcock.freenode.net 001 manverbot :Welcome to the freenode Internet Relay Chat Network manverbot")
    msg.should == {
      server: "hitchcock.freenode.net",
      cmd: "001",
      params: [
        "manverbot",
        "Welcome to the freenode Internet Relay Chat Network manverbot"
      ]
    }
  end

  it 'parses 002 RPL_YOURHOST' do
    msg = parse(":asimov.freenode.net 002 manverbot :Your host is asimov.freenode.net[174.143.119.91/6667], running version ircd-seven-1.0.3")
    msg.should == {
      server: "asimov.freenode.net",
      cmd: "002",
      params: [
        "manverbot",
        "Your host is asimov.freenode.net[174.143.119.91/6667], running version ircd-seven-1.0.3"
      ]
    }
  end

  require 'pp'

  it 'parses 003 RPL_CREATED' do
    msg = parse(":gibson.freenode.net 003 manverbot :This server was created Wed Feb 24 2010 at 00:05:12 CET")
    msg.should == {
      server: "gibson.freenode.net",
      cmd: "003",
      params: ["manverbot", "This server was created Wed Feb 24 2010 at 00:05:12 CET"]
    }
  end

  it 'parses PRIVMSG' do
    msg = parse(":manveru!~manveru@b08s28ur.corenetworks.net PRIVMSG manverbot :just a little test")

    msg.should == {
      user: "manveru!~manveru@b08s28ur.corenetworks.net",
      cmd: "PRIVMSG",
      params: ["manverbot", "just a little test"]
    }

    # Message from Angel to Wiz.
    parse(":Angel!wings@irc.org PRIVMSG Wiz :Are you receiving this message ?").should == {
      user: "Angel!wings@irc.org",
      cmd: "PRIVMSG",
      params: ["Wiz", "Are you receiving this message ?"]
    }

    # Command to send a message to Angel.
    parse("PRIVMSG Angel :yes I'm receiving it !").should == {
      cmd: "PRIVMSG",
      params: ["Angel", "yes I'm receiving it !"]
    }

    # Command to send a message to a user on server tolsun.oulu.fi with
    # username of "jto".
    parse("PRIVMSG jto@tolsun.oulu.fi :Hello !").should == {
      cmd: "PRIVMSG",
      params: ["jto@tolsun.oulu.fi", "Hello !"]
    }

    # Message to a user on server irc.stealth.net with username of "kalt",
    # and connected from the host millennium.stealth.net.
    parse("PRIVMSG kalt%millennium.stealth.net@irc.stealth.net :Are you a frog?").should == {
      cmd: "PRIVMSG",
      params: ["kalt%millennium.stealth.net@irc.stealth.net", "Are you a frog?"]
    }

    # Message to a user on the local server with username of "kalt", and
    # connected from the host millennium.stealth.net.
    parse("PRIVMSG kalt%millennium.stealth.net :Do you like cheese?").should == {
      cmd: "PRIVMSG",
      params: ["kalt%millennium.stealth.net", "Do you like cheese?"]
    }

    # Message to the user with nickname Wiz who is connected from the host
    # tolsun.oulu.fi and has the username "jto".
    parse("PRIVMSG Wiz!jto@tolsun.oulu.fi :Hello !").should == {
      cmd: "PRIVMSG",
      params: ["Wiz!jto@tolsun.oulu.fi", "Hello !"]
    }

    # Message to everyone on a server which has a name matching *.fi.
    parse("PRIVMSG $*.fi :Server tolsun.oulu.fi rebooting.").should == {
      cmd: "PRIVMSG",
      params: ["$*.fi", "Server tolsun.oulu.fi rebooting."]
    }

    # Message to all users who come from a host which has a name matching *.edu.
    parse("PRIVMSG #*.edu :NSFNet is undergoing work, expect interruptions").should == {
      cmd: "PRIVMSG",
      params: ["#*.edu", "NSFNet is undergoing work, expect interruptions"]
    }

    parse(":bougyman!bougyman@pdpc/supporter/gold/bougyman PRIVMSG #rubyists :hello there").should == {
      user: "bougyman!bougyman@pdpc/supporter/gold/bougyman",
      cmd: "PRIVMSG",
      params: ["#rubyists", "hello there"]
    }

    parse("PRIVMSG #foo :hi").should == {
      cmd: 'PRIVMSG',
      params: ['#foo', 'hi'],
    }
  end

  it 'parses 004 RPL_MYINFO' do
    msg = parse(":gibson.freenode.net 004 manverbot gibson.freenode.net ircd-seven-1.0.3 DOQRSZaghilopswz CFILMPQbcefgijklmnopqrstvz bkloveqjfI")
    msg.should == {
      server: "gibson.freenode.net",
      cmd: "004",
      params: [
        "manverbot",
        "gibson.freenode.net",
        "ircd-seven-1.0.3",
        "DOQRSZaghilopswz",
        "CFILMPQbcefgijklmnopqrstvz",
        "bkloveqjfI"
      ]
    }
  end

  it 'parses 005 RPL_ISUPPORT (partially)' do
    msg = parse(":jordan.freenode.net 005 manverbot CHANTYPES=# EXCEPTS INVEX CHANMODES=eIbq,k,flj,CFLMPQcgimnprstz CHANLIMIT=#:120 PREFIX=(ov)@+ MAXLIST=bqeI:100 MODES=4 NETWORK=freenode KNOCK STATUSMSG=@+ CALLERID=g :are supported by this server",)
    msg.should == {
      server: "jordan.freenode.net",
      cmd: "005",
      params: [
        "manverbot",
        "CHANTYPES=#",
        "EXCEPTS",
        "INVEX",
        "CHANMODES=eIbq,k,flj,CFLMPQcgimnprstz",
        "CHANLIMIT=#:120",
        "PREFIX=(ov)@+",
        "MAXLIST=bqeI:100",
        "MODES=4",
        "NETWORK=freenode",
        "KNOCK",
        "STATUSMSG=@+",
        "CALLERID=g",
        "are supported by this server"
      ]
    }
  end

  it 'parses 251 RPL_LUSERCLIENT' do
    msg = parse(":jordan.freenode.net 251 manverbot :There are 362 users and 58364 invisible on 24 servers")
    msg.should == {
      server: "jordan.freenode.net",
      cmd: "251",
      params: ["manverbot", "There are 362 users and 58364 invisible on 24 servers"]
    }
  end

  it 'parses 252 RPL_LUSEROP' do
    msg = parse(":jordan.freenode.net 252 manverbot 26 :IRC Operators online")
    msg.should == {
      server: "jordan.freenode.net",
      cmd: "252",
      params: ["manverbot", "26", "IRC Operators online"]
    }
  end

  it 'parses 253 RPL_LUSERUNKNOWN' do
    msg = parse(":jordan.freenode.net 253 manverbot 8 :unknown connection(s)")
    msg.should == {
      server: "jordan.freenode.net",
      cmd: "253",
      params: ["manverbot", "8", "unknown connection(s)"]
    }
  end

  it 'parses 254 RPL_LUSERCHANNELS' do
    msg = parse(":jordan.freenode.net 254 manverbot 36171 :channels formed")
    msg.should == {
      server: "jordan.freenode.net",
      cmd: "254",
      params: ["manverbot", "36171", "channels formed"]
    }
  end

  it 'parses 255 RPL_LUSERME' do
    msg = parse(":jordan.freenode.net 255 manverbot :I have 7480 clients and 1 servers")
    msg.should == {
      server: "jordan.freenode.net",
      cmd: "255",
      params: ["manverbot", "I have 7480 clients and 1 servers"]
    }
  end

  it 'parses 265' do
    msg = parse(":asimov.freenode.net 265 manverbot 5452 5452 :Current local users 5452, max 5452")
    msg.should == {
      server: "asimov.freenode.net",
      cmd: "265",
      params: ["manverbot", "5452", "5452", "Current local users 5452, max 5452"]
    }
  end

  it 'parses 266' do
    msg = parse(":asimov.freenode.net 266 manverbot 60906 67207 :Current global users 60906, max 67207")
    msg.should == {
      server: "asimov.freenode.net",
      cmd: "266",
      params: ["manverbot", "60906", "67207", "Current global users 60906, max 67207"]
    }
  end

  it 'parses 402 ERR_NOSUCHSERVER' do
    msg = parse(":sendak.freenode.net 402 manverbot b08s28ur.corenetworks.net :No such server")
    msg.should == {
      server: "sendak.freenode.net",
      cmd: "402",
      params: ["manverbot", "b08s28ur.corenetworks.net", "No such server"]
    }
  end

  it 'parses JOIN' do
    msg = parse(":manverbot!bot@iota JOIN :#rubyists")
    msg.should == {
      user: "manverbot!bot@iota",
      cmd: "JOIN",
      params: ["#rubyists"]
    }
  end

  it 'parses multiple JOIN' do
    msg = parse(":manverbot!bot@iota JOIN :#rubyists,#ramaze")
    msg.should == {
      user: "manverbot!bot@iota",
      cmd: "JOIN",
      params: ["#rubyists,#ramaze"]
    }
  end

  it 'parses JOIN with a key' do
    msg = parse(":manverbot!bot@iota JOIN :#rubyists foo")
    msg.should == {
      user: "manverbot!bot@iota",
      cmd: "JOIN",
      params: ["#rubyists foo"]
    }
  end

  it 'parses multiple JOIN with a key' do
    msg = parse(":manverbot!bot@iota JOIN :#rubyists,#ramaze foo")
    msg.should == {
      user: "manverbot!bot@iota",
      cmd: "JOIN",
      params: ["#rubyists,#ramaze foo"]
    }
  end

  it 'parses multiple JOIN with keys' do
    msg = parse(":manverbot JOIN :#rubyists,#ramaze foo,bar")
    msg.should == {
      server: "manverbot",
      cmd: "JOIN",
      params: ["#rubyists,#ramaze foo,bar"]
    }
  end

  it 'parses 331 RPL_NOTOPIC' do
    msg = parse(":calvino.freenode.net 331 manverbot #rubyists :No topic is set")
    msg.should == {
      server: "calvino.freenode.net",
      cmd: "331",
      params: ["manverbot", "#rubyists", "No topic is set"]
    }
  end

  it 'parses 332 RPL_TOPIC' do
    msg = parse(":calvino.freenode.net 332 manverbot #rubyists :http://github.com/bougyman/freeswitcher | http://github.com/rubyists/tiny_call_center/wiki")
    msg.should == {
      server: "calvino.freenode.net",
      cmd: "332",
      params: [
        "manverbot",
        "#rubyists",
        "http://github.com/bougyman/freeswitcher | http://github.com/rubyists/tiny_call_center/wiki"
      ]
    }
  end

  it 'parses 333 RPL_TOPIC_TIME' do
    msg = parse(":calvino.freenode.net 333 manverbot #rubyists bougyman!bougyman@pdpc/supporter/gold/bougyman 1298303043")
    msg.should == {
      server: "calvino.freenode.net",
      cmd: "333",
      params: [
        "manverbot",
        "#rubyists",
        "bougyman!bougyman@pdpc/supporter/gold/bougyman",
        "1298303043"
      ]
    }
  end

  it 'parses 353 RPL_NAMREPLY' do
    msg = parse(":calvino.freenode.net 353 manverbot = #rubyists :manverbot swk jShaf lele erikh bougyman manveru @ChanServ thedonvaughn wmoxam khaase Death_Syn misua")
    msg.should == {
      server: "calvino.freenode.net",
      cmd: "353",
      params: [
        "manverbot",
        "=",
        "#rubyists",
        "manverbot swk jShaf lele erikh bougyman manveru @ChanServ thedonvaughn wmoxam khaase Death_Syn misua"
      ]
    }
  end

  it 'parses 366 RPL_ENDOFNAMES' do
    msg = parse(":calvino.freenode.net 366 manverbot #rubyists :End of /NAMES list.")
    msg.should == {
      server: "calvino.freenode.net",
      cmd: "366",
      params: ["manverbot", "#rubyists", "End of /NAMES list."]
    }
  end
end
