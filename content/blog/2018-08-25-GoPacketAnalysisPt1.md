---
layout: post
title: GoPacket Analysis Pt. 1
date: 2018-08-25
---
# GoPacket Setup and Initial Analysis!

Today we will focus on some packet analysis using Golang as our inspection engine.

One of my side-project goals is to be able to build a packet analysis tool and Malware/Attack detection engine. I figured that Building this POC in GoLang would be the best choice from a performance & speed perspective.

One of the issues I had with getting the Google pcap library to work was an issue with getting the "C" library interfaces from working properly. After a bit of tinkering I was able to set up the environment for development correctly.

**Setup Instructions:**
```
Obviously we need a 64 bit version of Golang installed and set to path (make sure that is done first!)
1) Install mingw 64 https://sourceforge.net/projects/mingw-w64/ Architecture is: x86_64 (64 bit)
2) Add the gcc.exe to path, e.g. C:\Program Files\mingw-w64\x86_64-8.1.0-posix-seh-rt_v6-rev0\mingw64\bin
3) Install npcap: https://nmap.org/npcap/
4) Install WinPcap Developer tools: https://www.winpcap.org/devel.htm &
Save to C:\ Directory so it is set as: C:\wpdPack
5) Copy wpcap.dll & packet.dcc to a folder from C:\Windows\System32
6) Run "gendef" on both files in the directory you copied those files to this will generate ".def" files for each.
7) Generate the static library files:
--> dlltool --as-flags=--64 -m i386:x86-64 -k --output-lib libwpcap.a --input-def wpcap.def
--> dlltool --as-flags=--64 -m i386:x86-64 -k --output-lib libpacket.a --input-def packet.def
8) Copy libwpcap.a and libpacket.a to c:\WpdPack\Lib\x64
9) Lastly Install gopacket & pcap via.
--> go get github.com/google/gopacket
--> go get github.com/google/gopacket/pcap
10) Let the fun begin!
```
**Go**

The first step is simply getting a pcap file, you can do this by taking a packet capture with either tcpdump on windows or Wireshark. I used wireshark and took a packet capture of some HTTP requests targetted at the berkley packet filter website, http://biot.com/capstats/bpf.html

Opening the file and processing the pcap file for packets.
```go
package main

import (
	"fmt"
	"log"
	"github.com/google/gopacket"
	"github.com/google/gopacket/pcap"
)

var (
	pcapFile string = "capture.pcap"
	handle   *pcap.Handle
	err      error
)

func main() {
	// Open file instead of device
	handle, err = pcap.OpenOffline(pcapFile)
	if err != nil {
		log.Fatal(err)
	}
	defer handle.Close()

	// Loop through packets in file
	packetSource := gopacket.NewPacketSource(handle, handle.LinkType())
	for packet := range packetSource.Packets() {
		fmt.Println(packet)
	}
}
```
The above code simply reads the file and prints the packets out with their layers to the console, however in this case we want to look for a specific protocol, say HTTP. Modifying the code we add a BPFF filter for TCP port 80 (typically HTTP traffic) and a destination that I know will receive my web traffic.

```go
package main

import (
	"fmt"
	"log"
	"github.com/google/gopacket"
	"github.com/google/gopacket/pcap"
)

var (
	pcapFile string = "capture.pcap"
	handle   *pcap.Handle
	err      error
)

func main() {
	// Open file instead of device
	handle, err = pcap.OpenOffline(pcapFile)
	if err != nil {
		log.Fatal(err)
	}
	defer handle.Close()

	// Set filter
	var filter string = "host 88.99.24.79 and port 80"
	err = handle.SetBPFFilter(filter)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("Filter set to Port 80 only!")

	// Loop through packets in file
	packetSource := gopacket.NewPacketSource(handle, handle.LinkType())
	for packet := range packetSource.Packets() {
		fmt.Println(packet)
	}
}
```
After setting our filter to catch only port 80 traffic, we want to actually inspect the payload data of each HTTP packet. For this we need to peel open additional iplayers in the packet. "github.com/google/gopacket/layers"

