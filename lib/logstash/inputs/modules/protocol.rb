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

require_relative 'ipv4header'
require_relative 'udpheader'
require_relative 'tcpheader'

class Protocol
  ICMP = 0x01
  IGMP = 0x02
  TCP  = 0x06
  UDP  = 0x11
  IPv6 = 0x29

  def self.to_class protocol
    case protocol
    when Protocol::ICMP
      raise "ICMP is not supported"
    when Protocol::IGMP
      raise "IGMP is not supported"
    when Protocol::TCP
      TCPHeader
    when Protocol::UDP
      UDPHeader
    when Protocol::IPv6
      raise "IPv6 is not supported"
    else
      raise "Protocol:"+sprintf("0x%2X",protocol)+" is not supported"
    end
  end
 
  def self.to_s protocol
    case protocol
    when Protocol::ICMP
      "ICMP"
    when Protocol::IGMP
      "IGMP"
    when Protocol::TCP
      "TCP"
    when Protocol::UDP
      "UDP"
    when Protocol::IPv6
      "IPv6"
    else
      sprintf("0x%2X",protocol)
    end
  end

end
