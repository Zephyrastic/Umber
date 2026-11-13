local Games = { 
	[12334109280] = "https://raw.githubusercontent.com/nathanathan69420-pixel/Umber/refs/heads/main/gnb.lua"
}
local ScriptUrl = Games[game.PlaceId]
if not ScriptUrl then
	return
end
local Success, Source = pcall(function()
	return game:HttpGet(ScriptUrl)
end)
local _sc_s1 = not Success or type(Source) ~= "string"
if _sc_s1 or #Source == 0 then
	warn("Umber: failed to download the script for this game.")
	return
end
local Chunk, ErrorMessage = loadstring(Source)
if not Chunk then
	warn("Umber: script failed to compile: " .. tostring(ErrorMessage))
	return
end
Chunk()
