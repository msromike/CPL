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
local MAX_WHO_ATTEMPTS = 1        -- Max WHO retries before giving up
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
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL"
    -- Additional chat types (uncomment to enable):
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
CPL.lastWhoThrottleMsg = 0        -- WHO throttle debug message timestamp
CPL.lastGuildScan = 0             -- Guild scan throttle timestamp
CPL.lastGuildThrottleMsg = 0      -- Guild throttle debug message timestamp
CPL.WhoQueue = {}                 -- WHO query queue: {name, attempts}

-- Duplicate suppression state (event-driven, no timers)
local lastChatPlayer = nil        -- Last player processed in chat
local lastMouseoverPlayer = nil   -- Last player processed on mouseover
local lastTargetPlayer = nil      -- Last player processed on target

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
    status = {func = "showStatus", desc = "Show addon status", args = "[-what / -who / -how / name]", optional = true},
    channels = {func = "showChannels", desc = "Show monitored channels"},
    help = {func = "showHelp", desc = "Show this help"}
}

-- Slash command system
SLASH_CPL1 = "/cpl"
SlashCmdList["CPL"] = function(msg)
    local cmd, arg = strsplit(" ", msg, 2)
    cmd = cmd or "help"

    -- Allow any string starting with 'q' to trigger queue command
    if cmd:sub(1, 1):lower() == "q" and CPL.commands.queue then
        cmd = "queue"
    end

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
    -- Migration: Wipe old DB format (pre-v1.0.3 CPLDB.realm structure)
    if CPLDB and CPLDB.realm then
        CPLDB = { players = {} }
        return
    end

    -- Fresh install
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

            -- Get version from .toc file
            local version = GetAddOnMetadata("CPL", "Version") or "Unknown"

            CPL:debug("SYSTEM", "- Initializing")
            CPL:print("Chat Player Level v" .. version .. " by msromike. Type /cpl for options.")

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
function CPL:addName(Name, Level, Class, Source)
    local key = Name and Name:lower()
    local existing = key and CPLDB.players[key]

    -- Skip if invalid data
    if not (Name and Level and Level > 0) then
        return
    end

    local now = time()
    local trigger, firstSeen, cachedLevel, cachedTime

    -- Handle old format migration: {level, timestamp}
    if existing and type(existing[1]) == "number" then
        cachedLevel = existing[1]
        cachedTime = existing[2]
        firstSeen = cachedTime  -- Preserve original timestamp
    elseif existing then
        cachedLevel = existing.level
        cachedTime = existing.lastSeen
        firstSeen = existing.firstSeen
    end

    -- Determine trigger
    if not existing then
        trigger = "new"
        firstSeen = now
    elseif cachedLevel and cachedLevel ~= Level then
        trigger = "levelup"
    else
        trigger = "stale"
    end

    -- Optimization: Skip if level unchanged and cache still fresh
    if existing and cachedLevel == Level and (now - cachedTime) < CPL.cacheExpiry then
        return  -- Level unchanged and cache fresh, skip update
    end

    -- Store new table format
    CPLDB.players[key] = {
        level = Level,
        class = Class,
        source = Source and Source:lower() or "unknown",
        trigger = trigger,
        firstSeen = firstSeen,
        lastSeen = now,
        meshShared = false  -- Local collection (mesh protocol sets true)
    }

    -- Debug output for detection sources (skip guild scans - too verbose)
    if Source == "GUILD" then
        return  -- Data saved, skip debug output
    end
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

    if not data then
        return nil
    end

    -- Handle both old array format and new table format
    if type(data[1]) == "number" then
        return data[1]  -- Old format: {level, timestamp}
    else
        return data.level  -- New format: {level=X, class=Y, ...}
    end
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
    local key = Name and Name:lower()

    -- Event-driven duplicate suppression: Drop if same player as last target
    -- This handles multiple PLAYER_TARGET_CHANGED events for same target
    if key == lastTargetPlayer then
        return  -- Same player, skip processing
    end

    -- New player detected, update state and continue
    lastTargetPlayer = key

    self:addName(Name, UnitLevel("target"), UnitClass("target"), "TARGET")
end

-- Mouseover detection function
function CPL:updateMouseOver()
    if not UnitIsPlayer("mouseover") or not UnitIsFriend("player", "mouseover") then
        return
    end
    local Name = UnitName("mouseover")
    local key = Name and Name:lower()

    -- Event-driven duplicate suppression: Drop if same player as last mouseover
    -- This handles rapid fire UPDATE_MOUSEOVER_UNIT events
    if key == lastMouseoverPlayer then
        return  -- Same player, skip processing
    end

    -- New player detected, update state and continue
    lastMouseoverPlayer = key

    self:addName(Name, UnitLevel("mouseover"), UnitClass("mouseover"), "MOUSE")
