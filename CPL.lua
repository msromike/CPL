-- CPL - Chat Player Levels
-- Inspired by Prat-3.0's player level caching approach
-- Original Prat-3.0: Copyright (C) 2006-2018 Prat Development Team (GPL v2)
--
-- Slash Commands:
--   /cpl debug  - Toggle debug output (default ON)
--   /cpl cache  - Show cached player levels
--   /cpl queue  - Show WHO query queue
--   /cpl help   - List all commands

--------------------------------------------------
-- Addon Namespace & Configuration
--------------------------------------------------

-- Addon namespace
local CPL = {}

-- Player scan cache expiry time in seconds (8 hours)
CPL.cacheExpiry = 28800

-- Debug mode flag
CPL.debugMode = true

-- Enabled flag
CPL.enabled = true

-- WHO query throttle timestamp
CPL.lastWhoTime = 0

-- Guild scan throttle timestamp
CPL.lastGuildScan = 0

-- WHO query queue (array of {name, attempts})
CPL.WhoQueue = {}

-- Channel configuration (future GUI will modify this)
-- Note: No hard-coded names - using dynamic channelName from game events
CPL.channelConfig = {}

-- Initialize all channels 1-7 as enabled by default
for i = 1, 7 do
    CPL.channelConfig[i] = {enabled = true}
end

--------------------------------------------------
-- Slash Commands & Command Routing
--------------------------------------------------

-- Command table for easy extension (one line to add new commands)
CPL.commands = {
    debug = {func = "toggleDebug", desc = "Toggle debug mode on/off"},
    enable = {func = "toggleEnabled", desc = "Toggle addon on/off"},
    cache = {func = "debugCache", desc = "Show cache contents (optional: /cpl cache <name> to filter)", args = "[name]", optional = true},
    queue = {func = "debugQueue", desc = "Show WHO queue contents"},
    debugframe = {func = "toggleDebugFrame", desc = "Toggle debug frame visibility"},
    help = {func = "showHelp", desc = "Show this help"}
}

-- Clean slash command system
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

            -- Create simple debug frame
            local f = CreateFrame("Frame", "CPLDebugFrame", UIParent)
            f:SetSize(400, 300)
            f:SetPoint("CENTER")
            f:SetMovable(true)
            f:SetResizable(true)
            f:SetResizeBounds(200, 150, 800, 600)
            f:EnableMouse(true)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", f.StartMoving)
            f:SetScript("OnDragStop", f.StopMovingOrSizing)

            local bg = f:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0, 0, 0, 0.8)

            -- Create clear button in top right corner
            local clearBtn = CreateFrame("Button", nil, f)
            clearBtn:SetSize(60, 20)
            clearBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
            clearBtn:SetNormalFontObject(GameFontNormalSmall)
            clearBtn:SetText("Clear")

            -- Button background
            local btnBg = clearBtn:CreateTexture(nil, "BACKGROUND")
            btnBg:SetAllPoints()
            btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

            -- Button hover
            local btnHighlight = clearBtn:CreateTexture(nil, "HIGHLIGHT")
            btnHighlight:SetAllPoints()
            btnHighlight:SetColorTexture(0.4, 0.4, 0.4, 0.5)

            -- Create resize grip in bottom right corner
            local resizeGrip = CreateFrame("Button", nil, f)
            resizeGrip:SetSize(16, 16)
            resizeGrip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
            resizeGrip:EnableMouse(true)
            resizeGrip:RegisterForDrag("LeftButton")

            -- Visual indicator for resize grip
            local gripTexture = resizeGrip:CreateTexture(nil, "OVERLAY")
            gripTexture:SetAllPoints()
            gripTexture:SetColorTexture(0.5, 0.5, 0.5, 0.5)

            -- Resize functionality
            resizeGrip:SetScript("OnDragStart", function(self)
                f:StartSizing("BOTTOMRIGHT")
                f:SetScript("OnSizeChanged", function(self, width, height)
                    -- Enforce bounds during resize
                    if width < 200 then f:SetWidth(200) end
                    if height < 150 then f:SetHeight(150) end
                    if width > 800 then f:SetWidth(800) end
                    if height > 600 then f:SetHeight(600) end
                end)
            end)

            resizeGrip:SetScript("OnDragStop", function(self)
                f:StopMovingOrSizing()
                f:SetScript("OnSizeChanged", nil)
            end)

            local scroll = CreateFrame("ScrollingMessageFrame", nil, f)
            scroll:SetPoint("TOPLEFT", 10, -30)
            scroll:SetPoint("BOTTOMRIGHT", -10, 10)
            scroll:SetFontObject(GameFontNormal)
            scroll:SetJustifyH("LEFT")
            scroll:SetFading(false)
            scroll:SetMaxLines(2000)
            scroll:EnableMouseWheel(true)
            scroll:SetScript("OnMouseWheel", function(self, delta)
                if delta > 0 then
                    self:ScrollUp()
                else
                    self:ScrollDown()
                end
            end)

            -- Store reference globally for printing
            CPL.debugFrame = scroll

            -- Clear button functionality
            clearBtn:SetScript("OnClick", function()
                scroll:Clear()
            end)

            f:Show()

            CPL:debug("SYSTEM", "- Initializing")
            CPL:debug("SYSTEM", "- Debug frame active - Toggle with /cpl debugframe")
            CPL:print("CPL: Loaded - Chat player level caching active")

            -- Display monitored channels if debug mode is on
            if CPL.debugMode then
                CPL:debugChannels()
            end

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
        -- WHO results come through CHAT_MSG_SYSTEM in Classic Era
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
    if not self.enabled then
        return
    end
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

    -- Throttle: Only scan once per 10 minutes
    local now = time()
    if (now - self.lastGuildScan) < 600 then
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
    -- Skip if addon disabled
    if not CPL.enabled then
        return false
    end

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
    -- Skip if addon disabled
    if not CPL.enabled then
        return false
    end

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

