WireToolSetup.setCategory( "Advanced" )
WireToolSetup.open( "hdd", "Memory - Flash EEPROM", "gmod_wire_hdd", nil, "Flash EEPROMs" )

if ( CLIENT ) then
	language.Add( "Tool.wire_hdd.name", "Flash (EEPROM) tool (Wire)" )
	language.Add( "Tool.wire_hdd.desc", "Spawns flash memory. It is used for permanent storage of data (carried over sessions)" )
	TOOL.Information = { { name = "left", text = "Create/Update flash memory" } }

	WireToolSetup.setToolMenuIcon( "icon16/database.png" )
end
WireToolSetup.BaseLang()
WireToolSetup.SetupMax( 20 )

if (SERVER) then
	function TOOL:GetConVars()
		return self:GetClientNumber("driveid"), self:GetClientNumber("drivecap")
	end
	-- Uses default WireToolObj:MakeEnt's WireLib.MakeWireEnt function
end

TOOL.ClientConVar[ "model" ] = "models/jaanus/wiretool/wiretool_gate.mdl"
TOOL.ClientConVar[ "driveid" ] = 0
TOOL.ClientConVar[ "client_driveid" ] = 0
TOOL.ClientConVar[ "drivecap" ] = 1

TOOL.ClientConVar[ "packet_bandwidth" ] = 100
TOOL.ClientConVar[ "packet_rate" ] = 0.4

local function GetStructName(steamID,HDD,name)
	return "WireFlash/"..(steamID or "UNKNOWN").."/HDD"..HDD.."/"..name..".txt"
end

local function ParseFormatData(formatData)
	local driveCap = 0
	local blockSize = 16
	local formatInfo = string.Explode("\n",formatData)
	if tonumber(formatData) then
		driveCap = tonumber(formatData)
	else
		if formatInfo[1] == "FLASH2" then
			driveCap = tonumber(formatInfo[2]) or 0
			blockSize = tonumber(formatInfo[4]) or 1024
		elseif formatInfo[1] == "FLASH1" then
			driveCap = tonumber(formatInfo[2]) or 0
			blockSize = 32
		end
	end
	return driveCap, blockSize, formatInfo[1], tonumber(formatInfo[3])
end

local function GetFloatTable(Text)
	local text = Text
	local tbl = {}
	local ptr = 0
	while (string.len(text) > 0) do
		local value = string.sub(text,1,24)
		text = string.sub(text,24,string.len(text))
		tbl[ptr] = tonumber(value)
		ptr = ptr + 1
	end
	return tbl
end

local function MakeFloatTable(Table)
	local text = ""
	for i=0,#Table-1 do
		--Clamp size to 24 chars
		local floatstr = string.sub(tostring(Table[i]),1,24)
		--Make a string, and append missing spaces
		floatstr = floatstr .. string.rep(" ",24-string.len(floatstr))

		text = text..floatstr
	end

	return text
end

if SERVER then
	util.AddNetworkString("wire_flash_upload")
	util.AddNetworkString("wire_flash_confirm")
