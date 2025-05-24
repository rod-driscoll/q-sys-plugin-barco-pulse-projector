
# q-sys-plugin-barco-pulse-projector

Plugin for Q-Sys environment to control a Barco Pulse series projector.

Language: Lua\
Platform: Q-Sys

Source code location: <https://github.com/rod-driscoll/q-sys-plugin-barco-pulse-projector>

![Control tab](https://github.com/rod-driscoll/q-sys-plugin-barco-pulse-projector/blob/master/content/control.png)\
![Setup tab](https://github.com/rod-driscoll/q-sys-plugin-barco-pulse-projector/blob/master/content/setup.png)\

## Deploying code

Copy the *.qplug file into "%USERPROFILE%\Documents\QSC\Q-Sys Designer\Plugins" then drag the plugin into a design.

## Developing code

Instructions and resources for Q-Sys plugin development is available at:

* <https://q-syshelp.qsc.com/DeveloperHelp/>
* <https://github.com/q-sys-community/q-sys-plugin-guide/tree/master>

Do not edit the *.qplug file directly, this is created using the compiler.
"plugin.lua" contains the main code.

### Development and testing

The files in "./DEV/" are for dev only and may not be the most current code, they were created from the main *.qplug file following these instructions for run-time debugging:\
[Debugging Run-time Code](https://q-syshelp.qsc.com/DeveloperHelp/#Getting_Started/Building_a_Plugin.htm?TocPath=Getting%2520Started%257C_____3)

## Features

* Power control
* Wake On LAN
  * WoL won't work unil the mac has been populated. The plugin will query for the MAC.
  * WoL is needed if the projector goes into ECO mode, beware that it takes several minutes to come out of eco mode.
* Source select
* Shutter control

## Changelog

20250524 v1.0.0 Rod Driscoll<rod@theavitgroup.com.au>\
Initial version

## Authors

Original author: [Rod Driscoll](rod@theavitgroup.com.au)
Revision author: [Rod Driscoll](rod@theavitgroup.com.au)
