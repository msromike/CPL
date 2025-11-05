-- CPL - Chat Player Levels (Minimal Test)
-- Shows [??:playername] for everyone

-- State tracking
local cplEnabled = true

-- Bulletproof initialization function
local function InitializeCPLDB()
    if not CPLDB then CPLDB = {} end
    if not CPLDB.levels then CPLDB.levels = {} end
    if not CPLDB.indices then CPLDB.indices = {} end
    if not CPLDB.knownHoles then CPLDB.knownHoles = {} end
    if not CPLDB.lastScanIndex then CPLDB.lastScanIndex = 1 end
    if not CPLDB.guildMembers then CPLDB.guildMembers = {} end  -- New CSV-like structure
end

-- Initialize persistent data collection
InitializeCPLDB()

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
    -- Local Communication (SAY removed - you can see those players directly)
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

-- Simple data collection for testing persistence
local function OnTargetChanged()
    local name = UnitName("target")
    local level = UnitLevel("target")
    local isPlayer = UnitIsPlayer("target")

    if name and level and tonumber(level) and tonumber(level) > 0 and isPlayer then
        if not CPLDB then CPLDB = {} end
        if not CPLDB.levels then CPLDB.levels = {} end
        CPLDB.levels[name:lower()] = tonumber(level)
    end
end-- Guild roster scanning state
local needToScanGuild = false
local lastGuildScanTime = 0
local SCAN_THROTTLE_DELAY = 0.1  -- Delay between member scans (seconds)
local scanningHoles = false  -- Track if we're scanning holes or regular progression

-- Function to handle guild roster scanning
local function StartGuildScan()
    -- Don't start scanning if CPL is disabled
    if not cplEnabled then
        return
    end

    if IsInGuild() then
        needToScanGuild = true
        scanningHoles = false
        -- Resume from where we left off, don't restart at 1
        GuildRoster()  -- Request fresh data from server
        print("CPL: Resuming guild scan from index " .. CPLDB.lastScanIndex)
    end
end

-- Function to scan known holes for new members
local function ScanKnownHoles()
    InitializeCPLDB()  -- Ensure data structure exists

    if not IsInGuild() then return false end

    for holeIndex, _ in pairs(CPLDB.knownHoles) do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(holeIndex)
        if name and level and tonumber(level) and tonumber(level) > 0 then
            -- Hole filled! New member found
            local cleanName = name:match("([^-]+)")  -- Remove server suffix
            if cleanName then
                -- Ensure all CPLDB tables exist
                if not CPLDB.levels then CPLDB.levels = {} end
                if not CPLDB.indices then CPLDB.indices = {} end
                if not CPLDB.knownHoles then CPLDB.knownHoles = {} end

                -- Old format
                CPLDB.levels[cleanName:lower()] = tonumber(level)
                CPLDB.indices[holeIndex] = cleanName:lower()
                CPLDB.knownHoles[holeIndex] = nil  -- Remove from holes

                -- New CSV-like format
                CPLDB.guildMembers[holeIndex] = {
                    name = cleanName:lower(),
                    level = tonumber(level),
                    class = class,
                    rank = rank,
                    online = online,
                    zone = zone
                }

                print("CPL: New member found in hole " .. holeIndex .. ": " .. cleanName .. " (level " .. level .. ")")
            end
        end
        return true  -- Processed one hole, throttle next call
    end
    return false  -- No holes to scan
end

-- Function to process one guild member (called from OnUpdate)
local function ProcessOneGuildMember()
    InitializeCPLDB()  -- Ensure data structure exists

    if not needToScanGuild or not IsInGuild() then
        return false  -- Nothing to do
    end

    -- First priority: Check holes for new members (fast)
    if not scanningHoles and CPLDB.knownHoles and next(CPLDB.knownHoles) then
        scanningHoles = true
        return ScanKnownHoles()
    end

    -- Second priority: Continue regular scanning from last position
    local totalMembers = GetNumGuildMembers()

    -- Ensure lastScanIndex is initialized
    if not CPLDB.lastScanIndex then
        CPLDB.lastScanIndex = 1
    end

    -- Check if we've completed a full scan cycle
    if CPLDB.lastScanIndex > totalMembers then
        CPLDB.lastScanIndex = 1  -- Wrap around to start
        needToScanGuild = false  -- Mark scan complete for now
        print("CPL: Guild scan cycle completed, will resume on next trigger")
        return false
    end

    -- Get info for current member (get all available data)
    local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(CPLDB.lastScanIndex)

    if name and level and tonumber(level) and tonumber(level) > 0 then
        -- Store level data (remove server name if present)
        local cleanName = name:match("([^-]+)")  -- Remove -ServerName suffix
        if cleanName then
            -- Old format (keep for now)
            CPLDB.levels[cleanName:lower()] = tonumber(level)
            CPLDB.indices[CPLDB.lastScanIndex] = cleanName:lower()

            -- New CSV-like format - store all data in one record
            CPLDB.guildMembers[CPLDB.lastScanIndex] = {
                name = cleanName:lower(),
                level = tonumber(level),
                class = class,
                rank = rank,
                online = online,
                zone = zone
            }
        end

        -- Progress feedback every 50 members
        if CPLDB.lastScanIndex % 50 == 0 then
            print("CPL: Scanned " .. CPLDB.lastScanIndex .. "/" .. totalMembers .. " guild members")
        end

    elseif not name then
        -- Found a hole - record it in old format and clear new format
        CPLDB.knownHoles[CPLDB.lastScanIndex] = true
        CPLDB.guildMembers[CPLDB.lastScanIndex] = nil  -- Clear any old data for this slot
    end

    CPLDB.lastScanIndex = CPLDB.lastScanIndex + 1
    scanningHoles = false  -- Reset for next cycle
    return true  -- Processed one member
