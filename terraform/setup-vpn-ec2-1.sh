#!/usr/bin/expect

set timeout 3

spawn ssh -i /Users/modia1/Downloads/windows.pem root@18.203.178.92

expect "Are you sure you want to continue connecting*"

send "yes\r";

expect "Please enter 'yes' to indicate your agreement*"

send "yes\r";

expect "Will this be the primary Access Server node?*"

send "\r";

expect "Please enter the option number from the list above*"

send "\r";

expect "Please specify the port number for the Admin Web UI*"

send "\r";

expect "Please specify the TCP port number for the OpenVPN Daemon*"

send "\r";

expect "Should client traffic be routed by default through the VPN*"

send "\r";

expect "Should client DNS traffic be routed by default through the VPN*"

send "\r";

expect "Use local authentication via internal DB*"

send "\r";

expect "Should private subnets be accessible to clients by default*"

send "\r";

expect "*Press ENTER for default*"

send "yes\r";

expect "*Please specify your Activation key (or leave blank to specify later)*"

send "\r";

interact