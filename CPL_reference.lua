-- CPL - Chat Player Levels (Minimal Test)
-- Shows [??:playername] for everyone

-- State tracking
local cplEnabled = true

-- LEAN initialization function - new format only
local function InitDB()
    if not CPLDB then
        CPLDB = {
            members = {},   -- [guildIndex] = {name="playername", level=42}
            scanPos = 1     -- Current scan position
        }
    end
    if not CPLDB.members then CPLDB.members = {} end
    if not CPLDB.scanPos then CPLDB.scanPos = 1 end
end

-- Initialize LEAN database
InitDB()

-- Simple function to modify chat messages
local function AddLevelToChat(self, event, msg, author, ...)
    -- Check if CPL is enabled
    if not cplEnabled then
        return false  -- Pass through unchanged
    end

    -- Modify the message to include level info, keep author unchanged for right-click
    local modifiedMsg = "[??] " .. msg

    -- Return with original author intact, modified message
    return false, modifiedMsg, author, ...
end

-- Chat events where we want to show player levels
-- Focus on core social communication channels only
local events = {
    -- ACTIVE EVENTS
    "CHAT_MSG_WHISPER",             -- Incoming private messages
    -- Group Coordination
    "CHAT_MSG_PARTY",               -- Party chat (blue text)
    "CHAT_MSG_PARTY_LEADER",        -- Party leader messages (blue with icon)
    "CHAT_MSG_RAID",                -- Raid chat (orange text)
    "CHAT_MSG_RAID_LEADER",         -- Raid leader messages (orange with icon)
    "CHAT_MSG_INSTANCE_CHAT",       -- Dungeon/instance group chat
    "CHAT_MSG_INSTANCE_CHAT_LEADER", -- Instance group leader messages
    -- Guild Communications
    "CHAT_MSG_GUILD",               -- Guild chat (green text)
    "CHAT_MSG_OFFICER",             -- Officer chat (light green text)
    -- Public Channels
    "CHAT_MSG_CHANNEL",             -- Custom channels (/1 General, /2 Trade, etc.)

    -- DISABLED EVENTS
    -- Local Communication (SAY removed - you can see those players directly)
    -- "CHAT_MSG_YELL",             -- Yell messages (often roleplay/immersion)
    -- "CHAT_MSG_WHISPER_INFORM",   -- YOUR outgoing whispers (you=author, target in text)
    -- "CHAT_MSG_RAID_WARNING",     -- Raid warnings (large center text, keep clean)
    -- "CHAT_MSG_BN_WHISPER",       -- Battle.net friends (cross-game/server)
    -- "CHAT_MSG_BN_WHISPER_INFORM", -- Battle.net confirmations
    -- "CHAT_MSG_COMMUNITIES_CHANNEL", -- Community/club chat
    -- "CHAT_MSG_BATTLEGROUND",     -- Battleground team chat
    -- "CHAT_MSG_BATTLEGROUND_LEADER", -- BG leader messages
    -- "CHAT_MSG_BG_SYSTEM_NEUTRAL", -- BG system announcements
    -- "CHAT_MSG_BG_SYSTEM_ALLIANCE", -- BG system (Alliance)
    -- "CHAT_MSG_BG_SYSTEM_HORDE",  -- BG system (Horde)
    -- "CHAT_MSG_ACHIEVEMENT",      -- Achievement announcements
    -- "CHAT_MSG_GUILD_ACHIEVEMENT", -- Guild achievement announcements
    -- "CHAT_MSG_EMOTE",            -- Player emotes
    -- "CHAT_MSG_TEXT_EMOTE",       -- Text emotes
    -- "CHAT_MSG_SYSTEM",           -- System messages
    -- "CHAT_MSG_MONSTER_SAY",      -- NPC dialogue
    -- "CHAT_MSG_MONSTER_YELL"      -- NPC yells
}

-- Register the filter for all events
for _, event in pairs(events) do
    ChatFrame_AddMessageEventFilter(event, AddLevelToChat)
end