--[[
	local buffer = {}
	local bufferBlock = nil
	concommand.Add("wire_hdd_uploaddata", function(player, command, args)
		local HDDID = tonumber(args[1])
		HDDID = math.floor(HDDID)
		if (not HDDID) or (HDDID < 0) or (HDDID > 3) then return end
		local STEAMID = player:SteamID()
		STEAMID = string.gsub(STEAMID, ":", "_")
		if (STEAMID == "UNKNOWN") or (STEAMID == "STEAM_0_0_0") then
			return
		end

		local address = tonumber(args[2]) or nil
		local value = tonumber(args[3]) or nil
		if not (address and value) then return end
		
		local formatData = file.Read(GetStructName(STEAMID, HDDID, "drive"))
		if not formatData then return end
		local driveCap, blockSize = ParseFormatData(formatData)

		local block = math.floor(address / blockSize)
		if block == bufferBlock then
			buffer[address % blockSize] = value
		else
			if bufferBlock then
					file.Write(GetStructName(STEAMID,HDDID,bufferBlock),MakeFloatTable(buffer))
					file.Write(GetStructName(STEAMID,HDDID,"drive"),
					  "FLASH1\n"..GetConVarNumber("wire_hdd_drivecap").."\n"..(address + 31))
				end
			end

			bufferBlock = block
			buffer = {}
			buffer[address % blockSize] = value
		end
	end)
]]--
	
	local function DownloadData(_,  ply)
		local fmt, HDDID, block, size, blockSize = net.ReadUInt(4), net.ReadInt(8), net.ReadUInt(12), net.ReadUInt(12), net.ReadUInt(16)
		HDDID = math.floor(math.Clamp(HDDID, 0, 3))
		
		local steamID = ply:SteamID()
		steamID = string.gsub(steamID, ":", "_")
		if (steamID == "UNKNOWN") or (steamID == "STEAM_0_0_0") then
			return
		end
		
		if fmt == 2 then
			file.CreateDir("wireflash/".. steamID .. "/HDD" .. HDDID)
			local f = file.Open(GetStructName(steamID, HDDID, block), "wb", "DATA")
			if not f then return ErrorNoHalt("Failed to open " .. steamID .. "/HDD" .. HDDID .. " " .. block) end
			
			for i = 1, size do
				f:WriteDouble(net.ReadDouble())
			end
			
			f:Close()
			
			if net.ReadBool() then
				file.Write(GetStructName(steamID, HDDID, "drive"), string.format("FLASH2\n%s\n%s\n%s", (block + 1), block * blockSize + (size - 1), blockSize))
				net.Start("wire_flash_confirm")
					net.WriteInt(HDDID, 8) -- HDDID
					net.WriteUInt(block * blockSize + (size - 1), 32) -- Total Size
				net.Send(ply)
			end
		else
			local dataTable = {}
			for address = 1, size do
				dataTable[address] = net.ReadFloat()
			end
			
			file.Write(GetStructName("local", HDDID, math.floor(blockSize/size)), MakeFloatTable(dataTable))
			file.Write(GetStructName("local", HDDID, "drive"), "FLASH1\n"..GetConVarNumber("wire_hdd_drivecap").."\n"..(blockSize + size - 1))
		end
	end
	net.Receive("wire_flash_upload", DownloadData)

	-- Download from server to client
	local downloadPointer = {}
	concommand.Add("wire_hdd_download", function(player, command, args)
		local HDDID = tonumber(args[1])
		if (not HDDID) or (HDDID < 0) or (HDDID >= 4) then return end
		HDDID = math.floor(HDDID)
		local STEAMID = player:SteamID()
		STEAMID = string.gsub(STEAMID, ":", "_")
		if (STEAMID == "UNKNOWN") or (STEAMID == "STEAM_0_0_0") then
			return
		end
		
		local TGTHDDID = tonumber(args[2])
		if not TGTHDDID then TGTHDDID = -1 end
		

		local formatData = file.Read(GetStructName(STEAMID, HDDID, "drive"))
		if not formatData then return end
		local driveCap, blockSize, fmt = ParseFormatData(formatData)

		if fmt == "FLASH2" then
			downloadPointer[player:UserID()] = 0
			timer.Remove("wire_flash_download" .. player:UserID())
			timer.Create("wire_flash_download" .. player:UserID(), 0.02, driveCap, function()
				-- Player null check required here?
				local dlptr = downloadPointer[player:UserID()]
				local fname = GetStructName(STEAMID, HDDID, dlptr)
				print("Sending ".. fname)
				if file.Exists(fname, "DATA") then
					local f = file.Open(fname, "rb", "DATA")
					local size = math.min(f:Size() / 8, blockSize)
					net.Start("wire_flash_upload")
						net.WriteUInt(2, 4) -- Format
						net.WriteInt(TGTHDDID, 8) -- Target HDD
						net.WriteUInt(dlptr, 12) -- Block
						net.WriteUInt(size, 12) -- Size
						net.WriteUInt(blockSize, 16) -- Block Size
						for i = 1, size do
							net.WriteDouble(f:ReadDouble())
						end
						
						dlptr = dlptr + 1
						downloadPointer[player:UserID()] = dlptr
						if dlptr >= driveCap then
							net.WriteBool(true)
							timer.Remove("wire_flash_download" .. player:UserID())
						else
							net.WriteBool(false)
						end
					net.Send(player)
				else
					-- Abort
					net.Start("wire_flash_upload")
						net.WriteUInt(2, 4)
						net.WriteInt(TGTHDDID, 8)
						net.WriteUInt(dlptr, 12)
						net.WriteUInt(0, 12)
						net.WriteUInt(blockSize, 16)
						net.WriteBool(true)
					net.Send(player)
					timer.Remove("wire_flash_download" .. player:UserID())
				end
			end)
		-- cbf'd to make FLASH1 downloads right now even though it's probably easier
		-- Also they should automatically reformat to FLASH2
		--[[
		else
			-- Download code
			downloadPointer[player:UserID()] = 0
			timer.Remove("wire_flash_download"..player:UserID())
			timer.Create("wire_flash_download"..player:UserID(),1/60,0,function()

				if file.Exists(GetStructName(STEAMID,HDDID,downloadPointer[player:UserID()])) then
					local dataTable = GetFloatTable(file.Read(GetStructName(STEAMID,HDDID,downloadPointer[player:UserID()])))
					net.Start("wire_flash_upload")
						net.WriteUInt(downloadPointer[player:UserID()] * blockSize)
						net.WriteUInt(blockSize, 16)
						for i = 1, blockSize do
							net.WriteFloat(dataTable[i - 1])
						end
					net.Send(player)
				end

				downloadPointer[player:UserID()] = downloadPointer[player:UserID()] + 1
				if downloadPointer[player:UserID()] >= driveCap*1024/blockSize then
					timer.Remove("flash_download"..player:UserID())
				end
			end)
		]]--
		end
	end)

	-- Clear hard drive
	concommand.Add("wire_hdd_clearhdd", function(player, command, args)
		local HDDID = tonumber(args[1])
		if (not HDDID) or (HDDID < 0) or (HDDID >= 4) then return end
		HDDID = math.floor(HDDID)
		
		local STEAMID = player:SteamID()
		STEAMID = string.gsub(STEAMID or "UNKNOWN", ":", "_")
		if (STEAMID == "UNKNOWN") or (STEAMID == "STEAM_0_0_0") then
			return
		end

		local files = file.Find("wireflash/" .. STEAMID .. "/hdd" .. HDDID .. "/*", "DATA") or {}
		for _, v in ipairs(files) do
			file.Delete("wireflash/" .. STEAMID .. "/hdd" .. HDDID .. "/" .. v)
		end
		file.Delete("wireflash/" .. STEAMID .. "/hdd" .. HDDID)
	end)
