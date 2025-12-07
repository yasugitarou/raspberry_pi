require 'sinatra'
require 'eventmachine'
require 'websocket-eventmachine-server'

set :server, :puma   # ← Ruby 3.4 でも安定して動く

WS_PORT = 8081
CLIENTS = []

# --- WebSocket サーバーを別スレッドで起動 ---
Thread.new do
  EM.run do
    puts "WebSocket server running on ws://localhost:#{WS_PORT}"

    WebSocket::EventMachine::Server.start(
      host: "0.0.0.0",
      port: WS_PORT
    ) do |ws|

      ws.onopen do
        CLIENTS << ws
        puts "WebSocket connected"
      end

      ws.onmessage do |msg|
        puts "WS Received: #{msg}"
        CLIENTS.each { |c| c.send(msg) }
      end

      ws.onclose do
        CLIENTS.delete(ws)
        puts "WebSocket disconnected"
      end
    end
  end
end

# --- ここから Sinatra 通常ルート ---
get '/' do
  @message = params[:message]
  erb :index
end

post '/send' do
  msg = params[:text]

  # WebSocket にも送る
  CLIENTS.each { |c| c.send(msg) }

  redirect "/?message=#{msg}"
end
