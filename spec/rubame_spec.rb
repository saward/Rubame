require 'spec_helper'

describe Rubame::Server do
  it 'should create a new server' do
    server = Rubame::Server.new("0.0.0.0", 29929)
    server.class.should == Rubame::Server
    server.stop
  end

  it 'should receive a new client connecting' do
    server = Rubame::Server.new("0.0.0.0", 29929)

    client = TCPSocket.new 'localhost', 29929
    handshake = WebSocket::Handshake::Client.new(:url => 'ws://127.0.0.1:29929')
    client.write handshake.to_s
    connected = false

    server.run do |client|
      client.onopen do
        connected = true
      end
    end
    connected.should == true

    server.stop
  end

  it 'should send handshake replies to 10 clients' do
    server = Rubame::Server.new("0.0.0.0", 29929)

    clients = {}
    finished = false

    Thread.new do
      while server
        server.run
      end
    end

    10.times do
      client = TCPSocket.new 'localhost', 29929
      handshake = WebSocket::Handshake::Client.new(:url => 'ws://127.0.0.1:29929')
      clients[client] = handshake
      client.write handshake.to_s
      while line = client.gets
        handshake << line
        break if handshake.finished?
      end
      handshake.finished?.should == true
    end

    clients.each do |s, h|
      s.close
    end
    server.stop
    server = nil
    finished = true
  end

  it 'should be able to send a message to a client' do
    server = Rubame::Server.new("0.0.0.0", 29929)

    finished = false

    Thread.new do
      while server
        server.run do |client|
          client.onopen do
            client.send "Tester"
          end
        end
      end
    end

    client = TCPSocket.new 'localhost', 29929
    handshake = WebSocket::Handshake::Client.new(:url => 'ws://127.0.0.1:29929')
    client.write handshake.to_s
    while line = client.gets
      handshake << line
      break if handshake.finished?
    end
    handshake.finished?.should == true

    frame = WebSocket::Frame::Incoming::Client.new(:version => handshake)
    waiting = true
    while waiting
      r, w = IO.select([client], [], nil, 0)
      if r
        r.each do |s|
          pairs = client.recvfrom(20000)
          frame << pairs[0]
          # puts frame.next
          waiting = false
        end
      end
    end

    (/Tester/ =~ frame.to_s).should > 0

    client.close
    server.stop
    server = nil
    finished = true
  end
end
