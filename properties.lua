table.insert(props,{
  Name    = "Connection Type",
  Type    = "enum", 
  Choices = {"Ethernet", "Serial"},
  Value   = "Ethernet"
})
table.insert(props,{
  Name    = "Debug Print",
  Type    = "enum",
  Choices = {"None", "Tx/Rx", "Tx", "Rx", "Function Calls", "All"},
  Value   = "None"
})
table.insert(props,{
  Name  = "Poll Interval",
  Type  = "integer",
  Min   = 1,
  Max   = 60,
  Value = 10
})
table.insert(props,{
  Name  = "Get Device Info",
  Type  = "boolean",
  Value = true
})