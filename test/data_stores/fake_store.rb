module Tickwork
  class FakeStore 

    def initialize
      @data_store = {}
    end

    def get(key)
      @data_store[key]
    end

    def set(key, value)
      @data_store[key] = value
    end

    # not part of the interface but used for testing
    def size
      @data_store.size
    end
  end
end
