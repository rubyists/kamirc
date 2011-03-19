require_relative '../../lib/kamirc/parser'
require_relative '../../lib/kamirc/box'

require 'bacon'
Bacon.summary_on_exit

describe KamIRC::Box do
  parser = KamIRC::MessageParser.new

  def parse(str)
    parser = KamIRC::Message.new
    parser.parse(str)
  rescue Parslet::ParseFailed => error
    puts
    puts error, parser.root.error_tree
    raise(error)
  end

  it 'boxes NOTICE' do
    msg = parse(":pratchett.freenode.net NOTICE * :*** Looking up your hostname...")
    box = KamIRC::Box::Notice.from_message(msg)
    box.from.should == {hostname: 'pratchett.freenode.net'}
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
end
