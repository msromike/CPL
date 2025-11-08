std = "max"
unused_args = false
max_line_length = false
allow_defined_top = true
ignore = {"212"}  -- Ignore unused argument warnings for stub functions

read_globals = {
    "CreateFrame",
    "ChatFrame_AddMessageEventFilter",
    "UnitExists",
    "UnitName",
    "UnitLevel",
    "UnitIsPlayer",
    "UnitClass",
    "UnitRace",
    "strsplit",
    "strjoin",
    "print",
    "select",
    "pairs",
    "ipairs",
    "next",
    "type",
    "tostring",
    "tonumber",
    "table",
    "string",
    "math",
    "bit",
    "C_AddOns",
    "C_FriendList",
    "C_Timer",
    "LibStub",
    "GetAddOnMetadata",
    "IsAddOnLoaded",
    "SlashCmdList",
    "GetNumGroupMembers",
    "GetNumSubgroupMembers",
    "GetRaidRosterInfo",
    "IsInRaid",
    "GetNumGuildMembers",
    "GetGuildRosterInfo",
    "UnitIsFriend",
    "time",
    "WorldFrame",
    "GetChannelName",
    "date",
    "DEFAULT_CHAT_FRAME",
    "GameFontNormal",
    "GameFontNormalSmall",
    "UIParent",
    "GetTime",
    "IsInGuild",
    "GuildRoster",
    "Chattynator",  -- Optional dependency
    "CPL",          -- Our global namespace
}

globals = {
    "ADDON_LOADED",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_LOGIN",
    "PLAYER_LOGOUT",
    "CPLDB",
    "_G",
    "SLASH_CPL1",
}