-- Register display filters for all chat types except SAY/YELL
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", PrependLevel)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", PrependLevel)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", PrependLevel)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", PrependLevel)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", PrependLevel)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_WARNING", PrependLevel)
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", PrependLevel)
ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", PrependLevel)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", PrependLevel)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", PrependLevel)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", PrependLevel)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", PrependLevel)

--------------------------------------------------
-- WHO Query System
--------------------------------------------------

-- Process WHO results when CHAT_MSG_SYSTEM fires
function CPL:processWhoResults()
    local targetName = self.whoTarget
    if not targetName then return end

    -- Process WHO results using modern API
    local numResults = C_FriendList.GetNumWhoResults()

    if numResults > 0 then
        for i = 1, numResults do
            local info = C_FriendList.GetWhoInfo(i)
            if info and info.fullName and info.level then
                if info.fullName:lower() == targetName:lower() then
                    -- Cache the result
                    self:addName(info.fullName, info.level, "WHO")
                    -- Remove from queue on successful match
                    for j, entry in ipairs(self.WhoQueue) do
                        if entry[1] == targetName then
                            table.remove(self.WhoQueue, j)
                            break
                        end
                    end
                end
            end
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

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FilterWhoResults)

--------------------------------------------------
-- WHO Queue Processing
--------------------------------------------------

-- Process WHO queue on hardware events (mouse clicks)
function CPL:processQueue()
    -- Skip if addon disabled
    if not self.enabled then
        return
    end

    -- Enforce 5-second cooldown between WHO queries
    local timeSinceLastWho = time() - self.lastWhoTime
    if timeSinceLastWho < 5 then
        self:debug("WHO", "- Throttled API call - Next in " .. string.format("%.1fs", 5 - timeSinceLastWho))
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

        -- Increment attempt counter and remove if exhausted
        entry[2] = entry[2] + 1
        if entry[2] >= 3 then
            table.remove(self.WhoQueue, 1)
            self:debug("WHO", "- Removed [" .. nextPlayer .. "] from queue - Max attempts (3)")
        end
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

    -- Increment attempt counter and remove if exhausted
    entry[2] = entry[2] + 1
    if entry[2] >= 3 then
        table.remove(self.WhoQueue, 1)
        self:debug("WHO", "- Removed [" .. nextPlayer .. "] from queue - Max attempts (3)")
    end
end

-- Hook mouse clicks to process queue
WorldFrame:HookScript("OnMouseDown", function()
    CPL:processQueue()
end)

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

    -- Debug output with normalized format (only if cached)
    if Source == "GUILD" then
        -- Guild detections stay in GUILD category, no debug output here
    elseif Source == "WHO" then
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
-- Debug & Utility Functions
--------------------------------------------------

