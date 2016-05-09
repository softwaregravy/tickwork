module Tickwork
  class FakeStore 

    def initialize
      @data_store = {}
    end

    def get(key)
      @data_store[:key]
    end

    def set(key, value)
      @data_store[:key] = value
    end
  end
end
