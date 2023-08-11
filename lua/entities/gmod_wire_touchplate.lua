AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")
ENT.PrintName = "Wire Touch Plate"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.WireDebugName = "Touch Plate"

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end
else
	function ENT:Initialize()
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetTrigger(true)

		self.Inputs  = WireLib.CreateInputs (self, { "OnlyPlayers" })
		self.Outputs = WireLib.CreateOutputs(self, { "Touched", "Toucher [ENTITY]", "Touchers [ARRAY]" })

		self.Touchers = {}
		self.only_players = false

		self:UpdateOutputs()
	end

	function ENT:TriggerInput(name, value)
		if name == "OnlyPlayers" then
			self.only_players = value ~= 0
		end
	end

	function ENT:UpdateOutputs()
		local numTouchers = #self.Touchers
		WireLib.TriggerOutput(self, "Touched", numTouchers > 0 and 1 or 0)
		WireLib.TriggerOutput(self, "Toucher", self.Touchers[numTouchers] or NULL)
		WireLib.TriggerOutput(self, "Touchers", self.Touchers)
	end

	function ENT:StartTouch(ent)
		if not self:MyPassesTriggerFilters(ent) then return end
		table.insert(self.Touchers, ent)
		self:UpdateOutputs()
	end

	function ENT:EndTouch(ent)
		for i, v in ipairs(self.Touchers) do
			if v == ent then
				table.remove(self.Touchers, i)
				self:UpdateOutputs()
				break
			end
		end
	end

	function ENT:MyPassesTriggerFilters(ent)
		return ent:IsPlayer() or not self.only_players
	end

	function ENT:Setup(only_players)
		self.only_players = only_players
	end

	duplicator.RegisterEntityClass("gmod_wire_touchplate", WireLib.MakeWireEnt, "Data", "only_players")
end