-- LEAN targeting data collection - new format only
local function OnTargetChanged()
    local name = UnitName("target")
    local level = UnitLevel("target")

    if name and level and tonumber(level) > 0 and UnitIsPlayer("target") then
        local cleanName = name:lower():match("^([^%-]+)")  -- Remove server suffix
        -- Store in new format at index 0 (non-guild player)
        CPLDB.members[0] = {name = cleanName, level = tonumber(level)}
    end
end

-- LEAN guild scanning state
local needToScanGuild = false
local lastGuildScanTime = 0
local SCAN_THROTTLE_DELAY = 0.1

-- LEAN guild scan starter
local function StartGuildScan()
    if not cplEnabled then return end

    if IsInGuild() then
        needToScanGuild = true
        GuildRoster()
        print("CPL: Starting guild scan from position " .. CPLDB.scanPos)
    end
end

-- LEAN guild member scanning - new format only
local function ScanOneGuildMember()
    if not needToScanGuild or not IsInGuild() then
        return false
    end

    local totalMembers = GetNumGuildMembers()

    -- Wrap around when we reach the end
    if CPLDB.scanPos > totalMembers then
        CPLDB.scanPos = 1
        needToScanGuild = false
        print("CPL: Guild scan completed")
        return false
    end

    -- Scan current position - get all data
    local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(CPLDB.scanPos)

    if name and level and tonumber(level) > 0 then
        local cleanName = name:lower():match("^([^%-]+)")
        if cleanName then
            -- Use server time for consistent timestamps across sessions
            local serverTime = GetServerTime()  -- This gives Unix epoch time
            local currentTime = serverTime
            local guildIndex = CPLDB.scanPos
            local existingMember = CPLDB.members[guildIndex]

            -- Check if this is a level change
            local newLevel = tonumber(level)
            local previousLevel = 0
            local previousTimestamp = 0
            local scanCount = 1
            local firstScanned = currentTime

            if existingMember then
                -- Update existing member
                scanCount = (existingMember.scanCount or 0) + 1
                firstScanned = existingMember.firstScanned or currentTime

                if existingMember.level ~= newLevel then
                    -- Level changed! Store transition
                    previousLevel = existingMember.level
                    previousTimestamp = existingMember.lastUpdated
                else
                    -- Level same, keep previous data
                    previousLevel = existingMember.previousLevel or 0
                    previousTimestamp = existingMember.previousTimestamp or 0
                end
            end

            CPLDB.members[guildIndex] = {
                name = cleanName,
                level = newLevel,
                guildIndex = guildIndex,        -- Store the guild roster index explicitly
                lastUpdated = currentTime,
                previousLevel = previousLevel,
                previousTimestamp = previousTimestamp,
                lastSeen = online and currentTime or 0,
                firstScanned = firstScanned,
                scanCount = scanCount
            }
        end
    else
        -- Empty slot - clear any old data
        CPLDB.members[CPLDB.scanPos] = nil
    end

    CPLDB.scanPos = CPLDB.scanPos + 1
    return true
end-- WHO testing globals
WHO_TEST_CACHE = WHO_TEST_CACHE or {}
local LAST_WHO_QUERY = nil

-- Main frame for events and OnUpdate processing
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("WHO_LIST_UPDATE")

-- OnUpdate script for throttled guild scanning
frame:SetScript("OnUpdate", function(self, elapsed)
    -- STOP EVERYTHING if CPL is disabled
    if not cplEnabled then
        return
    end

    if needToScanGuild and (GetTime() - lastGuildScanTime) >= SCAN_THROTTLE_DELAY then
        if ScanOneGuildMember() then
            lastGuildScanTime = GetTime()
        end
    end
end)

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        OnTargetChanged()
    elseif event == "GUILD_ROSTER_UPDATE" then
        -- Start a new scan when guild roster changes
        StartGuildScan()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Scan guild roster when we log in
        C_Timer.After(2, StartGuildScan)  -- Small delay to let guild data load
    elseif event == "PLAYER_GUILD_UPDATE" then
        -- Handle guild join/leave events
        if IsInGuild() then
            C_Timer.After(1, StartGuildScan)
        end
    elseif event == "WHO_LIST_UPDATE" then
        -- WHO test event handler
        local numResults = GetNumWhoResults()
        print("CPL: WHO_LIST_UPDATE fired - " .. numResults .. " results")

        if LAST_WHO_QUERY and numResults == 1 then
            local resultName, _, level, _, class, zone = GetWhoInfo(1)
            print("CPL: WHO result - " .. (resultName or "nil") .. " Level " .. (level or "nil"))

            if resultName == LAST_WHO_QUERY then
                WHO_TEST_CACHE[resultName] = {
                    level = level,
                    class = class,
                    zone = zone,
                    timestamp = GetTime()
                }
                print("CPL: Cached data for " .. resultName)
            end
            LAST_WHO_QUERY = nil
        end
    end
