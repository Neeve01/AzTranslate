AzTranslate.CurrentLanguage = nil

function AzTranslate.Translatable(key)
	return AzTranslate.GetTranslation(AzTranslate.CurrentLanguage, key) != "N/A"
end

function AzTranslate.SynchronizeLanguage() 
	net.Start("AzTranslate Sync")
		net.WriteString(AzTranslate.CurrentLanguage)
	net.SendToServer()
end

function az_translate(key, ...)
	return AzTranslate.GetTranslation(AzTranslate.CurrentLanguage, key, ...)
end

function az_translatable(key)
	return AzTranslate.Translatable(key)
end

local nextCheck = 0
hook.Add("Initialize", "AzTranslate InitSync", function()
	hook.Add("Think", "AzTranslate LangChange", function()
		if (CurTime() < nextCheck) then return end
		nextCheck = CurTime() + 1

		local new = GetConVarString("gmod_language")
		if (new != AzTranslate.CurrentLanguage) then
			AzTranslate.CurrentLanguage = new
			AzTranslate.SynchronizeLanguage()
		end
	end)
end)

net.Receive("AzTranslate Update", function(len, ply)
	MsgC(Color(64, 255, 64), "> Updating translation keys from server...\n")
	AzTranslate.Keys = net.ReadTable()
	AzTranslate.Aliases = net.ReadTable()
	AzTranslate.Compile(AzTranslate.Keys)
end)