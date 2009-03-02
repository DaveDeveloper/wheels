require "helper"

class ApplicationTest < Test::Unit::TestCase

  def setup
    @router = Wheels::Router.new do
      get("/") {}
      post("/") {}
    end
  end

  def test_csrf_protection
    app = Wheels::Application.new(@router)
    env = { "PATH_INFO" => "/", "REQUEST_METHOD" => "POST" }

    assert_raises(Wheels::Application::InvalidCSRFToken) do
      app.call(env)
    end

    assert_nothing_raised do
      app.call(Rack::MockRequest.env_for("/", :method => "POST", :input => "_csrf_token=#{Wheels::Application.csrf_token}"))
    end
  end
end