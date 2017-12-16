AzTranslate = AzTranslate or {}
AzTranslate.Keys = AzTranslate.Keys or {}
AzTranslate.Aliases = AzTranslate.Aliases or {}

function AzTranslate.Fallback(lang, key, ...)
	if (lang != "en") then
		return AzTranslate.GetTranslation("en", key, ...)
	else
		-- MsgC(Color(255, 128, 0), "! Translation key \"", key,"\" not found!\n")
		return "N/A"
	end
end

function AzTranslate.GetLanguage(lang)
	return AzTranslate.Aliases[lang] and AzTranslate.Aliases[lang] or lang
end	

local attributePattern = "(%[%!att.-%])"
local attributeInnerPattern = "%[!att%s*(.-)%s*%]"

function AzTranslate.GetTranslation(lang, key, ...)
	local lang = AzTranslate.GetLanguage(lang)
	local tkey = AzTranslate.Keys[key]
	if (!tkey) then
		return AzTranslate.Fallback(lang, key, ...)
	end
	local keylang = tkey[lang]
	if (!keylang) then
		return AzTranslate.Fallback(lang, key, ...)
	end
	
	local translated = "N/A"
	if (type(keylang) == "function") then
		translated = keylang(...)
	else
		local vararg = {...}
		local success
		success, translated = pcall(function()
			return (#vararg > 0) and string.format(keylang, unpack(vararg)) or keylang
		end)
		
		if (!success) then
			MsgC(Color(255, 128, 0), "! Invalid translation format: \"", translated,"\"!\n")
			MsgC(Color(255, 128, 0), "! Key = ", key, "\n")
			return "N/A"
		end
	end
	
	local attributed = translated:match(attributePattern)
	if (attributed) then
		local result = {}
		translated:gsub(attributePattern, function(attribute)
			local hresult = hook.Run("AzTranslate:Attribute", attribute:match(attributeInnerPattern))
			
			local att_start, att_end = translated:find(attribute, 1, true)
			local pre = translated:sub(1, att_start - 1)
			local post = translated:sub(att_end + 1, -1)
			
			if (pre && #pre > 0) then
				table.insert(result, pre)
			end
			
			if (hresult) then
				table.insert(result, hresult)
			end
			
			translated = post
		end)
		if (translated && #translated > 0) then
			table.insert(result, translated)
		end
		
		return unpack(result)
	end
	
	return translated
end

function AzTranslate.Compile(kv)
	for gkey, item in pairs(kv) do
		for lang, value in pairs(item) do
			if (type(value) == "table" && value.Type == "LUA") then
				item[lang] = CompileString(value.Value or "", "AzTranslate Key " .. gkey)() or "N/A"
			end
		end
	end
end

hook.Add("AzTranslate:Attribute", "Default Attributes", function(attribute)
	local name, remainder = attribute:match("([^%s]+)%s*(.*)")

	-- Color
	if (name == "color") then
		local r, g, b = remainder:match("([^%s]+)%s*([^%s]+)%s*([^%s]+)")
		return Color(tonumber(r), tonumber(g), tonumber(b))
	end
end)