We add the line(s):
```go
ipLayer := packet.Layer(layers.LayerTypeIPv4)
fmt.Printf("%+v", ipLayer)
```
Output:
```
Filter set to Port 80 only!
&{BaseLayer:{Contents:[69 0 2 32 75 114 64 0 128 6 0 0 192 168 1 38 88 99 24 79] Payload:[203 52
32 77 97 114 32 50 48 48 57 32 49 57 58 52 48 58 53 53 32 71 77 84 13 10 13 10]} Version:4 IHL:5
TOS:0 Length:544 Id:19314 Flags:DF FragOffset:0 TTL:128 Protocol:TCP Checksum:0 SrcIP:192.168.1.38
DstIP:88.99.24.79 Options:[] Padding:[]}
Process finished with exit code 0
```
We need to extract the Payload data of each packet. In order to handle this data we must
know what object is being passed back to us. Checking this reveals an interface.
```go
fmt.Printf("%t", ipLayer)
type: *layers.IPv4
```
In order to handle this interface and get the payload it needs to be Casted to type interface. The line we added from before changes to.
```go
ipLayer := packet.Layer(layers.LayerTypeIPv4)
ip, _ := ipLayer.(*layers.IPv4)
fmt.Println(string(ip.Payload))
```
Output ->
```bash
Filter set to Port 80 only!
� PMq��ߘP �4�  GET /capstats/bpf.html HTTP/1.1
Host: biot.com
Connection: keep-alive
Cache-Control: max-age=0
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9
If-None-Match: W/"49bc0847-6b3b"
If-Modified-Since: Sat, 14 Mar 2009 19:40:55 GMT


 P���ߘMs�P �av  HTTP/1.1 304 Not Modified
Server: nginx
Date: Sat, 25 Aug 2018 18:38:12 GMT
Last-Modified: Sat, 14 Mar 2009 19:40:55 GMT
Connection: keep-alive
ETag: "49bc0847-6b3b"


� PMsڙ��FP �2�  
� P��I��P 2�  
� PMsڙ��FP �4�  GET /capstats/bpf.html HTTP/1.1
Host: biot.com
Connection: keep-alive
Cache-Control: max-age=0
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9
If-None-Match: W/"49bc0847-6b3b"
If-Modified-Since: Sat, 14 Mar 2009 19:40:55 GMT


� P���    ���2�  �
 P�����IP ��  
� P��I��P 2�  
 P�Y����r�:  �
� P���Y�P 2�  
 P����FMu�P �Z�  HTTP/1.1 304 Not Modified
Server: nginx
Date: Sat, 25 Aug 2018 18:38:16 GMT
Last-Modified: Sat, 14 Mar 2009 19:40:55 GMT
Connection: keep-alive
ETag: "49bc0847-6b3b"


� PMuҙ���P �2�  

Process finished with exit code 0
```
You can see there are some interesting characters @ the start of each payload. This is padding, and those bytes can be removed.
I confirmed with a packet capture software tool (such as wireshark) that the data is nearly identical (minus the padding).

<a href="/img/pcap1/pcap.png">Packet Analysis on Wireshark</a>

Nice that we are getting some Raw HTTP data back we can start inspecting this data to start analyzing patterns to create a detection engine.

We need to implement a way to remove some of the TCP padding that is showing up within the data payload (�). It was found that these are typically padded around 20 bytes.

We can slice the payload by 20 bytes to get rid of most of the non readable characters.

```go
fmt.Println(string(ip.Payload[20:]))
```

Unfortunatley for us, the last HTTP reponse (304) is over 21 bytes long. Since we are capturing all protocol data we are actually getting both TCP and HTTP payload data mixed in our dataset.

As discussed later in the post, we will need to be able to filter out some of this unecessary encoded data since we are not interested in it. TCP in the sense of our target application (the HTTP web server) is pureley the underlay component of the protocol, e.g. it allows us to maintain an established and reliable connection via TCP, the actual content data, is actually built ontop of TCP via the Hypertext Transfer Protocol (HTTP) which is responsible for initiating the communication necessary to the web server in order to begin a data transaction.

