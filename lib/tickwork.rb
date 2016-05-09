require 'logger'
require 'active_support/time'

require 'tickwork/at'
require 'tickwork/event'
require 'tickwork/manager'

module Tickwork
  class << self
    def included(klass)
      klass.send "include", Methods
      klass.extend Methods
    end

    def manager
      @manager ||= Manager.new
    end

    def manager=(manager)
      @manager = manager
    end
  end

  module Methods
    def configure(&block)
      Tickwork.manager.configure(&block)
    end

    def handler(&block)
      Tickwork.manager.handler(&block)
    end

    def error_handler(&block)
      Tickwork.manager.error_handler(&block)
    end

    def on(event, options={}, &block)
      Tickwork.manager.on(event, options, &block)
    end

    def every(period, job, options={}, &block)
      Tickwork.manager.every(period, job, options, &block)
    end

    def run
      Tickwork.manager.run
    end

    def clear!
      Tickwork.manager = Manager.new
    end
  end

  extend Methods
end
