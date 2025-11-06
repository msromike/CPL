-- CPL - Chat Player Levels
-- Minimal Prat-style level caching system

-- Addon namespace
local CPL = {}

-- Debug system - easily toggleable
CPL.debugMode = true

function CPL:debug(...)
    if self.debugMode then
        print("CPL DEBUG:", ...)
    end
end

function CPL:toggleDebug()
    self.debugMode = not self.debugMode
    print("CPL Debug mode:", self.debugMode and "ON" or "OFF")
end

-- WHO query queue (memory only)
CPL.WhoQueue = {}

-- Cache expiry time in seconds (2 hours)
CPL.cacheExpiry = 7200

-- Persistent storage - create on init if missing
local function InitDB()
    if not CPLDB then
        CPLDB = {
            players = {}  -- [playername:lower()] = {level, timestamp}
        }
    end
end

-- Core function to store player data
function CPL:addName(Name, Level, Source)
    local key = Name and Name:lower()
    local existing = key and CPLDB.players[key]

    -- Skip if invalid data or already cached at max level (immutable)
    if not (Name and Level and Level > 0) or (existing and existing[1] == 60) then
        return
    end

    local now = time()
    CPLDB.players[key] = {Level, now}

    -- Debug output
    self:debug(Source .. ":", Name, "-", Level, "[" .. now .. "]")
end

-- Retrieval function
function CPL:getLevel(player)
    local key = player:lower()
    local data = CPLDB.players[key]
    return data and data[1]
end

-- Debug function to inspect cache contents
function CPL:debugCache()
    print("=== CPL CACHE DEBUG ===")
    print("Players:")
    for name, data in pairs(CPLDB.players) do
        print("  " .. name .. " = level " .. data[1] .. " [" .. data[2] .. "]")
    end
    print("======================")
end

-- Debug function to inspect WHO queue
function CPL:debugQueue()
    print("=== CPL WHO QUEUE ===")
    local count = 0
    for name, _ in pairs(self.WhoQueue) do
        print("  " .. name)
        count = count + 1
    end
    print("Total: " .. count .. " players")
    print("=====================")
end

-- Show help text (auto-generated from commands table)
function CPL:showHelp()
    print("CPL Commands:")
    for cmd, info in pairs(CPL.commands) do
        local usage = "/cpl " .. cmd
        if info.args then
            usage = usage .. " " .. info.args
        end
        print("  " .. usage .. " - " .. info.desc)
    end
end

-- Initialize database on load
InitDB()
CPL:debug("Database initialized")

-- Command table for easy extension (one line to add new commands)
CPL.commands = {
    debug = {func = "toggleDebug", desc = "Toggle debug mode on/off"},
    cache = {func = "debugCache", desc = "Show cache contents"},
    queue = {func = "debugQueue", desc = "Show WHO queue contents"},
    help = {func = "showHelp", desc = "Show this help"}
}

-- Clean slash command system
SLASH_CPL1 = "/cpl"
SlashCmdList["CPL"] = function(msg)
    local cmd, arg = strsplit(" ", msg, 2)
    cmd = cmd or "help"

    local command = CPL.commands[cmd]
    if command then
        -- Handle commands that require arguments
        if command.args and not arg then
            print("Usage: /cpl " .. cmd .. " " .. command.args)
        else
            -- Call the function
            CPL[command.func](CPL, arg)
        end
    else
        CPL:showHelp()
    end
end

-- Target detection function
function CPL:updateTarget()
    if not UnitIsPlayer("target") or not UnitIsFriend("player", "target") then
        return
    end
    local Name = UnitName("target")
    self:addName(Name, UnitLevel("target"), "TARGET")
end

-- MouseOver detection function
function CPL:updateMouseOver()
    if not UnitIsPlayer("mouseover") or not UnitIsFriend("player", "mouseover") then
        return
    end
    local Name = UnitName("mouseover")
    self:addName(Name, UnitLevel("mouseover"), "MOUSE")
end

-- Party detection function
function CPL:updateParty()
    for i = 1, GetNumSubgroupMembers() do
        local Unit = "party" .. i
        local Name = UnitName(Unit)
        self:addName(Name, UnitLevel(Unit), "PARTY")
    end
end

-- Raid detection function
function CPL:updateRaid()
    for i = 1, GetNumGroupMembers() do
        local _, _, _, Level = GetRaidRosterInfo(i)
        local Name = UnitName("raid" .. i)
        self:addName(Name, Level, "RAID")
    end
end