Results:
```bash
Filter set to Port 80 only!
GET /capstats/bpf.html HTTP/1.1
Host: biot.com
Connection: keep-alive
Cache-Control: max-age=0
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9
If-None-Match: W/"49bc0847-6b3b"
If-Modified-Since: Sat, 14 Mar 2009 19:40:55 GMT


HTTP/1.1 304 Not Modified
Server: nginx
Date: Sat, 25 Aug 2018 18:38:12 GMT
Last-Modified: Sat, 14 Mar 2009 19:40:55 GMT
Connection: keep-alive
ETag: "49bc0847-6b3b"




GET /capstats/bpf.html HTTP/1.1
Host: biot.com
Connection: keep-alive
Cache-Control: max-age=0
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9
If-None-Match: W/"49bc0847-6b3b"
If-Modified-Since: Sat, 14 Mar 2009 19:40:55 GMT


�


�

HTTP/1.1 304 Not Modified
Server: nginx
Date: Sat, 25 Aug 2018 18:38:16 GMT
Last-Modified: Sat, 14 Mar 2009 19:40:55 GMT
Connection: keep-alive
ETag: "49bc0847-6b3b"
```
You will notice we don't actually get any Payload <html> data back from the Server. I visited the web page before I ran the packet capture. Notice the HTTP Header in the request: If-None-Match: W/"49bc0847-6b3b", On the Response we get a HTTP 304 response code indicating the file has not changed "bpf.html" and the ETAG value returned is the same (ignore the W/ it's just an ETag option specification).

So effectivley the browser cached the HTTP response. Clearing my browsing data will reveal the full payload when I make the initial response to the server, AKA there wont be an If-None-Match header in the GET request.

```bash
GET /capstats/bpf.html HTTP/1.1
Host: yawp.biot.com
Connection: keep-alive
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9

HTTP/1.1 200 OK
Server: nginx
Date: Sun, 26 Aug 2018 00:48:55 GMT
Content-Type: text/html
Last-Modified: Sat, 14 Mar 2009 19:40:55 GMT
Transfer-Encoding: chunked
Connection: keep-alive
Vary: Accept-Encoding
ETag: W/"49bc0847-6b3b"
Content-Encoding: gzip

1f66
�0qs��R��y��j򮍏��w��@VH�}�멢
g�F]��.g��/_�,�6���:���N�zQV0�<�LP��Muz�"s�� L�@"
k����"�㬲�eU��f7ԩE��֓�&+�����"��l����
+M��u	ԣP�rC}�,�(�W$oS���R0���~*�/�`��x���_?
����7�"�tx��E�iU�h��<pM,Y{�����;�U��}SW7b�'p
(��҉(��+��,�:���͂�,�%.� �J�T'��t��u�4��6(�l�^�
�{ w�-p���G���9��`���m�@�%/$ ���"}����WZ4EF�2o
```
There we go! After clearing our browsing history we get the raw payload back, although it still looks messy.. As you can see clearly from the HTTP headers, they indicate that the content has been encoded.
```
Vary: Accept-Encoding
Content-Encoding: gzip
```

In order to decode the Payload data we need to unpack it, when the data is transfered it is compressed/encoded into the gzip format. To build a decoding system we need to inspect the HTTP headers to use as a means to logically apply the correct decoding methods.

```bash
Content-Type: text/html
Transfer-Encoding: chunked
Content-Encoding: gzip
```

This is purely just to explain how the HTTP response sends data. From a Client side perspective, we are not that interested in the response data from the HTTP server because it is simply doing what the Client "requests." We would only need to inspect Client Side / Compressed HTTP data if we were interested in preventing Client Side attacks as well as preventing command and control traffic from being transmitted within the HTTP Response data.

So, without further-ado since we now have all the HTTP metadata we need, we can implement a more efficient decoder and begin analyzing the HTTP GET, POST, & PUT requests that are being sent from the client to the server.

For this we will implement a more efficient decoder that can unwrap the layers we need to remove some of the TCP noise showing up in-between some of our HTTP payload data (even after removing the 20 byte padding). As specified, by the library developers, for faster processing it is recommended that ```NewDecodingLayerParser()``` is implemented rather than using the built-in decoder from ```packet.Layer(layers.LayerTypeIPv4)```
