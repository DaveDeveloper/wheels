require "stringio"
require Pathname(__FILE__).dirname + "view"

module Wheels
  class Response

    attr_accessor :status, :content_type, :headers

    def initialize(request)
      @request = request
      @headers = {}
      @content_type = "text/html"
      @status = 200
    end

    def headers
      @headers.merge!({
        "Content-Type" => self.content_type,
        "Content-Length" => self.size.to_s
      })
      @headers
    end
    
    def flush
      @io = nil
    end
    
    def size
      buffer.size
    end

    def puts(value)
      string.puts(value)
    end
    
    def print(value)
      string.print(value)
    end
    
    def buffer
      if @io.is_a?(StringIO)
        @io.string
      else
        @io || ""
      end
    end
    
    def send_file(name, path, content_type = Rack::File::MIME_TYPES.fetch(File.extname(path)[1..-1], "binary/octet-stream"))
      if @request.env.has_key?("HTTP_X_SENDFILE_TYPE")
        @headers["X-Sendfile"] = path.to_s
        @headers["Content-Length"] = File.size(path)
      else
        @io = BlockIO.new(path)
        @headers["Content-Length"] = @io.size
      end
      @headers["Content-Disposition"] = "attachment; filename=\"#{name}\""
      @content_type = content_type
      nil
    end
    
    def render(view, context = {})

      layout = nil

      unless view.is_a?(View)
        layout = context.fetch(:layout, @request.layout) unless @request.xhr?
        view = View.new(view, context.merge({ :request => @request }))
      end

      self.content_type = view.content_type
      puts view.to_s(layout)
    end

    def redirect(url, params = nil)
      self.status = 303
      self.headers = { "Location" => (params ? "#{url}?#{Rack::Utils::build_query(params)}" : url) }
      self.flush
      self
    end
    
    def redirect!(url, params = nil)
      redirect(url, params) and throw(:abort_request)
    end

    def unauthorized
      self.status = 401
    end

    def unauthorized!
      unauthorized and throw(:abort_request)
    end

    def inspect
      "<#{self.class} headers=#{headers.inspect} content_type=#{content_type.inspect} status=#{status.inspect} body=#{buffer.inspect}>"
    end
    
    private
    def string
      @io ||= StringIO.new("")
    end

  end
end