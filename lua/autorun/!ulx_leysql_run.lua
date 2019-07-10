


if(SERVER) then
	util.AddNetworkString("leysql_shitgrp")
	print("Loading ulx leysql!")

	timer.Simple(0.5, function()
		include("ulx_leysql.lua")
	end)
end


local meta = FindMetaTable("Player")
if(not meta) then return end

--start really hacky shit, uids, why ulx, WHY?
AddCSLuaFile()

local function doit()
	print("hacky shit")
	local ucl = ULib and ULib.ucl

	if(ucl) then

		ucl_getuserregisteredid_old = ucl_getuserregisteredid_old or ucl.getUserRegisteredID
		function ucl.getUserRegisteredID( ply )
			if(IsValid(ply)) then return ply:SteamID() end
		end
		
		if(SERVER) then
			for k,v in pairs(player.GetAll()) do
				ucl.probe(v)
			end
		end
	end



end

doit()

if(CLIENT) then
	net.Receive("leysql_shitgrp", function(l)
		local e = net.ReadEntity()
		if(not IsValid(e)) then return end 
		ULib.ucl.authed[e:UniqueID()].group = net.ReadString()
		xgui.processModules()
	end)
end
--end really hacky shit