local STANDALONE = true

if (AzTranslate && STANDALONE && !AzTranslate.Standalone) then
	MsgC(Color(255, 128, 0), "> Standalone version found, reloading...\n")
elseif (AzTranslate) then
	return
end

MsgC(Color(255, 128, 0), "> AzTranslate Loaded\n")
MsgC(Color(255, 128, 0), "> Copyright (c) Azedith, @NotMyWing\n")

include( "az_translate/shared.lua" )

AzTranslate.Standalone = STANDALONE
if SERVER then
	include( "az_translate/sv_init.lua" ) 
else
	include( "az_translate/cl_init.lua" )
end 