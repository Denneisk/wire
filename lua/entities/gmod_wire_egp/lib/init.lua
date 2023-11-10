EGP = {}

--------------------------------------------------------
-- Include all other files
--------------------------------------------------------

local Folder = "entities/gmod_wire_egp/lib/egplib/"
local entries = file.Find( Folder .. "*.lua", "LUA")
for _, entry in ipairs( entries ) do
	if (SERVER) then
		AddCSLuaFile( Folder .. entry )
	end
	include( Folder .. entry )
end

local EGP = EGP

EGP.ConVars = {
	MaxObjects	 = CreateConVar("wire_egp_max_objects", 300, { FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE }, "The maximum number of objects on an EGP screen", 0),
	MaxPerSec	 = CreateConVar("wire_egp_max_bytes_per_sec", 10000, { FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE }, nil, 0), -- Keep between 2500-40000
	MaxVertices	 = CreateConVar("wire_egp_max_poly_vertices", 1024, { FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE }, nil, 0),
	AllowEmitter = CreateConVar("wire_egp_allow_emitter", 1, { FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE  }, "Whether EGP Emitters should be enabled on the server"),
	AllowHUD	 = CreateConVar("wire_egp_allow_hud", 1, { FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE  }, "Whether EGP HUDs should be enabled on the server"),
	AllowScreen	 = CreateConVar("wire_egp_allow_screen", 1, { FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE  }, "Whether EGP Screens should be enabled on the server")
}
