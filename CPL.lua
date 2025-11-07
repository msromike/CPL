-- CPL - Chat Player Levels
-- Author: msromike
-- Inspired by Prat-3.0's level caching approach
-- Original Prat-3.0: Copyright (C) 2006-2018 Prat Development Team (GPL v2)

-- Detects and displays player levels in chat channels.
-- Uses intelligent caching and WHO queries to minimize API calls.

-- Core Commands:
--   /cpl enable    - Toggle addon on/off
--   /cpl cache     - Show cached player levels
--   /cpl channels  - Show monitored channels
--   /cpl help      - List all commands

-- Debug Commands (requires Debug.lua):
--   /cpl debug      - Toggle debug output
--   /cpl queue      - Show WHO query queue
--   /cpl debugframe - Toggle debug frame

CPL = {} -- Global namespace (accessible to Debug.lua)

--------------------------------------------------
-- Configuration Constants
--------------------------------------------------

CPL.cacheExpiry = 28800           -- Player cache expiry (8 hours)
local WHO_COOLDOWN_SECONDS = 5    -- WoW API throttle limit
local MAX_WHO_ATTEMPTS = 3        -- Max WHO retries before giving up
local GUILD_SCAN_COOLDOWN = 600   -- Guild roster scan throttle (10 minutes)

-- Chat events to prepend player levels to (add/remove as needed)
local CHAT_EVENTS_WITH_LEVELS = {
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM"
    -- Additional chat types (uncomment to enable):
    -- "CHAT_MSG_SAY",
    -- "CHAT_MSG_YELL",
    -- "CHAT_MSG_EMOTE",
    -- "CHAT_MSG_TEXT_EMOTE",
    -- "CHAT_MSG_AFK",
    -- "CHAT_MSG_DND",
    -- "CHAT_MSG_INSTANCE_CHAT",
    -- "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

CPL.debugMode = true              -- Toggle with /cpl debug (requires Debug.lua)

--------------------------------------------------
-- State Variables
--------------------------------------------------

CPL.lastWhoTime = 0               -- WHO query throttle timestamp
CPL.lastGuildScan = 0             -- Guild scan throttle timestamp
CPL.WhoQueue = {}                 -- WHO query queue: {name, attempts}

-- Channel monitor configuration
CPL.channelConfig = {}

-- Initialize all channels 1-7 as enabled by default
for i = 1, 7 do
    CPL.channelConfig[i] = {enabled = true}
end

--------------------------------------------------
-- Slash Commands & Command Routing
--------------------------------------------------

-- Command table for easy extension (one line to add new commands)
-- Core commands only - Debug.lua adds its own commands when loaded
CPL.commands = {
    cache = {func = "debugCache", desc = "Show cache contents", args = "[name]", optional = true},
    channels = {func = "showChannels", desc = "Show monitored channels"},
    help = {func = "showHelp", desc = "Show this help"}
}

-- Slash command system
SLASH_CPL1 = "/cpl"
SlashCmdList["CPL"] = function(msg)
    local cmd, arg = strsplit(" ", msg, 2)
    cmd = cmd or "help"

    local command = CPL.commands[cmd]
    if command then
        -- Handle commands that require arguments (but not optional ones)
        if command.args and not command.optional and not arg then
            CPL:print("Usage: /cpl " .. cmd .. " " .. command.args)
        else
            -- Call the function
            CPL[command.func](CPL, arg)
        end
    else
        CPL:showHelp()
    end
end

--------------------------------------------------
-- Event Registration & Initialization
--------------------------------------------------

-- Persistent storage - create on init if missing
local function InitDB()
    if not CPLDB then
        CPLDB = {
            players = {}  -- [playername:lower()] = {level, timestamp}
        }
    end
end

-- Event registration and handlers
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "CPL" then
            InitDB()

            CPL:debug("SYSTEM", "- Initializing")
            CPL:print("CPL: Loaded - Chat player level caching active")

            -- Display monitored channels on startup (Debug.lua provides the implementation)
            CPL:debugChannels()

            -- Request guild roster if in guild
            if IsInGuild() then
                GuildRoster()
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        CPL:updateTarget()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        CPL:updateMouseOver()
    elseif event == "GUILD_ROSTER_UPDATE" then
        CPL:updateGuild()
    elseif event == "GROUP_ROSTER_UPDATE" then
        if IsInRaid() then
            CPL:updateRaid()
        else
            CPL:updateParty()
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        CPL:processWhoResults()
    end
end)

