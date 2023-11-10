--------------------------------------------------------
-- Objects
--------------------------------------------------------
local EGP = EGP
---@type { [string]: EGPObject }
local egpObjects = {}
--- All implemented EGPObjects by lowercase name
EGP.Objects = egpObjects
---@type EGPObject[]
local egpObjectsByID = {}
--- An array of all implemented EGPObjects by ID. Note that ID is not as deterministic as names.
EGP.ObjectsByID = egpObjectsByID

--- A prototypical EGPObject to extend from.
---@class EGPObject
---@field ID integer The ID of the EGPObject class
local baseObj = {
	ID = 0,
	x = 0,
	y = 0,
	angle = 0,
	r = 255,
	g = 255,
	b = 255,
	a = 255,
	filtering = TEXFILTER.ANISOTROPIC,
	parent = 0
}
if SERVER then
	baseObj.material = ""
	baseObj.EGP = NULL --[[@as Entity]] -- EGP entity parent
else
	baseObj.material = false
end

--- Used in a net writing context to transmit the object's entire data.
---@see EGPObject.Receive
function baseObj:Transmit()
	EGP.SendPosAng(self)
	EGP:SendColor( self )
	EGP:SendMaterial(self)
	if self.filtering then net.WriteUInt(math.Clamp(self.filtering,0,3), 2) end
	net.WriteInt( self.parent, 16 )
end
--- Used in a net reading context to read the object's entire data.
---@see EGPObject.Transmit
function baseObj:Receive()
	local tbl = {}
	EGP.ReceivePosAng(tbl)
	EGP:ReceiveColor( tbl, self )
	EGP:ReceiveMaterial( tbl )
	if self.filtering then tbl.filtering = net.ReadUInt(2) end
	tbl.parent = net.ReadInt(16)
	return tbl
end

--- Serializes the data of the EGPObject for transmitting
function baseObj:DataStreamInfo()
	return { x = self.x, y = self.y, angle = self.angle, w = self.w, h = self.h, r = self.r, g = self.g, b = self.b, a = self.a, material = self.material, parent = self.parent }
end
--- Returns `true` if the object contains the point.
---@param x number
---@param y number
---@return boolean
function baseObj:Contains(x, y)
	return false
end

--- Edits the fields of the EGPObject with the given table. Returns `true` if a field changed.
--- Use `SetPos` for setting position directly. Use `Set` to set a single field.
---@param args { [string]: any } The fields to edit on the object. Values are *not* type checked or sanity checked!
---@return boolean # Whether the object changed
---@see EGPObject.SetPos
---@see EGPObject.Set
function baseObj:EditObject(args)
	local ret = false
	if args.x or args.y or args.angle then
		ret = self:SetPos(args.x or self.x, args.y or self.y, args.angle or self.angle)
		args.x, args.y, args.angle = nil, nil, nil
	end
	for k, v in pairs(args) do
		if self[k] ~= nil and self[k] ~= v then
			self[k] = v
			ret = true
		end
	end
	return ret
end

--- A helper method for EGPObjects that may need to do something on initialization. Calls `EditObject` by default.
---@param args { [string]: any }
---@see EGPObject.EditObject
function baseObj:Initialize(args) self:EditObject(args) end

--- Sets the position of the EGPObject directly. This method should be overwritten if special behavior is needed.
--- Call this method when you need to change position.
---@param x number
---@param y number
---@param angle number In degrees
---@return boolean # Whether the position changed
---@see EGPObject.EditObject
function baseObj:SetPos(x, y, angle)
	local ret = false
	if x and self.x ~= x then self.x, ret = x, true end
	if y and self.y ~= y then self.y, ret = y, true end
	if angle then
		angle = angle % 360
		if self.angle ~= angle then self.angle, ret = angle, true end
	end
	return ret
end

