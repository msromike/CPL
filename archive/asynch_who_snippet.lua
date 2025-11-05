-- This table is globally accessible and will store the data.
-- Your AddOn retrieves the data from here AFTER the WHO_LIST_UPDATE fires.
-- Key: Player Name (e.g., "Grum")
-- Value: Table containing {level, class, zone}
WHO_DATA_CACHE = WHO_DATA_CACHE or {}
local QueryFrame = CreateFrame("Frame", "WhoQueryFrame")
local LAST_QUERIED_NAME = nil

-- CORE FUNCTION: Call this from your AddOn's queue management system.
-- It triggers the server query silently.
function WhoQuery_Start(name)
    if not name or name == "" then return end

    -- 1. Store the name so we know who the server is responding about.
    LAST_QUERIED_NAME = name

    -- 2. Execute the /who command silently. This forces the server lookup.
    RunSystemCommand("who " .. name)
end

-- EVENT HANDLER: Fired when the server sends the /who response.
local function OnWhoListUpdate(self, event)
    if not LAST_QUERIED_NAME then return end

    local name = LAST_QUERIED_NAME
    LAST_QUERIED_NAME = nil -- Clear immediately, ready for the next query.

    local numResults = GetNumWhoResults()

    -- We only proceed if we got exactly one result (the player we queried).
    if numResults == 1 then
        local resultName, _, level, _, class, zone = GetWhoInfo(1)

        -- Double-check the returned name matches the one we queried.
        if resultName == name then
            -- CRITICAL: Store the data in the global cache table.
            WHO_DATA_CACHE[name] = {
                level = level,
                class = class,
                zone = zone,
                timestamp = GetTime(),
            }
        end
    end
end

-- SETUP: Required to listen for the server's delayed response.
QueryFrame:RegisterEvent("WHO_LIST_UPDATE")
QueryFrame:SetScript("OnEvent", OnWhoListUpdate)