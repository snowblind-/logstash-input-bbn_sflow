# encoding: utf-8

#####################################################################################
# Copyright 2015 BAFFIN BAY NETWORKS
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
#
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#####################################################################################

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

class LogStash::Inputs::Sflow < LogStash::Inputs::Base
	config_name "bbn_sflow"

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
      		sflow = parse_data(client[3], payload)
      		event = LogStash::Event.new(sflow)
        	decorate(event)
       		queue << event
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


	def parse_data(host, data)
	
		header = Header.read(data)
	
		if header.version == 5
	
			if header.address_type == 1
		
				agent_address = IPAddr.new(header.agent_address, Socket::AF_INET).to_s
				@sflow = { "agent_address" => agent_address }
		
			elsif header.address_type == 2
		
				# agent_address is IPv6 nothing to do
				return @sflow

			end
		
			header.flow_samples.each do |sample|
			
				if sample.sflow_sample_type == 3 or sample.sflow_sample_type == 1
				
					sampledata = Sflow5sampleheader3.read(sample.sample_data) if sample.sflow_sample_type == 3
					sampledata = Sflow5sampleheader1.read(sample.sample_data) if sample.sflow_sample_type == 1
				
					sflow_sample = { "sampling_rate" => sampledata.sampling_rate,
						"i_iface_value" => sampledata.i_iface_value.to_i,
						"o_iface_value" => sampledata.o_iface_value.to_i }
				
					@sflow.merge!(sflow_sample)

					sampledata.records.each do |record|
					
						if record.format == 1001 # Extended Switch data
							extswitch = Sflow5extswitch.read(record.record_data)
						
							sflow_switch = { "vlan_src" => extswitch.src_vlan.to_i,
								"vlan_dst" => extswitch.dst_vlan.to_i }

							@sflow.merge!(sflow_switch)

						elsif record.format == 1 # Raw packet format

							rawpacket = Sflow5rawpacket.read(record.record_data)
						
							if rawpacket.header_protocol == 11 # Header protocol equal ethernet
							
								eth_header = Sflow5rawpacketheaderEthernet.read(rawpacket.rawpacket_data.to_ary.join)
								ip_packet = eth_header.ethernetdata.to_ary.join

								if eth_header.eth_type == 33024 # Ethernet type equal VLAN TAG
	
									vlan_header = Sflow5rawpacketdataVLAN.read(eth_header.ethernetdata.to_ary.join)
									ip_packet = vlan_header.vlandata.to_ary.join
								end
	
							
								ipv4 = IPv4Header.new(ip_packet)

								sflow_ip = { "ipv4_src" => ipv4.sndr_addr,
									"ipv4_dst" => ipv4.dest_addr }

								@sflow.merge!(sflow_ip)
							
								if ipv4.protocol == 6 #Protocol equal TCP
									sflow_frame = { "frame_length" => rawpacket.frame_length.to_i,
										"frame_length_multiplied" => rawpacket.frame_length.to_i * sflow_sample["sampling_rate"].to_i }

									@sflow.merge!(sflow_frame)
							
									header = TCPHeader.new(ipv4.data)
							
									sflow_header = { "tcp_src_port" => header.sndr_port.to_i,
										"tcp_dst_port" => header.dest_port.to_i }

									@sflow.merge!(sflow_header)

								elsif ipv4.protocol == 17 #Protocol equal UDP
												
									header = UDPHeader.new(ipv4.data)
									sflow_header = { "udp_src_port" => header.sndr_port.to_i,
									"udp_dst_port" => header.dist_port.to_i }

									@sflow.merge!(sflow_header)
								end
							end		
						end
					end
			
				elsif sample.sflow_sample_type == 4 or sample.sflow_sample_type == 2

					sampledata = Sflow5counterheader4.read(sample.sample_data) if sample.sflow_sample_type == 4
					sampledata = Sflow5counterheader2.read(sample.sample_data) if sample.sflow_sample_type == 2

					sampledata.records.each do |record|
					
						if record.format == 1
							generic_int_counter = Sflow5genericcounter.read(record.record_data)
							sflow_counter = { "i_octets" => generic_int_counter.input_octets.to_i,
								"o_octets" => generic_int_counter.output_octets.to_i,
								"interface" => generic_int_counter.int_index.to_i,
								"input_packets_error" => generic_int_counter.input_packets_error.to_i,
								"output_packets_error" => generic_int_counter.output_packets_error.to_i }

							@sflow.merge!(sflow_counter)

						elsif record.format == 2
							eth_int_counter = Sflow5ethcounter.read(record.record_data)
							@sflow
						end #if
					end # do
				end # if
			end # do
		end #if
	
		return @sflow

	end
  
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
            		"tcp_dst_port" => "sflow_tcp_dst_port"}

		prefixed_sflow = Hash[sflow.map {|k, v| [mappings[k], v] }]

		# TODO: Implement snmpwalk to get the interface name of the switch
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
