module Tickwork
  class Manager
    class NoHandlerDefined < RuntimeError; end
    class DuplicateJobName < RuntimeError; end

    attr_reader :config

    def initialize
      @events = []
      @callbacks = {}
      @config = default_configuration
      @handler = nil
    end

    def thread_available?
      Thread.list.select { |t| t['creator'] == self }.count < config[:max_threads]
    end

    def configure
      yield(config)
      if config[:sleep_timeout]
        config[:logger].warn 'INCORRECT USAGE: sleep_timeout is not used'
      end
      if config[:sleep_timeout] < 1
        config[:logger].warn 'sleep_timeout must be >= 1 second'
      end
      if config[:grace_period] < 60
        config[:logger].warn 'grace_period must be >= 1 second'
      end
    end

    def default_configuration
      { :sleep_timeout => 1, grace_period: 300, :logger => Logger.new(STDOUT), :thread => false, :max_threads => 10 }
    end

    def handler(&block)
      @handler = block if block_given?
      raise NoHandlerDefined unless @handler
      @handler
    end

    def error_handler(&block)
      @error_handler = block if block_given?
      @error_handler
    end

    def on(event, options={}, &block)
      raise "Unsupported callback #{event}" unless [:before_tick, :after_tick, :before_run, :after_run].include?(event.to_sym)
      (@callbacks[event.to_sym]||=[]) << block
    end

    def every(period, job, options={}, &block)
      if options[:at].respond_to?(:each)
        every_with_multiple_times(period, job, options, &block)
      else
        register(period, job, block, options)
      end
    end

    def fire_callbacks(event, *args)
      @callbacks[event].nil? || @callbacks[event].all? { |h| h.call(*args) }
    end

    def run
      log "Starting clock for #{@events.size} events: [ #{@events.map(&:to_s).join(' ')} ]"
      loop do
        tick
        interval = config[:sleep_timeout] - Time.now.subsec + 0.001
        sleep(interval) if interval > 0
      end
    end

    def tick(t=Time.now)
      if (fire_callbacks(:before_tick))
        events = events_to_run(t)
        events.each do |event|
          if (fire_callbacks(:before_run, event, t))
            event.run(t)
            fire_callbacks(:after_run, event, t)
          end
        end
      end
      fire_callbacks(:after_tick)
      events
    end

    def log_error(e)
      config[:logger].error(e)
    end

    def handle_error(e)
      error_handler.call(e) if error_handler
    end

    def log(msg)
      config[:logger].info(msg)
    end

    private
    def events_to_run(t)
      @events.select{ |event| event.run_now?(t) }
    end

    def register(period, job, block, options)
      event = Event.new(self, period, job, block || handler, options)
      guard_duplicate_events(event)
      @events << event
      event
    end

    def guard_duplicate_events(event)
      if @events.map{|e| e.to_s }.include? event.to_s
        raise DuplicateJobName
      end
    end

    def every_with_multiple_times(period, job, options={}, &block)
      each_options = options.clone
      options[:at].each do |at|
        each_options[:at] = at
        register(period, job + '_' + at, block, each_options)
      end
    end
  end
end