end-- Main frame for events and OnUpdate processing
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")

-- OnUpdate script for throttled guild scanning
frame:SetScript("OnUpdate", function(self, elapsed)
    -- STOP EVERYTHING if CPL is disabled
    if not cplEnabled then
        return
    end

    if needToScanGuild and (GetTime() - lastGuildScanTime) >= SCAN_THROTTLE_DELAY then
        if ProcessOneGuildMember() then
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
    end
end)

-- Slash command handler
local function HandleSlashCommand(msg)
    local command = string.lower(msg or "")

    if command == "status" then
        local status = cplEnabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r"
        local levelCount = 0
        local indexCount = 0
        local holeCount = 0

        if CPLDB and CPLDB.levels then
            for _ in pairs(CPLDB.levels) do levelCount = levelCount + 1 end
        end
        if CPLDB and CPLDB.indices then
            for _ in pairs(CPLDB.indices) do indexCount = indexCount + 1 end
        end
        if CPLDB and CPLDB.knownHoles then
            for _ in pairs(CPLDB.knownHoles) do holeCount = holeCount + 1 end
        end

        local scanStatus = needToScanGuild and "|cffffaa00scanning...|r" or "|cff00ff00idle|r"

        print("CPL status: " .. status)
        print("CPL: " .. levelCount .. " player levels cached")
        print("CPL: " .. indexCount .. " guild indices mapped")
        print("CPL: " .. holeCount .. " known holes tracked")
        print("CPL: Next scan starts at index " .. (CPLDB.lastScanIndex or 1))
        print("CPL: Guild scanner " .. scanStatus)

        if IsInGuild() and GetNumGuildMembers() then
            print("CPL: Guild has " .. GetNumGuildMembers() .. " members")
        end    elseif command == "enable" then
        cplEnabled = true
        print("CPL |cff00ff00enabled|r - Player levels will be shown in chat")

    elseif command == "disable" then
        cplEnabled = false
        needToScanGuild = false  -- Stop any ongoing scan
        print("CPL |cffff0000disabled|r - Player levels hidden from chat and scanning stopped")

    elseif command == "scan" or command == "guild" then
        if IsInGuild() then
            StartGuildScan()
            print("CPL: Starting guild roster scan...")
        else
            print("CPL: You must be in a guild to scan roster")
        end

    elseif command == "clear" then
        if CPLDB and CPLDB.levels then
            local count = 0
            for _ in pairs(CPLDB.levels) do count = count + 1 end
            CPLDB.levels = {}
            print("CPL: Cleared " .. count .. " cached player levels")
        else
            print("CPL: No cached data to clear")
        end

    elseif command == "members" then
        if CPLDB and CPLDB.guildMembers then
            local count = 0
            print("CPL: Guild Members (CSV Format):")
            print("Index | Name | Level | Class | Rank | Online | Zone")
            print("------|------|-------|-------|------|--------|------")
            for index, member in pairs(CPLDB.guildMembers) do
                count = count + 1
                local online = member.online and "Yes" or "No"
                local zone = member.zone or "Unknown"
                print(string.format("%5d | %-12s | %5d | %-8s | %-10s | %-6s | %s",
                    index, member.name, member.level, member.class or "?",
                    member.rank or "?", online, zone))
                if count >= 20 then  -- Limit output to prevent spam
                    print("... and " .. (table.getn and table.getn(CPLDB.guildMembers) or "more") .. " more members")
                    break
                end
            end
            print("CPL: Total guild members in new format: " .. count)
        else
            print("CPL: No guild member data in new format")
        end

    else
        -- Show help
        print("CPL - Chat Player Levels Commands:")
        print("  /cpl status  - Show current status and cached data")
        print("  /cpl enable  - Enable level display")
        print("  /cpl disable - Disable level display")
        print("  /cpl scan    - Manually scan guild roster")
        print("  /cpl clear   - Clear all cached level data")
        print("  /cpl members - Show guild members in new CSV format")
    end
end

-- Register slash commands
SLASH_CPL1 = "/cpl"
SlashCmdList["CPL"] = HandleSlashCommand

print("CPL - Chat Player Levels loaded")
print("CPL: Registered filters for " .. #events .. " chat events")
print("CPL: Guild roster scanning enabled")
print("CPL: Use '/cpl status' to check status and cached data")