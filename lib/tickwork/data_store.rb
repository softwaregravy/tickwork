module Tickwork
  class DataStore

    # This is an abstract parent class, ruby style :)
    #
    # Tickwork requires a data store to record the last time events ran
    # Ideally, this would be an optimistic write, but it doesn't really matter.
    # It doesn't matter because our goal is errrs for at least once, vs. at most or exactly
    # So we run, we record that we ran. There's a chance that another process also ran at the same time
    # e.g we both read the same 'last time running'
    # In practice, this shouldn't happen unless our external ticker is called faster than our jobs can run


    # Providers should implement
    #
    # def read(key)
    #
    # end
    # 
    # def write(key, value)
    #
    # end
    #
    # note: keys will be prefixed with '_tickwork_' both for easy identification and also to 
    # help avoid conflicts with the rest of the app
    #
    # Keen observers will note that this interface is compatible with ActiveSupport::Cache::Store. So you should
    # be able to just drop an instance of Store in and be ready to go. Preferably with a cache expiration time
    # longer than your max_catchup value

  end
end
