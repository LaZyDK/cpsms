#!/bin/bash
#--------------------------------------------------------------------------------------------
#
# (C)opyleft Keld Norman Aug, 2020
# 
# This script can send spoofed SMS messages using the danish SMS provider www.cpsms.dk
#
# yyyy-mm-dd    Version xxxx    - Description
# 
# 2020-08-10    Version 1.0i    - Initial script
#
#--------------------------------------------------------------------------------------------
clear
#set -x
#DEBUG=1
#--------------------------------------------------------------------------------------------
# STATICS
#--------------------------------------------------------------------------------------------
SEND_URL="https://api.cpsms.dk/v2/send"
AUTH_TOKEN="Enter-your-own-AUTH-TOKEN-here-that-you-get-from-cpsms.dk-XXXX=="
DISALLOWED_FROM_ADDRESS_ARRAY=("politi" "p0liti" "skat" "nets") # Seperate words by space
#--------------------------------------------------------------------------------------------
# VARIABLES
#--------------------------------------------------------------------------------------------
TO=""          # Number to send the SMS to
FROM=""        # From address to spoofe
FLASH=""       # Default is 0. Specifies if the SMS should be sent as a flash SMS.
FORMAT=""      # Default is GSM - Send normal message (160 chars, but if more than 160 chars, 153 chars per part message)
MESSAGE=""     # Message to send
ENCODING=""    # Default is UTF-8. Alternative ISO-8859-1.
TIMESTAMP=""   # Unix timestamp - If specified, the message will be sent at this time. "timestamp": 1474970400
REFERENCE=""   # Reference for the log max 32 chars
REPORT_URL=""  # If for example the dlr_url is http://google.com/ then CPSMS.dk will append ?status=x&receiver=xx. You can add your own parameters at the end of your dlr_url.
CONNECT_TIMEOUT=10 # Curl connect timeout in seconds
#--------------------------------------------------------------------------------------------
# EXECUTABLES NEEDED FOR THIS SCRIPT
#--------------------------------------------------------------------------------------------
CURL="/usr/bin/curl"
GETOPT="/usr/bin/getopt"
#--------------------------------------------------------------------------------------------
# FUNCTIONS
#--------------------------------------------------------------------------------------------
function show_help {
#--------------------------------------------------------------------------------------------
 usage 
 echo " --------------------------------------------------------------------------------------------
 This is the maual for $0:
 --------------------------------------------------------------------------------------------

 [ -a | --auth ]         Basic Authorization is a Base64 encoded string of your login name at cpsms.dk and your api key
                         Example: a2VsZG5vcm1hbjoxMjM0aGF2ZS1tYWRlLXRoaXMtc2NyaS1wdDR5b3UwMDEzMzc=

 [ -e | --encoding ]     Send the message as UTF-8 or ISO-8859-1

 [ -f | --from ]         Set the number that the receiver will see as the sender of the SMS. 
                         It can be either numeric with a limit of 15 chars or alphanumeric with a limit of 11 chars
                         Example: +4511111111 or "A Secret Number"

 [ -F | --format ]       Send the message as GSM or UNICODE (default is GSM)

                         The format can be:

                         GSM      Send normal message (160 chars, but if more than 160 chars, 153 chars per part message)
                         UNICODE  To send speciality chars like chinese letters. A normal message is 160 chars, but if you 
		                  use unicode each message can only hold up to 70 chars (But if more than 70 chars, 67 chars per part message)
		    
 [ -m | --message ]      The body text of the SMS message. Specifies the message to be sent. All characters allowed by the SMS protocol are accepted.
                         If the message contains any illegal characters, they are automatically removed, and the message shortened. 
		         The maximum message length is 1530 characters, which is the length of 10 SMS'es joined together.

 [ -r | --reporturl ]    If specified, delivery reports will be send to this address via GET.
                         If for example specified as http://google.com/ then CPSMS.dk will append ?status=x&receiver=xx
                         If needed you can add your own parameters at the end of your url.

                         Example: http://google.com/?status=x&receiver=xx

                         Status Codes: 

                         Status		Description
                            1		Delivery successful
                            2		Delivery failed
                            4		Message buffered
                            8		Delivery abandoned

 [ -R | --reference ]    An optional reference of your choice in the form of a string up to 32 characters 
                         Example: \"Newsletter #123456\"

 [ -t | --to ]           The recipient(s) of the message. The number starting with country code. Can be a string or an array
                         Example: \"+4511111111\"

 [ -T | --time ]         If specified, the message will be sent at this time (integer representing a unix timestamp)
                         You can generate the epoc date using https://www.epochconverter.com/

                         Example: \"1640995199\"  # date -d '31/12/2021 23:59:59' +\"%s\"

 [ -x | --flash 0|1 ]    Specifies if the SMS should be sent as a flash SMS. Default value is 0

 [ -h | -? | --help ]         Show this help manual

 --------------------------------------------------------------------------------------------
 "
 exit 0
}
#--------------------------------------------------------------------------------------------
function usage() {
#--------------------------------------------------------------------------------------------
echo " --------------------------------------------------------------------------------------------
 Usage: ${0} 
 --------------------------------------------------------------------------------------------

 [ -a | --auth ]		[ \"Base64 encoded string\" ]
 [ -e | --encoding ]		[ UTF-8 | ISO-8859-1 ]
 [ -f | --from ]		[ \"11 digits | 15 mixed digit and characters\" ]
 [ -F | --format ]		[ GSM | UNICODE ]
 [ -m | --message ]		[ \"String up to 1530 characters\" ]
 [ -r | --reporturl ] 		[ \"http[s]://URL\" ]
 [ -R | --reference ]		[ \"String at up to 32 characters \" ]
 [ -t | --to ]		        [ \"String or array\" ]
 [ -T | --time ]		[ Unix epoc time ]
 [ -x | --flash 0|1 ]		[ 0|1 ]	

 [ -h | -? | --help ]
	
 --------------------------------------------------------------------------------------------
 Example: 
 --------------------------------------------------------------------------------------------

  ${0} -a a2VsZG5vcm1hbjoxMjM0aGF2ZS1tYWRlLXRoaXMtc2NyaS1wdDR5b3UwMDEzMzc= \\
           -e UTF-8                                                            \\
           -f +4511111111                                                      \\
           -F GSM                                                              \\
           -m \"Testing API\"                                                    \\
           -r \"https://www.googlenalytics.com\"                                 \\
           -R \"PROJECT X\"                                                      \\
           -t 4511111111                                                       \\
           -T 1474970400                                                       \\
           -x 0                                                                \\

  A more simple example: 

  ${0} --from nobody --to +4511111111 --message \"Testing API\" --flash=1
" 
}
#--------------------------------------------------------------------------------------------
function validate_auth {
#--------------------------------------------------------------------------------------------
 if [ -z "${AUTH_TOKEN}" ]; then    # The variable AUTH_TOKEN is NOT defined in this script
  if [ ! -z "${1}" ]; then          # The variable AUTH_TOKEN is NOT empty
   AUTH_TOKEN=${1}
  else
   printf "\n ### ERROR - You must specify an AUTH_TOKEN (see https://api.cpsms.dk/documentation/index.html)\n\n"
   exit 11
  fi
 fi
 if [ $(${CURL} --connect-timeout ${CONNECT_TIMEOUT} -s -X GET -H "Authorization: Basic ${1}" -LI "https://api.cpsms.dk/v2/creditvalue" -o /dev/null -w '%{http_code}\n') != "200" ]; then
  printf "\n ### ERROR - The AUTH token specified is not correct (see https://api.cpsms.dk/documentation/index.html)\n\n"
  printf " You specified: -a | --auth ${AUTH_TOKEN} \n\n"
  exit 12
 fi
}
#--------------------------------------------------------------------------------------------
function validate_encoding {
#--------------------------------------------------------------------------------------------
 if [ -z "${ENCODING}" ]; then 
  if [ ! -z "${1}" ]; then
   ENCODING=${1}
  else
   printf "\n ### ERROR - You must specify an ENCODING method (see https://api.cpsms.dk/documentation/index.html)\n\n"
   exit 21 
  fi
 fi
 [[ ! ${ENCODING:-error} =~ UTF-8|ISO-8859-1 ]] && { 
  printf "\n ### ERROR - Incorrect options provided as parameter (-e | --encoding ${ENCODING})\n\n" 
  printf "     Syntax: -e | --encoding [ UTF-8 | ISO-8859-1 ]\n\n" 
  exit 22
 }
}
#--------------------------------------------------------------------------------------------
function validate_from {
#--------------------------------------------------------------------------------------------
 if [ -z "${FROM}" ]; then 
  if [ ! -z "${1}" ]; then
   FROM=${1}
  else
   printf "\n ### ERROR - The \"FROM\" field is missing\n\n"
   exit 31
  fi
 fi
 # IS IT A NUMBER
 numbers='^[0-9]+$'
 if [[ ${FROM} =~ $numbers ]] ; then
  # IS THERE MORE THAN 15 DIGITS
  if [ ${#FROM} -gt 15 ]; then 
   printf "\n ### ERROR - When the \"FROM\" field is numeric it must not > 15 digits\n\n"
   exit 32
  fi
 else
  if [ ${#FROM} -gt 11 ]; then 
   printf "\n ### ERROR - When the \"FROM\" field containing characters it must not > 11\n\n"
   exit 33
  else
   for WORD in "${DISALLOWED_FROM_ADDRESS_ARRAY[@]}" ; do 
    if [[ ${FROM} == *"${WORD}"* ]]; then
     printf "\n ### ERROR  - The \"FROM\" field contains an illigal word (${WORD}) now allowed to spoofe by law in Denmark!\n" 
     exit 34
    fi
   done
  fi
 fi
}
#--------------------------------------------------------------------------------------------
function validate_format {
#--------------------------------------------------------------------------------------------
 if [ -z "${FORMAT}" ]; then 
  if [ ! -z "${1}" ]; then
   FORMAT=${1}
  else
   printf "\n ### ERROR - You must specify a FORMAT (see https://api.cpsms.dk/documentation/index.html)\n\n"
   exit 41
  fi
 fi
 [[ ! ${FORMAT:-error} =~ GSM|UNICODE ]] && { 
  printf "\n ### ERROR - Incorrect options provided as parameter (-F | --format ${FORMAT})\n\n" 
  printf "     Syntax: -F | --format [ GSM | UNICODE ]\n\n" 
  exit 42
 }
}
#--------------------------------------------------------------------------------------------
function validate_message {
#--------------------------------------------------------------------------------------------
 if [ -z "${MESSAGE}" ]; then 
  if [ ! -z "${1}" ]; then
   MESSAGE=${1}
  else
   printf "\n ### ERROR - You must specify a MESSAGE (see https://api.cpsms.dk/documentation/index.html)\n\n"
   exit 51
  fi
 fi
 # IS IT GREATER THAN 1530
 if [ ${#MESSAGE} -gt 1530 ]; then 
  printf "\n ### ERROR - The \"MESSAGE\" field length must not be > 1530 characters\n\n"
  exit 52
 fi
}
#--------------------------------------------------------------------------------------------
function validate_report_url {
#--------------------------------------------------------------------------------------------
 if [ -z "${REPORT_URL}" ]; then 
  if [ ! -z "${1}" ]; then 
   REPORT_URL=${1}
  fi
 fi
}
#--------------------------------------------------------------------------------------------
function validate_reference {
#--------------------------------------------------------------------------------------------
 if [ -z "${REFERENCE}" ]; then 
  if [ ! -z "${1}" ]; then 
   REFERENCE=${1}
  fi
 fi
 if [ ${#REFERENCE} -gt 32 ]; then 
  printf "\n ### ERROR - The \"REFERENCE\" field length must not be > 32 characters\n\n"
  exit 71
 fi
}
#--------------------------------------------------------------------------------------------
function validate_to {
#--------------------------------------------------------------------------------------------
 if [ -z "${TO}" ]; then 
  if [ ! -z "${1}" ]; then 
   TO=${1}
  else
   printf "\n ### ERROR - The \"TO\" field has is missing\n\n"
   exit 81
  fi
 fi
 # IS IT GREATER THAN 10
 if [ ${#TO} -gt 15 ]; then 
  printf "\n ### ERROR - The \"TO\" field length must not be > 15 digits\n\n"
  exit 82
 fi
}
#--------------------------------------------------------------------------------------------
function validate_timestamp {
#--------------------------------------------------------------------------------------------
 if [ -z "${TIMESTAMP}" ]; then 
  if [ ! -z "${1}" ]; then 
   TIMESTAMP=${1}
  fi
 fi
 # IS IT EMPTY
 if [ ! -z "${TIMESTAMP}" ]; then 
  numbers='^[0-9]+$'
  if ! [[ ${TIMESTAMP} =~ $numbers ]] ; then
   printf "\n ### ERROR - The \"TIMESTAMP\" field is not valid (must constist of numbers)\n\n"
   exit 91
  fi
  NOW=$EPOCHSECONDS
  MAX=$(expr ${NOW} + 86400) # 24 hours
  if [ ${TIMESTAMP} -lt ${NOW} ]; then 
   printf "\n ### ERROR - The \"TIMESTAMP\" field is not valid (must not be in the past)\n\n"
   exit 92
  fi
  if [ ${TIMESTAMP} -gt ${MAX} ]; then 
   printf "\n ### ERROR - The \"TIMESTAMP\" field is not valid (must not be > 24 hours from now)\n\n"
   EXIT 93
  fi
 fi
}
#--------------------------------------------------------------------------------------------
function validate_flash {
#--------------------------------------------------------------------------------------------
 if [ -z "${FLASH}" ]; then 
  if [ ! -z "${1}" ]; then 
   FLASH=${1}
  fi
 fi
}
#--------------------------------------------------------------------------------------------
function print_all_variables {
#--------------------------------------------------------------------------------------------
 printf " ### DEBUG - Printing debug informations:\n\n"
 printf " %-13s : %s\n" "* Auth"   "${AUTH}"
 printf " %-13s : %s\n" "  Encoding"    "${ENCODING}"
 printf " %-13s : %s\n" "* From"        "${FROM}"
 printf " %-13s : %s\n" "  Format"      "${FORMAT}"
 printf " %-13s : %s\n" "* Message"     "${MESSAGE}"
 printf " %-13s : %s\n" "  Report_URL"   "${REPORT_URL}"
 printf " %-13s : %s\n" "  Reference"   "${REFERENCE}"
 printf " %-13s : %s\n" "* To"          "${TO}"
 printf " %-13s : %s\n" "  Time"        "${TIME}"
 printf " %-13s : %s\n" "  Flash"       "${FLASH}"
}
#--------------------------------------------------------------------------------------------
function show_credit {
#--------------------------------------------------------------------------------------------
 CREDIT=$(${CURL} --connect-timeout ${CONNECT_TIMEOUT} -s -X GET -H "${AUTH}" "https://api.cpsms.dk/v2/creditvalue" |cut -d '"' -f4|cut -d ',' -f1 )
 printf "\n Credits available: ${CREDIT:-0}\n"
 if [ ${CREDIT} -lt 1 ]; then 
  printf "\n ### ERROR - You do not have enough credits ( see https://www.cpsms.dk/login/index.php?page=smsbestil )\n\n"
  exit 100
 fi
}
#--------------------------------------------------------------------------------------------
function show_error_message {
#--------------------------------------------------------------------------------------------
 if [ -z "${1}" ]; then 
  ERROR="Error in parameter send to function get_error_message"
 else
 CODE=$1
  case ${CODE} in
   207)	ERROR="Multi-Status – Your request is successful but you have some error(s) you should look at";;
   400)	ERROR="Bad Request – There is something wrong with your request.";;
   401)	ERROR="Unauthorized – Something wrong with the user credentials.";;
   402)	ERROR="Payment Required – You do not have enough SMS credit/points.";;
   403)	ERROR="Forbidden – IP validation gone wrong.";;
   404)	ERROR="Not Found – The specified method could not be found.";;
   406)	ERROR="Not Acceptable – You did something.";;
   409)	ERROR="Conflict – Nothing to return based on posted data.";;
   500)	ERROR="Internal Server Error – We had a problem with our server. Try again later.";;
   *)   ERROR="Unknown error";;
  esac
 fi
 printf "\n ### ERROR CODE ${CODE} - ${ERROR}\n\n"
}
#--------------------------------------------------------------------------------------------
# PRE 
#--------------------------------------------------------------------------------------------
if [ ! -x ${GETOPT} ]; then 
 printf "\n ### ERROR - Missing util ${GETOPT}\n\n"
 printf " Install the util-linux package ( apt-get install util-linux)\n\n"
 exit 5
fi
if [ ! -x ${CURL} ]; then 
 printf "\n ### ERROR - Missing util ${CURL}\n\n"
 printf " Install the curl package ( apt-get install curl)\n\n"
 exit 5
fi
if [ $# -lt 1 ]; then 
 printf "\n ### ERROR - Missing parameters\n\n"
 usage
 exit 6
fi
#--------------------------------------------------------------------------------------------
# SHOW HELP
#--------------------------------------------------------------------------------------------
if [ $(echo "${@}" | egrep -E -c "\-h$|\-h |\--help$|\--help |\-\?$|\-\? ") -ne 0 ]; then
 show_help 
 exit 0 
fi
#--------------------------------------------------------------------------------------------
# ENSURE AUTHENTICATION WORKS
#--------------------------------------------------------------------------------------------
 if [ -z "${AUTH_TOKEN}" ]; then 
  if [ $(echo "${@}" | egrep -E -c "\-a$|\-a |\--auth$|\--auth ") -eq 0 ]; then
   printf "\n ### ERROR - Missing auth parameter\n\n"
   exit 6
  fi
  auth_options=$(${GETOPT} -a -n sms.sh -o cha:e:f:F:m:r:R:t:T:x: --long credit --long help --long auth:,encoding:,from:,format:,message:,reporturl:,reference:,to:,time:,flash: -- "$@")
  eval set -- "$auth_options"
  while true; do
   case "$1" in
    -a | --auth)      shift; validate_auth      "${1}" ;;
    --)               shift; break                   ;;
   esac
   shift
  done
 else
  validate_auth "${AUTH_TOKEN}"
 fi
 AUTH="Authorization: Basic ${AUTH_TOKEN}"
#--------------------------------------------------------------------------------------------
# JUST DO A CREDIT CHECK ?
#--------------------------------------------------------------------------------------------
if [ $(echo "${@}" | egrep -E -c "\-c$|\-c |\--credit$|\--credit ") -ne 0 ]; then
 show_credit; echo ""; exit 0 
fi
#--------------------------------------------------------------------------------------------
# OPTIONS
#--------------------------------------------------------------------------------------------
# Ensure atleast 3 parameters ( to, from and message ) have been entered
if [ $# -lt 3 ]; then 
 printf "\n ### ERROR - Missing or wrong parameter(s)\n\n"
 usage
 exit 6
fi
printf "\n "
options=$(${GETOPT} -a -n sms.sh -o cha:e:f:F:m:r:R:t:T:x: --long credit --long help --long auth:,encoding:,from:,format:,message:,reporturl:,reference:,to:,time:,flash: -- "$@")
[ $? -eq 0 ] || { 
 usage
 exit 7
}
eval set -- "$options"
while true; do
 case "$1" in
  -e | --encoding)  shift; validate_encoding  "${1}" ;;
  -f | --from)      shift; validate_from      "${1}" ;;
  -F | --format)    shift; validate_format    "${1}" ;;
  -m | --message)   shift; validate_message   "${1}" ;;
  -r | --reporturl) shift; validate_reporturl "${1}" ;;
  -R | --reference) shift; validate_reference "${1}" ;;
  -t | --to)        shift; validate_to        "${1}" ;;
  -T | --time)      shift; validate_time      "${1}" ;;
  -x | --flash)     shift; validate_flash     "${1}" ;;
  --)               shift; break                   ;;
 esac
 shift
