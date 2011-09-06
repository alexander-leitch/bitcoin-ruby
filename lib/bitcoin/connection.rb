require 'socket'
require 'eventmachine'
require 'bitcoin'

module Bitcoin

  module ConnectionHandler
    def hth(h); h.unpack("H*")[0]; end
    def htb(h); [h].pack("H*"); end

    def on_inv_transaction(hash)
      p ['inv transaction', hth(hash)]
      pkt = Protocol.getdata_pkt(:tx, [hash])
      send_data(pkt)
    end

    def on_inv_block(hash)
      p ['inv block', hth(hash)]
      pkt = Protocol.getdata_pkt(:block, [hash])
      send_data(pkt)
    end

    def on_get_transaction(hash)
      p ['get transaction', hth(hash)]
    end

    def on_get_block(hash)
      p ['get block', hth(hash)]
    end

    def on_addr(addr)
      p ['addr', addr, addr.alive?]
    end

    def on_tx(tx)
      p ['tx', tx.hash]
    end

    def on_block(block)
      p ['block', block.hash]
      #p block.payload.each_byte.map{|i| "%02x" % [i] }.join(" ")
      #puts block.to_json
    end

    def on_version(payload)
      p [@sockaddr, 'version']
      send_data( Protocol.verack_pkt )
    end

    def on_handshake_complete
      p [@sockaddr, 'handshake complete']
      @connected = true

      #query_blocks
    end

    def query_blocks
      start = ("\x00"*32)
      stop  = ("\x00"*32)
      pkt = Protocol.pkt("getblocks", "\x00" + start + stop )
      send_data(pkt)
    end

    def on_handshake_begin
      block   = 127953
      from    = "127.0.0.1:8333"
      from_id = Bitcoin::Protocol::Uniq
      to      = @sockaddr.reverse.join(":")
      # p "==", from_id, from, to, block
      pkt = Protocol.version_pkt(from_id, from, to, block)
      p ['sending version pkt', pkt]
      send_data(pkt)
    end
  end


  class Connection < EM::Connection
    include ConnectionHandler

    def initialize(host, port, connections)
      @sockaddr = [port, host]
      @connections = connections
      @parser = Bitcoin::Protocol::Parser.new( self )
    end

    def post_init
      p ['connected', @sockaddr]
      EM.schedule{ on_handshake_begin }
    end

    def receive_data(data)
      @parser.parse(data)
    end

    def unbind
      p ['disconnected', @sockaddr]
    end

    def self.connect(host, port, connections)
      EM.connect(host, port, self, host, port, connections)
    end

    def self.connect_random_from_dns(connections)
      host = `nslookup bitseed.xf2.org`.scan(/Address\: (.+)$/).flatten.sample
      connect(host, 8333, connections)
    end
  end
end


if $0 == __FILE__
  EM.run do

    connections = []
    #Bitcoin::Connection.connect('127.0.0.1', 8333, connections)
    #Bitcoin::Connection.connect('217.157.1.202', 8333, connections)
    Bitcoin::Connection.connect_random_from_dns(connections)

  end
end
