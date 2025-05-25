--[[
	Barco Pulse Projector Runtime

	2 Connectivity types;  Direct Serial Connection and Ethernet
	Both use the same commands
	Based on user set Property "Connection Type"  the communication engine and send and receive functions will be defined to use one or the other.

	The command parsing, processsing, and input handlers will call the same functions so Send needs to have the same inputs in both builds.
]]

rapidjson = require "rapidjson"

-- Control aliases
Status = Controls.Status

local DebugTx = true
local DebugRx = false
local DebugFunction = true

-- Helper functions
-- A function to determine common print statement scenarios for troubleshooting
function SetupDebugPrint()
	if Properties["Debug Print"]=="Tx/Rx" then
		DebugTx,DebugRx=true,true
	elseif Properties["Debug Print"]=="Tx" then
		DebugTx=true
	elseif Properties["Debug Print"]=="Rx" then
		DebugRx=true
	elseif Properties["Debug Print"]=="Function Calls" then
		DebugFunction=true
	elseif Properties["Debug Print"]=="All" then
		DebugTx,DebugRx,DebugFunction=true,true,true
	end
end

-- Timers, tables, and constants
StatusState = { OK = 0, COMPROMISED = 1, FAULT = 2, NOTPRESENT = 3, MISSING = 4, INITIALIZING = 5 }
Heartbeat = Timer.New()
PowerupTimer = Timer.New()
VolumeDebounce = Timer.New()
StartupTimer = Timer.New()
PowerupCount = 0
PollRate = Properties["Poll Interval"].Value
Timeout = PollRate + 10
BufferLength = 1024
ConnectionType = Properties["Connection Type"].Value
DataBuffer = ""
CommandQueue = {}
SentMessages = {}

CommandProcessing = false
--Internal command timeout
CommandTimeout = 5
CommunicationTimer = Timer.New()
PowerOnDebounceTime = 20
PowerOnDebounce = false
TimeoutCount = 0

local messageId = 1

ActiveInput = 1
for i=1,#Controls['InputButtons'] do
	if Controls['InputButtons'][i].Boolean then
		ActiveInput = i
	end
end

--[[
	Request Command Set
	Named reference to each of the command objects used here in
	Note commands are in decimal here, translation to hex is done in Send()
]]

-- Command items that don't have properties
local Commands = {
	Login       ={method='authenticate',params={username=Controls.Username.String, password=Controls.Password.String}}, -- { "jsonrpc": "2.0", "method":"authenticate", "params": {"code": 98765}, "id": 1 }
	PowerOn     ={method='system.poweron' }, -- {"jsonrpc": "2.0", "method": "system.poweron"}
	PowerOff    ={method='system.poweroff'}, -- {"jsonrpc": "2.0", "method": "system.poweroff"}
  SourceList  ={method="image.source.list"},
}
-- properties to be queried or subscribed to
-- if you create a Control[xxx] with any name in this table then the Control will automatically be populated
-- several are commented out because they're not being used, but they will work if you un-comment them
local Properties = { 
	Status        = "system.state",
  DeviceFirmware= "system.firmwareversion",
  SerialNumber  = "system.serialnumber",
  DeviceName    = "system.name",
  ModelName     = "system.modelname",
  FamilyName    = "system.familyname",
  ArticleNumber = "system.articlenumber",
  --EcoAvailable  = "system.eco.available", -- boolean
  --EcoEnable     = "system.eco.enable",    -- boolean
  --InitialState  = "system.initialstate",  -- string 'ready'
  --IlluminationState  = "illumination.state",  -- string 'Off'
  MACAddress    = "network.device.lan.hwaddress",
  HostName      = "network.hostname",
  Shutter       = "optics.shutter.target",
  --RunTime       = "statistics.projectorruntime.value", -- 'Property not found'
  --SystemTime    = "statistics.systemtime.value",       -- 'Property not found'
  --UpTime        = "statistics.uptime.value",           -- 'Property not found'
  Input         = "image.window.main.source",      -- {"jsonrpc": "2.0", "method": "property.set", "params": {"property": "image.window.main.source", "value": "DisplayPort 1"} }
  -- the properties below should be loaded dynamically after getting the souces list but that's too much effort for the moment.
  HDMIProperties="image.connector.hdmi.detectedsignal", --{"jsonrpc": "2.0", "method": "property.get", "params": {"property": "image.connector.hdmi.detectedsignal"} }
  DpProperties="image.connector.displayport.detectedsignal",
}