-- Debug categories with colors
CPL.debugColors = {
    SYSTEM = {1, 1, 1},      -- White
    GUILD = {0, 1, 0},       -- Green
    DETECT = {0, 1, 1},      -- Cyan
    CHAT = {1, 1, 0},        -- Yellow
    WHO = {1, 0, 0}          -- Red
}

-- Debug output function with category-based coloring
function CPL:debug(category, ...)
    if self.debugMode then
        if self.debugFrame then
            local color = self.debugColors[category] or {1, 1, 1}  -- Default white
            -- Right-justify category name in 6-character brackets
            local paddedCategory = string.format("%6s", category)
            local msg = "[" .. paddedCategory .. "] " .. table.concat({...}, " ")
            self.debugFrame:AddMessage(msg, color[1], color[2], color[3])
        end
    end
end

-- Print to chat frame (for non-debug system messages like help, cache, etc)
function CPL:print(...)
    local msg = table.concat({...}, " ")
    DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 1)
end

-- Toggle debug mode on/off
function CPL:toggleDebug()
    self.debugMode = not self.debugMode
    self:print("CPL Debug mode:", self.debugMode and "ON" or "OFF")
end

-- Toggle addon on/off
function CPL:toggleEnabled()
    self.enabled = not self.enabled
    self:print("CPL:", self.enabled and "ENABLED" or "DISABLED")
end

-- Toggle debug frame visibility
function CPL:toggleDebugFrame()
    local frame = _G["CPLDebugFrame"]
    if frame then
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
            -- Show toggle instructions when frame is raised
            self:debug("SYSTEM", "- Debug frame active - Toggle with /cpl debugframe")
        end
    end
end

-- Show cache contents
function CPL:debugCache(filterName)
    self:print("=== CPL CACHE DEBUG ===")

    -- Build sorted cache table
    local cache = {}
    local filter = filterName and filterName:lower()
    local oldestEpoch, newestEpoch

    for name, data in pairs(CPLDB.players) do
        if not filter or name:find(filter, 1, true) then
            local epoch = data[2]
            table.insert(cache, {
                name = name,
                level = data[1],
                timestamp = date("%Y-%m-%d %H:%M:%S", epoch),
                epoch = epoch
            })

            -- Track oldest and newest timestamps
            if not oldestEpoch or epoch < oldestEpoch then oldestEpoch = epoch end
            if not newestEpoch or epoch > newestEpoch then newestEpoch = epoch end
        end
    end

    -- Sort by name
    table.sort(cache, function(a, b) return a.name < b.name end)

    -- Print summary when no filter (no dump)
    if not filter then
        self:print("Total Entries: " .. #cache)
        if oldestEpoch then
            self:print("First Timestamp: " .. date("%Y-%m-%d %H:%M:%S", oldestEpoch))
            self:print("Last Timestamp: " .. date("%Y-%m-%d %H:%M:%S", newestEpoch))
        end
        self:print("======================")
        return
    end

    -- Print filtered results with separators
    for _, entry in ipairs(cache) do
        self:print(string.format("%-15s | Lvl %2d | TS: %s", entry.name, entry.level, entry.timestamp))
    end

    self:print("Showing " .. #cache .. " player(s) matching '" .. filterName .. "'")
    self:print("======================")
end

-- Show WHO queue contents
function CPL:debugQueue()
    self:print("=== CPL WHO QUEUE ===")
    local count = 0
    for i, entry in ipairs(self.WhoQueue) do
        local name, attempts = entry[1], entry[2]
        self:print(string.format("  %d. %s (attempts: %d)", i, name, attempts))
        count = count + 1
    end
    self:print("Total: " .. count .. " player(s)")
    self:print("=====================")
end

-- Show monitored channels
function CPL:debugChannels()
    for channelNum, config in pairs(self.channelConfig) do
        if config.enabled then
            local channelID, channelName = GetChannelName(channelNum)
            if channelID > 0 then
                self:debug("SYSTEM", "- Monitoring channel " .. channelNum .. " (" .. channelName .. ")")
            end
        end
    end
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
