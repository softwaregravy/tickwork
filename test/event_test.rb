require File.expand_path('../../lib/clockwork', __FILE__)
require 'mocha/mini_test'
require "minitest/autorun"

describe Tickwork::Event do
  describe '#thread?' do
    before do
      @manager = Class.new
    end

    describe 'manager config thread option set to true' do
      before do
        @manager.stubs(:config).returns({ :thread => true })
      end

      it 'is true' do
        event = Tickwork::Event.new(@manager, nil, 'unnamed', nil)
        assert_equal true, event.thread?
      end

      it 'is false when event thread option set' do
        event = Tickwork::Event.new(@manager, nil, 'unnamed', nil, :thread => false)
        assert_equal false, event.thread?
      end
    end

    describe 'manager config thread option not set' do
      before do
        @manager.stubs(:config).returns({})
      end

      it 'is true if event thread option is true' do
        event = Tickwork::Event.new(@manager, nil, 'unnamed', nil, :thread => true)
        assert_equal true, event.thread?
      end
    end
  end
end
