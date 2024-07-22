#!/bin/bash

CR=""

# use this for symlinking all commands to the master command
# grep '^  8.*' _8control.sh |cut -d ')' -f 1|tr -d ' '|while read x; do ln -s _8control.sh $x; done

# based on Octoprint API documentation, http://docs.octoprint.org/en/master/api/index.html



CFGLOCMAIN=/etc/octocmd.conf
CFGLOCLOC=~/.octocmd.conf
if [ -f "$CFGLOCLOC" ]; then CFGLOC="$CFGLOCLOC"; else CFGLOC="$CFGLOCMAIN"; fi

OCTOHOST=`cat $CFGLOC|grep OctoPrint_URL | cut -d '"' -f 4`
OCTOKEY=`cat  $CFGLOC|grep OctoAPI_KEY   | cut -d '"' -f 4`

CURLOPT="--connect-timeout 5 -m 3"
VERBOSE=""

# gcode temporary file, for pipe-to-print
GTMP=/tmp/tmp.g

# ejection variables - bowden length/Fspeed, tip correction length/Fspeed
EJECT_BOWL=800
EJECT_BOWF=2500
EJECT_TIPL=3
EJECT_TIPF=700

# mapping between Raspi and Marlin GPIO lines for mutual communication
PIN0_RASPI=26 ;  PIN0_MARLIN=63
PIN1_RASPI=27 ;  PIN1_MARLIN=40
PIN2_RASPI=28 ;  PIN2_MARLIN=42
PIN3_RASPI=29 ;  PIN3_MARLIN=65


help(){
  echo "8control octoprint command suite, complementary to octocmd"
  echo ""
  echo "Global commands:"
  echo "  -h      this help"
  echo "  -v      verbose (show requests)"
  echo "  -vv     more verbose (show requests and headers)"
  echo ""
  echo "Config file location: $CFGLOCMAIN (or $CFGLOCLOC) (current=$CFGLOC)"
  grep '^ #8' "$0" |tr '#' ' '
}


if [ "$1" == "-h" ]; then help;exit 0; fi
if [ "$1" == "--help" ]; then help;exit 0; fi
if [ "$1" == "-v" ]; then VERBOSE=1; shift; fi
if [ "$1" == "-vv" ]; then VERBOSE=1; CURLOPT="$CURLOPT -i"; shift; fi


if [ "$OCTOHOST" = "" ]; then
  echo "Cannot find configuration."
  echo "Looking for '$CFGLOCMAIN' or '$CFGLOCLOC' with format"
  echo '{'
  echo '    "OctoAPI_KEY": "0123456789ABCDEF0123456789ABCDEF",'
  echo '    "OctoPrint_URL": "http://1.2.3.4:5000"'
  echo '}'
  exit 1
fi

#echo ${testx1/"`echo -e "\r"`"/}


postjson(){
  if [ "$VERBOSE" ]; then echo "curl $CURLOPT -H \"X-Api-Key: $OCTOKEY\" -H \"Content-Type: application/json\" -X POST -d \"${2/$CR/}\" \"$OCTOHOST/$1\""; echo; fi
  s="`curl -s $CURLOPT -H "X-Api-Key: $OCTOKEY" -H "Content-Type: application/json" -X POST -d "${2/$CR/}" "$OCTOHOST/$1" 2>&1`"
  if [ "$s" ]; then echo "$s"; fi
}

posturlenc(){
  if [ "$VERBOSE" ]; then echo "curl $CURLOPT -H \"X-Api-Key: $OCTOKEY\" -H \"Content-Type: application/x-www-form-urlencoded\" -X POST -d \"${2/$CR/}\" \"$OCTOHOST/$1\""; echo; fi
  s="`curl -s $CURLOPT -H "X-Api-Key: $OCTOKEY" -H "Content-Type: application/x-www-form-urlencoded" -X POST -d "${2/$CR/}" "$OCTOHOST/$1" 2>&1`"
  if [ "$s" ]; then echo "$s"; fi
}


