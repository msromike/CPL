-- CPL Integration for Chattynator
-- Prepend player levels to names in social chat channels

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("CHANNEL_UI_UPDATE")

-- Social channel patterns to detect
local SOCIAL_CHANNEL_PATTERNS = {
    "General",
    "Trade",
    "LocalDefense",
    "LookingForGroup",
    "WorldDefense",
    "Services"
}

-- Store detected social channel IDs (key = channelID, value = channelName)
local socialChannels = {}

-- Discover all numbered channels and identify social ones
local function DiscoverChannels()
    if not (CPL and CPL.debug) then
        return
    end

    CPL:debug("CHAT", "=== CHANNEL DISCOVERY ===")

    -- Reset social channels table
    socialChannels = {}

    -- Scan for channels
    for i = 1, 50 do
        local channelID, channelName = GetChannelName(i)
        if channelID > 0 and channelName then
            CPL:debug("CHAT", string.format("Channel %d (ID %d): %s", i, channelID, channelName))

            -- Check if this matches any social channel pattern
            for _, pattern in ipairs(SOCIAL_CHANNEL_PATTERNS) do
                if channelName:find(pattern, 1, true) then
                    socialChannels[channelID] = channelName
                    CPL:debug("CHAT", string.format(">>> Social channel: %s (ID %d)", channelName, channelID))
                    break
                end
            end
        end
    end

    CPL:debug("CHAT", "========================")
end

-- Add levels to player names in social channels
local function AddLevelsToChat(data)
    if not (data.typeInfo and data.typeInfo.channel) then
        return
    end

    -- Check if this is a social channel we care about
    local channelID = data.typeInfo.channel.index
    if not socialChannels[channelID] then
        return  -- Not a social channel, skip
    end

    -- Reconstruct player hyperlinks with level-prefixed names and class colors
    local modifiedText = data.text:gsub("(|Hplayer:([^:]+)[^|]*|h)(|cff%x%x%x%x%x%x)([^|]+)|r(|h)", function(header, hyperlinkName, colorCode, displayName, closer)
        -- Strip realm suffix from name (e.g., "Name-Realm" -> "Name")
        local nameOnly = hyperlinkName:match("^([^%-]+)") or hyperlinkName

        -- Look up level from CPL cache
        local level = CPL:getLevel(nameOnly)
        local levelPrefix = level and string.format("[%d] ", level) or "[??] "

        -- Rebuild: |Hplayer:...|h|cffCOLOR[Level] Name|r|h
        return header .. colorCode .. levelPrefix .. displayName .. "|r" .. closer
    end)

    -- Apply modified text to display in chat
    data.text = modifiedText
end

local function InitIntegration()
    if not (CPL and Chattynator and Chattynator.API and Chattynator.API.AddModifier) then
        return
    end

    CPL:debug("SYSTEM", "Chattynator integration initializing")

    -- Discover channels once on init
    DiscoverChannels()

    -- Register modifier to add levels to all social channels
    Chattynator.API.AddModifier(AddLevelsToChat)

    CPL:debug("SYSTEM", "Chattynator integration ready")
end

frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "CPL" or addonName == "Chattynator" then
            InitIntegration()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        if CPL and CPL.debug then
            CPL:debug("SYSTEM", "Zone changed - rescanning channels")
            DiscoverChannels()
        end
    elseif event == "CHANNEL_UI_UPDATE" then
        if CPL and CPL.debug then
            CPL:debug("SYSTEM", "Channels updated - rescanning")
            DiscoverChannels()
        end
    end
end)