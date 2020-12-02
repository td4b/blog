---
layout: post
title: HTTP New Decoding Methods.
date: 2018-09-01
---
# HTTP New Decoding Methods.

As mentioned in the previous post. We need to be able to filter out the TCP streams from our HTTP streams, and then implement a more efficient way to decode the packet data.

We need to filter the TCP data by flagging our TCP options.

Since data is being pushed through the TCP stream, we need to filter by the packet flags (TCP options) as they are set.

Even though we have defined a filter criteria in our packet capture, we still need to filter out some of the raw TCP packets. We can use the TCP flags in the payload (PSH,ACK) in order to inspect the specific HTTP streams. With this we can additionally filter the HTTP methods we want to look at in the Requests such as (GET, PUT, POST).

We apply the some logic to filter the payload data based on this simple TCP flag.

```go
if tcp.PSH == true && tcp.ACK == true {
   fmt.Println(string(ipv4.Payload))
}
```

As well, we implemented a function to parse the HTTP methods we are interested in.

```go
func http_methods(data string) bool {
	val := false
	methods := []string{"GET","PUT","POST"}
	for _, httpmsg := range methods {
		if strings.Contains(strings.Split(string(data),"\n")[0],httpmsg) == true {
			val = true
		}
	}
	return val
}
```

In order to decode more efficiently the method ```go gopacket.NewDecodingLayerParser()``` was implemented and now our source code looks like ->


```go
package main

import (
	"fmt"
	"github.com/google/gopacket"
	"github.com/google/gopacket/layers"
	"github.com/google/gopacket/pcap"
	"strings"
)

func http_methods(data string) bool {
	val := false
	methods := []string{"GET","PUT","POST"}
	for _, httpmsg := range methods {
		if strings.Contains(strings.Split(string(data),"\n")[0],httpmsg) == true {
			val = true
		}
	}
	return val
}

func main() {

	// decoder objects
	var ipv4 layers.IPv4
	var eth layers.Ethernet
	var tcp layers.TCP

	// Device Handler
	handle, err := pcap.OpenLive("ens33", 1600, true, pcap.BlockForever)
	if err != nil {
   	panic(err)
	}

	// Packet Decoder.
	packetSource := gopacket.NewPacketSource(handle, handle.LinkType())
	parser := gopacket.NewDecodingLayerParser(layers.LayerTypeEthernet, &eth, &ipv4, &tcp)
	decoded := []gopacket.LayerType{}
	for packet := range packetSource.Packets() {
		_ = parser.DecodeLayers(packet.Data(), &decoded)
		if tcp.PSH == true && tcp.ACK == true {
			if http_methods(string(ipv4.Payload)) == true {
				payload := string(ipv4.Payload)[20:]
				fmt.Println(payload)
			}
		} else {
			fmt.Println("### Encrypted Alert ###", string(ipv4.Payload))
		}
	}
	defer handle.Close()
}
```

Notice that now we are getting live packets off the wire e.g. the *pcap.handle is a pointer to our ens33 Ethernet NIC.

This is probably not the best, nor the most efficient way to be handling HTTP data. Lets use GoLangs native HTTP libraries for parsing our HTTP headers, that way we can focus on the metadata.

```bash
GET /capstats/bpf.html HTTP/1.1
Host: yawp.biot.com
Connection: keep-alive
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9
```bash

```bash
GET /site.css HTTP/1.1
Host: yawp.biot.com
Connection: keep-alive
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)
Accept: text/css,*/*;q=0.1
Referer: http://yawp.biot.com/capstats/bpf.html
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9
```

At this point, we have what we need from a formatting perspective for the raw HTTP metadata. However, we have a problem. What if we want to peel open the session of a HTTPS packet? Notice we added ```fmt.Println("### Encrypted Alert ###", string(ipv4.Payload))``` as an else statement that is triggered if the HTTP methods are not found in the payload.

This will be true if the payload is encrypted which as can be seen below, even a simple HTTP webpage may have embedded SSL/TLS elements.

Browsing to www.bbc.com you will see both HTTP and HTTPS elements, as clicking any one of the articles will redirect to a TLS session.

```bash
### Encrypted Alert ### P�|D)@f����`���
### Encrypted Alert ### �|P����D)@gPr�
GET /bbc/bbc/s?name=smp.player.page&app_name=smphtml5&app_type=web&ml_name=echo_js&ml_version=11.0.2&screen_resolution=1319x1094&ns_c=UTF-8&c8=BBC%20-%20Homepage&c9=&c7=http%3A%2F%2Fwww.bbc.com%2F&bbc_mc=ad1ps1pf1&bbc_site=invalid-data&bbc_smp_bv=3.35.7&connection_type=wifi&ns_st_mp=smphtml5&ns_st_mv=2.21.15.5&plugin_url=%2F%2Femp.bbci.co.uk%2Fplugins%2FdfpAdsHTML%2F3.24.4%2Fjs%2FdfpAds.js&action_type=plugin_loaded&action_name=plugin_manager&echo_event=userAct&ns_type=hidden&ns__t=1535998787072 HTTP/1.1
Host: sa.bbc.co.uk
User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:61.0) Gecko/20100101 Firefox/61.0
Accept: */*
Accept-Language: en-GB,en;q=0.5
Accept-Encoding: gzip, deflate
Referer: http://www.bbc.com/
Connection: keep-alive
```

```bash
### Encrypted Alert ### P�|D)@g����P��&�
### Encrypted Alert ### �|P����D)A�Pu@�
### Encrypted Alert ### 5�Gá����gelfilesbbcicouk�
                                                           "gelfilesbbcicoukedgekeynet�2e3891dscf
akamaiedge�O�` Y��3�` Y��3)
### Encrypted Alert ### ��ٵ�
                              �rHa�
�&��
```

```bash
GET /js/core/bridge3.233.0_en.html HTTP/1.1
Host: imasdk.googleapis.com
User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:61.0) Gecko/20100101 Firefox/61.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-GB,en;q=0.5
Accept-Encoding: gzip, deflate
Referer: http://emp.bbc.com/emp/SMPj/2.21.15/iframe.html
Connection: keep-alive
Upgrade-Insecure-Requests: 1
```

```
### Encrypted Alert ### P��.l~LC]YP����
### Encrypted Alert ### ���)U�e�r�0�
���
### Encrypted Alert ### �����J�r�0�
```

In order for us to protect a web-applicaiton we need to view the entire payload (in it's pure HTTP form). To decrypt data we need the server(s) private key so we can effectivley man in the middle the TLS session so we can view the raw payload data.

In order to do this, we need to capture the TLS Sessions CLIENTHELLO and SERVERHELLO so we can capture the key-exchange (negotiation), more about this on a future post!
