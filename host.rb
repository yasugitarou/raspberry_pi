require 'eventmachine'
require 'websocket-eventmachine-server'

clients = []

EM.run do
  puts "WebSocket server running on ws://localhost:8081"

  WebSocket::EventMachine::Server.start(host: "0.0.0.0", port: 8080) do |ws|
    ws.onopen do
      clients << ws
      puts "Client connected"
    end

    ws.onmessage do |msg|
      puts "Received: #{msg}"

      # 接続中の全クライアントへ送信
      clients.each { |c| c.send(msg) }
    end

    ws.onclose do
      clients.delete(ws)
      puts "Client disconnected"
    end
  end
end