--------------------------------------------------
-- Utility Functions
--------------------------------------------------

-- Convert seconds to fractional hours with 1 decimal place
function CPL:formatAge(seconds)
    return string.format("%.1fh", seconds / 3600)
end

--------------------------------------------------
-- Core Database Functions
--------------------------------------------------

-- Core function to store player data
function CPL:addName(Name, Level, Source)
    local key = Name and Name:lower()
    local existing = key and CPLDB.players[key]

    -- Skip if invalid data
    if not (Name and Level and Level > 0) then
        return
    end

    -- Optimization: Skip if level unchanged and cache still fresh
    local now = time()
    if existing then
        local cachedLevel, cachedTime = existing[1], existing[2]
        if cachedLevel == Level and (now - cachedTime) < CPL.cacheExpiry then
            return  -- Level unchanged and cache fresh, skip update
        end
    end

    -- Store level with timestamp: {level, timestamp}
    CPLDB.players[key] = {Level, now}

    -- Skip debug output for guild scans (too verbose)
    if Source == "GUILD" then
        return
    end

    -- Debug output for other detection sources
    if Source == "WHO" then
        self:debug("WHO", "- Received [" .. Name .. "] - Lvl " .. Level)
    elseif Source == "TARGET" and existing then
        self:debug("DETECT", "- Cached target [" .. Name .. "] - Lvl " .. Level)
    elseif Source == "MOUSE" and existing then
        self:debug("DETECT", "- Cached mouse [" .. Name .. "] - Lvl " .. Level)
    elseif (Source == "PARTY" or Source == "RAID") and existing then
        self:debug("DETECT", "- Cached " .. Source:lower() .. " [" .. Name .. "] - Lvl " .. Level)
    end
end

-- Retrieval function - returns level only, ignores timestamp
function CPL:getLevel(player)
    local key = player:lower()
    local data = CPLDB.players[key]
    return data and data[1]
end

--------------------------------------------------
-- Debug & Utility Functions (Stubs)
--------------------------------------------------

-- Debug stub - overridden by Debug.lua if loaded
function CPL:debug(category, ...) end

-- Print to chat frame (for non-debug system messages like help, cache, etc)
function CPL:print(...)
    local msg = table.concat({...}, " ")
    DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 1)
end

-- Debug stubs - overridden by Debug.lua if loaded
function CPL:toggleDebug() end
function CPL:toggleDebugFrame() end
function CPL:debugQueue() end
function CPL:debugChannels() end

--------------------------------------------------
-- Player Detection Functions
--------------------------------------------------

-- Target detection function
function CPL:updateTarget()
    if not UnitIsPlayer("target") or not UnitIsFriend("player", "target") then
        return
    end
    local Name = UnitName("target")
    self:addName(Name, UnitLevel("target"), "TARGET")
end

-- Mouseover detection function
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

-- Guild roster scanning
function CPL:updateGuild()
    if not IsInGuild() then
        return
    end

    -- Throttle guild roster scans
    local now = time()
    if (now - self.lastGuildScan) < GUILD_SCAN_COOLDOWN then
        self:debug("GUILD", "- Requesting roster update - Throttled")
        return
    end

    self.lastGuildScan = now
    local count = 0

    for i = 1, GetNumGuildMembers() do
        local name, _, _, level = GetGuildRosterInfo(i)

        if name and level and level > 0 then
            -- Remove server suffix if present (cross-realm)
            local cleanName = name:match("([^%-]+)")
            self:addName(cleanName, level, "GUILD")
            count = count + 1
        end
    end

    self:debug("GUILD", "- Updated roster -", count, "members")
end

--------------------------------------------------
-- Chat Channel Monitoring
--------------------------------------------------