-- add any properties to the commands table that are settable
Commands["Input"  ] = {method='property.set', params={property=Properties["Input"]}} -- "jsonrpc": "2.0", "method": "property.set", "params": {"property": "image.window.main.source", "value": "DisplayPort 1"} }
Commands["Shutter"] = {method='property.set', params={property=Properties["Shutter"]}} -- "jsonrpc": "2.0", "method": "property.set", "params": {"property": "optics.shutter.target", "value": "Open"} }
-- create a table of items that require subscriptions
local Subscriptions = {}
for i,v in ipairs({ "Status", "Input", "Shutter" }) do --, "HDMIProperties"
  Subscriptions[v] = { params={property=Properties[v]}, method='property.subscribe' } 
end
-- create a table of items that require querying on connect
local PropertiesToGet = {}
PropertiesToGet['SourceList'] = { method=Commands.SourceList.method } 
for i,v in pairs(Properties) do PropertiesToGet[i] = { params={property=v}, method='property.get' } end

-- create a queue of commands, these commands will be iteratively called after connection when the regular command queue is empty
local PollQueueCurrent = {}
local function LoadPollQueue()
  if DebugFunction then print("LoadPollQueue()") end
  local queue = {}
  for k,v in pairs(PropertiesToGet) do table.insert(queue, v) end
  for k,v in pairs(Subscriptions  ) do table.insert(queue, v) end
  return queue
end 
PollQueueCurrent = LoadPollQueue()

-- A function to clear controls/flags/variables and clears tables
function ClearVariables()
	if DebugFunction then print("ClearVariables() Called") end
	DataBuffer = ""
	CommandQueue = {}
  SentMessages = {}
end

--Reset any of the "Unavailable" data;  Will cause a momentary colision that will resolve itself the customer names the device "Unavailable"
function ClearUnavailableData()
	if DebugFunction then print("ClearUnavailableData() Called") end
end

-- Update the Status control
function ReportStatus(state,msg)
	--if DebugFunction then print("ReportStatus() Called: "..state.." - "..msg) end
	--Dont report status changes immediately after power on
	if PowerOnDebounce == false then
		local msg=msg or ""
		Status.Value=StatusState[state]
		Status.String=msg
		--Show the power off state if we can't communicate
		if(state ~= "OK")then
			Controls["PowerStatus"].Value = 0
			Controls["ShutterOpenStatus"].Boolean = false
			Controls["PowerState"].String = ''
			Controls["ShutterState"].String = ''
		end
	end
end

-- Set the current input indicators
function SetActiveInput(index)
	if DebugFunction then print("SetActiveInputIndicator() Called") end
	if(index)then
		Controls["Input"].String = InputTypes[index].Name
		Controls["InputButtons"][ActiveInput].Value = false
		Controls["InputStatus"][ActiveInput].Value = false
		Controls["InputButtons"][index].Value = true
		Controls["InputStatus"][index].Value = true
		ActiveInput = index
	else
		Controls["Input"].String = "Unknown"
		Controls["InputButtons"][ActiveInput].Value = false
		Controls["InputStatus"][ActiveInput].Value = false
	end
end

--A debounce timer on power up avoids reporting the TCP reset that occurs as ane error
function ClearDebounce()
	PowerOnDebounce = false
end

------ Communication Interfaces --------

-- Shared interface functions
function Init()
	if DebugFunction then print("Init() Called") end
	Disconnected()
	Connect()
end


