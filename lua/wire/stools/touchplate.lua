WireToolSetup.setCategory("Detection")
WireToolSetup.open("touchplate", "Touch Plate", "gmod_wire_touchplate", nil, "Touch Plates")

if CLIENT then
	language.Add("Tool.wire_touchplate.name", "Wire Touch Plate")
	language.Add("Tool.wire_touchplate.desc", "Spawns a touch plate that outputs when it's touched.")

	language.Add("Tool.wire_touchplate.only_players", "Only trigger for players")

	language.Add("undone_WireTouchplate", "Undone Wire Touch Plate")
	language.Add("Cleanup_wire_touchplates", "Wire Touch Plates")
	language.Add("Cleaned_wire_touchplates", "Cleaned up all Wire Touch Plates")
	language.Add("SBoxLimit_wire_touchplates", "You've reached the touch plates limit!")
end
WireToolSetup.BaseLang()
WireToolSetup.SetupMax(20)

if SERVER then
	function TOOL:GetConVars()
		return
			self:GetClientNumber("only_players") ~= 0
	end
end

TOOL.ClientConVar = {
	model		 = "models/props_phx/construct/metal_plate1.mdl",
	only_players = 1,
	createflat	 = 1
}

function TOOL.BuildCPanel(panel)
	ModelPlug_AddToCPanel(panel, "Touchplate", "wire_touchplate", true, 6)

	panel:CheckBox("#Tool.wire_touchplate.only_players", "wire_touchplate_only_players")
	panel:CheckBox("#Create Flat to Surface", "wire_touchplate_createflat")
end