postfile(){
# curl -k -H "X-Api-Key: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" -F "select=false" -F "print=false" -F "file=@[output_filepath]" "http://IPADDRESS/api/files/local" {STRIP "; postProcessing"}
  if [ "$VERBOSE" ]; then echo "curl -k -s $CURLOPT -H \"X-Api-Key: $OCTOKEY\" -F \"select=$2\" -F \"print=$3\" -F \"file=@$1\" \"$OCTOHOST/$1\""; echo; fi
  s="`curl -k -s $CURLOPT -H "X-Api-Key: $OCTOKEY" -F "select=$2" -F "print=$3" -F "file=@$1" "$OCTOHOST/api/files/local" {STRIP "; postProcessing"} 2>&1`"
  if [ "$s" ]; then
    s2="`echo "$s"|grep '"done":'`";
    if [ "$s2" ]; then echo $s2|tr -d '", '
                  else echo "$s"
    fi
  fi
}




getmsg(){
  if [ "$VERBOSE" ]; then echo "curl $CURLOPT -H \"X-Api-Key: $OCTOKEY\" \"$OCTOHOST/$1\""; echo; fi
  s="`curl -s $CURLOPT -H "X-Api-Key: $OCTOKEY" "$OCTOHOST/$1" 2>&1`"
  if [ "$s" ]; then echo "$s"; fi
}

getstatus(){
  getmsg api/connection | tr ',]}' '\n\n\n' |tr -d '"'|grep 'state:'|cut -d ':' -f 2
#| grep '"state":'|cut -d '"' -f 4
# Printing
# Paused
}

sendM108_ssh(){
  if [ -f "/bin/shad/3dprinter_forcestop" ]; then /bin/shad/3dprinter_forcestop; fi
}

sendg(){
  GCMD="`echo "$1" | tr '[a-z]' '[A-Z]'`"
#  if [ "${GCMD:0:3}" == "G7 " ]; then
#    GCMD="$1"
#  fi
  if [ "$GCMD" == "M108" ]; then sendM108_ssh;fi
#  echo '{ "command": "'"$GCMD"'" }'
  postjson api/printer/command '{ "command": "'"$GCMD"'" }'
}

sendgcase(){
  GCMD="$1"
  if [ "$GCMD" == "M108" ]; then sendM108_ssh;fi
#  echo '{ "command": "'"$GCMD"'" }'
  postjson api/printer/command '{ "command": "'"$GCMD"'" }'
}

CMD=`basename "$0"`

if [ "$VERBOSE" ]; then
  if [ "$CMD" == "8status" ]; then CMD="8status_raw";
  elif [ "$CMD" == "8gettemp" ]; then CMD="8gettemp_raw";
  elif [ "$CMD" == "8getbed" ]; then CMD="8getbed_raw";
  fi
fi




# use fixed format for facilitation of help and install:
# two spaces before command, for installer
# one space and hash for command help

case "$CMD" in
 #8checkcfg              check 8control's configuration
  8checkcfg)      echo "Octoprint host: $OCTOHOST"
                  echo "Octoprint API key: '$OCTOKEY'"
                  echo "Config file: '$CFGLOC'"
                  ;;

 #8apiver                show API and server version
  8apiver)        getmsg api/version  ;;
 #8statusraw             show controller connection status, raw JSON
  8status_raw)    getmsg api/connection  ;;
 #8status                show controller connection status, status only
  8status)        if [ "$1" != "-q" ]; then echo "Machine: $OCTOHOST"; fi
                  getstatus  ;;

 #8connect               connect controller to server
  8connect)       postjson api/connection '{ "command": "connect" }'  ;;
 #8disconnect            disconnect controller from server
  8disconnect)    postjson api/connection '{ "command": "disconnect" }'  ;;
 #8reconnect             disconnect, reset, connect
  8reconnect)
                  postjson api/connection '{ "command": "disconnect" }'  
                  sleep 0.2
                  postjson api/system/commands/custom/reset
                  sleep 0.5
                  postjson api/connection '{ "command": "connect" }'  ;;

  # todo: more commands into array
 #8g "<code>"            send gcode to controller
 #8gcode "<code>"        send gcode to controller
  8g|8gcode)      sendg "`echo "$@"`";;
  8gcase)         sendgcase "`echo "$@"`";;

 #8g0 "<coords>"         send G0 command to controller
  8g0)            sendg "G0 `echo "$@"`"  ;;

 #8g1 "<coords>"         send G1 command to controller
  8g1)            sendg "G1 `echo "$@"`"  ;;

 #8speed <factor>        override speed, in percents
  8speed)         sendg "M220 S$1";;
 #8feed <factor>         override filament feed, in percents
  8feed)          sendg "M221 S$1";;


 #8start                 start loaded print job
 #8print                 start loaded print job
  8start|8print)  postjson api/job '{ "command": "start" }'  ;;
 #8restart               restart print job
  8restart)       postjson api/job '{ "command": "restart" }'  ;;
  # todo: handle pausing toggle - pause just pauses, unpause unpauses
 #8pause_raw             pause/unpause running job, raw call
  8pause_raw)     postjson api/job '{ "command": "pause" }'  ;;
 #8pause                 pause running job
  8pause)         postjson api/job '{ "command": "pause", "action": "pause" }'  ;;