end

-- Party detection function
function CPL:updateParty()
    for i = 1, GetNumSubgroupMembers() do
        local Unit = "party" .. i
        local Name = UnitName(Unit)
        self:addName(Name, UnitLevel(Unit), UnitClass(Unit), "PARTY")
    end
end

-- Raid detection function
function CPL:updateRaid()
    for i = 1, GetNumGroupMembers() do
        local Unit = "raid" .. i
        local Name = UnitName(Unit)
        self:addName(Name, UnitLevel(Unit), UnitClass(Unit), "RAID")
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
        -- Only show throttle message once per minute to prevent spam
        if (now - self.lastGuildThrottleMsg) >= 60 then
            local timeRemaining = GUILD_SCAN_COOLDOWN - (now - self.lastGuildScan)
            local minutes = math.floor(timeRemaining / 60)
            local seconds = timeRemaining % 60
            self:debug("GUILD", string.format("- Scan throttled - Next in %dm %.0fs", minutes, seconds))
            self.lastGuildThrottleMsg = now
        end
        return
    end

    self.lastGuildScan = now
    local count = 0

    for i = 1, GetNumGuildMembers() do
        local name, _, _, level, _, _, _, _, _, _, class = GetGuildRosterInfo(i)

        if name and level and level > 0 then
            -- Remove server suffix if present (cross-realm)
            local cleanName = name:match("([^%-]+)")
            self:addName(cleanName, level, class, "GUILD")
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

    -- Event-driven duplicate suppression: Drop if same player as last chat message
    -- This handles rapid spam from automated channels (death alerts, etc.)
    if key == lastChatPlayer then
        return false  -- Same player, skip processing silently
    end

    -- New player detected, update state and continue processing
    lastChatPlayer = key

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
        CPL:debug("CHAT", "- Channel " .. channelNumber .. " (" .. (channelName or "Unknown") .. ") [" .. playerName .. "]")
        CPL:debug("WHO", "- Added [" .. playerName .. "] to queue - New")
        table.insert(CPL.WhoQueue, {key, 0})
        return false
    end

    -- Cache stale (older than expiry)? Re-queue for update
    local timestamp = type(data[1]) == "number" and data[2] or data.lastSeen
    local age = time() - timestamp
    if age > CPL.cacheExpiry then
        local overdue = age - CPL.cacheExpiry
        CPL:debug("CHAT", "- Channel " .. channelNumber .. " (" .. (channelName or "Unknown") .. ") [" .. playerName .. "]")
        CPL:debug("WHO", "- Added [" .. playerName .. "] to queue - Stale (" .. CPL:formatAge(overdue) .. " overdue)")
        table.insert(CPL.WhoQueue, {key, 0})
        return false
    end

    -- Cache is fresh, just log and pass through
    CPL:debug("CHAT", "- Channel " .. channelNumber .. " (" .. (channelName or "Unknown") .. ") [" .. playerName .. "]")
    return false
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

    -- Only prepend level if known (don't show [??] for unknown)
    if level then
        local prefix = string.format("[%02d] ", level)
        return false, prefix .. msg, author, ...
    end

    -- No level known - return message unchanged
    return false, msg, author, ...
end

-- Register display filters for configured chat events
-- Skip events handled by Chattynator integration
local chattynatorEvents = {
    CHAT_MSG_CHANNEL = true,
    CHAT_MSG_SAY = true,
    CHAT_MSG_YELL = true,
    CHAT_MSG_WHISPER = true,
    CHAT_MSG_WHISPER_INFORM = true,
    CHAT_MSG_PARTY = true,
    CHAT_MSG_PARTY_LEADER = true,
    CHAT_MSG_RAID = true,
    CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_RAID_WARNING = true,
    CHAT_MSG_GUILD = true,
    CHAT_MSG_OFFICER = true,
}

for _, event in ipairs(CHAT_EVENTS_WITH_LEVELS) do
    if chattynatorEvents[event] and Chattynator then
        CPL:debug("SYSTEM", "Skipping PrependLevel for " .. event .. " - Chattynator integration active")
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
            -- Cache the result (WHO provides class via info.classStr)
            self:addName(info.fullName, info.level, info.classStr, "WHO")

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
        -- Suppress duplicate throttle messages from OnMouseDown + OnMouseUp firing together
        -- Only show message if 200ms has elapsed since last message (prevents spam from normal clicks)
        local now = GetTime() -- Use GetTime() for sub-second precision
        if (now - self.lastWhoThrottleMsg) >= 0.2 then
            self:debug("WHO", "- Throttled API call - Next in " .. string.format("%.1fs", WHO_COOLDOWN_SECONDS - timeSinceLastWho))
            self.lastWhoThrottleMsg = now
        end
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
    local timestamp = type(data[1]) == "number" and data[2] or data.lastSeen
    local age = time() - timestamp

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

-- Hook hardware events to process queue
WorldFrame:HookScript("OnMouseDown", function()
    CPL:processQueue()
end)

WorldFrame:HookScript("OnMouseUp", function()
    CPL:processQueue()
end)

--------------------------------------------------
-- Command & Cache Display Functions
--------------------------------------------------

-- Status command - unified info display with multiple modes
-- Usage: /cpl status [flags|name]
-- Modes: summary (default), -what, -who, -how, or name filter
function CPL:showStatus(args)
    -- Parse arguments to determine mode
    local mode = "summary"  -- Default mode
    local nameFilter = nil

    if args then
        args = args:lower()

        -- Check for flag modes (exact matches only)
        if args == "-what" then
            mode = "what"
        elseif args == "-who" then
            mode = "who"
        elseif args == "-how" then
            mode = "how"
        else
            -- Not a flag, treat as name filter
            mode = "name"
            nameFilter = args
        end
    end

    -- Route to appropriate display function
    if mode == "summary" then
        self:showStatusSummary()
    elseif mode == "what" then
        self:showStatusWhat()
    elseif mode == "who" then
        self:showStatusWho()
    elseif mode == "how" then
        self:showStatusHow()
    elseif mode == "name" then
        self:showStatusName(nameFilter)
    end
end

-- Summary mode - basic stats
function CPL:showStatusSummary()
    self:print("=== CPL STATUS ===")

    -- Count players
    local count = 0
    for _ in pairs(CPLDB.players) do
        count = count + 1
    end

    self:print("Cached Players: " .. count)
    self:print("WHO Queue: " .. #self.WhoQueue)
    self:print("Mesh Status: Local only (v2.0)")
    self:print("==================")
end

-- Stub functions for other modes (to be implemented)
function CPL:showStatusWhat()
    self:print("=== WHAT DATA DO WE HAVE? ===")


    local totalLevel = 0
    local count = 0
    local firstEpoch, lastEpoch

    -- Collect data
    for name, data in pairs(CPLDB.players) do
        local level, timestamp

        -- Handle both old and new formats
        if type(data[1]) == "number" then
            level = data[1]
            timestamp = data[2]
        else
            level = data.level
            timestamp = data.lastSeen
        end

        totalLevel = totalLevel + level
        count = count + 1

        -- Track first/last timestamps
        if timestamp then
            firstEpoch = (not firstEpoch or timestamp < firstEpoch) and timestamp or firstEpoch
            lastEpoch = (not lastEpoch or timestamp > lastEpoch) and timestamp or lastEpoch
        end
    end

    -- Calculate average level
    local avgLevel = count > 0 and (totalLevel / count) or 0

    self:print(string.format("Total Players: %d", count))
    self:print(string.format("Average Level: %.1f", avgLevel))
    self:print("")

    if firstEpoch then
        self:print("First Saved: " .. date("%Y/%m/%d %H:%M", firstEpoch))
    end
    if lastEpoch then
        self:print("Last Saved: " .. date("%Y/%m/%d %H:%M", lastEpoch))
    end

    self:print("======================")
end

function CPL:showStatusWho()
    self:print("=== WHO HAVE WE SEEN? ===")


    local classes = {}
    local entries = {}

    -- Collect class data and entries
    for name, data in pairs(CPLDB.players) do
        local class, level, lastSeen

        -- Only new format has class data
        if type(data[1]) ~= "number" then
            class = data.class or "Unknown"
            level = data.level
            lastSeen = data.lastSeen
            classes[class] = (classes[class] or 0) + 1

            table.insert(entries, {name = name, level = level, lastSeen = lastSeen})
        end
    end

    -- Sort by lastSeen (newest first) for "Last 3 learned"
    table.sort(entries, function(a, b) return a.lastSeen > b.lastSeen end)

    -- Show last 3 learned
    if #entries > 0 then
        self:print("Last 3 Learned:")
        for i = 1, math.min(3, #entries) do
            local e = entries[i]
            self:print(string.format("  [%d] %s", e.level, e.name))
        end
        self:print("")
    end

    -- Sort by count (descending)
    local sorted = {}
    for class, count in pairs(classes) do
        table.insert(sorted, {class = class, count = count})
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    -- Display class breakdown
    if #sorted == 0 then
        self:print("No class data available (old format entries only)")
    else
        self:print("Class Breakdown:")
        for _, entry in ipairs(sorted) do
            self:print(string.format("  %s: %d", entry.class, entry.count))
        end
    end

    self:print("======================")
end

function CPL:showStatusHow()
    self:print("=== HOW DID WE LEARN? ===")

    local sources = {}
    local meshCount = 0
    local localCount = 0

    -- Collect source data
    for name, data in pairs(CPLDB.players) do
        -- Handle both formats
        if type(data[1]) == "number" then
            -- Old format - always local, unknown source
            sources["unknown"] = (sources["unknown"] or 0) + 1
            localCount = localCount + 1
        else
            -- New format - check if mesh or local
            if data.meshShared then
                meshCount = meshCount + 1
            else
                local source = data.source or "unknown"
                sources[source] = (sources[source] or 0) + 1
                localCount = localCount + 1
            end
        end
    end

    -- Sort by count (descending)
    local sorted = {}
    for source, count in pairs(sources) do
        table.insert(sorted, {source = source, count = count})
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    -- Display local collection methods
    self:print("Collection Methods:")
    for _, entry in ipairs(sorted) do
        self:print(string.format("  %s: %d", entry.source, entry.count))
    end

    -- Show mesh data if any
    if meshCount > 0 then
        self:print(string.format("  mesh: %d", meshCount))
    end

    self:print("")

    -- Show next 3 to learn (WHO queue)
    if #self.WhoQueue > 0 then
        self:print("Next 3 to Learn:")
        for i = 1, math.min(3, #self.WhoQueue) do
            self:print(string.format("  %s", self.WhoQueue[i][1]))
        end
    else
        self:print("WHO Queue: Empty")
    end

    self:print("======================")
end

function CPL:showStatusName(filter)
    if not filter then
        self:print("Usage: /cpl status <name>")
        return
    end

    local matches = {}

    -- Collect matching entries
    for name, data in pairs(CPLDB.players) do
        if name:find(filter, 1, true) then
            local level, class, source

            -- Handle both formats
            if type(data[1]) == "number" then
                level = data[1]
                class = nil
                source = "unknown"
            else
                level = data.level
                class = data.class
                source = data.source or "unknown"
            end

            table.insert(matches, {
                name = name,
                level = level,
                class = class or "?",
                source = source
            })
        end
    end

    -- Sort by name
    table.sort(matches, function(a, b) return a.name < b.name end)

    -- Display results
    if #matches == 0 then
        self:print("No players found matching: " .. filter)
        return
    end

    self:print(string.format("=== MATCHES: %d ===", #matches))
    for _, entry in ipairs(matches) do
        self:print(string.format("%-15s | Lvl %2d | %s | %s",
            entry.name, entry.level, entry.class, entry.source))
    end
    self:print("==================")
end

-- Show cache contents (core command - always available)
function CPL:debugCache(filterName)
    self:print("=== CPL CACHE ===")

    local cache = {}
    local filter = filterName and filterName:lower()
    local oldestEpoch, newestEpoch

    -- Build cache table
    for name, data in pairs(CPLDB.players) do
        if not filter or name:find(filter, 1, true) then
            -- Handle both old and new formats
            local level, epoch
            if type(data[1]) == "number" then
                level = data[1]
                epoch = data[2]
            else
                level = data.level
                epoch = data.lastSeen
            end

            table.insert(cache, {
                name = name,
                level = level,
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
    self:print("")

    -- /cpl (bare command shows help)
    self:print("  /cpl - Show this help")
    self:print("")

    -- /cpl channels
    self:print("  /cpl channels - Show monitored channels")
    self:print("")

    -- /cpl status (multiline explanation)
    self:print("  /cpl status - Show addon status")
    self:print("    -what : Stats breakdown (avg level, sources, classes)")
    self:print("    -who  : Class breakdown sorted by count")
    self:print("    -how  : Source breakdown sorted by count")
    self:print("    <name>: Filter by player name substring")
    self:print("")

    -- Check if debug commands are available
    if CPL.commands.debug then
        self:print("  .")
        self:print("")

        -- Debug commands
        self:print("  /cpl debug - Toggle debug mode on/off")
        self:print("")

        self:print("  /cpl queue - Show WHO query queue")
        self:print("")

        self:print("  /cpl debugframe - Toggle debug window")
        self:print("")

        -- /cpl dbcheck (multiline explanation)
        self:print("  /cpl dbcheck - Inspect database format")
        self:print("    old   : Show old format entries")
        self:print("    new   : Show new format entries")
        self:print("    <name>: Filter by player name substring")
        self:print("")
    end
end
