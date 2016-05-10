module Tickwork
  class Event
    class IllegalJobName < RuntimeError; end

    attr_accessor :job, :data_store_key

    def initialize(manager, period, job, block, options={})
      validate_if_option(options[:if])
      @manager = manager
      @period = period
      raise IllegalJobName unless job.is_a?(String) && !job.empty? && Tickwork::Manager::MANAGER_KEY != job
      @job = job
      @at = At.parse(options[:at])
      @block = block
      @if = options[:if]
      @thread = options.fetch(:thread, @manager.config[:thread])
      @timezone = options.fetch(:tz, @manager.config[:tz])
      namespace = options[:namespace] 
      namespace ||= '_tickwork_'
      @data_store_key = namespace + @job
    end

    def last
      @manager.data_store.read(data_store_key)
    end

    def last=(value)
      @manager.data_store.write(data_store_key, value)
    end

    def convert_timezone(t)
      @timezone ? t.in_time_zone(@timezone) : t
    end

    def run_now?(t)
      t = convert_timezone(t)
      elapsed_ready(t) and (@at.nil? or @at.ready?(t)) and (@if.nil? or @if.call(t))
    end

    def elapsed_ready(t)
      last.nil? || (t - last.to_i).to_i >= @period
    end

    def thread?
      @thread
    end

    def run(t)
      @manager.log "Triggering '#{self}'"
      self.last = convert_timezone(t)
      if thread?
        if @manager.thread_available?
          t = Thread.new do
            execute
          end
          t['creator'] = @manager
        else
          @manager.log_error "Threads exhausted; skipping #{self}"
        end
      else
        execute
      end
    end

    def to_s
      job
    end

    private
    def execute
      @block.call(@job, last)
    rescue => e
      @manager.log_error e
      @manager.handle_error e
    end

    def validate_if_option(if_option)
      if if_option && !if_option.respond_to?(:call)
        raise ArgumentError.new(':if expects a callable object, but #{if_option} does not respond to call')
      end
    end
  end
end