#  8pause)         STATUS=`getstatus`
#                  if [ "$STATUS" == "Printing" ]; then postjson api/job '{ "command": "pause" }'; fi  ;;
 #8resume                resume running job
  8resume)         postjson api/job '{ "command": "pause", "action": "resume" }'  ;;
#  8resume)        STATUS=`getstatus`
#                  if [ "$STATUS" == "Paused" ]; then postjson api/job '{ "command": "pause" }'; fi  ;;
 #8cancel                cancel running job
  8cancel)        #if [ -f "/bin/shad/3dprinter_forcestop" ]; then /bin/shad/3dprinter_forcestop; fi
                  sendg "M108";sendg "M77"; # cancel job, stop timer
                  postjson api/job '{ "command": "cancel" }'  ;;

 #8xcancel               cancel running job, keep temperature setting of the tools
  8xcancel)       TEMP0=`8gettemp|grep target:|head -n1|cut -d ':' -f 2`
                  TEMPB=`8getbed |grep target:|head -n1|cut -d ':' -f 2`
                  echo Cancelling job
                  8cancel
                  echo Setting tool and bed back to $TEMP0:$TEMPB
                  8settemp $TEMP0
                  8setbed $TEMPB
                  echo Homing
                  8home
                  ;;

#status: Operational, Connecting, 

 #8home                  home printer head
  8home)          postjson api/printer/printhead '{ "command": "home", "axes": [ "x","y","z"] }'  ;;
#  8home)          sendg "G28 S1"  ;; # uses shad's mod to not safe the head
 #8jog <x> <y> <z>       jog printer head by x,y,z mm
 #8jog <z>               jog printer head by z mm
  8jog)           x=$1; y=$2; z=$3;
                  if [ "$y" == "" ]; then x=0;y=0;z=$1; fi
                  # invert the values to make the increments match the G1 position signs
                  if [ "${x:0:1}" == "-" ]; then x=${x:1}; else x=-$x; fi
                  if [ "${y:0:1}" == "-" ]; then y=${y:1}; else y=-$y; fi
                  if [ "${z:0:1}" == "-" ]; then z=${z:1}; else z=-$z; fi
                  postjson api/printer/printhead '{ "command": "jog", "x": '$x', "y": '$y', "z": '$z' }'  ;;

  # todo: handle more heads than just tool0
 #8settemp <temp>        set tool0 to <temp> 'C, M104 S<temp>
  8settemp)       postjson api/printer/tool '{ "command": "target", "targets": { "tool0": '$1' } }'  ;;
 #8setbed <temp>         set bed to <temp> 'C, M140 S<temp>
  8setbed)        postjson api/printer/bed  '{ "command": "target", "target": '$1' }'  ;;
 #8settempr <temp>       adjust tool0 by <temp> 'C, M104 R S<temp>; firmware MUST support Shad's R extension
  8settempr)      sendg "M104 R S$1" ;;
 #8setbedr <temp>        set bed to <temp> 'C, M140 R S<temp>; firmware MUST support Shad's R extension
  8setbedr)       sendg "M140 R S$1" ;;
 #8ex <mm>               extrude <mm> millimeters of filament (negative to retract)
 #8extrude <mm>          extrude <mm> millimeters of filament (negative to retract)
  8ex)            postjson api/printer/tool '{ "command": "extrude", "amount": '$1' }'  ;;
  8extrude)       postjson api/printer/tool '{ "command": "extrude", "amount": '$1' }'  ;;
 #8fex <mm> [mm/min]     fast extrude <mm> millimeters of filament (negative to retract) with optional speed
  8fex)           SP="$2"; if [ ! "$SP" ]; then SP=2000;fi
                  postjson api/printer/command '{ "commands": ["G91","G1 E'$1' F'$SP'","G90"] }'  ;;
 #8eject [-t temp]       eject filament, optionally heat head before
  8eject)         if [ "$1" == "-t" ]; then  8settemp "$2"; 8alarm t "$2"; fi
                  postjson api/printer/command '{ "commands": ["G91","G1 E'$EJECT_TIPL' F'$EJECT_TIPF'","G1 E-'$EJECT_BOWL' F'$EJECT_BOWF'","G90"] }'
                  if [ "$1" == "-t" ]; then  8settemp 0; fi;;

 #8gmulti <cmd> [<cmd>]...  send several commands in one transaction
  8gmulti)        CMD='["'$1'"';
                  while [ "$2" ]; do
                    if [ "$2" ]; then CMD="$CMD"',"'$2'"';shift;fi
                  done
                  CMD="$CMD"'] }'
                  CMD="{ \"commands\": `echo "$CMD"|tr '[a-z]' '[A-Z]'`"
                  echo "$CMD"
                  postjson api/printer/command "$CMD"  ;;
