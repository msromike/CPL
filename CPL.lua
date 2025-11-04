-- CPL - Chat Player Levels (Minimal Test)
-- Shows [??:playername] for everyone

-- State tracking
local cplEnabled = true

-- Simple function to modify chat messages
local function AddLevelToChat(self, event, msg, author, ...)
    -- Check if CPL is enabled
    if not cplEnabled then
        return false  -- Pass through unchanged
    end

    -- Split server name from player name
    local name = strsplit("-", author)

    -- Prepend level info to the message instead of modifying author
    -- This keeps the author clickable while still showing level info
    local modifiedMsg = "[??:" .. name .. "] " .. msg

    -- Return with original author intact, modified message
    return false, modifiedMsg, author, ...
end

-- Chat events where we want to show player levels
-- Focus on core social communication channels only
local events = {
    -- ACTIVE EVENTS
    -- Local Communication
    "CHAT_MSG_SAY",                 -- Local area chat (white text)
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

-- Slash command handler
local function HandleSlashCommand(msg)
    local command = string.lower(msg or "")

    if command == "status" then
        local status = cplEnabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r"
        print("CPL status: " .. status)

    elseif command == "enable" then
        cplEnabled = true
        print("CPL |cff00ff00enabled|r - Player levels will be shown in chat")

    elseif command == "disable" then
        cplEnabled = false
        print("CPL |cffff0000disabled|r - Player levels hidden from chat")

    else
        -- Show help
        print("CPL - Chat Player Levels Commands:")
        print("  /cpl status  - Show current status")
        print("  /cpl enable  - Enable level display")
        print("  /cpl disable - Disable level display")
    end
end

-- Register slash commands
SLASH_CPL1 = "/cpl"
SlashCmdList["CPL"] = HandleSlashCommand

print("CPL - Chat Player Levels loaded")
print("CPL: Registered filters for " .. #events .. " chat events")
print("CPL: Use '/cpl status' to check if enabled")