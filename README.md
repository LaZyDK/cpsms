
Send spoofed SMS Messages using the danish SMS provider cpsms.dk

This BASH script uses the danish SMS provider cpsms.dk's API: https://api.cpsms.dk/documentation/index.html?php to send spoofed SMS Messages

You need to purchase credits at the site https://www.cpsms.dk/ to be able to use it.

NB: I do not work for that company or in any other way get commision/compensation for advertising for them - I have just used them for performing Redteam tasks.


This script was made on a Debian 10 (buster) Linux installation


PRE INSTALL: 

apt-get update && apt-get install util-linux curl
 
HOW TO USE THE SCRIPT: 
 ```
 --------------------------------------------------------------------------------------------
 Usage: ./sms.sh 
 --------------------------------------------------------------------------------------------

 [ -a | --auth ]                [ "Base64 encoded string" ]
 [ -e | --encoding ]            [ UTF-8 | ISO-8859-1 ]
 [ -f | --from ]                [ "11 digits | 15 mixed digit and characters" ]
 [ -F | --format ]              [ GSM | UNICODE ]
 [ -m | --message ]             [ "String up to 1530 characters" ]
 [ -r | --reporturl ]           [ "http[s]://URL" ]
 [ -R | --reference ]           [ "String at up to 32 characters " ]
 [ -t | --to ]                  [ "String or array" ]
 [ -T | --time ]                [ Unix epoc time ]
 [ -x | --flash 0|1 ]           [ 0|1 ]
 
 [ -h | -? | --help ]
 ```
 --------------------------------------------------------------------------------------------
 Example: 
 --------------------------------------------------------------------------------------------
 ```
  ./sms.sh -a a2VsZG5vcm1hbjoxMjM0aGF2ZS1tYWRlLXRoaXMtc2NyaS1wdDR5b3UwMDEzMzc= \
            -e UTF-8                                                           \
             -f +4511111111                                                    \
             -F GSM                                                            \
             -m "Testing API"                                                  \
             -r "https://www.googleanalytics.com"                              \
             -R "PROJECT X"                                                    \
             -t 4511111111                                                     \
             -T 1474970400                                                     \
             -x 0                                                                
 ```
  A more simple example: 
 ```
  ./sms.sh --from nobody --to +4511111111 --message "Testing API" --flash=1
 ```
 --------------------------------------------------------------------------------------------
 This is the maual for ./sms.sh:
 --------------------------------------------------------------------------------------------
 ```
 [ -a | --auth ]         Basic Authorization is a Base64 encoded string of your login name at cpsms.dk and your api key
                         Example: a2VsZG5vcm1hbjoxMjM0aGF2ZS1tYWRlLXRoaXMtc2NyaS1wdDR5b3UwMDEzMzc=

[ -e | --encoding ]     Send the message as UTF-8 or ISO-8859-1
 [ -f | --from ]         Set the number that the receiver will see as the sender of the SMS. 
                         It can be either numeric with a limit of 15 chars or alphanumeric with a limit of 11 chars
                         Example: +4511111111 or A Secret Number

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

                         Status         Description
                            1           Delivery successful
                            2           Delivery failed
                            4           Message buffered
                            8           Delivery abandoned

 [ -R | --reference ]    An optional reference of your choice in the form of a string up to 32 characters 
                         Example: "Newsletter #123456"

 [ -t | --to ]           The recipient(s) of the message. The number starting with country code. Can be a string or an array
                         Example: "+4511111111"

 [ -T | --time ]         If specified, the message will be sent at this time (integer representing a unix timestamp)
                         You can generate the epoc date using https://www.epochconverter.com/

                         Example: "1640995199"  # date -d '31/12/2021 23:59:59' +"%s"

 [ -x | --flash 0|1 ]    Specifies if the SMS should be sent as a flash SMS. Default value is 0
 [ -h | -? | --help ]    Show this help manual
 ```
 --------------------------------------------------------------------------------------------
