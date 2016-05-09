require File.expand_path('../../lib/tickwork', __FILE__)
require File.expand_path('../data_stores/fake_store.rb', __FILE__)
require 'minitest/autorun'
require 'mocha/mini_test'

describe Tickwork do
def self.test_order
   :alpha
end
  before do
    @log_output = StringIO.new
    Tickwork.configure do |config|
      config[:logger] = Logger.new(@log_output)
      #config[:logger] = Logger.new(STDOUT)
      config[:data_store] = Tickwork::FakeStore.new
    end
  end

  after do
    Tickwork.clear!
  end

  it 'should run events with configured logger' do
    run = false
    Tickwork.handler do |job|
      run = job == 'myjob'
    end
    Tickwork.every(1.minute, 'myjob')
    # don't know why this doesn't work with while but did with loop
    #Tickwork.manager.expects(:while).yields.then.returns
    Tickwork.run

    assert run
    assert @log_output.string.include?('Triggering')
  end

  it 'should log event correctly' do
    run = false
    Tickwork.handler do |job|
      run = job == 'an event'
    end
    Tickwork.every(1.minute, 'an event')
    # Tickwork.manager.expects(:while).yields.then.returns
    Tickwork.run
    assert run
    assert @log_output.string.include?("Triggering 'an event'")
  end

  it 'should pass event without modification to handler' do
    event_object = 'myEvent'
    run = false
    Tickwork.handler do |job|
      run = job == event_object
    end
    Tickwork.every(1.minute, event_object)
    # Tickwork.manager.expects(:while).yields.then.returns
    Tickwork.run
    assert run
  end

  it 'should not run anything after reset' do
    Tickwork.every(1.minute, 'myjob') {  }
    Tickwork.clear!
    Tickwork.configure do |config|
      config[:sleep_timeout] = 0
      config[:logger] = Logger.new(@log_output)
      config[:data_store] = Tickwork::FakeStore.new
    end
    # Tickwork.manager.expects(:while).yields.then.returns
    Tickwork.run
    assert @log_output.string.include?('0 events')
  end

  it 'should pass all arguments to every' do
    Tickwork.every(1.second, 'myjob', if: lambda { |_| false }) {  }
    # Tickwork.manager.expects(:while).yields.then.returns
    Tickwork.run
    assert @log_output.string.include?('1 events')
    assert !@log_output.string.include?('Triggering')
  end

  it 'support module re-open style' do
    $called = false
    module ::Tickwork
      every(1.second, 'myjob') { $called = true }
    end
    # Tickwork.manager.expects(:while).yields.then.returns
    Tickwork.run
    assert $called
  end
end
