require 'rack/session/moneta'
require './app'

# set :port, 80

use Rack::Session::Moneta do
  use :Expires
  adapter :Memory
end

run Sinatra::Application