else -- CLIENT
	local function DownloadData()
		local fmt, HDDID, block, size, blockSize = net.ReadUInt(4), net.ReadInt(8), net.ReadUInt(12), net.ReadUInt(12), net.ReadUInt(16)
		if HDDID < 0 then HDDID = GetConVarNumber("wire_hdd_client_driveid") end
		HDDID = math.Clamp(HDDID, 0, 99)
		
		if fmt == 2 then
			file.CreateDir("wireflash/local/HDD".. HDDID)
			
			if size > 0 then
				local f = file.Open(GetStructName("local", HDDID, block), "wb", "DATA")
				if not f then return ErrorNoHalt("Failed to open local HDD " .. HDDID .. " " .. block) end
				
				for i = 1, size do
					f:WriteDouble(net.ReadDouble())
				end
				
				f:Close()
			end
			
			if net.ReadBool() then
				file.Write(GetStructName("local", HDDID, "drive"), string.format("FLASH2\n%s\n%s\n%s", block + 1, block * blockSize + (size - 1), blockSize))
				notification.AddLegacy(string.format("HDD %d downloaded (size: %d)", HDDID, block * blockSize + (size - 1)), 0, 3)
			end
		else
			local dataTable = {}
			for address = 1, size do
				dataTable[address] = net.ReadFloat()
			end
			
			file.Write(GetStructName("local", HDDID, math.floor(blockSize/size)), MakeFloatTable(dataTable))
			file.Write(GetStructName("local", HDDID, "drive"), "FLASH1\n"..GetConVarNumber("wire_hdd_drivecap").."\n"..(blockSize + size - 1))
		end
	end
	net.Receive("wire_flash_upload", DownloadData)
	
	net.Receive("wire_flash_confirm", function()
		notification.AddLegacy(string.format("Server received HDD %d (size %d)", net.ReadInt(8), net.ReadUInt(32)), 0, 3)
	end)

	-- This is probably abusable or unsafe in some way
	concommand.Add("wire_hdd_clearhdd_client", function(player, command, args)
		local HDDID = GetConVarNumber("wire_hdd_client_driveid")
		if not HDDID then return end

		local files = file.Find("wireflash/local/hdd" .. HDDID .. "/*", "DATA") or {}
		for _, v in ipairs(files) do
			file.Delete("wireflash/local/hdd" .. HDDID .. "/" .. v)
		end
		file.Delete("wireflash/local/hdd" .. HDDID)
	end)

	-- Upload from client to server
	local uploadPointer = 0
	concommand.Add("wire_hdd_upload", function(player, command, args)
		local HDDID = GetConVarNumber("wire_hdd_client_driveid")
		local TGTHDDID = GetConVarNumber("wire_hdd_driveid")
		local formatData = file.Read(GetStructName("local", HDDID, "drive"))
		if not formatData then return end
		local driveCap, blockSize, fmt, maxSize = ParseFormatData(formatData)

		if fmt == "FLASH2" then
			uploadPointer = 0
			notification.AddLegacy(string.format("Sending client HDD %d to server HDD %d (size: %d)", HDDID, TGTHDDID, maxSize), 0, 3)
			-- DriveCap is effectively halved because you can only effectively store 32 bit integers using Lua. That hopefully shouldn't matter too much.
			-- "128KB" = 1MiB is pretty decent compared to 3MiB.
			timer.Remove("wire_flash_upload")
			timer.Create("wire_flash_upload", 0.02, driveCap, function()
				local fname = GetStructName("local", HDDID, uploadPointer)
				if file.Exists(fname, "DATA") then
					local f = file.Open(fname, "rb", "DATA")
					local size  = math.min(math.floor(f:Size() / 8), blockSize) -- Just send a whole block
					
					net.Start("wire_flash_upload")
						net.WriteUInt(2, 4) -- Format
						net.WriteInt(TGTHDDID, 8) -- Target HDD
						net.WriteUInt(uploadPointer, 12) -- block number
						net.WriteUInt(size, 12) -- Size
						net.WriteUInt(blockSize, 16) -- block size
						
						for i = 1, size do
							net.WriteDouble(f:ReadDouble())
						end
						
						uploadPointer = uploadPointer + 1
						if uploadPointer >= driveCap then
							net.WriteBool(true)
							
							timer.Remove("wire_flash_upload")
						else
							net.WriteBool(false)
						end
					net.SendToServer()
				else
					net.Start("wire_flash_upload")
						net.WriteUInt(2, 4)
						net.WriteInt(TGTHDDID, 8)
						net.WriteUInt(uploadPointer, 12)
						net.WriteUInt(0, 12)
						net.WriteUInt(blockSize, 16)
						
						net.WriteBool(true)
					net.SendToServer()
					timer.Remove("wire_flash_upload")
				end
			end)
		--[[
		else
			-- Upload code
			uploadPointer = 0
			timer.Remove("wire_flash_upload")
			timer.Create("wire_flash_upload", 0.1, 0, function()
				if file.Exists(GetStructName("local", HDDID, uploadPointer)) then
					local dataTable = GetFloatTable(file.Read(GetStructName("SINGLEPLAYER",HDDID,uploadPointer)))
					for i=0,blockSize-1 do
						RunConsoleCommand("wire_hdd_uploaddata",TGTHDDID,i+uploadPointer*blockSize,dataTable[i])
					end
				end

				uploadPointer = uploadPointer + 1
				if uploadPointer >= driveCap*1024/blockSize then
					RunConsoleCommand("wire_hdd_uploadend",TGTHDDID)
				end
			end)
		]]--
		end
	end)
