require File.expand_path('../../lib/tickwork', __FILE__)
require File.expand_path('../data_stores/fake_store.rb', __FILE__)
require 'mocha/mini_test'
require "minitest/autorun"

describe Tickwork::Event do
  describe '#thread?' do
    before do
      @manager = Class.new
      @data_store = Tickwork::FakeStore.new
    end

    describe 'manager config thread option set to true' do
      before do
        @manager.stubs(:config).returns({ :thread => true })
        @manager.stubs(:data_store).returns(@data_store)
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

    describe 'job name' do 
      before do
        @manager.stubs(:config).returns({})
      end
      it 'is required' do 
        assert_raises(Tickwork::Event::IllegalJobName) do  
          Tickwork::Event.new(@manager, nil, nil, nil)
        end
      end
      it 'must be a string' do 
        assert_raises(Tickwork::Event::IllegalJobName) do  
          Tickwork::Event.new(@manager, nil, Class.new, nil)
        end
      end
      it 'must not be empty' do 
        assert_raises(Tickwork::Event::IllegalJobName) do  
          Tickwork::Event.new(@manager, nil, '', nil)
        end
      end
      it 'raises exception on manager key name clash' do      
        assert_raises(Tickwork::Event::IllegalJobName) do  
          Tickwork::Event.new(@manager, nil, '__manager', nil)
        end
      end
    end
  end
end