# #8fastex <mm>    extrude <mm> millimeters of filament (negative to retract)
#  8fex)            postjson api/printer/tool '{ "command": "extrude", "amount": '$1' }'  ;;

#g91;g1 e500 f2000;g90

 #8upload <file>         upload gcode file
  8upload)        FN="$1";
                  if [ "$1" == "-" ]; then FN="$GTMP"; cat > "$GTMP"
                    else if [ ! -f "$1" ]; then
                      echo "File '$1' not found.";exit 1
                    fi
                  fi
                  postfile "$FN" false false;;

 #8runfile <file>        upload gcode file as tmp.g and execute it
  8runfile)       FN="$1";
                  if [ "$1" == "-" ]; then FN="$GTMP"; cat > "$GTMP"
                    else if [ ! -f "$1" ]; then
                      echo "File '$1' not found.";exit 1
                    fi
                  fi
                  if [ "$1" != "-" ]; then cat "$1" > "$GTMP"; fi
                  postfile "$GTMP" true true;;

 #8fan <on|off|0..255>   control the head fan
  8fan)           if [ "$1" == "on" ]; then sendg "M106 S255";
                  elif [ "$1" == "off" ]; then sendg "M107";
                  else sendg "M106 S$1";
                  fi;;

 #8fan2 <on|off>         control the bed fan (M42 P57)
  8fan2)          if [ "$1" == "on" ]; then sendg "M42 P57 S255";
                  elif [ "$1" == "off" ]; then sendg "M42 P57 S0";
                  fi;;

#  8click)        send M108, simulate panel click
  8click)         sendg "M108"  ;;
#  8getpos)       get position via M114
  8getpos)        sendg "M114"  ;;
###  8waitfinish)   wait for all movements finished, M400
##  8waitfinish)    sendg "M400"  ;;
#  8waitend)      wait until print job finishes
  8waitend)       s2="Printing"
                  while true; do
                    s=`8status -q|tr -d ' '`
                    echo -ne "`date`: [$s]\r"
                    if [ "$s" != "$s2" ]; then echo; fi
                    s2=$s
                    if [ "$s" == "Operational" ]; then break; fi
                    sleep 10
#                    if [ "$s" == "Printing" ]; then sleep 10; continue; fi
#                    if [ "$s" == "Paused" ];   then sleep 5; continue; fi
#                    if [ "$s" == "" ];         then sleep 5; continue; fi # error
#                    break
                  done;;
#  8sleep)        wait for n seconds, G4 S
  8sleep)         sendg "G4 S$1"  ;;
#  8sleepms)      wait for n milliseconds, G4 P
  8sleepms)       sendg "G4 P$1"  ;;
# 8stepon)        switch on steppers, M17
  8stepon)        sendg "M17"   ;;
# 8stepoff)       switch off steppers, M18
  8stepoff)       sendg "M18"   ;;

 #8gettemp_raw           show tool temperature
  8gettemp_raw)   getmsg api/printer/tool  ;;
 #8gettemp               show tool temperature
# 8gettemp)       getmsg api/printer/tool | grep '  "'|tr -d '{}, "'  ;;
  8gettemp)       getmsg api/printer/tool | tr '{,' '\n\n' | grep 'actual'|tr -d '{}, "' | cut -d ':' -f 2  ;;
 #8getbed                show bed temperature, raw JSON
  8getbed_raw)    getmsg api/printer/bed  ;;
 #8getbed                show bed temperature
