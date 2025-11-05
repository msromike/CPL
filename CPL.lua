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

-- Memory cache (session only) - Prat style
CPL.Classes = {}      -- [playername:lower()] = "CLASS"
CPL.Levels = {}       -- [playername:lower()] = level_number
CPL.Subgroups = {}    -- [playername:lower()] = subgroup_number

-- Persistent storage - create on init if missing
local function InitDB()
    if not CPLDB then
        CPLDB = {
            realm = {
                classes = {},  -- [playername:lower()] = "CLASS"
                levels = {}    -- [playername:lower()] = level_number
            }
        }
    end
end

-- Core function to store player data - based on Prat's addName()
function CPL:addName(Name, Server, Class, Level, SubGroup, Source)
    if Name then
        -- Build full name with server suffix if provided
        Name = Name .. (Server and Server:len() > 0 and ("-" .. Server) or "")
        local key = Name:lower()

        -- Single clean debug line showing source
        self:debug(Source .. ":", Name, "-", Level, "-", Class)

        -- Store level data
        if Level and Level > 0 then
            self.Levels[key] = Level
            CPLDB.realm.levels[key] = Level
        end

        -- Store class data
        if Class then
            self.Classes[key] = Class
            CPLDB.realm.classes[key] = Class
        end        -- Store subgroup data (memory only)
        if SubGroup then
            self.Subgroups[key] = SubGroup
            self:debug("Stored subgroup", SubGroup, "for", key)
        end
    end
end

-- Retrieval functions - check memory first, then persistent
function CPL:getLevel(player)
    local key = player:lower()
    return self.Levels[key] or CPLDB.realm.levels[key]
end

function CPL:getClass(player)
    local key = player:lower()
    return self.Classes[key] or CPLDB.realm.classes[key]
end

function CPL:getSubgroup(player)
    return self.Subgroups[player:lower()]
end

-- Debug function to inspect cache contents
function CPL:debugCache()
    print("=== CPL CACHE DEBUG ===")
    print("Memory Levels:")
    for name, level in pairs(self.Levels) do
        print("  " .. name .. " = " .. level)
    end
    print("Memory Classes:")
    for name, class in pairs(self.Classes) do
        print("  " .. name .. " = " .. class)
    end
    print("Persistent Levels:")
    for name, level in pairs(CPLDB.realm.levels) do
        print("  " .. name .. " = " .. level)
    end
    print("======================")
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
    who = {func = "testWho", args = "<name>", desc = "Test WHO query for player"},
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

-- Target detection function - based on Prat's updateTarget()
function CPL:updateTarget()
    local Class, Name, Server
    if not UnitIsPlayer("target") or not UnitIsFriend("player", "target") then
        return
    end
    Class = select(2, UnitClass("target"))
    Name, Server = UnitName("target")
    self:addName(Name, Server, Class, UnitLevel("target"), nil, "TARGET")
end

-- MouseOver detection function - based on Prat's updateMouseOver()
function CPL:updateMouseOver()
    local Class, Name, Server
    if not UnitIsPlayer("mouseover") or not UnitIsFriend("player", "mouseover") then
        return
    end
    Class = select(2, UnitClass("mouseover"))
    Name, Server = UnitName("mouseover")
    self:addName(Name, Server, Class, UnitLevel("mouseover"), nil, "MOUSE")
end-- Party detection function - based on Prat's updateParty()
function CPL:updateParty()
    local Class, Unit, Name, Server
    for i = 1, GetNumSubgroupMembers() do
        Unit = "party" .. i
        _, Class = UnitClass(Unit)
        Name, Server = UnitName(Unit)
        self:addName(Name, Server, Class, UnitLevel(Unit), nil, "PARTY")
    end
end

-- Raid detection function - based on Prat's updateRaid()
function CPL:updateRaid()
    local Name, Class, SubGroup, Level, Server, rank
    for i = 1, GetNumGroupMembers() do
        _, rank, SubGroup, Level, _, Class = GetRaidRosterInfo(i)
        Name, Server = UnitName("raid" .. i)
        self:addName(Name, Server, Class, Level, SubGroup, "RAID")
    end
end

-- WHO test function - sends query and processes results
function CPL:testWho(targetName)
    if not targetName or #targetName < 3 then
        print("CPL: Name must be at least 3 characters for WHO search")
        return
    end

    -- Store target name for result processing
    self.whoTarget = targetName

    -- Register for WHO results
    if not self.whoFrame then
        self.whoFrame = CreateFrame("Frame")
        self.whoFrame:SetScript("OnEvent", function(frame, event)
            if event == "WHO_LIST_UPDATE" then
                CPL:processWhoResults()
                -- Clean up - unregister until next query
                frame:UnregisterEvent("WHO_LIST_UPDATE")
            end
        end)
    end

    self.whoFrame:RegisterEvent("WHO_LIST_UPDATE")

    -- Send the WHO query using modern API
    C_FriendList.SendWho(targetName)
end

-- Process WHO results when WHO_LIST_UPDATE fires
function CPL:processWhoResults()
    local targetName = self.whoTarget
    if not targetName then return end

    -- Process WHO results using modern API
    local numResults = C_FriendList.GetNumWhoResults()

    for i = 1, numResults do
        local info = C_FriendList.GetWhoInfo(i)
        if info and info.fullName and info.level then
            if info.fullName:lower() == targetName:lower() then
                -- Store the data we found
                self:addName(info.fullName, nil, info.filename, info.level, nil, "WHO")
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
    -- Check if this channel is enabled
    if CPL.channelConfig[channelNumber] and CPL.channelConfig[channelNumber].enabled then
        -- Strip realm suffix (retail client artifact - not used in Classic Era)
        local playerName = strsplit("-", author, 2)

        -- Debug output
        print("CPL CHAT - Channel " .. channelNumber .. " (" .. (channelName or "Unknown") .. "): " .. playerName)
    end
    return false -- Pass through unchanged
end

-- Event registration and handlers
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(self, event)
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
    end
end)

-- Register chat message filter for channel monitoring
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", OnChannelChat)

print("CPL: Core database system loaded with chat monitoring")