-- Chat message processing function
local function OnChannelChat(self, event, msg, author, language, channelString, target, flags, unknown, channelNumber, channelName, ...)
    -- Check if this channel is enabled
    if not (CPL.channelConfig[channelNumber] and CPL.channelConfig[channelNumber].enabled) then
        return false
    end

    local playerName = strsplit("-", author, 2)
    local key = playerName:lower()

    -- Check cache status
    local data = CPLDB.players[key]

    -- Early exit: Already queued (avoid duplicate work)
    local alreadyQueued = false
    for i, entry in ipairs(CPL.WhoQueue) do
        if entry[1] == key then
            alreadyQueued = true
            break
        end
    end

    if alreadyQueued then
        CPL:debug("CHAT", "- Channel " .. channelNumber .. " (" .. (channelName or "Unknown") .. ") [" .. playerName .. "]")
        return false
    end

    -- Not cached at all? Queue immediately (2nd most common for new players)
    if not data then
        table.insert(CPL.WhoQueue, {key, 0})
        CPL:debug("WHO", "- Added [" .. playerName .. "] to queue - New")
        CPL:debug("CHAT", "- Channel " .. channelNumber .. " (" .. (channelName or "Unknown") .. ") [" .. playerName .. "]")
        return false
    end

    -- Cache stale (older than expiry)? Re-queue for update
    local age = time() - data[2]
    if age > CPL.cacheExpiry then
        table.insert(CPL.WhoQueue, {key, 0})
        CPL:debug("WHO", "- Added [" .. playerName .. "] to queue - Stale " .. CPL:formatAge(age))
    end

    CPL:debug("CHAT", "- Channel " .. channelNumber .. " (" .. (channelName or "Unknown") .. ") [" .. playerName .. "]")
    return false -- Pass through unchanged
end

-- Register chat message filter for channel monitoring
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", OnChannelChat)

--------------------------------------------------
-- Chat Message Display (Level Prepending)
--------------------------------------------------

-- Generic display filter that prepends level to message
local function PrependLevel(self, event, msg, author, ...)
    -- Strip realm suffix and get level
    local playerName = strsplit("-", author, 2)
    local level = CPL:getLevel(playerName)

    -- Prepend level if known (pad single digits), otherwise show [..]
    local prefix
    if level then
        prefix = string.format("[%02d] ", level)
    else
        prefix = "[..] "
    end

    -- Return modified message with all original params
    return false, prefix .. msg, author, ...
end

-- Register display filters for configured chat events
-- Skip CHAT_MSG_CHANNEL if Chattynator is loaded (it handles channel display)
for _, event in ipairs(CHAT_EVENTS_WITH_LEVELS) do
    if event == "CHAT_MSG_CHANNEL" and Chattynator then
        CPL:debug("SYSTEM", "Skipping PrependLevel for CHAT_MSG_CHANNEL - Chattynator integration active")
    else
        ChatFrame_AddMessageEventFilter(event, PrependLevel)
    end
end

--------------------------------------------------
-- WHO Query System
--------------------------------------------------

-- Process WHO results when CHAT_MSG_SYSTEM fires
function CPL:processWhoResults()
    local targetName = self.whoTarget
    if not targetName then return end

    -- Process WHO results using modern API
    local numResults = C_FriendList.GetNumWhoResults()
    if numResults == 0 then
        return
    end

    for i = 1, numResults do
        local info = C_FriendList.GetWhoInfo(i)

        -- Process valid entries that match our target
        if info and info.fullName and info.level and info.fullName:lower() == targetName:lower() then
            -- Cache the result
            self:addName(info.fullName, info.level, "WHO")

            -- Remove from queue on successful match (always index 1 - we only query the first entry)
            table.remove(self.WhoQueue, 1)
        end
    end

    -- Clean up
    self.whoTarget = nil
    -- Fallback timer clears suppressWho in case "total" never arrives (black hole/throttle)
    C_Timer.After(1.0, function()
        if CPL.suppressWho then
            CPL.suppressWho = false
        end
    end)
end

-- Filter to suppress WHO results generated by addon (but not player manual /who)
local function FilterWhoResults(self, event, msg, ...)
    -- Only suppress if we initiated the query
    if CPL.suppressWho then
        -- Match WHO result patterns:
        -- "PlayerName: Level XX ..." or anything ending with "total"
        if msg:match("^.+: Level %d+") or msg:match("total$") then
            -- Clear flag immediately when we see "total" (event-driven)
            if msg:match("total$") then
                CPL.suppressWho = false
            end
            return true -- Suppress this message
        end
    end
    return false -- Show the message
end

-- Suppress addon-initiated WHO results from chat
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FilterWhoResults)

--------------------------------------------------
-- WHO Queue Processing
--------------------------------------------------

-- Helper: Increment attempt counter and remove from queue if max attempts reached
local function incrementAttemptOrRemove(entry, index, playerName)
    entry[2] = entry[2] + 1
    if entry[2] >= MAX_WHO_ATTEMPTS then
        table.remove(CPL.WhoQueue, index)
        CPL:debug("WHO", "- Removed [" .. playerName .. "] from queue - Max attempts (" .. MAX_WHO_ATTEMPTS .. ")")
    end
end