#  8getbed)        getmsg api/printer/bed  | grep '  "'|tr -d '{}, "'  ;;
  8getbed)        getmsg api/printer/bed  | tr '{,' '\n\n' | grep 'actual'|tr -d '{}, "' | cut -d ':' -f 2  ;;

 #8servo <num> <angle>   set servo angle
  8servo)         sendg "M280 P$1 S$2"   ;;

  # run the system command like from the menu
 #8run <cmd>             run system-menu custom command (see .octoprint/config.yaml or 8ListCmds for commands)
  8run)           postjson api/system/commands/custom/"$1"  ;;
 #8reset                 run system-menu command "reset"
  8reset)         postjson api/system/commands/custom/reset  ;;

 #8on                    power up the printer
  8on)            postjson api/system/commands/custom/reset
                  sendg "M80" ;;
                  #postjson api/system/commands/custom/on  ;;
 #8off                   power down the printer
  8off)           #postjson api/system/commands/custom/off ;;
                  sendg "M81" ;;

 #8ListCmds              list system commands (raw JSON)
#  8ListCmds)      getmsg api/system/commands ;;
  8ListCmds)      getmsg api/system/commands | tr ',]}' '\n\n\n' ;;


 #8ls_raw                list available files (raw JSON)
#  8ls_raw)        getmsg api/files ;;
  8ls_raw)        getmsg api/files | tr ',]}' '\n\n\n' ;;
 #8ls                    list available files
#  8ls)            getmsg api/files | grep "\"name\":" | cut -d '"' -f 4 ;;
  8ls)            getmsg api/files | tr ',]}' '\n\n\n' | grep "\"name\":" | cut -d '"' -f 4 ;;
 #8ll <filename>         show info for <filename> (raw JSON)
  8ll)            getmsg "api/files/local/$1"  | tr ',]}' '\n\n\n' ;;

 #8fselect <filename>    select <filename>
  8fselect)       postjson api/files/local/"$1" '{ "command": "select", "print": false }'  ;;

 #8getjob                information about current job, raw JSON
  8getjob)        getmsg api/job | tr ',]}' '\n\n\n';;

 #8msg "<msg>"           show message on display via M117 gcode
  8msg)           postjson api/printer/command '{ "command": "M117 '"$1"'" }'  ;;
 #8beep [n [f]]   beep via M300 gcode [optionally for n milliseconds [at f Hz]]
  8beep)          BEEPLEN="$1"; if [ "$BEEPLEN" == "" ];then BEEPLEN=500;fi
                  BEEPFRE="$2"; if [ "$BEEPFRE" == "" ];then BEEPFRE=2000;fi
                  postjson api/printer/command '{ "command": "M300 P'"$BEEPLEN"' S'"$BEEPFRE"'" }'  ;;


  8gsetpin|8gwaitpin)
                  case "$2" in
                    1|H|h)  val=1;;
                    0|L|l)  val=0;;
                    P|p)    val="P";; # pulse
                    R|r)    val="R";; # rising edge
                    F|f)    val="F";; # falling edge
                    *) echo "Unknown value: '$2'. Aborting.";exit 255;;
                  esac
                  case "$1" in
                    0)  pin=$PIN0_MARLIN;;
                    1)  pin=$PIN1_MARLIN;;
                    2)  pin=$PIN2_MARLIN;;
                    3)  pin=$PIN3_MARLIN;;
                    *) echo "Unknown pin number: '$1'. Aborting.";exit 255;;
                  esac
                  case $CMD in
                    8gsetpin)
                      echo $val
                      case "$val" in
                        0) #echo "M42 P$pin S0"
                           sendg "M42 P$pin S0";;
                        1) #echo "M42 P$pin S255"
                           sendg "M42 P$pin S255";;
                        P) pwait=50;pwait2=10
                           postjson api/printer/command "{ \"commands\": [\"M42 P$pin S0\",\"G4 P$pwait2\",\"M42 P$pin S255\",\"G4 P$pwait\",\"M42 P$pin S0\"] }";;
                        R) pwait=10
                           postjson api/printer/command "{ \"commands\": [\"M42 P$pin S0\",\"G4 P$pwait\",\"M42 P$pin S255\"] }";;
                        F) pwait=10
                           postjson api/printer/command "{ \"commands\": [\"M42 P$pin S255\",\"G4 P$pwait\",\"M42 P$pin S0\"] }";;
                        *) echo "Error: val can't be '$val'."
                      esac;;
                    8gwaitpin)
                      case "$val" in
                        0) sendg "M226 P$pin S0";8msg;;
                        1) sendg "M226 P$pin S1";8msg;;
                        R)   postjson api/printer/command "{ \"commands\": [\"M226 P$pin S0\",\"M226 P$pin S1\"] }";8msg;;
                        F|P) postjson api/printer/command "{ \"commands\": [\"M226 P$pin S1\",\"M226 P$pin S0\"] }";8msg;;
                      esac;;
                    *) echo "Unknown command: '$CMD'. Aborting.";exit 255;;
                  esac;;


  8getpin)
                  case "$1" in
                    0)  pin=$PIN0_RASPI;;
                    1)  pin=$PIN1_RASPI;;
                    2)  pin=$PIN2_RASPI;;
                    3)  pin=$PIN3_RASPI;;
                    *) echo "Unknown pin number: '$1'. Aborting.";exit 255;;
                  esac
                  gpio read $pin;;

  8setpin|8waitpin)
                  case "$1" in
                    0)  pin=$PIN0_RASPI;;
                    1)  pin=$PIN1_RASPI;;
                    2)  pin=$PIN2_RASPI;;
                    3)  pin=$PIN3_RASPI;;
                    *) echo "Unknown pin number: '$1'. Aborting.";exit 255;;
                  esac
                  case "$2" in
                    1|H|h)  val=1;;
                    0|L|l)  val=0;;
                    P|p)    val="P";; # pulse
                    R|r)    val="R";; # rising edge
                    F|f)    val="F";; # falling edge
                    *) echo "Unknown value: '$2'. Aborting.";exit 255;;
                  esac
                  case $CMD in
                    8setpin)
                      gpio mode $pin out
                      case "$val" in
                	0|1)   gpio write $pin $val;;
                	P)     gpio write $pin 0;gpio write $pin 1;gpio write $pin 0;;
                	R)     gpio write $pin 0;gpio write $pin 1;;
                	F)     gpio write $pin 1;gpio write $pin 0;;
                      esac;;
                    8waitpin)  
                      gpio mode $pin in
                             echo "Waitig for pin $pin to become $val..."
                      case "$val" in
                	0|1)   while true; do if [ `gpio read $pin` == $val ]; then break; fi; done;;
                	R)     while true; do if [ `gpio read $pin` == 0 ]; then break; fi; done
                	       while true; do if [ `gpio read $pin` == 1 ]; then break; fi; done;;
                	F|P)   while true; do if [ `gpio read $pin` == 1 ]; then break; fi; done
                	       while true; do if [ `gpio read $pin` == 0 ]; then break; fi; done;;
                      esac;;
                    *) echo "Unknown command: '$CMD'. Aborting.";exit 255;;
                  esac;;
