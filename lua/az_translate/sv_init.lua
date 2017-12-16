AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

AzTranslate.ScriptPath = "data/azt/%s"

AzTranslate.ClientAliases = AzTranslate.Aliases or {}
AzTranslate.ServerAliases = AzTranslate.Aliases or {}
AzTranslate.ClientKeys = AzTranslate.ClientKeys or {}
AzTranslate.ServerKeys = AzTranslate.ServerKeys or {}

AzTranslate.PlayerLanguage = AzTranslate.PlayerLanguage or {}

local SIDE_CLIENT = 1
local SIDE_SERVER = 2
local SIDE_SHARED = 3

util.AddNetworkString("AzTranslate Update")
util.AddNetworkString("AzTranslate Sync")

function AzTranslate.SetKV(side, lang, key, str)
	if (side == SIDE_CLIENT || side == SIDE_SHARED) then
		AzTranslate.ClientKeys[key] = AzTranslate.ClientKeys[key] or {}
		AzTranslate.ClientKeys[key][lang] = str
		return
	end
	if (side == SIDE_SERVER || side == SIDE_SHARED) then
		AzTranslate.ServerKeys[key] = AzTranslate.ServerKeys[key] or {}
		AzTranslate.ServerKeys[key][lang] = str
		return
	end	
end

function AzTranslate.SetAlias(side, key, value)
	if (side == SIDE_CLIENT || side == SIDE_SHARED) then
		AzTranslate.ClientAliases[key] = value
		return
	end
	if (side == SIDE_SERVER || side == SIDE_SHARED) then
		AzTranslate.ServerAliases[key] = value
		return
	end	
end

function AzTranslate.SyncLanguages()
	net.Start("AzTranslate Sync")
	net.Broadcast()
end

function AzTranslate.SendUpdates(keys, aliases)
	net.Start("AzTranslate Update")
		net.WriteTable(keys)
		net.WriteTable(aliases)
	net.Broadcast()
end