function Connected()
	if DebugFunction then print("Connected() Called") end
	CommunicationTimer:Stop()
	Heartbeat:Start(PollRate)
	CommandProcessing = false
  
  PollQueueCurrent = LoadPollQueue()
  --if DebugFunction then print("#PollQueueCurrent: "..#PollQueueCurrent) end
  Controls.LoggedIn.Boolean = false 
  if Controls.RequiresAuthentication.Boolean then 
    Send( Commands.Login, true )
  elseif #CommandQueue<1 then
    if #PollQueueCurrent>0 then 
      --if DebugFunction then print("#PollQueueCurrent: "..#PollQueueCurrent) end
      local item = table.remove(PollQueueCurrent)
      --if DebugFunction then print("item "..(item and 'exists' or 'is nil')) end  
      Send( item ) end
	else
    SendNextCommand()
  end
end

--Wrapper for setting the pwer level
function SetPowerLevel(val)
	--
	if val==1 and Controls["PowerStatus"].Value~=val then
		ClearUnavailableData()
		PowerupTimer:Stop()

	--If the display is being shut off, clear the buffer of commands
	--This prevents a hanging off command from immediately turn the display off on next power-on command
	elseif(val == 0)then
		CommandQueue = {}
	end
	Controls["PowerStatus"].Value = val
end

--[[  Communication format
	All commands are hex bytes of the format:
	{ "jsonrpc": "2.0", "method":"authenticate", "params": {"code": 98765}, "id": 1 }

	Both Serial and TCP mode must contain functions:
		Connect()
		Controls["PowerOn"].EventHandler() 
		And a receive handler that passes data to ParseData()
]]

-- Take a request object and queue it for sending.  Object format is of:
function Send(cmd, sendImmediately) --
  --if DebugFunction then print("Send("..rapidjson.encode(cmd)..") "..tostring(sendImmediately).." Called") end
  cmd['jsonrpc']="2.0"
  messageId = messageId>10000 and 1 or messageId + 1
  cmd['id']=messageId

	--Check for if a command is already queued
	for i, val in ipairs(CommandQueue) do
    --print('['..i..'] '..val)
		--if val.method == cmd.method and (not val.params or (val.params == cmd.params)) then
		if val.method == cmd.method then
      --if DebugTx then print("Command method already in queue") end
      if not val.params or (val.params == cmd.params) then
        --if DebugTx then print("Command params already in queue") end
        --Some Commands should be sent immediately
        if sendImmediately then
          --remove other copies of a command and move to head of the queue
          table.remove(CommandQueue,i)
          if DebugTx then print("Send immediately -> moving to front of queue" )end
          table.insert(CommandQueue,1,cmd)
        end
        return
      end
		end
	end
	--Queue the command if it wasn't found
	table.insert(CommandQueue,cmd)
	SendNextCommand()
end

--Timeout functionality
-- Close the current and start a new connection with the next command
-- This was included due to behaviour within the Device Serial; may be redundant check on TCP mode
CommunicationTimer.EventHandler = function()
	if DebugFunction then print("CommunicationTimer Event (timeout) Called") end
	ReportStatus("MISSING","Communication Timeout")
	CommunicationTimer:Stop()
	CommandProcessing = false
	SendNextCommand()
end 

--  Serial mode Command function  --
if ConnectionType == "Serial" then
	print("Serial Mode Initializing...")
	-- Create Serial Connection
	Device = SerialPorts[1]
	Baudrate, DataBits, Parity = 9600, 8, "N"

	--Send the display the next command off the top of the queue
	function SendNextCommand()
		if DebugFunction and not DebugTx then print("SendNextCommand() Called") end
		if CommandProcessing then
			-- Do Nothing
		elseif #CommandQueue > 0 then
			CommandProcessing = true
      local command = table.remove(CommandQueue,1)
			if DebugTx then print("Sending["..Commands.id.."]("..type(command).."): "..rapidjson.encode(command)) end
      SentMessages[Commands.id] = command
			Device:Write( command )
			CommunicationTimer:Start(CommandTimeout)
		else
			CommunicationTimer:Stop()
		end
	end

	function Disconnected()
		if DebugFunction then print("Disconnected() Called") end
		CommunicationTimer:Stop() 
		CommandQueue = {}
		Heartbeat:Stop()
    Controls.LoggedIn.Boolean = false 
	end

	-- Clear old and open the socket, sending the next queued command
	function Connect()
		if DebugFunction then print("Connect() Called") end
		Device:Close()
		Device:Open(Baudrate, DataBits, Parity)
	end

	-- Handle events from the serial port
	Device.Connected = function(serialTable)
		if DebugFunction then print("Connected handler called Called") end
		ReportStatus("OK","")
		Connected()
	end

	Device.Reconnect = function(serialTable)
		if DebugFunction then print("Reconnect handler called Called") end
		Connected()
	end

	Device.Data = function(serialTable, data)
		ReportStatus("OK","")
		CommunicationTimer:Stop() 
		CommandProcessing = false
		local msg = DataBuffer .. Device:Read(1024)
		DataBuffer = "" 
		if DebugRx then print("Received: "..rapidjson.encode(msg)) end
		ParseResponse(msg)
		SendNextCommand()
	end

	Device.Closed = function(serialTable)
		if DebugFunction then print("Closed handler called Called") end
		Disconnected()
		ReportStatus("MISSING","Connection closed")
	end

	Device.Error = function(serialTable, error)
		if DebugFunction then print("Socket Error handler called Called") end
		Disconnected()
		ReportStatus("MISSING",error)
	end

	Device.Timeout = function(serialTable, error)
		if DebugFunction then print("Socket Timeout handler called Called") end
		Disconnected()
		ReportStatus("MISSING","Serial Timeout")
	end

  function SetPowerOn()
		if DebugFunction then print("PowerOn Serial Handler Called") end
		PowerupTimer:Stop()
		--Documentation calls for 3 commands to be sent, every 2 seconds, for 3 repetitions
		Send( Commands["PowerOn"], true )
		PowerupCount=0
		PowerupTimer:Start(2)
		PowerOnDebounce = true
		Timer.CallAfter( ClearDebounce, PowerOnDebounceTime)
	end
	--Serial mode PowerOn handler uses the main api (see network power on below for more fun)
	Controls["PowerOn"].EventHandler = SetPowerOn	

	Controls["ShutterOpen"].EventHandler = function()
		if DebugFunction then print("Shutter open Serial Handler Called") end
		Controls["ShutterState"].String = ''
  	local cmd = Commands["Shutter"]
    cmd.params.value ="Open"
		Send( cmd )
    SetPowerOn()
	end


--  Ethernet Command Function  --
else
	print("TCP Mode Initializing...")
	IPAddress = Controls.IPAddress
	if Controls.Port.Value == 0 then Controls.Port.Value = 9090 end
	Port = Controls.Port
  if Controls.Username.String == '' then Controls.Username.String = 'admin' end
  if Controls.Password.String == '' then Controls.Password.String = 'default1234' end

	-- Create Sockets
	Device = TcpSocket.New()
	Device.ReconnectTimeout = 5
	Device.ReadTimeout = 10  --Tested to verify 6 seconds necessary for input switches;  Appears some TV behave mroe slowly
	Device.WriteTimeout = 10
	udp = UdpSocket.New()
	
	--Send the display the next command off the top of the queue
	function SendNextCommand()
		if DebugFunction and not DebugTx then print("SendNextCommand() Called") end
		if CommandProcessing then
			-- Do Nothing
		elseif #CommandQueue > 0 then
			if not Device.IsConnected then
				Connect()
			else
				CommandProcessing = true
        local command = table.remove(CommandQueue,1)
        local id = command.id
        SentMessages[command.id] = command
        command = rapidjson.encode(command)		
        if DebugTx then print("Sending["..id.."]: "..command) end
        Device:Write( command )
			end
		end
	end

	function Disconnected()
		if DebugFunction then print("Disconnected() Called") end
		if Device.IsConnected then
			Device:Disconnect()
		end
		CommandQueue = {}
		Heartbeat:Stop()
    Controls.LoggedIn.Boolean = false 
	end

	-- Clear old and open the socket
	function Connect()
		if DebugFunction then print("Connect() Called") end
		if IPAddress.String ~= "Enter an IP Address" and IPAddress.String ~= "" and Port.String ~= "" then
			if Device.IsConnected then
				Device:Disconnect()
			end
			Device:Connect(IPAddress.String, tonumber(Port.String))
		else
			ReportStatus("MISSING","No IP Address or Port")
		end
	end

	-- Handle events from the socket;  Nearly identical to Serial
	Device.EventHandler = function(sock, evt, err)
		--if DebugFunction then print("Ethernet Socket Handler Called "..evt) end
		if evt == TcpSocket.Events.Connected then
			ReportStatus("OK","")
			Connected()
		elseif evt == TcpSocket.Events.Reconnect then
      --if DebugFunction then print('Reconnect event - IsConnected: '..tostring(Device.IsConnected)) end
			--Disconnected()

		elseif evt == TcpSocket.Events.Data then
			ReportStatus("OK","")
			CommandProcessing = false
			TimeoutCount = 0
			local data = sock:Read(BufferLength)
			local line = data
			local msg = DataBuffer
			DataBuffer = "" 
			while (line ~= nil) do
				msg = msg..line
				line = sock:Read(BufferLength)
			end
			if DebugRx then 
        print("Received: "..rapidjson.encode(data))
        if #data ~= #msg then print("Buffer: "..rapidjson.encode(msg)) end
      end
			ParseResponse(msg)  
			SendNextCommand()
			
		elseif evt == TcpSocket.Events.Closed then
			Disconnected()
			ReportStatus("MISSING","Socket closed")

		elseif evt == TcpSocket.Events.Error then
			Disconnected()
			ReportStatus("MISSING","Socket error")

		elseif evt == TcpSocket.Events.Timeout then
			TimeoutCount = TimeoutCount + 1
      --print('TimeoutCount: '..TimeoutCount)
			if TimeoutCount > 3 then
				Disconnected()
				ReportStatus("MISSING","Socket Timeout")
			end

		else
			Disconnected()
			ReportStatus("MISSING",err)

		end
	end

	--Ethernet specific event handlers
	Controls["IPAddress"].EventHandler = function()
		if DebugFunction then print("IP Address Event Handler Called") end
		if Controls["IPAddress"].String == "" then
			Controls["IPAddress"].String = "Enter an IP Address"
		end
		ClearVariables()
		Init()
	end
	Controls["Port"].EventHandler = function()
		if DebugFunction then print("Port Event Handler Called") end
		ClearVariables()
		Init()
	end

	-- Get the binary numerical value from a string IP address of the format "%d.%d.%d.%d"
	-- Consider hardening inputs for this function
	function IPV4ToValue(ipString)
		local bitShift = 24
		local ipValue = 0
		for octet in ipString:gmatch("%d+") do
			ipValue = ipValue + (tonumber(octet) << bitShift)
			bitShift = bitShift - 8
		end
		return ipValue or nil
	end

	-- Convert a 32bit number into an IPV4 string format
	function ValueToIPV4(value)
		return string.format("%d.%d.%d.%d", value >> 24, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
	end

	-- Compare IPAddresses as values (32bit integers)
	function IPMaskCheck(ip1, ip2, mask)
		return ip1 & mask == ip2 & mask
	end

	-- Accept IPAddresses as strings
	function IsIPInSubnet(ip1, ip2, mask)
		return IPMaskCheck(IPV4ToValue(ip1), IPV4ToValue(ip2), IPV4ToValue(mask))
	end

  function SetPowerOn(ctl)
		if DebugFunction then print("PowerOn Ethernet Handler Called") end
		--MAC from device is sent as string text, needs translation
    local macstr = Controls["MACAddress"].String:gsub(":", ""):gsub("-", "") -- remove semi colons or hyphens
		if not Device.IsConnected and macstr:len()==12 then
			local mac = ""
			local localIPAddress = nil
			local broadcastRange = "255.255.255.255"
			local deviceIpValue = IPV4ToValue(IPAddress.String)
			local nics = Network.Interfaces()

			--WOL Packet is 6 full scale bytes then 16 repetitions of Device MAC
			for i=1,6 do
				mac = mac..string.char( tonumber( "0x"..macstr:sub((i*2)-1, i*2) ) );  
			end
			local WOLPacket = "\xff\xff\xff\xff\xff\xff"
			for i=1,16 do
				WOLPacket = WOLPacket..mac
			end

			-- Check Gateways and generate a broadcast range if it is found to be 0.0.0.0.  This might be better as a property (if user wanted local range for some reason)
			for name,interface in pairs(nics) do
				if interface.Gateway == "0.0.0.0" then
					for _,nic in pairs(nics) do
						local ipValue = IPV4ToValue(nic.Address)
						local maskValue = IPV4ToValue(nic.Netmask or "255.255.255.0")  -- Mask may not be available in emulation mode
						if ipValue & maskValue == deviceIpValue & maskValue then
							localIPAddress = nic.Address
							if nic.BroadcastAddress then
								broadcastRange = nic.BroadcastAddress
							else
								broadcastRange = ValueToIPV4((deviceIpValue & maskValue) | (0xFFFFFFFF - maskValue))
							end
							break
						end
					end
					break
				end
			end
      --hack
      --broadcastRange = '192.168.104.255'
			--UDP broadcast of the wake on lan packet
			if DebugTx then print("Sending WoL packet UDP: 9 "..broadcastRange) end
			udp:Open( localIPAddress )
			udp:Send( broadcastRange, 9, WOLPacket )
			udp:Close()
		end

		PowerupTimer:Stop()
		Send( Commands["PowerOn"], true )
		--Also send the command in case of broadcast awake signal
		PowerupCount = 0
		PowerupTimer:Start(2)
		PowerOnDebounce = true
		Timer.CallAfter( ClearDebounce, PowerOnDebounceTime)
	end

	-- PowerOn command on Ethernet requires a UDP broadcast wake-on-lan packet
	-- The packet needs the MAC of the display to be formed - GetDisplayInfo must be run once to get the MAC first.
	-- If Display is connected WiFi the poweron will not work
	Controls.PowerOn.EventHandler = SetPowerOn

	Controls["ShutterOpen"].EventHandler = function()
		if DebugFunction then print("Shutter open Ethernet Handler Called") end
  	local cmd = Commands["Shutter"]
    cmd.params.value ="Open"
		Send( cmd )
    SetPowerOn()
	end
end

--  Device Request and Data handlers

-- Function to split concatenated JSON objects
local function split_json_objects(str)
  local objects = {}
  local depth, start = 0, nil

  for i=1, #str do
    local c = str:sub(i, i)
    if c == '{' then
      if depth == 0 then start = i end
      depth = depth + 1
    elseif c == '}' then
      depth = depth - 1
      if depth == 0 and start then
        table.insert(objects, str:sub(start, i))
        start = nil
      end
    end
  end
  return objects
end

--[[  Response Data parser
	{"jsonrpc":"2.0","id":74,"result":"on"}
  {"jsonrpc":"2.0","id":3,"error":{"code":-32001,"message":"Access permission error"}}
  {"jsonrpc":"2.0","id":1,"error":{"code":-32001,"message":"Access permission error, your permission are: NO_ACCESS Rewritten: 0"}}
  {"jsonrpc":"2.0","id":7,"result":{"active":false,"name":"",
      "vertical_total":0,"horizontal_total":0,"vertical_resolution":0,"horizontal_resolution":0,"vertical_sync_width":0,
      "vertical_front_porch":0,"vertical_back_porch":0,"horizontal_sync_width":0,"horizontal_front_porch":0,"horizontal_back_porch":0,
      "horizontal_frequency":0.0,"vertical_frequency":0.0,"pixel_rate":0,"scan":"Progressive","bits_per_component":0,
      "color_space":"RGB","signal_range":"0-255","chroma_sampling":"4:4:4","gamma_type":"POWER","color_primaries":"REC709",
      "mastering_luminance":-1.0,"max_cll":-1.0,"max_fall":-1.0,"content_aspect_ratio":"Unknown","content_type":"Unknown",
      "is_stereo":false,"stereo_mode":"None"}}
]]
function ParseResponse(str)
  if DebugFunction and not DebugRx then print("ParseResponse() Called: "..str) end
  local msg = rapidjson.decode(str)
  
	--Message is too short, buffer the chunk and wait for more
	if str:len()==0 then 
      print('ERROR message is nil')
		  DataBuffer = DataBuffer .. msg
		--do nothing
	--elseif msg.method == Commands.Login.method then
	elseif msg==nil then
    print('ERROR message is not properly formatted json, probably multiple concatenated json strings')
    local json_objects = split_json_objects(str)
    for _,obj_str in ipairs(json_objects) do
      ParseResponse(obj_str)
    end

	elseif msg.error then
    print('ERROR received: '..msg.error.message)
    if msg.error.code then

      if msg.error.code == -32000 then -- 'Ignored POWER_ON event, busy transitioning to ready', 'Could not set source!'

        if msg.error.message:match('transitioning to off') then
          print('COOLING')
          Controls.PowerState.String   = 'Cooling'
          Controls.PowerStatus.String  = 'Cooling'
          Controls.PowerStatus.Boolean = false
        elseif msg.error.message:match('transitioning to ') then -- 'ready' or 'conditioing'
          print('WARMING')
          Controls.PowerState.String   = 'Warming'
          Controls.PowerStatus.String  = 'Warming'
          Controls.PowerStatus.Boolean = true
        end

      elseif msg.error.code == -32001 then -- 'Access permission error'
        Controls.RequiresAuthentication.Boolean = true 
        Controls.LoggedIn.Boolean = false 
        Send( Commands.Login, true )

      elseif msg.error.code == -32602 then 
        --"message":"Wrong parameter type"
      end
    end
  --Handle a good message
	else
    DataBuffer = ''
		local ResponseObj = {}
		HandleResponse(msg)
	end
  if #CommandQueue<1 then
    if #PollQueueCurrent>0 then
      local item = table.remove(PollQueueCurrent)
      if DebugFunction and item==nil then print('poll item is nil') end
      Send( item )
    else
      --if DebugFunction then print('PollQueue is empty') end
    end
  end
end

-- Query response (need to compare id with SentMessage.Id)
-- {"jsonrpc":"2.0","id":22,"result":"ready"}
-- Subscription message
--{"jsonrpc":"2.0","method":"property.changed","params":{"property":[{"system.state":"ready"}]}}

-- Handler for good data from interface
function HandleResponse(msg)
  if DebugFunction then print("HandleResponse(["..(msg.id or msg.method).."]) Called") end
  
  local function ParseProperty(property, result)
    if DebugFunction then print('ParseProperty('..property..', '..tostring(result)..')') end
    for k,v in pairs(Properties) do --k='MACAddress' v="network.device.lan.hwaddress"
      if v==property and result~=nil then 
        --if DebugFunction then print('Property['..k..']') end        
        if type(result)=='string' then
          if Controls[k] then 
            Controls[k].String = result
            if DebugFunction then print('Controls['..k..'].String = '..result) end
          end
          -- special cases
          if     k=='Status' then 
            Controls.PowerState.String  = result:gsub("^%l", string.upper) -- capitalise first letter
            Controls.PowerStatus.String = result:gsub("^%l", string.upper) -- capitalise first letter
            Controls.PowerStatus.Boolean = result=='on'
          elseif k=='Input'  then 
            for i1,v1 in pairs(InputTypes) do 
              if Controls.InputButtons[i1] then Controls.InputButtons[i1].Boolean = v1.Value == result end
            end
          elseif k=='Shutter' then 
						Controls.ShutterOpenStatus.Boolean = result=='Open'
						Controls.ShutterState.String = result:gsub("^%l", string.upper) -- capitalise first letter
          end
        elseif type(result)=='boolean' then
          if Controls[k] then
            if DebugFunction then print('Controls['..k..'].Boolean = '..tostring(result)) end
            Controls[k].Boolean = result
          end
        elseif type(result)=='number' or type(result)=='float' or type(result)=='integer' then
          if Controls[k] then 
            if DebugFunction then print('Controls['..k..'].Value = '..result..', type: '..type(result)) end
            Controls[k].Value = result
          end
        else
          if DebugFunction then print('Controls['..k..'] found: '..type(result)) end
          if     property == Properties[k] then -- k=='HDMIProperties', Properties[k]=='image.connector.hdmi.detectedsignal'
            local input = Properties[k]:match('image%.connector%.([^.]+)%.detectedsignal') -- input == 'hdmi'
            for i,v in ipairs(InputTypes) do
              if v.Value:lower()==input then
                if DebugFunction then print('Controls[InputStatus]['..i..'].Value = '..tostring(result.active)) end
                Controls.InputStatus[i].Boolean = result.active
              break end
            end
          end
        end
        if msg.id and SentMessages[msg.id] then SentMessages[msg.id] = nil end
        return result
      end
    end
    return nil
  end

   -- response to a command or query
  if msg==nil then
    if DebugFunction then print("message is nil, not handling response") end
  elseif msg.id then
    if SentMessages[msg.id] then --SentMessages[msg.id].method could be 'property.get' or 'property.subscribe'
      if SentMessages[msg.id].params then
        if DebugFunction then print('msg['..msg.id..'] extracted: '..rapidjson.encode(SentMessages[msg.id])) end
        -- authentication response
        if SentMessages[msg.id].method == Commands.Login.method then -- {"id":2,"method":"authenticate","params":{"password":"default1234","username":"admin"},"jsonrpc":"2.0"}
					if Controls.RequiresAuthentication.Boolean and not Controls.LoggedIn.Boolean and msg.result then
						PollQueueCurrent = LoadPollQueue() -- need to re-send all queries because some may have failed due to user permission
					end
					Controls.LoggedIn.Boolean = msg.result --{"jsonrpc":"2.0","id":2,"result":true}
        -- property response
        --{"jsonrpc":"2.0","method":"property.changed","params":{"property":[{"system.state":"ready"}]}}
        elseif SentMessages[msg.id].method ~= 'property.subscribe' and SentMessages[msg.id].params.property then --'network.device.lan.hwaddress'
          if ParseProperty(SentMessages[msg.id].params.property, SentMessages[msg.id].params.value or msg.result) == nil then return end
        end
      else-- response from Commands[x]
        if DebugFunction then print('SentMessage "'..SentMessages[msg.id].method..'" had no params') end
      --TX: {"jsonrpc":"2.0","method":"image.source.list","id":6}
      --RX: {"jsonrpc":"2.0","id":6,"result":["HDMI","DisplayPort"]}
        for k,v in pairs(Commands) do
          if v.method==SentMessages[msg.id].method then  --Commands['SourceList']='image.source.list'
            if DebugFunction then print('parsing Commands['..k..']') end
            if k=='SourceList' then
              InputTypes = {}
              local choices = {}
              for i,name in ipairs(msg.result) do
                table.insert(InputTypes, { Name=name, Value=name})
                table.insert(choices, name)
                Controls['InputLabels'][i].Legend = name
              end
              Controls.Input.Choices = choices
              InputCount = #msg.result
            end
          end
        end

      end
      SentMessages[msg.id] = nil -- local sentMessage = table.remove(SentMessages, msg.id) doesn't work
    end
  -- subscription message 
  else   --{"jsonrpc":"2.0","method":"property.changed","params":{"property":[{"system.state":"ready"}]}}
    print('Message type '..msg.method)
    for i,v in ipairs(msg.params.property) do --[1], {"system.state":"ready"}
      for k1,v1 in pairs(v) do ParseProperty(k1, v1) end
    end
  end

end

--[[    Input Handler functions      ]]

-- Re-Initiate communication when the user changes the IP address or Port or ID being queried
function SetPowerOff()
	if DebugFunction then print("PowerOff Handler Called") end
	-- Stop the power on sequence if the user presses power off
	PowerupTimer:Stop()
	CommandQueue = {}
	Controls["PowerStatus"].Value = 0
	Controls["PowerState"].String = ''
	Send( Commands["PowerOff"], true )
end

--Controls Handlers
-- Power controls
Controls["PowerOff"].EventHandler = SetPowerOff

-- Panel controls
Controls["ShutterClose"].EventHandler = function()
	if DebugFunction then print("PanelOff Handler Called") end
	Controls["ShutterOpenStatus"].Boolean = false
	Controls["ShutterState"].String = ''
  local cmd = Commands["Shutter"]
  cmd.params.value ="Closed"
  Send( cmd )
end

-- Input controls
  -- "jsonrpc": "2.0", "method": "property.set", "params": {"property": "image.window.main.source", "value": "DisplayPort 1"} }
for i=1,#Controls['InputButtons'] do
  if InputTypes[i] and InputTypes[i].Name then Controls['InputButtons'][i].Legend = InputTypes[i].Name end
	Controls['InputButtons'][i].EventHandler = function(ctl)
		if ctl.Boolean then
		  if DebugFunction then print("Input["..(InputTypes[i].Name or i).."] button "..tostring(ctl.Boolean)) end
			local cmd = Commands["Input"]
      cmd.params.value = InputTypes[i].Name
			Send( cmd )
		end
	end
end
Controls.Input.EventHandler = function(ctl)
  if DebugFunction then print("Input choice "..ctl.String) end
  local cmd = Commands["Input"]
  cmd.params.value = ctl.String
  Send( cmd )
end

-- Timer EventHandlers  --
Heartbeat.EventHandler = function()
	if DebugFunction then print("Heartbeat Event Handler Called") end
	--if DebugFunction and not DebugTx then print("Heartbeat Event Handler Called") end
  local cmd = { params={property=Properties["Status"]}, method='property.get' } 
	Send( cmd ) -- using this as a KeepAlive, this is already be handled by a subscription
end

-- PowerOn command requires spamming the interface 3 times at 2 second intervals
PowerupTimer.EventHandler = function()
	if Controls["PowerStatus"].Value == 1 then
		PowerupTimer:Stop()
	else
		Send( Commands["PowerOn"], true )
		PowerupCount= PowerupCount + 1
		if PowerupCount>2 then
			PowerupTimer:Stop()
		end
	end
end

  -- Kick it off
  SetupDebugPrint()
  if not StartupTimer:IsRunning() then
      StartupTimer.EventHandler = function()
        print("StartupTimer expired")
        Init()
        StartupTimer:Stop()
      end
      StartupTimer:Start(2)
  end
