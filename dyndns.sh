#!/bin/sh

### CONSTANTS
regex_IP="\b([0-9]{1,3}\.){3}[0-9]{1,3}\b"
regex_RESPONSE_CODE="\"+code+\"+\:"
regex_RESPONSE_DATA='\"data\"'
regex_RESPONSE_PARKED="Parked"


### VARIABLES
DNS_IP=''
EXT_IP=''
SHOULD_EXIT=0


### DEFAULT ARGUMENTS
SLEEP=120


### ARGUMENTS
while getopts :l:s:a:i:t: option
do
    case "${option}"
    in
        l) LOG_FILE=${OPTARG};;
        s) SSO_KEY=${OPTARG};;
        a) API_ENDPOINT=${OPTARG};;
        i) IP_API=${OPTARG};;
        t) SLEEP=${OPTARG};;
    esac
done


### FUNCTIONS
check_arguments () {
    check_argument "$SSO_KEY" "-s SSO_KEY"
    check_argument "$API_ENDPOINT" "-a API_ENDPOINT"
    check_argument "$IP_API" "-i IP_API"
    check_argument "$LOG_FILE" "-l LOG_FILE"
    if [ "$SHOULD_EXIT" = 1 ] ; then
        log_fatal "Missing required arguments."
        exit 0;
    fi
}

check_argument () {
    if [ -z "$1" ] ; then
        set_date
        log_error "Missing Argument $2"
        SHOULD_EXIT=1
    fi
}

set_date() {
    date=$(TZ=Europe/Stockholm date '+%Y-%m-%d %H:%M:%S')
}

log () {
    set_date
    echo "$date INFO  $1" >> $LOG_FILE
}

log_detail () {
    set_date
}

log_error () {
    set_date
    echo "$date ERROR $1" >> $LOG_FILE
}

log_fatal () {
    set_date
    echo "$date FATAL $1" >> $LOG_FILE
    exit 0;
}

try_again_get_DNS_IP() {
    tryagainin=$(($SLEEP + 300))
    tryagainin=$(($SLEEP - 9))
    sleep "$tryagainin"
    log "Trying again."
    get_DNS_IP
}

get_DNS_IP () {
    local response=$(curl -X GET --silent -H "Authorization: sso-key $SSO_KEY" "$API_ENDPOINT")
    local response_RESPONSE_DATA=$(echo $response | grep -E "$regex_RESPONSE_DATA")
    if [ ${#response_RESPONSE_DATA} -gt 0 ] ; then
        local data=$(echo "$response" | jq -r .[0].data)
        # data = 192.168.1.1 || Parked
        local data_regex_IP=$(echo $response | grep -E "$regex_IP")
        if [ ${#data_regex_IP} -gt 0 ] ; then
            DNS_IP=$(echo "$data")
        else
            local data_regex_RESPONSE_PARKED=$(echo $data | grep -E "$regex_RESPONSE_PARKED")
            if [ ${#data_regex_RESPONSE_PARKED} -gt 0  ] ; then
                log_error "Domain parked. Updating A-record."
                update_dns_a_record "192.168.1.1"
                try_again_get_DNS_IP
            else
                log_fatal "Reason: $data"
            fi
        fi
    else
        local response_regex_RESPONSE_CODE=$(echo $response | grep -E "$regex_RESPONSE_CODE")
        if [ ${#response_regex_RESPONSE_CODE} -gt 0 ] ; then
            local code=$(echo "$response" | jq -r .code)
            local message=$(echo "$response" | jq -r .message)
            log_error "Could not parse A-record. Code: $code. Message: $message."
            log_fatal "Exiting"
        else
            log_error "Unkown. Response: $response"
            log_fatal "Exiting"
        fi
    fi
}

get_EXT_IP () {
    local response=$(curl --silent $IP_API)
    local response_regex_IP=$(echo $response | grep -E "$regex_IP")
    if [ ${#response_regex_IP} -gt 0 ] ; then
        EXT_IP=$(curl --silent $IP_API)
    else 
        log_error "Invalid External IP"
    fi
}

compare () {
    if [ "$1" = "$2" ] ; then 
        log_detail "Match: $1"
    else
        log_error "No match. DNS: $1 External: $2"
        local result_1_regex_IP=$(echo $1 | grep -E "$regex_IP")
        local result_2_regex_IP=$(echo $2 | grep -E "$regex_IP")
        if [ ${#result_1_regex_IP} -gt 0 ] && [ ${#result_2_regex_IP} -gt 0 ] ; then
            update_dns_a_record "$2"
            DNS_IP=$(echo "$2")
        else
            if [ ${#result_1_regex_IP} -lt 1 ] ; then
                log_error "Not valid IP. DNS: $1"
            fi
            if [ ${#result_2_regex_IP} -lt 1 ] ; then
                log_error "Not valid IP. External: $2"
            fi
        fi
    fi
}

update_dns_a_record () {
    local new_ip=$(echo "$1")
    log "Updating DNS A Record IP to $new_ip"
    response=$(curl -X PUT --silent -H "Authorization: sso-key $SSO_KEY" -H "Content-Type: application/json" --data '[{"type":"A", "name":"@","data":"'$new_ip'"}]' "$API_ENDPOINT")
}

main () {
    log "Job Started"
    check_arguments
    get_DNS_IP
    get_EXT_IP
    log "DNS: $DNS_IP External: $EXT_IP"
    compare "$DNS_IP" "$EXT_IP"
    sleep "$SLEEP"

    while [ "$1" -le "$2" ]
    do 
        get_EXT_IP
        compare "$DNS_IP" "$EXT_IP"
        sleep "$SLEEP"
    done
}

### RUN
main 1 2