done
if [ ${DEBUG:-0} -eq 1 ]; then print_all_variables; fi
#--------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------
show_credit
#--------------------------------------------------------------------------------------------
# SEND THE SMS
#--------------------------------------------------------------------------------------------
printf "\n Sending SMS from \"${FROM}\" to \"${TO}\" with the message: \"${MESSAGE}\"\n\n"
if [ ${DEBUG:-0} -eq 1 ]; then 
 printf " ### DEBUG - Printing debug informations:\n\n"
 echo ${CURL} --connect-timeout ${CONNECT_TIMEOUT} -s -X POST -H "${AUTH}" -d '{
"to":"'"${TO}"'",
"from":"'"${FROM}"'",
"flash":"'"${FLASH:-0}"'",
"message":"'"${MESSAGE}"'",
"format":"'"${FORMAT:-GSM}"'",
"dlr_url":"'"${REPORT_URL}"'",
"encoding":"'"${ENCODING:-UTF-8}"'",
"reference":"'"${REFERENCE}"'",
"timestamp":"'"${TIMESTAMP}"'"}' "${SEND_URL}
 "
fi
STATUS=$(${CURL} --connect-timeout ${CONNECT_TIMEOUT} -s -X POST -H "${AUTH}" -d '{
"to":"'"${TO}"'",
"from":"'"${FROM}"'",
"flash":"'"${FLASH:-0}"'",
"message":"'"${MESSAGE}"'",
"format":"'"${FORMAT:-GSM}"'",
"dlr_url":"'"${REPORT_URL}"'",
"encoding":"'"${ENCODING:-UTF-8}"'",
"reference":"'"${REFERENCE}"'",
"timestamp":"'"${TIMESTAMP}"'"}' "${SEND_URL}")
#--------------------------------------------------------------------------------------------
# REPORT DELIVERY STATUS
#--------------------------------------------------------------------------------------------
if [ -z "${STATUS}" ]; then
 printf " FAILED - No answer received from the curl request\n\n"
 exit 8
fi
SUCCESS=$(echo "${STATUS}"|cut -d '"' -f2) # error or success
if [ -z "${SUCCESS}" ]; then 
 printf " FAILED - No answer received from the curl request\n\n"
 exit 8
fi
if [ "${SUCCESS}" == "success" ]; then 
 printf " SUCCESS - Your message has been send successfully.\n\n"
 exit 8
else
 printf " FAILED - Sending message failed.\n\n"
 ERROR_CODE=$(echo ${STATIS}|grep code|cut -d ':' -f3|cut -d"," -f1)
 if [ ${ERROR_CODE:-0} -ne 0 ]; then 
  show_error_message ${ERROR_CODE}
 fi
 ERROR_MESSAGE=$(echo "${STATUS}"|cut -d '"' -f 8)
 if [ "${ERROR_MESSAGE:-error}" != "error" ]; then 
  printf " Extended error message: ${ERROR_MESSAGE:-error}\n\n"
  exit 9
 fi
fi
#--------------------------------------------------------------------------------------------
# END OF SCRIPT
#--------------------------------------------------------------------------------------------
