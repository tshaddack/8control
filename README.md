Autogenerated from [https://www.improwis.com/projects/sw_8control/](https://www.improwis.com/projects/sw_8control/)






OctoControl







OctoControl
===========



---

[Problem](#Problem "#Problem")  
[Solution approach](#Solutionapproach "Solution approach")  
[Command suite](#Commandsuite "Command suite")  
      [Commands](#Commands "Command suite.Commands")  
            [Status handling](#Statushandling "Command suite.Commands.Status handling")  
            [Connection handling](#Connectionhandling "Command suite.Commands.Connection handling")  
            [G-code](#Gcode "Command suite.Commands.G-code")  
            [Job control](#Jobcontrol "Command suite.Commands.Job control")  
            [Positioning](#Positioning "Command suite.Commands.Positioning")  
            [Extrusion](#Extrusion "Command suite.Commands.Extrusion")  
            [Temperature](#Temperature "Command suite.Commands.Temperature")  
            [Head fan](#Headfan "Command suite.Commands.Head fan")  
            [Speed control](#Speedcontrol "Command suite.Commands.Speed control")  
            [System commands](#Systemcommands "Command suite.Commands.System commands")  
            [File commands](#Filecommands "Command suite.Commands.File commands")  
            [Display, beep, and alarm commands](#Displaybeepandalarmcommands "Command suite.Commands.Display, beep, and alarm commands")  
[Examples](#Examples "Examples")  
[Weaknesses](#Weaknesses "Weaknesses")  
[Download](#Download "Download")  
[TODO](#TODO "TODO")  


---

Problem
-------



[OctoPrint](http://octoprint.org/ "remote link: http://octoprint.org/") is a neat software used as a web-operated printserver
for [3D printers](https://en.wikipedia.org/wiki/3D_printers "Wikipedia link: 3D printers").




Sometimes, however, a commandline control is desired.




There is a utility called [octocmd](https://github.com/vishnubob/octocmd "remote link: https://github.com/vishnubob/octocmd"), that provides
a way to upload and select files, run printing and slicer, and watch status. It however misses
a lot of functionality.




An easy way with a richer set of commandline utilities was desired. Many functions (move, extrude,
retract, pause...) may need to be run from e.g. a control panel sending [USB HID](https://en.wikipedia.org/wiki/USB_HID "Wikipedia link: USB HID") events. A simple
script then can handle the events and send the associated OctoPrint API calls.





---

Solution approach
-----------------



The OctoPrint server comes with a powerful [REST](https://en.wikipedia.org/wiki/Representational_state_transfer "Wikipedia link: Representational state transfer") [API](https://en.wikipedia.org/wiki/Application_programming_interface "Wikipedia link: Application programming interface") accessible
over the [HTTP](https://en.wikipedia.org/wiki/HTTP "Wikipedia link: HTTP") protocol and extensively using [JSON](https://en.wikipedia.org/wiki/JSON "Wikipedia link: JSON") format for the data.
The production version API documentation is [here](http://docs.octoprint.org/en/master/api/index.html "remote link: http://docs.octoprint.org/en/master/api/index.html").




The HTTP REST API can be accessed via [cURL](https://en.wikipedia.org/wiki/cURL "Wikipedia link: cURL") commandline utility.




The OctoControl, aka 8control, is a simple [bash](https://en.wikipedia.org/wiki/Bash_(Unix_shell) "Wikipedia link: Bash (Unix shell)") [shell script](https://en.wikipedia.org/wiki/shell_script "Wikipedia link: shell script") housing multiple utilities and calling the API via cURL.
The host and API key are fetched from the octocmd configuration file, housed in ~/.octocmd.conf - the file is in JSON
format and is parsed via grep and cut to extract the variables.




Bash was chosen instead of e.g. [Python](https://en.wikipedia.org/wiki/Python_(programming_language) "Wikipedia link: Python (programming language)"). Octocmd is written in Python and
on less powerful computers, e.g. the [Raspberry Pi](https://en.wikipedia.org/wiki/Raspberry_Pi "Wikipedia link: Raspberry Pi"), Python tends have a fairly slow start. Bash scripts,
at least the simple ones, are much snappier.





---

Command suite
-------------



The core command is a bash shell script, \_8command.sh. All the commands it hosts are linked by a
[symbolic link](https://en.wikipedia.org/wiki/symbolic_link "Wikipedia link: symbolic link").




Options:

```
8control octoprint command suite, complementary to octocmd

Global commands:
  -h      this help
  -v      verbose (show requests)
  -vv     more verbose (show requests and headers)

Config file location: /etc/octocmd.conf (or /root/.octocmd.conf) (current=/etc/octocmd.conf)
  8checkcfg              check 8control's configuration
  8apiver                show API and server version
  8statusraw             show controller connection status, raw JSON
  8status                show controller connection status, status only
  8connect               connect controller to server
  8disconnect            disconnect controller from server
  8reconnect             disconnect, reset, connect
  8g "<code>"            send gcode to controller
  8gcode "<code>"        send gcode to controller
  8g0 "<coords>"         send G0 command to controller
  8g1 "<coords>"         send G1 command to controller
  8speed <factor>        override speed, in percents
  8feed <factor>         override filament feed, in percents
  8start                 start loaded print job
  8print                 start loaded print job
  8restart               restart print job
  8pause_raw             pause/unpause running job, raw call
  8pause                 pause running job
  8resume                resume running job
  8cancel                cancel running job
  8xcancel               cancel running job, keep temperature setting of the tools
  8home                  home printer head
  8jog <x> <y> <z>       jog printer head by x,y,z mm
  8jog <z>               jog printer head by z mm
  8settemp <temp>        set tool0 to <temp> 'C, M104 S<temp>
  8setbed <temp>         set bed to <temp> 'C, M140 S<temp>
  8settempr <temp>       adjust tool0 by <temp> 'C, M104 R S<temp>; firmware MUST support Shad's R extension
  8setbedr <temp>        set bed to <temp> 'C, M140 R S<temp>; firmware MUST support Shad's R extension
  8ex <mm>               extrude <mm> millimeters of filament (negative to retract)
  8extrude <mm>          extrude <mm> millimeters of filament (negative to retract)
  8fex <mm> [mm/min]     fast extrude <mm> millimeters of filament (negative to retract) with optional speed
  8eject [-t temp]       eject filament, optionally heat head before
  8gmulti <cmd> [<cmd>]...  send several commands in one transaction
  8upload <file>         upload gcode file
  8runfile <file>        upload gcode file as tmp.g and execute it
  8fan <on|off|0..255>   control the head fan
  8fan2 <on|off>         control the bed fan (M42 P57)
  8gettemp_raw           show tool temperature
  8gettemp               show tool temperature
  8getbed                show bed temperature, raw JSON
  8getbed                show bed temperature
  8servo <num> <angle>   set servo angle
  8run <cmd>             run system-menu custom command (see .octoprint/config.yaml or 8ListCmds for commands)
  8reset                 run system-menu command "reset"
  8on                    power up the printer
  8off                   power down the printer
  8ListCmds              list system commands (raw JSON)
  8ls_raw                list available files (raw JSON)
  8ls                    list available files
  8ll <filename>         show info for <filename> (raw JSON)
  8fselect <filename>    select <filename>
  8getjob                information about current job, raw JSON
  8msg "<msg>"           show message on display via M117 gcode
  8beep [n [f]]   beep via M300 gcode [optionally for n milliseconds [at f Hz]]
  8alarm [d] <t|b> <T>   wait until <t>ip or <b>ed reaches temperature T ("d" for decreasing), then beep and exit
  8alarmq [d] <t|b> <T>  wait until <t>ip or <b>ed reaches temperature T ("d" for decreasing), then quietly exit

```



### Commands



Some commands retrieve data. They are usually in JSON format. The most commonly needed data are extracted via grep.
Such commands have the corresponding \_raw version that shows the JSON itself.




All the commands start with 8. The host file starts with \_8, to avoid collisions.




Most commands do not have parameters. Most commands do not have any response.




Some commands use [G-code](https://en.wikipedia.org/wiki/G-code "Wikipedia link: G-code"). There is also a command to directly send G-code commands to the printer.



#### Status handling


* 8status - shows the current printer status (Closed (port disconnected), Connecting, Operational, Printing, Paused)

#### Connection handling


* 8connect - connects server to the default controller port
* 8disconnect - disconnects server (e.g. before attempting to reflash the controller, or running a script directly operating the printer)

#### G-code


* 8g - send raw G-code to the printer, like from OctoPrint terminal


The G-code is converted to uppercase before being sent to the printer.



#### Job control


* 8start - start the job
* 8restart - restart print job
* 8pause - pause print job
* 8resume - resume paused job
* 8cancel - cancel print job


The pause API call toggles the printing and paused status; calling it twice would pause and resume the print.
To achieve stateless operation, the corresponding commands are checking the printer status before acting;
8pause will fire only when Printing, 8resume only when Paused. This will be important for pausing prints when
some supervisory electronics (filament jam or runout sensor, computer vision...) detects an operator-requiring
anomaly.




Beware, the API documentation shows /api/job correctly but the examples show /api/control/job - this was confusing a bit.



#### Positioning


* 8home - home all the axes
* jog <x> <y> <z> - move axes by relative position in mm
* 8g1 [X<x>] [Y<y>] [Z<z>] [F<speed>]  - use G-code to directly move to position


The jog directions are sign-flipped, to match the directions of the G-code based movements, so e.g. positive Z would
move up and negative would move down.



#### Extrusion


* 8extrude <mm> - extrude length of the filament; negative to retract
* 8ex <mm> - shortcut for 8ex
* 8fex <mm> [speed]  - fast extrude length of the filament at 2000 mm/min or at different speed in mm/sec (e.g. 8fex -600 retracts 60 cm of the filament)


The fast extrude is handy for replacing the filament.



#### Temperature


* 8settemp <degC> - set extruder temperature
* 8setbed <degC> - set bed temperature
* 8gettemp - get extruder temperature
* 8getbed - get bed temperature

#### Head fan


* 8fan <on|off|0..255> - set fan to full power, switch it off, or set its PWM control to a value (low values need higher values initially to spin the fan on, then can be slowed down)

#### Speed control


* 8speed <%> - set speed to % of nominal (e.g. 8speed 120 sets 120% speed)
* 8feed <%> - set filament feed to % of nominal (e.g. 8feed 105 sets 5% overextrusion)

#### System commands


* 8run <command> - run a command from the System menu from OctoPrint


The commands are set up in the ~/.octoprint/config.yaml file. Typical functions are switching the video
streaming on and off.




This was not described in the documentation, or it was not possible to find there, so it had to be
reverse-engineered using tcpdump or tshark.



#### File commands


* 8ls - list uploaded files on the printer
* 8ll <filename> - list the file parameters, as raw JSON

#### Display, beep, and alarm commands


* 8msg "<message>" - show message on the display, using M117 G-code
* 8beep - beep the printer's beeper, using M130 G-code
* 8alarm [d] <t|b> <temperature> - wait until temperature of tip or bed increases (or decreases) to temperature, then 8beep the printer and exit
* 8alarmq [d] <t|b> <temperature> - the same, without the beep



---

Examples
--------


* Show "This is a test" message on the display: 8msg "This is a test"
* Position printer to center, 10 mm above the bed: 8g1 x0 y0 z10
* Set extruder to 180 °C: 8settemp 180
* Set bed to 60 °C: 8setbed 60
* Retract filament by 20 mm: 8extrude -20
* Lift head by 20 mm: 8jog 0 0 -20
* Wait until bed temperature reaches at least 50 °C, then beep: 8alarm b 50
* Silently wait until tool1 temperature cools down to at most 50 °C: 8alarmq d t 50



---

Weaknesses
----------


* There is little to no checking of parameter validity.
* There is no parsing of JSON; the processing relies on the server providing a well-readable format with one variable per line.
* Most commands have no indication of success or failure.
* There is no way to get responses of the G-code commands. OctoPrinter seems to be extracting the data from a [websocket](https://en.wikipedia.org/wiki/websocket "Wikipedia link: websocket") monitor of the port for the interactive ones.



---

Download
--------



The archive with the host file and the symlink can be unzipped right to the target
directory (usually /usr/bin/ or /usr/local/bin/. Simply cd to the directory
and then run tar -xzvf &lt;archive\_name.tar.gz&gt;.



* [OctoControl.tar.gz](OctoControl.tar.gz "local file") - archive with host script and all the symlinks
* [\_8control.sh](_8control.sh "local file") - the host script itself


Do not forget to run the install.sh script to make the symlinks, eg. to /usr/bin:
./install.sh /usr/bin/




---

TODO
----


* Find a way to get feedback for the G-code commands. Patching OctoPrint may be necessary.