end

function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", { Text = "#Tool.wire_hdd.name", Description = "#Tool.wire_hdd.desc" })

	local mdl = vgui.Create("DWireModelSelect")
	mdl:SetModelList( list.Get("Wire_gate_Models"), "wire_hdd_model" )
	mdl:SetHeight( 5 )
	panel:AddItem( mdl )

	panel:AddControl("Slider", {
		Label = "Drive ID",
		Type = "Integer",
		Min = "0",
		Max = "3",
		Command = "wire_hdd_driveid"
	})

	panel:AddControl("Slider", {
		Label = "Capacity (KB)",
		Type = "Integer",
		Min = "1",
		Max = "256",
		Command = "wire_hdd_drivecap"
	})

	panel:AddControl("Label", { Text = "" })
	panel:AddControl("Label", { Text = "Flash memory manager" })

	panel:AddControl("Slider", {
		Label = "Server drive ID",
		Type = "Integer",
		Min = "0",
		Max = "3",
		Command = "wire_hdd_driveid"
	})

	panel:AddControl("Slider", {
		Label = "Client drive ID",
		Type = "Integer",
		Min = "0",
		Max = "99",
		Command = "wire_hdd_client_driveid"
	})

	local Button = vgui.Create("DButton", panel)
	panel:AddPanel(Button)
	Button:SetText("Download server drive to client drive")
	Button.DoClick = function()
			RunConsoleCommand("wire_hdd_download",GetConVarNumber("wire_hdd_driveid"))
	end

	panel:AddControl("Button", {
		Text = "Upload client drive to server drive",
		Command = "wire_hdd_upload"
	})

	local Button = vgui.Create("DButton", panel)
	panel:AddPanel(Button)
	Button:SetText("Clear server drive")
	Button.DoClick = function()
		RunConsoleCommand("wire_hdd_clearhdd",GetConVarNumber("wire_hdd_driveid"))
	end

	panel:AddControl("Button", {
		Text = "Clear client drive",
		Command = "wire_hdd_clearhdd_client"
	})

end
