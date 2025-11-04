-- Chat Levels and Race Addon
local addonName, addonTable = ...

-- Create a lookup table for Vanilla race and class icons
local raceIcons = {
    ["Human"] = "|TInterface\\Icons\\Achievement_Character_Human_Male:16|t",
    ["Orc"] = "|TInterface\\Icons\\Achievement_Character_Orc_Male:16|t",
    ["Night Elf"] = "|TInterface\\Icons\\Achievement_Character_Nightelf_Male:16|t",
    ["Undead"] = "|TInterface\\Icons\\Achievement_Character_Undead_Male:16|t",
    ["Dwarf"] = "|TInterface\\Icons\\Achievement_Character_Dwarf_Male:16|t",
    ["Tauren"] = "|TInterface\\Icons\\Achievement_Character_Tauren_Male:16|t",
    ["Gnome"] = "|TInterface\\Icons\\Achievement_Character_Gnome_Male:16|t",
    ["Troll"] = "|TInterface\\Icons\\Achievement_Character_Troll_Male:16|t",
}

local classIcons = {
    ["Warrior"] = "|TInterface\\Icons\\ClassIcon_Warrior:16|t",
    ["Mage"] = "|TInterface\\Icons\\ClassIcon_Mage:16|t",
    ["Rogue"] = "|TInterface\\Icons\\ClassIcon_Rogue:16|t",
    ["Druid"] = "|TInterface\\Icons\\ClassIcon_Druid:16|t",
    ["Hunter"] = "|TInterface\\Icons\\ClassIcon_Hunter:16|t",
    ["Paladin"] = "|TInterface\\Icons\\ClassIcon_Paladin:16|t",
    ["Priest"] = "|TInterface\\Icons\\ClassIcon_Priest:16|t",
    ["Shaman"] = "|TInterface\\Icons\\ClassIcon_Shaman:16|t",
    ["Warlock"] = "|TInterface\\Icons\\ClassIcon_Warlock:16|t",
}

-- Event handler
local function AddPrefixToChat(self, event, msg, author, ...)
    local name, _ = strsplit("-", author)
    if not name then return false, msg, author, ... end

    -- Get player info (level, race, and class)
    local level = UnitLevel(name)
    local race = UnitRace(name)
    local class = UnitClass(name)

    -- Build the prefix if data is available
    local prefix = ""
    if raceIcons[race] and classIcons[class] and level then
        local raceIcon = raceIcons[race] or ""
        local classIcon = classIcons[class] or ""
        prefix = string.format("[%s] %s %s: ", level, classIcon, raceIcon)
    elseif not level then
        -- If level is unavailable, fallback to showing just name
        prefix = "[Unknown Level] "
    end

    -- Prepend the prefix to the message
    msg = string.format("%s%s", prefix, msg)

    -- Return the modified message correctly
    return false, msg, author, ...
end

-- Hook the chat filter
for _, event in ipairs({
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_RAID",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_CHANNEL", -- Add channel chat
    "CHAT_MSG_TRADESKILL", -- Add tradeskill chat (for things like crafting)
}) do
    ChatFrame_AddMessageEventFilter(event, AddPrefixToChat)
end

-- Slash command for testing
SLASH_CHATLEVELSRACE1 = "/chatlevels"
SlashCmdList["CHATLEVELSRACE"] = function(msg)
    print("Chat Levels, Race, and Class Addon for Vanilla WoW is active!")
end

-- Add a message when the addon is loaded
local function OnAddonLoaded(self, event, arg1)
    if arg1 == addonName then
        DEFAULT_CHAT_FRAME:AddMessage("Chat Levels and Race Addon loaded! Author: HazorAU/Nekminute")
    end
end

-- Register the event for addon load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnAddonLoaded)
