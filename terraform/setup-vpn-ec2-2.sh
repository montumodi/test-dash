#!/usr/bin/expect

set timeout 3

spawn ssh -i /Users/modia1/Downloads/windows.pem openvpnas@18.203.178.92

expect "openvpnas@*"

send "sudo passwd openvpn\r"

expect "Enter new UNIX password*"

send "Password1!\r";

expect "Retype new UNIX password*";

send "Password1!\r";

exit

interact