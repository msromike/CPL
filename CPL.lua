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

-- Initialize database on load
InitDB()
CPL:debug("Database initialized")

-- Slash command system
SLASH_CPL1 = "/cpl"
SlashCmdList["CPL"] = function(msg)
    local args = {strsplit(" ", msg)}
    local cmd = args[1] or ""

    if cmd == "debug" then
        CPL:toggleDebug()
    elseif cmd == "cache" then
        CPL:debugCache()
    elseif cmd == "help" then
        print("CPL Commands:")
        print("  /cpl debug - Toggle debug mode on/off")
        print("  /cpl cache - Show cache contents")
        print("  /cpl help  - Show this help")
    else
        print("CPL loaded. Type '/cpl help' for commands.")
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

-- WHO detection function - based on Prat's updateWho()
function CPL:updateWho()
    local numWhos, totalWhos = GetNumWhoResults()

    for i = 1, numWhos do
        local name, guild, level, race, class = GetWhoInfo(i)

        if name and level and level > 0 then
            self:addName(name, nil, class, level, nil, "WHO")
        end
    end
end

-- Event registration and handlers
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("WHO_LIST_UPDATE")
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
    elseif event == "WHO_LIST_UPDATE" then
        print("WHO_LIST_UPDATE event fired!")  -- Debug: show event fired
        CPL:updateWho()
    end
end)

print("CPL: Core database system loaded")