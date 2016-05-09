module Tickwork
  class Manager
    class NoHandlerDefined < RuntimeError; end
    class NoDataStoreDefined < RuntimeError; end
    class DuplicateJobName < RuntimeError; end

    attr_reader :config

    def initialize
      @events = []
      @callbacks = {}
      @config = default_configuration
      @handler = nil
      @error_handler = nil
    end

    def thread_available?
      Thread.list.select { |t| t['creator'] == self }.count < config[:max_threads]
    end

    def configure
      yield(config)
      if config[:sleep_timeout]
        config[:logger].warn 'INCORRECT USAGE: sleep_timeout is not used'
        if config[:sleep_timeout] < 1
          config[:logger].warn 'sleep_timeout must be >= 1 second'
        end
      end
      if config[:grace_period] < 60
        config[:logger].warn 'grace_period must be >= 1 second'
      end
      if config[:data_store].nil?
        raise NoDataStoreDefined.new
      end
    end

    def default_configuration
      { 
        grace_period: 300, 
        logger: Logger.new(STDOUT), 
        thread: false, 
        max_threads: 10,
        namespace: '_tickwork_',
        tick_size: 60,
        max_ticks: 10
      }
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

    def data_store
      config[:data_store]
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

    def data_store_key
      @data_store_key ||= config[:namespace] + 'manager'
    end

      # pretty straight forward if you think about it
      # run the ticks from the last time we ran to our max
      # but don't run ticks in the future
    def run
      raise NoDataStoreDefined.new if data_store.nil?
      log "Starting clock for #{@events.size} events: [ #{@events.map(&:to_s).join(' ')} ]"

      last = last_t = data_store.get(data_store_key)
      last ||= Time.now.to_i - config[:tick_size] 

      ticks = 0
      tick_time = last + config[:tick_size]

      while ticks < config[:max_ticks] && tick_time <= Time.now.to_i do
        tick(tick_time) 
        last = tick_time
        tick_time += config[:tick_size]
        ticks += 1
      end
      data_store.set(data_store_key, last)
    end

    def tick(t=Time.now.to_i)
      t = Time.at(t) # TODO refactor below
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
      options.merge({:namespace => config[:namespace]})
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