--- Sets a single field of the EGP Object. Do **not** use this for position. Use `SetPos` instead.
---@param member string
---@param value any
---@return boolean # Whether the field changed
function baseObj:Set(member, value)
	if self[member] and self[member] ~= value then
		self[member] = value
		return true
	else
		return false
	end
end

local M_EGPObject = {__tostring = function(self) return "[EGPObject] ".. self.Name end}
setmetatable(baseObj, M_EGPObject)
EGP.Objects.Base = baseObj

local M_NULL_EGPOBJECT
local M_NULL_EGPOBJECT = { __tostring = function() return "[EGPObject] NULL" end, __eq = function(_, b) return getmetatable(b) == M_NULL_EGPOBJECT end }
---@type EGPObject
local NULL_EGPOBJECT = setmetatable({}, M_NULL_EGPOBJECT)
--- An invalid EGPObject
EGP.NULL_EGPOBJECT = NULL_EGPOBJECT

--- Gets an instance of the EGPObject class by its numerical ID.
---@param ID integer
---@return EGPObject # A copy (instance) the class
local function getObjectByID(ID)
	return 
	ErrorNoHalt( "[EGP] Error! Object with ID '" .. ID .. "' does not exist. Please post this bug message in the EGP thread on the wiremod forums.\n" )
end
EGP.GetObjectByID = getObjectByID

----------------------------
-- Load all objects
----------------------------

--- Creates a new EGPObject class and returns it reference. If you want to inherit from another class, see `EGP.ObjectInherit`, which properly handles out-of-order loading.
---@param name string The name of the class. Case insensitive.
---@param super EGPObject? The superclass of the class. If nil, defaults to base object.
---@return EGPObject # The EGPObject class
---@see EGP.ObjectInherit
local function newObject(name, super)
	local lower = name:lower() -- Makes my life easier
	if egpObjects[lower] then return egpObjects[lower] end

	if not super then super = baseObj end

	local newObj = {}

	newObj.Name = name
	table.Inherit(newObj, super)

	newObj.ID = #egpObjectsByID

	egpObjects[lower] = newObj
	egpObjectsByID[ID] = newObj

	return setmetatable(newObj, M_EGPObject)
end
EGP.NewObject = newObject

local folder = "entities/gmod_wire_egp/lib/objects/"

--- Used to inherit from another EGPObject class.
---@return EGPObject # The new class
function EGP.ObjectInherit(to, from)
	from = from:lower()
	local super = egpObjects[from]
	if not super then
		coroutine.yield(false, from)
		super = egpObject[from]
	end
	if super then
		return newObject(to, super)
	else
		ErrorNoHalt(string.format("EGP couldn't find object %q to inherit from (to object %q).\n", from, to))
		return NULL_EGPOBJECT
	end
end

