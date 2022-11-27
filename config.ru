require 'rack/session/moneta'
require './app'

use Rack::Session::Moneta do
  use :Expires
  adapter :Memory
end

run Sinatra::Application