-- Process WHO queue on hardware events (mouse clicks)
function CPL:processQueue()
    -- Enforce 5-second cooldown between WHO queries
    local timeSinceLastWho = time() - self.lastWhoTime
    if timeSinceLastWho < WHO_COOLDOWN_SECONDS then
        self:debug("WHO", "- Throttled API call - Next in " .. string.format("%.1fs", WHO_COOLDOWN_SECONDS - timeSinceLastWho))
        return
    end

    -- Get first entry from queue (index 1)
    if #self.WhoQueue == 0 then
        return -- Queue empty (most common case when no chat activity)
    end

    local entry = self.WhoQueue[1]
    local nextPlayer = entry[1]
    local data = CPLDB.players[nextPlayer]

    -- Not cached at all? Send WHO query
    if not data then
        self.whoTarget = nextPlayer
        self.suppressWho = true
        self:debug("WHO", "- Sending query for [" .. nextPlayer .. "] - New")
        C_FriendList.SendWho("n-\"" .. nextPlayer .. "\"")
        self.lastWhoTime = time()

        incrementAttemptOrRemove(entry, 1, nextPlayer)
        return
    end

    -- Check cache age
    local age = time() - data[2]

    -- Cache fresh? Remove from queue
    if age <= CPL.cacheExpiry then
        table.remove(self.WhoQueue, 1)
        self:debug("WHO", "- Removed [" .. nextPlayer .. "] from queue - Fresh " .. self:formatAge(age))
        return
    end

    -- Cache stale? Send WHO query for update
    self.whoTarget = nextPlayer
    self.suppressWho = true
    self:debug("WHO", "- Sending query for [" .. nextPlayer .. "] - Update " .. self:formatAge(age))
    C_FriendList.SendWho("n-\"" .. nextPlayer .. "\"")
    self.lastWhoTime = time()

    incrementAttemptOrRemove(entry, 1, nextPlayer)
end

-- Hook mouse clicks to process queue
WorldFrame:HookScript("OnMouseDown", function()
    CPL:processQueue()
end)

--------------------------------------------------
-- Command & Cache Display Functions
--------------------------------------------------

-- Show cache contents (core command - always available)
function CPL:debugCache(filterName)
    self:print("=== CPL CACHE ===")

    local cache = {}
    local filter = filterName and filterName:lower()
    local oldestEpoch, newestEpoch

    -- Build cache table
    for name, data in pairs(CPLDB.players) do
        if not filter or name:find(filter, 1, true) then
            local epoch = data[2]
            table.insert(cache, {
                name = name,
                level = data[1],
                timestamp = date("%Y-%m-%d %H:%M:%S", epoch),
                epoch = epoch
            })

            oldestEpoch = (not oldestEpoch or epoch < oldestEpoch) and epoch or oldestEpoch
            newestEpoch = (not newestEpoch or epoch > newestEpoch) and epoch or newestEpoch
        end
    end

    table.sort(cache, function(a, b) return a.name < b.name end)

    -- Summary view (no filter)
    if not filter then
        self:print("Total Entries: " .. #cache)
        if oldestEpoch then
            self:print("First Timestamp: " .. date("%Y-%m-%d %H:%M:%S", oldestEpoch))
            self:print("Last Timestamp: " .. date("%Y-%m-%d %H:%M:%S", newestEpoch))
        end
        self:print("=================")
        return
    end

    -- Filtered detail view
    for _, entry in ipairs(cache) do
        self:print(string.format("%-15s | Lvl %2d | TS: %s", entry.name, entry.level, entry.timestamp))
    end

    self:print("Showing " .. #cache .. " player(s) matching '" .. filterName .. "'")
    self:print("=================")
end

-- Show monitored channels (core command - always available)
function CPL:showChannels()
    self:print("=== CPL Monitored Channels ===")
    local count = 0

    for channelNum, config in pairs(self.channelConfig) do
        -- Display enabled channels with valid IDs
        if config.enabled then
            local channelID, channelName = GetChannelName(channelNum)
            if channelID > 0 then
                self:print("  Channel " .. channelNum .. ": " .. channelName)
                count = count + 1
            end
        end
    end

    if count == 0 then
        self:print("  No channels currently monitored")
    end
    self:print("===============================")
end

-- Show help text (auto-generated from commands table)
function CPL:showHelp()
    self:print("CPL Commands:")
    for cmd, info in pairs(CPL.commands) do
        local usage = "/cpl " .. cmd
        if info.args then
            usage = usage .. " " .. info.args
        end
        self:print("  " .. usage .. " - " .. info.desc)
    end
end