#                  sendg "M$mval P$pin S$val";;


 #8alarm [d] <t|b> <T>   wait until <t>ip or <b>ed reaches temperature T ("d" for decreasing), then beep and exit
 #8alarmq [d] <t|b> <T>  wait until <t>ip or <b>ed reaches temperature T ("d" for decreasing), then quietly exit
  8alarm|8alarmq)
                  if [ "$1" == "d" ]; then comp="-le";comp2=">";shift;else comp="-ge";comp2="<";fi
                  if   [ "$1" == "t" ]; then tempcmd="8gettemp";tipno=1;tempend="tip"
                  elif [ "$1" == "b" ]; then tempcmd="8getbed"; tipno=1;tempend="bed"; else
                    echo -e "Unknown parameter '$1'.\nUsage: $CMD [d] <t|b> <temperature>\nWaits for <t>ip or <b>ed reaching temperature, optionally for [d]ecreasing, then beeps and exits."
                    exit 1
                  fi
                  while true; do
                    #temp2=`$tempcmd |grep 'actual'|head -n $tipno|tail -n1|cut -d ':' -f 2`
                    #temp=`echo $temp2 |cut -d '.' -f 1`
                    tempR=`$tempcmd|cut -d '.' -f 1`
                    temp=`echo $tempR|cut -d '.' -f 1`
                    #echo temp=$temp comp=$comp val=$2 tempcmd="$tempcmd" tempend="$tempend"
                    if [ "$temp" == "" ]; then echo "ERR: temp value not received: $tempR";
                    elif [ $temp $comp $2 ]; then
                      echo "$tempend temperature $2'C reached.             ";if [ "$CMD" == "8alarm" ]; then 8beep;fi
                      exit 0;
                    fi
                    echo -en "$tempend temperature $temp'C $comp2 $2'C, waiting...\r";sleep 2
                  done;;


  *)              echo "_8control.sh: unknown command '$CMD'."  ;;
esac


