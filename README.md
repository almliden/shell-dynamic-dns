# Readme

This shell-script serves as an Dynamic DNS for sites where GoDaddy is the registrar. It fetches the DNS A-record for a domain and compares the public IP address for the computer from where the script is executed. If the A Record is different from the public IP address, it calls GoDaddys API to update the A record.

The primary use is to update your DNS A records for whenever your public IP address changes, which can happen for various reasons.

## Dependencies
The package `jq` to parse JSON. Install with:

`sudo apt install jq`

## Installation

1. Clone this repo.
2. Make the script executable `chmod +x dyndns.sh`
3. Schedule it for execution. This can be done in various ways, some are better that others. This command can be used to call the script: 
    
    `/bin/sh /path/dyndns.sh -l /path/dyns-dns-log.log -s {godaddy SSO-key} -a https://api.godaddy.com/v1/domains/{your domain here}/records/A -i https://{ your IP API} -t 60`

### Schedule for execution

Since we don't need to call the DNS-record more than once when we initiate the DNS A record we want to start the script at boot and keep it running. Some would argue against it, but it's possible to put it in crontab with the @reboot interval. This serves our purpose well, and all the ways except the bad are good, right?

Example on how this can be initiated in the crontab:

`@reboot /bin/sh /path/dyndns.sh -l /path/dyns-dns-log.log -s {godaddy SSO-key} -a https://api.godaddy.com/v1/domains/{your domain here}/records/A -i https://{ your IP API} -t 60`

Note: the `@reboot` might not work on all systems, or some users. Therefor this script might have to be executed as root. To install it in root's crontab: `crontab -e -u root`.
Note: the interpreter is not /bin/bash, it's /bin/sh which makes all the parsing and regex-matching a little trickier and requires a few more steps. Keep that in mind.

## Argument flags
-l LOG_FILE, where logs should be stored
-s SSO_KEY, API-key for your GoDaddy account
-a API_ENDPOINT, the API-endpoint used. Should be something similiar to: https://api.godaddy.com/v1/domains/{your domain here}/records/A
-i IP_API, to find your public IP. The response is supposed to be an IP-address in plaintext.
-t SLEEP, check interval
