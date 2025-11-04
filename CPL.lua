-- CPL - Chat Player Levels
-- Adds player levels to chat messages
local addonName, CPL = ...

-- Database for storing player levels
CPL.db = {}

-- Events that carry player info
local CHAT_EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE"
}

-- Frame for event handling
local frame = CreateFrame("Frame")

-- Function to get/cache player level
local function GetPlayerLevel(playerName)
    if not playerName then return nil end

    -- Remove server name if present
    local name = strsplit("-", playerName)

    -- Check cache first
    if CPL.db[name] then
        return CPL.db[name]
    end

    -- Try to get level from inspection/targeting
    -- This is limited in Classic but we'll cache what we can get
    if UnitExists("target") and UnitName("target") == name then
        local level = UnitLevel("target")
        if level and level > 0 then
            CPL.db[name] = level
            return level
        end
    end

    return nil
end

-- Function to modify chat messages
local function AddLevelToChat(self, event, msg, author, ...)
    local level = GetPlayerLevel(author)
    local name = strsplit("-", author)

    -- Always show level - either known level or [??] for unknown
    local levelDisplay = level and ("[" .. level .. "]") or "[??]"
    local modifiedMsg = msg:gsub(name, name .. " " .. levelDisplay)

    return false, modifiedMsg, author, ...
end

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonLoaded = ...
        if addonLoaded == addonName then
            -- Initialize saved variables
            if not CPLDB then
                CPLDB = {}
            end
            CPL.db = CPLDB
            print("CPL - Chat Player Levels loaded")
        end
    elseif event == "PLAYER_LOGOUT" then
        -- Save database
        CPLDB = CPL.db
    end
end

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", OnEvent)

-- Hook chat message filters
for _, event in pairs(CHAT_EVENTS) do
    ChatFrame_AddMessageEventFilter(event, AddLevelToChat)
end

-- Hook target changes to cache levels
local targetFrame = CreateFrame("Frame")
targetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
targetFrame:SetScript("OnEvent", function(self, event)
    if UnitExists("target") and UnitIsPlayer("target") then
        local name = UnitName("target")
        local level = UnitLevel("target")
        if name and level and level > 0 then
            CPL.db[name] = level
        end
    end
end)

-- Expose CPL globally for debugging
_G.CPL = CPL