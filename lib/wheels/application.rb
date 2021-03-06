gem "rack", "~> 0.4.0"
require "rack"

require "yaml"
require "thread"

require Pathname(__FILE__).dirname + "rack/utils"
require Pathname(__FILE__).dirname + "request"
require Pathname(__FILE__).dirname + "response"
require Pathname(__FILE__).dirname + "block_io"

module Wheels
  class Application

    def self.services=(container)
      @services = container
    end

    def self.services
      @services ||= Wheels::Container.new
    end

    attr_reader :environment, :logger

    def initialize(router, environment = ENV["ENVIRONMENT"])
      @router = router
      @environment = (environment || "development").to_s
      @logger = self.class.services.get("logger") rescue nil
    end

    def default_layout
      "layouts/application"
    end

    def not_found(request, response)
      response.flush
      response.status = 404
      response.puts "The page you requested could not be found"
      [response.status, response.headers, response.buffer]
    end

    def call(env)
      env["APP_ENVIRONMENT"] = environment
      request = Request.new(self, env)
      response = Response.new(request)
      
      handler = @router.match(request)
      return not_found(request, response) if handler == false
      
      catch(:abort_request) do
        dispatch_request(handler, request, response)
      end
      
      [response.status, response.headers, response.buffer]
    end
    
    def dispatch_request(handler, request, response)
      handler.call(request, response)
    end

  end
end