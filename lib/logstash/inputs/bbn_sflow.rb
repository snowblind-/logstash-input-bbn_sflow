# Logstash specific dependencies
require "logstash/inputs/base"
require "logstash/namespace"

# Other dependencies
require "bindata"
require "socket"
require "ipaddr"
require "json"
require "date"
require "concurrent_ruby"


##########################################################################################
# This plugin is written by Baffin Bay Networks and are being used for
# receiving and parsing sflow data.
#
# Author: Joakim Sundberg
# Email: joakim.sundberg@baffinbaynetworks.com
# Copyright Baffin Bay Networks
##########################################################################################

class LogStash::Inputs::Sflow < LogStash::Inputs::Base
	config_name "bbn_sflow"

	milestone 1
	default :codec, "plain"
  
  	######################################################################################
  	# This section lists the configurable parameters for this plugin.
  	######################################################################################
	# IP address to bind to the sflow collector
	config :sflow_collector_ip, :validate => :string, :default => "0.0.0.0"
	
	# Port to bind to the sflow collector  
	config :sflow_collector_port, :validate => :number, :default => 6343
	
	# Allowed sflow agents to send sflow data to slfow colelctor, default any
	#config :sflow_agents, :validate => :string, :default => "0.0.0.0"
	
	# Timezone string defaults to "UTC" = +00.00
	config :timezone, :validate => :string

	public
  	def initialize(params)
    	super
    	
    	@shutdown_requested = Concurrent::AtomicBoolean.new(false)
    	BasicSocket.do_not_reverse_lookup = true
  	
  	end

	public
	def register

		require "logstash/inputs/modules/binary"
		require "logstash/inputs/modules/protocol"
		require "logstash/inputs/modules/ipv4header"
		require "logstash/inputs/modules/tcpheader"
		require "logstash/inputs/modules/udpheader"

    	@udp = nil
	
	end

	def run(queue)
    	udp_thread = Thread.new(queue) do |queue|
      		server(:udp, queue)
    	end

    	udp_thread.join
      
  	end
  	
  	private
  	def server(protocol, queue)
    	self.send("#{protocol}_listener", queue)
  	
  	rescue => e
    	
    	if @shutdown_requested.false?
      		@logger.warn("listener died",
      			:protocol => protocol,
      			:address => "#{@sflow_collector_ip}:#{@sflow_collector_port}",
      			:exception => e,
      			:backtrace => e.backtrace)
      		
      		sleep(5)
      		
      		retry
    	
    	end
	
	end
	
	private
  	def udp_listener(queue)
    	@logger.info("Starting bbn_sflow collector ", :address => "#{@sflow_collector_ip}:#{@sflow_collector_port}")

    	@udp.close if @udp
    	@udp = UDPSocket.new(Socket::AF_INET)
    	@udp.bind(@sflow_collector_ip, @sflow_collector_port)

    	while true
      		payload, client = @udp.recvfrom(9000)
      		sflow = Parser.parse_data(client[3], payload)
      		json_sflow << sflow_to_json(sflow)
      		queue << json_sflow
    	end
  	
  	ensure
    	
    	close_udp
  
	end
  
  	public
  	def teardown
    	
    	@shutdown_requested.make_true
    	close_udp
    	finished
  
  	end

  	private
  	def close_udp
    
    	if @udp
      		@udp.close_read rescue nil
      		@udp.close_write rescue nil
    	end # if
    	
    	@udp = nil
    
  	end # def
  
	def sflow_to_json(sflow)
	
		mappings = {"agent_address" => "sflow_agent_address",
			"sampling_rate" => "sflow_sampling_rate",
			"i_iface_value" => "sflow_i_iface_value",
			"o_iface_value" => "sflow_o_iface_value",
			"vlan_src" => "sflow_vlan_src",
            "vlan_dst" => "sflow_vlan_dst",
            "ipv4_src" => "sflow_ipv4_src",
            "ipv4_dst" => "sflow_ipv4_dst",
            "frame_length" => "sflow_frame_length",
            "frame_length_multiplied" => "sflow_frame_length_multiplied",
            "tcp_src_port" => "sflow_tcp_src_port",
            "tcp_dst_port" => "sflow_tcp_dst_port"
      	}

		prefixed_sflow = Hash[sflow.map {|k, v| [mappings[k], v] }]

      	#if sflow['i_iface_value'] and sflow['o_iface_value']
        
        #	i_iface_name = { "sflow_i_iface_name" => SNMPwalk.mapswitchportname(sflow['agent_address'],
        #		sflow['i_iface_value']) }
        	
        #	o_iface_name = { "sflow_o_iface_name" => SNMPwalk.mapswitchportname(sflow['agent_address'],
        #		sflow['o_iface_value']) }
        	
        #	prefixed_sflow.merge!(i_iface_name)
        	
        #	prefixed_sflow.merge!(o_iface_name)
      	
      	#end

      	return prefixed_sflow.to_json

	end
	
end # class LogStash::Inputs::Sflow
