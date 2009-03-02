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

    class InvalidCSRFToken < Exception; end

    ##
    # Setter for anti-CSRF token to be used by form helper, and
    # verified when requests are parsed.
    ##
    def self.csrf_token=(token)
      @@csrf_token = token
    end

    ##
    # Getter for anti-CSRF token. Defaults to MD5 digest of `uname -a`,
    # i.e., a machine-specific non-guessable value.
    ##
    def self.csrf_token
      @@csrf_token
    rescue NameError
      require 'digest/md5'
      Digest::MD5.hexdigest(`uname -a`.chomp)
    end

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

      if request.request_method != "GET" && request.csrf_token != self.class.csrf_token
        raise InvalidCSRFToken.new("CSRF token (#{request.csrf_token.inspect}) does not match Wheels::Application.csrf_token (#{self.class.csrf_token.inspect})")
      end

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