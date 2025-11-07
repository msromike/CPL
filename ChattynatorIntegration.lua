-- CPL Integration for Chattynator
-- Discover and report all available channels

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Store Trade channel ID
local tradeChannelID = nil

-- Discover all numbered channels and report them
local function DiscoverChannels()
    if not (CPL and CPL.debug) then
        return
    end

    CPL:debug("CHAT", "=== CHANNEL DISCOVERY ===")

    -- Scan a wide range - GetChannelName returns 0 if channel doesn't exist
    for i = 1, 50 do
        local channelID, channelName = GetChannelName(i)
        if channelID > 0 and channelName then
            CPL:debug("CHAT", string.format("Channel %d (ID %d): %s", i, channelID, channelName))

            -- Store Trade channel ID
            if channelName:find("Trade", 1, true) then
                tradeChannelID = channelID
                CPL:debug("CHAT", string.format(">>> Trade channel found: ID %d", channelID))
            end
        end
    end

    CPL:debug("CHAT", "========================")
end

-- Echo Trade channel messages to debug
local function EchoTrade(data)
    if not (data.typeInfo and data.typeInfo.channel) then
        return
    end

    -- Check if this is the Trade channel
    if data.typeInfo.channel.index == tradeChannelID then
        -- Escape pipes to show raw hyperlink codes
        local escapedText = data.text:gsub("|", "||")
        CPL:debug("CHAT", string.format("TRADE RAW: %s", escapedText))
        CPL:debug("CHAT", string.format("TRADE RENDERED: %s", data.text))
    end
end

local function InitIntegration()
    if not (CPL and Chattynator and Chattynator.API and Chattynator.API.AddModifier) then
        return
    end

    CPL:debug("SYSTEM", "Chattynator integration initializing")

    -- Discover channels once on init
    DiscoverChannels()

    -- Register modifier to echo Trade messages
    Chattynator.API.AddModifier(EchoTrade)

    CPL:debug("SYSTEM", "Chattynator integration ready")
end

frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "CPL" or addonName == "Chattynator" then
            InitIntegration()
        end
    end
end)