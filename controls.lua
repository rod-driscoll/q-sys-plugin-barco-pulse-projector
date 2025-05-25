-- Configuration Controls --
table.insert(ctrls, {
  Name         = "IPAddress",
  ControlType  = "Text",
  Count        = 1,
  DefaultValue = "Enter an IP Address",
  UserPin      = true,
  PinStyle     = "Both"
})
table.insert(ctrls, {
  Name         = "Port",
  ControlType  = "Text",
  ControlUnit  = "Integer",
  DefaultValue = "9090",
  Min          = 0,
  Max          = 65535,
  Count        = 1,
  UserPin      = true,
  PinStyle     = "Both"
})
table.insert(ctrls, {
  Name         = "MACAddress",
  ControlType  = "Text",
  PinStyle     = "Both",
  UserPin      = true,
  Count        = 1,
  DefaultValue = ""
})
table.insert(ctrls, {
  Name         = "Username",
  ControlType  = "Text",
  PinStyle     = "Both",
  UserPin      = true,
  Count        = 1,
  DefaultValue = "admin"
})
table.insert(ctrls, {
  Name         = "Password",
  ControlType  = "Text",
  PinStyle     = "Both",
  UserPin      = true,
  Count        = 1,
  DefaultValue = "default1234"
})

-- Status Controls --
table.insert(ctrls, {
  Name          = "Status",
  ControlType   = "Indicator",
  IndicatorType = Reflect and "StatusGP" or "Status",
  PinStyle      = "Output",
  UserPin       = true,
  Count         = 1
})
table.insert(ctrls, {
  Name         = "FamilyName",
  ControlType  = "Text",
  PinStyle     = "Output",
  UserPin      = true,
  Count        = 1
})
table.insert(ctrls, {
  Name         = "ArticleNumber",
  ControlType  = "Text",
  PinStyle     = "Output",
  UserPin      = true,
  Count        = 1
})
table.insert(ctrls, {
  Name         = "ModelName",
  ControlType  = "Text",
  PinStyle     = "Output",
  UserPin      = true,
  Count        = 1
})
table.insert(ctrls, {
  Name         = "DeviceName",
  ControlType  = "Text",
  PinStyle     = "Output",
  UserPin      = true,
  Count        = 1
})
table.insert(ctrls, {
  Name         = "SerialNumber",
  ControlType  = "Text",
  PinStyle     = "Output",
  UserPin      = true,
  Count        = 1
})
table.insert(ctrls, {
  Name         = "DeviceFirmware",
  ControlType  = "Text",
  PinStyle     = "Output",
  UserPin      = true,
  Count        = 1
})
table.insert(ctrls, {
  Name         = "HostName",
  ControlType  = "Text",
  PinStyle     = "Output",
  UserPin      = true,
  Count        = 1,
  DefaultValue = ""
})
table.insert(ctrls, {
  Name          = "LoggedIn",
  ControlType   = "Indicator",
  IndicatorType = "Led",
  Count         = 1,
  UserPin       = true,
  PinStyle      = "Output"
})
table.insert(ctrls, {
  Name          = "RequiresAuthentication",
  ControlType   = "Indicator",
  IndicatorType = "Led",
  Count         = 1,
  UserPin       = true,
  PinStyle      = "Output"
})

-- Power Controls --
table.insert(ctrls, {
  Name          = "PowerStatus",
  ControlType   = "Indicator",
  IndicatorType = "Led",
  Count         = 1,
  UserPin       = true,
  PinStyle      = "Output"
})
table.insert(ctrls, {
  Name          = "PowerState",
  ControlType  = "Text",
  PinStyle     = "Output",
  UserPin      = true,
  Count        = 1,
  DefaultValue = ""
})
table.insert(ctrls, {
  Name          = "StandbyStatus",
  ControlType   = "Indicator",
  IndicatorType = "Led",
  Count         = 1,
  UserPin       = true,
  PinStyle      = "Output"
})
table.insert(ctrls, {
  Name         = "Power",
  ControlType  = "Button",
  ButtonType   = "Trigger",
  Count        = 1,
  UserPin      = true,
  PinStyle     = "Input",
  Icon         = "Power"
})
table.insert(ctrls, {
  Name         = "PowerOn",
  ControlType  = "Button",
  ButtonType   = "Trigger",
  Count        = 1,
  UserPin      = true,
  PinStyle     = "Input"
})
table.insert(ctrls, {
  Name         = "PowerOff",
  ControlType  = "Button",
  ButtonType   = "Trigger",
  Count        = 1,
  UserPin      = true,
  PinStyle     = "Input"
})

-- Panel Controls --
table.insert(ctrls, {
  Name          = "ShutterOpenStatus",
  ControlType   = "Indicator",
  IndicatorType = "Led",
  Count         = 1,
  UserPin       = true,
  PinStyle      = "Output"
})
table.insert(ctrls, {
  Name          = "ShutterState",
  ControlType  = "Text",
  PinStyle     = "Output",
  UserPin      = true,
  Count        = 1,
  DefaultValue = ""
})
table.insert(ctrls, {
  Name         = "Shutter",
  ControlType  = "Button",
  ButtonType   = "Trigger",
  Count        = 1,
  UserPin      = true,
  PinStyle     = "Input",
  Icon         = "Power"
})
table.insert(ctrls, {
  Name         = "ShutterOpen",
  ControlType  = "Button",
  ButtonType   = "Trigger",
  Count        = 1,
  UserPin      = true,
  PinStyle     = "Input"
})
table.insert(ctrls, {
  Name         = "ShutterClose",
  ControlType  = "Button",
  ButtonType   = "Trigger",
  Count        = 1,
  UserPin      = true,
  PinStyle     = "Input"
})

-- Input Controls --
table.insert(ctrls, {
  Name         = "Input",
  ControlType  = "Text",
  Style        = "ComboBox",
  PinStyle     = "Both",
  UserPin      = true,
  Count        = 1
})
table.insert(ctrls, {
  Name         = "InputButtons",
  ControlType  = "Button",
  ButtonType   = "Momentary",
  Count        = InputCount,
  UserPin      = true,
  PinStyle     = "Both"
})
table.insert(ctrls, {
  Name         = "InputLabels",
  ControlType  = "Text",
  Count        = InputCount,
  UserPin      = true,
  PinStyle     = "Output"
})
table.insert(ctrls, {
  Name          = "InputStatus",
  ControlType   = "Indicator",
  IndicatorType = "Led",
  Count         = InputCount
})