--[[
  20250521 v1.0 Rod Driscoll<rod@theavitgroup.com.au>
  Barco Pulse projector control.
  Source code location: <https://github.com/rod-driscoll/q-sys-plugin-barco-pulse-projector>
  
  Developer notes:
  - The projector responds to source commands and queries with an error when it is off.
  - 'off', 'standby', 'eco' and 'ready' are all different levels of off. 
  - 'conditioning' is warming, 'deconditioning' is cooling
  - if you want to trigger actions like motorised screen controls from the power state be aware that it will send a 'ready' state temporarily as it warms up so you need to create logic to ignore any state changes between 'Warming' and 'On' 
  - sending a WoL on power on if TCP is not connected, could probably check 'EcoEnable' and only send it if enabled.
  - it takes several minutes to wake from eco mode so it is best to avoid unless absolutely necessary.
]]

PluginInfo = {
  Name = "Barco~Pulse Series Display v1.0",
  Version = "1.0",
  BuildVersion = "1.0.0.0",
  Id = "Barco Pulse Series Display v1.0",
  Author = "Rod Driscoll<rod@theavitgroup.com.au>",
  Description = "Control and Status for Barco Pulse Series Display.",
  Manufacturer = "Barco",
  Model = "Pulse",
  IsManaged = true,
  Type = Reflect and Reflect.Types.Display or 0,
}
