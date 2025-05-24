--[[
  20250521 v1.0 Rod Driscoll<rod@theavitgroup.com.au>
  Barco Pulse projector control.

  Developer notes:
  - The projector responds to source commands and queries with an error when it is off.
  - 'off', 'standby', 'eco' and 'ready' are all different levels of off. 
  - 'conditioning' is warming, 'deconditioning' is cooling
  -- sending a WoL on power on, could probably check 'EcoEnable' and only send it if enabled.
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