do
	local files = file.Find(folder.."*.lua", "LUA")
	local suspended = {}
	local function yieldedProcess(target)
		for _, rout in ipairs(target) do
			local _, _, ret = rout.resume() -- Assume it succeeds this time

			local suspendedFor = suspended[ret]
			if suspendedFor then yieldedProcess(suspendedFor) end -- Recursively include everything else
		end
	end

	for _, v in ipairs(files) do
		if not egpObjects[v:sub(1, #v - 4):lower()] then -- Remove the extension and check if the object already exists.
			local co = coroutine.create(function()
				local ret = include(folder .. v)
				AddCSLuaFile(folder .. v)
				return true, ret.Name:lower()
			end)

			local _, success, ret = coroutine.resume(co)
			local suspendedFor = suspended[ret]
			if success then
				if suspendedFor then
					yieldedProcess(suspendedFor)
				end
			else
				if not suspendedFor then
					suspendedFor = {}
					suspended[ret] = suspendedFor
				end
				suspendedFor[#suspendedFor + 1] = co
			end
		end
	end
end

----------------------------
-- Object existance check
----------------------------
function EGP:HasObject( Ent, index )
	if not EGP:ValidEGP(Ent) then return false end
	if SERVER then index = math.Round(math.Clamp(index or 1, 1, self.ConVars.MaxObjects:GetInt())) end
	if not Ent.RenderTable or #Ent.RenderTable == 0 then return false end
	for k,v in pairs( Ent.RenderTable ) do
		if (v.index == index) then
			return true, k, v
		end
	end
	return false
end

----------------------------
-- Object order changing
----------------------------
function EGP:SetOrder(ent, from, to, dir)
	if not ent.RenderTable or #ent.RenderTable == 0 then return false end
	dir = dir or 0

	if ent.RenderTable[from] then
		to = math.Clamp(math.Round(to or 1),1,#ent.RenderTable)
		if SERVER then ent.RenderTable[from].ChangeOrder = {target=to,dir=dir} end
		return true
	end
	return false
end

local already_reordered = {}
function EGP:PerformReorder_Ex(ent, originIdx, maxn)
	local obj = ent.RenderTable[originIdx]
	local idx = obj.index
	if obj then
		-- Check if this object has already been reordered
		if already_reordered[idx] then
			-- if yes, get its new position (or old position if it didn't change)
			return already_reordered[idx]
		end

		-- Set old position (to prevent recursive loops)
		already_reordered[idx] = originIdx

		if obj.ChangeOrder then
			local target = obj.ChangeOrder.target
			local dir = obj.ChangeOrder.dir

			local targetIdx = 0
			if dir == 0 then
				-- target is absolute position
				targetIdx = target
			else
				-- target is relative position
				local bool, k = self:HasObject(ent, target)
				if bool then
					-- Check for order dependencies
					k = self:PerformReorder_Ex(ent, k, maxn) or k

					targetIdx = k + dir
				else
					targetIdx = target
				end
			end

			if targetIdx > 0 then
				-- Make a copy of the object and insert it at the new position
				targetIdx = math.Clamp(targetIdx, 1, maxn)
				if originIdx ~= targetIdx then
					local ob = table.remove(ent.RenderTable, originIdx)
					table.insert(ent.RenderTable, targetIdx, ob)
				end

				obj.ChangeOrder = nil

				-- Update already reordered reference to new position
				already_reordered[idx] = targetIdx

				return targetIdx
			else
				return originIdx
			end
		end
	end
end

function EGP:PerformReorder(ent)
	-- Reset, just to be sure
	already_reordered = {}

	-- Now we remove and create at the same time!
	local maxn = #ent.RenderTable
	for i, _ in ipairs(ent.RenderTable) do
		self:PerformReorder_Ex(ent, i, maxn)
	end

	-- Clear some memory
	already_reordered = {}
end

----------------------------
-- Create / edit objects
----------------------------

function EGP:CreateObject( Ent, ObjID, Settings )
	if not self:ValidEGP(Ent) then return false, NULL_EGPOBJECT end

	if not self.Objects.Names_Inverted[ObjID] then
		ErrorNoHalt("Trying to create nonexistant object! Please report this error to Divran at wiremod.com. ObjID: " .. ObjID .. "\n")
		return false, NULL_EGPOBJECT
	end

	if SERVER then Settings.index = math.Round(math.Clamp(Settings.index or 1, 1, self.ConVars.MaxObjects:GetInt())) end
	Settings.EGP = Ent

	local bool, k, v = self:HasObject( Ent, Settings.index )
	if (bool) then -- Already exists. Change settings:
		if v.ID ~= ObjID then -- Not the same kind of object, create new
			local Obj = self:GetObjectByID( ObjID )
			Obj:Initialize(Settings)
			Obj.index = Settings.index
			Ent.RenderTable[k] = Obj
			return true, Obj
		else
			return v:EditObject(Settings), v
		end
	else -- Did not exist. Create:
		local Obj = self:GetObjectByID( ObjID )
		Obj:Initialize(Settings)
		Obj.index = Settings.index
		table.insert( Ent.RenderTable, Obj )
		return true, Obj
	end
end

function EGP:EditObject(obj, settings)
	return obj:EditObject(settings)
end



--------------------------------------------------------
--  Homescreen
--------------------------------------------------------

EGP.HomeScreen = {}

local mat
if CLIENT then mat = Material else mat = function( str ) return str end end

-- Create table
local tbl = {
	{ ID = EGP.Objects.Names["Box"], Settings = { x = 256, y = 256, h = 356, w = 356, material = mat("expression 2/cog"), r = 150, g = 34, b = 34, a = 255 } },
	{ ID = EGP.Objects.Names["Text"], Settings = {x = 256, y = 256, text = "EGP 3", font = "WireGPU_ConsoleFont", valign = 1, halign = 1, size = 50, r = 135, g = 135, b = 135, a = 255 } }
}

--[[ Old homescreen (EGP v2 home screen design contest winner)
local tbl = {
	{ ID = EGP.Objects.Names["Box"], Settings = {		x = 256, y = 256, w = 362, h = 362, material = true, angle = 135, 					r = 75,  g = 75, b = 200, a = 255 } },
	{ ID = EGP.Objects.Names["Box"], Settings = {		x = 256, y = 256, w = 340, h = 340, material = true, angle = 135, 					r = 10,  g = 10, b = 10,  a = 255 } },
	{ ID = EGP.Objects.Names["Text"], Settings = {		x = 229, y = 28,  text =   "E", 	size = 100, fontid = 4, 						r = 200, g = 50, b = 50,  a = 255 } },
	{ ID = EGP.Objects.Names["Text"], Settings = {	 	x = 50,  y = 200, text =   "G", 	size = 100, fontid = 4, 						r = 200, g = 50, b = 50,  a = 255 } },
	{ ID = EGP.Objects.Names["Text"], Settings = {		x = 400, y = 200, text =   "P", 	size = 100, fontid = 4, 						r = 200, g = 50, b = 50,  a = 255 } },
	{ ID = EGP.Objects.Names["Text"], Settings = {		x = 228, y = 375, text =   "2", 	size = 100, fontid = 4, 						r = 200, g = 50, b = 50,  a = 255 } },
	{ ID = EGP.Objects.Names["Box"], Settings = {		x = 256, y = 256, w = 256, h = 256, material = mat("expression 2/cog"), angle = 45, 		r = 255, g = 50, b = 50,  a = 255 } },
	{ ID = EGP.Objects.Names["Box"], Settings = {		x = 128, y = 241, w = 256, h = 30, 	material = true, 									r = 10,  g = 10, b = 10,  a = 255 } },
	{ ID = EGP.Objects.Names["Box"], Settings = {		x = 241, y = 128, w = 30,  h = 256, material = true, 									r = 10,  g = 10, b = 10,  a = 255 } },
	{ ID = EGP.Objects.Names["Circle"], Settings = {	x = 256, y = 256, w = 70,  h = 70, 	material = true, 									r = 255, g = 50, b = 50,  a = 255 } },
	{ ID = EGP.Objects.Names["Box"], Settings = {	 	x = 256, y = 256, w = 362, h = 362, material = mat("gui/center_gradient"), angle = 135, 	r = 75,  g = 75, b = 200, a = 75  } },
	{ ID = EGP.Objects.Names["Box"], Settings = {		x = 256, y = 256, w = 362, h = 362, material = mat("gui/center_gradient"), angle = 135, 	r = 75,  g = 75, b = 200, a = 75  } }
}
]]

-- Convert table
for k,v in pairs( tbl ) do
	local obj = EGP:GetObjectByID( v.ID )
	obj.index = k
	for k2,v2 in pairs( v.Settings ) do
		if obj[k2] ~= nil then obj[k2] = v2 end
	end
	table.insert( EGP.HomeScreen, obj )
end