-- Process WHO results when CHAT_MSG_SYSTEM fires
function CPL:processWhoResults()
    local targetName = self.whoTarget
    if not targetName then return end

    -- Process WHO results using modern API
    local numResults = C_FriendList.GetNumWhoResults()

    for i = 1, numResults do
        local info = C_FriendList.GetWhoInfo(i)
        if info and info.fullName and info.level then
            if info.fullName:lower() == targetName:lower() then
                -- Cache the result
                self:addName(info.fullName, info.level, "WHO")
            end
        end
    end

    -- Clean up
    self.whoTarget = nil
end

-- Channel configuration (future GUI will modify this)
-- Note: No hard-coded names - using dynamic channelName from game events
CPL.channelConfig = {
    [1] = {enabled = true},
    [2] = {enabled = true},
    [5] = {enabled = true}
}

-- Chat message processing function
local function OnChannelChat(self, event, msg, author, language, channelString, target, flags, unknown, channelNumber, channelName, ...)
    -- Check if this channel is enabled (most frequent check)
    if not (CPL.channelConfig[channelNumber] and CPL.channelConfig[channelNumber].enabled) then
        return false
    end

    -- Strip realm suffix (retail client artifact - not used in Classic Era)
    local playerName = strsplit("-", author, 2)
    local key = playerName:lower()

    -- Check cache status
    local data = CPLDB.players[key]
    
    -- Early exit: Already queued (avoid duplicate work)
    if CPL.WhoQueue[key] then
        CPL:debug("CHAT - Channel " .. channelNumber .. " (" .. (channelName or "Unknown") .. "): " .. playerName)
        return false
    end

    -- Not cached at all? Queue immediately (2nd most common for new players)
    if not data then
        CPL.WhoQueue[key] = true
        CPL:debug("QUEUE: Added", playerName, "to WHO queue (new)")
        CPL:debug("CHAT - Channel " .. channelNumber .. " (" .. (channelName or "Unknown") .. "): " .. playerName)
        return false
    end

    -- Level 60? Never update (most common for cached players)
    if data[1] == 60 then
        CPL:debug("CHAT - Channel " .. channelNumber .. " (" .. (channelName or "Unknown") .. "): " .. playerName)
        return false
    end

    -- Cache stale (older than expiry)? Re-queue for update
    local age = time() - data[2]
    if age > CPL.cacheExpiry then
        CPL.WhoQueue[key] = true
        CPL:debug("QUEUE: Added", playerName, "to WHO queue (stale, age=" .. age .. "s)")
    end

    CPL:debug("CHAT - Channel " .. channelNumber .. " (" .. (channelName or "Unknown") .. "): " .. playerName)
    return false -- Pass through unchanged
end

-- Event registration and handlers
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        CPL:updateTarget()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        CPL:updateMouseOver()
    elseif event == "GROUP_ROSTER_UPDATE" then
        if IsInRaid() then
            CPL:updateRaid()
        else
            CPL:updateParty()
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        -- WHO results come through CHAT_MSG_SYSTEM in Classic Era
        CPL:processWhoResults()
    end
end)

-- Register chat message filter for channel monitoring
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", OnChannelChat)

-- Process WHO queue on hardware events (mouse clicks)
function CPL:processQueue()
    -- Get next player from queue
    local nextPlayer = next(self.WhoQueue)
    if not nextPlayer then
        return -- Queue empty (most common case when no chat activity)
    end

    local data = CPLDB.players[nextPlayer]
    
    -- Not cached at all? Send WHO query
    if not data then
        self.whoTarget = nextPlayer
        self:debug("HARDWARE EVENT: Sending WHO query for", nextPlayer, "(new)")
        C_FriendList.SendWho(nextPlayer)
        return
    end

    -- Cached at level 60? Remove from queue (immutable, most common cached case)
    if data[1] == 60 then
        self.WhoQueue[nextPlayer] = nil
        self:debug("QUEUE: Removed level 60 player", nextPlayer)
        return
    end

    -- Check cache age
    local age = time() - data[2]
    
    -- Cache fresh? Remove from queue
    if age <= CPL.cacheExpiry then
        self.WhoQueue[nextPlayer] = nil
        self:debug("QUEUE: Removed fresh cached player", nextPlayer, "(age=" .. age .. "s)")
        return
    end

    -- Cache stale? Send WHO query for update
    self.whoTarget = nextPlayer
    self:debug("HARDWARE EVENT: Sending WHO query for", nextPlayer, "(update, age=" .. age .. "s)")
    C_FriendList.SendWho(nextPlayer)
end

-- Hook mouse clicks to process queue
WorldFrame:HookScript("OnMouseDown", function()
    CPL:processQueue()
end)

print("CPL: Core database system loaded with chat monitoring")