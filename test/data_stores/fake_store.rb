module Tickwork
  class FakeStore 
    @data_store = {}

    def get(key)
      @data_store[:key]
    end

    def set(key, value)
      @data_store[:key] = value
    end
  end
end