end)

-- Slash command handler
local function HandleSlashCommand(msg)
    local command = string.lower(msg or "")

    if command == "status" then
        local memberCount = 0
        if CPLDB.members then
            for _ in pairs(CPLDB.members) do memberCount = memberCount + 1 end
        end

        print("CPL Status:")
        print("  Level display: " .. (cplEnabled and "ON" or "OFF"))
        print("  Guild members cached: " .. memberCount)
        print("  Current scan position: " .. CPLDB.scanPos)
        print("  Scanner: " .. (needToScanGuild and "ACTIVE" or "IDLE"))
        if IsInGuild() and GetNumGuildMembers() then
            print("  Guild size: " .. GetNumGuildMembers() .. " members")
        end

    elseif command == "enable" then
        cplEnabled = true
        print("CPL: Level display ENABLED - you'll now see [level] in chat messages")

    elseif command == "disable" then
        cplEnabled = false
        needToScanGuild = false
        print("CPL: Level display DISABLED - chat will show [??] instead")

    elseif command == "scan" then
        if IsInGuild() then
            StartGuildScan()
            print("CPL: Guild scan started - collecting member levels...")
        else
            print("CPL: You must be in a guild to scan member levels")
        end

    elseif command == "clear" then
        local oldCount = 0
        if CPLDB.members then
            for _ in pairs(CPLDB.members) do oldCount = oldCount + 1 end
        end
        CPLDB.members = {}
        CPLDB.scanPos = 1
        print("CPL: Cleared " .. oldCount .. " cached member levels")

    elseif command == "list" then
        local count = 0
        print("CPL Guild Members (showing first 10):")
        for index, member in pairs(CPLDB.members) do
            if count < 10 then
                local onlineStatus = (member.lastSeen > 0) and "Online" or "Offline"
                local prevInfo = (member.previousLevel > 0) and
                    string.format(" (was %d)", member.previousLevel) or ""
                print("  " .. string.format("%3d: %-12s Lv%2d%s [%s] Scans:%d",
                    index, member.name, member.level, prevInfo, onlineStatus, member.scanCount))
            end
            count = count + 1
        end
        if count > 10 then
            print("  ... and " .. (count - 10) .. " more members")
        end
        print("CPL: Total " .. count .. " members in database")

    elseif command:match("^who ") then
        local playerName = command:match("^who (.+)")
        if playerName and playerName ~= "" then
            print("CPL: Testing WHO query for '" .. playerName .. "'")

            if SendWho then
                print("CPL: Using SendWho API...")
                LAST_WHO_QUERY = playerName
                SendWho(playerName)
            else
                print("CPL: ERROR - SendWho function not found!")
            end
        else
            print("CPL: Usage: /cpl who PlayerName")
        end

    else
        print("CPL Commands:")
        print("  /cpl status  - Show addon status and statistics")
        print("  /cpl enable  - Turn on level display in chat")
        print("  /cpl disable - Turn off level display")
        print("  /cpl scan    - Start guild member scanning")
        print("  /cpl clear   - Clear all cached data")
        print("  /cpl list    - Show cached guild members")
        print("  /cpl who <name> - Test WHO query for player")
    end
end

-- Register slash commands
SLASH_CPL1 = "/cpl"
SlashCmdList["CPL"] = HandleSlashCommand

print("CPL - Chat Player Levels loaded")
print("CPL: Registered filters for " .. #events .. " chat events")
print("CPL: Guild roster scanning enabled")
print("CPL: Use '/cpl status' to check status and cached data")