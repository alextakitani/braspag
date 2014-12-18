module Braspag
  class Poster
    def initialize(url)
      @request = ::HTTPI::Request.new(url)
    end

    def do_post(method, data)
      @request.body = data
      configure_request

      with_logger(method) do
        ::HTTPI.post @request
      end
    end

    private

    def configure_request
      proxy_address = Braspag.proxy_address
      open_timeout = Braspag.http_global_options[:open_timeout]
      read_timeout = Braspag.http_global_options[:read_timeout]

      @request.proxy = proxy_address if proxy_address
      @request.open_timeout = open_timeout if open_timeout
      @request.read_timeout = read_timeout if read_timeout
    end

    def with_logger(method)
      if Braspag::logger
        Braspag::logger.info("[Braspag] ##{method}: #{@request.url}, data: #{mask_data(@request.body).inspect}")
        response = yield
        Braspag::logger.info("[Braspag] ##{method} returns: #{response.body.inspect}")
      else
        response = yield
      end
      response
    end

    def mask_data(data)
      copy_data = Rack::Utils.parse_nested_query(data)
      copy_data['cardNumber'] = "************%s" % copy_data['cardNumber'][-4..-1] if copy_data['cardNumber']
      copy_data['securityCode'] = "***" if copy_data['securityCode']
      copy_data
    end
  end
end