function AzTranslate.ReloadFiles()
	AzTranslate.ClientKeys = {}
	AzTranslate.ServerKeys = {}
	AzTranslate.Aliases = {}
	AzTranslate.Variables = {}
	
	MsgC(Color(128, 255, 128), "> Reloading AzTranslate files...\n") 
	local files = file.Find("data/azt/*.txt", "GAME")
	for k, v in pairs(files) do
		local side = v:match("(...)")
		local client = side != "sv_"
		local server = side != "cl_"
		if (client && server) then
			side = SIDE_SHARED
		elseif (client && !server) then
			side = SIDE_CLIENT
		elseif (!client && server) then
			side = SIDE_SERVER
		end
				
		local locale = "en"
		local line_counter = 0
		MsgC(Color(128, 255, 128), string.format("- > %s\n", v)) 
		local f = file.Read(string.format(AzTranslate.ScriptPath, v), "GAME"):Replace("\r\n", "\n"):Split("\n")
		while (line_counter < #f) do
			line_counter = line_counter + 1
			local line = f[line_counter]
	
			-- Trim comments and spaces
			line = line:gsub("(.+)%s(%/%/.+)", "%1"):Trim()
			
			-- Command
			if (line:match("@(%w+)%s*(.+)")) then
				cmd, args = line:match("@(%w+)%s*(.+)")
				cmd = cmd:lower()
				
				-- Trim spaces
				cmd = cmd:Trim()
				args = args:Trim()
				if (cmd == "setlocale") then
					local loc = args:match("(.+)")
					
					if (loc && #loc == 0) then loc = nil end
					
					if (!loc) then
						MsgC(Color(255, 128, 0), "! Syntax error [", line, ", ", line_counter,"]: ", Color(255,128,128), "@setlocale LOCALE expected\n")
						continue
					end
					locale = loc
				elseif (cmd == "set") then
					local what, to = args:match("(.+)%s*=%s*(.+)")
					
					if (what && #what == 0) then what = nil end
					if (to && #to == 0) then to = nil end
					
					if (!what or !to) then
						MsgC(Color(255, 128, 0), "! Syntax error [", line, ", ", line_counter,"]: ", Color(255,128,128), "@set WHAT = TO expected\n")
						continue
					end
					AzTranslate.Variables[what:lower():Trim()] = to:Trim()
				elseif (cmd == "alias") then
					local what, to = args:match("(.+)%s*=%s*(.+)")
					
					if (what && #what == 0) then what = nil end
					if (to && #to == 0) then to = nil end
					
					if (!what or !to) then
						MsgC(Color(255, 128, 0), "! Syntax error [", line, ", ", line_counter,"]: ", Color(255,128,128), "@alias WHAT = TO expected\n")
						continue
					end
					AzTranslate.SetAlias(side, what:Trim(), to:Trim())
				else
					MsgC(Color(255, 128, 0), "! Unrecognized command [", line, ", ", line_counter,"]: ", Color(64,255,64), "@", cmd, "\n")
				end
				continue
			-- Keyvalue
			elseif (line:match("(.+)%s*=%s*(.+)")) then
				local key, value = line:match("(.+)%s*=%s*(.+)")
				if (key && #key == 0) then key = nil end
				if (value && #value == 0) then value = nil end
				
				local lua_s, lua_e = value:find("[LUA]", 1, true)
				if (lua_s && lua_s == 1) then
					local line = value
					local lua_start = line_counter
					local lua_string = line:sub(lua_e + 1, -1)
					
					while (true) do
						local luaend_s, luaend_e = line:find("[/LUA]", 1, true)
						if (luaend_s) then
							lua_string = lua_string .. "\n" .. line:sub(1, luaend_s - 1)
							break
						else
							if (lua_start != line_counter) then
								lua_string = lua_string .. "\n" .. line
							end
							line_counter = line_counter + 1
							if (line_counter > #f) then
								MsgC(Color(255, 128, 0), "! Embed Lua error [", line, ", ", line_counter,"]: ", Color(64,255,64), "[/LUA] expected (to close [LUA] at line", lua_start,").\n")
								return
							end
							line = f[line_counter]
						end
					end

					-- TODO: Sandboxing?
					local value = {}
					value.Type = "LUA"
					value.Value = string.format("return function(...)\n%s\nend", lua_string)
					
					AzTranslate.SetKV(side, locale:lower(), key:Trim(), value) 
				elseif (lua_s && lua_s != 1) then
					MsgC(Color(255, 128, 0), "! Embed Lua error [", line, ", ", line_counter,"]: ", Color(64,255,64), "Embed lua tag can only start KeyValue. Skipping entire block.\n")
				else			
					if (key && value) then
						AzTranslate.SetKV(side, locale:lower(), key:Trim(), value:Trim())
					end
				end
			elseif (#line != 0) then
				MsgC(Color(255, 128, 0), "! Syntax error [", line, ", ", line_counter,"]: ", Color(255,128,128), "Unknown line: ", line, "\n")
			end
		end
	end
	
	AzTranslate.Keys = AzTranslate.ServerKeys
	AzTranslate.Aliases = AzTranslate.ServerAliases
	
	AzTranslate.SendUpdates(AzTranslate.ClientKeys, AzTranslate.ClientAliases)
	AzTranslate.Compile(AzTranslate.ServerKeys)
end

AzTranslate.ReloadFiles()

--[[ -----------
		Hooks
]]   -----------

hook.Add("PlayerAuthed", "AzTranslate PlayerAuthed", function(ply)
	net.Start("AzTranslate Update")
		net.WriteTable(AzTranslate.ClientKeys)
		net.WriteTable(AzTranslate.ClientAliases)
	net.Send(ply)
end)

net.Receive("AzTranslate Sync", function(len, ply)
	local old = AzTranslate.PlayerLanguage[ply]
	AzTranslate.PlayerLanguage[ply] = net.ReadString()

	if (old != AzTranslate.PlayerLanguage[ply]) then
		MsgC(Color(64, 255, 64), string.format("> Synced %s's language: %s.\n", ply:Nick(), AzTranslate.PlayerLanguage[ply]) )
	end
end)

concommand.Add( "azt_reload", function()
	AzTranslate.ReloadFiles()
end )

--[[ ----------
		Meta
]]   ----------

PLAYER = FindMetaTable("Player")

function PLAYER:AzTranslate_SendUpdates(keys, aliases)
	net.Start()
		net.WriteTable(keys)
		net.WriteTable(aliases)
	net.Send(self)
end

function PLAYER:AzTranslate(key, ...)
	-- TODO:
end