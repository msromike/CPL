--[[
CPL Debug Module - Optional Debugging Tools

OVERVIEW:
    Provides comprehensive debugging functionality for CPL addon including:

ARCHITECTURE:
    - Dynamically extends CPL core using stub override pattern
    - Core functions in CPL.lua are stubs (no-ops) when this module is disabled
    - Registers debug commands dynamically to CPL.commands table

COMMANDS ADDED:
    /cpl debug       - Toggle debug mode on/off
    /cpl queue       - Display WHO query queue contents
    /cpl debugframe  - Show/hide debug frame window

HOW TO DISABLE:
    Comment out "Debug.lua" in CPL.toc and restart client
    - Core addon continues to function normally
--]]

--------------------------------------------------
-- Constants
--------------------------------------------------
local FRAME_DEFAULTS = {
    width = 400,
    height = 300,
    minWidth = 200,
    minHeight = 150,
    maxWidth = 800,
    maxHeight = 600
}

local BUTTON_SIZE = { width = 60, height = 20 }
local BUTTON_SPACING = 5
local FRAME_PADDING = { top = 30, bottom = 10, left = 10, right = 10 }
local RESIZE_GRIP_SIZE = 16

-- Debug categories with colors
local DEBUG_COLORS = {
    SYSTEM = {1, 1, 1},      -- White
    GUILD = {0, 1, 0},       -- Green
    DETECT = {0, 1, 1},      -- Cyan
    CHAT = {1, 1, 0},        -- Yellow
    WHO = {1, 0, 0}          -- Red
}

--------------------------------------------------
-- Debug Message Handler
--------------------------------------------------

local MAX_STORED_MESSAGES = 2000
local CATEGORY_WIDTH = 6

-- Override the stub debug function from CPL.lua
function CPL:debug(category, ...)
    if not self.debugMode or not self.debugFrame then
        return
    end

    local color = DEBUG_COLORS[category] or DEBUG_COLORS.SYSTEM
    local paddedCategory = string.format("%-" .. CATEGORY_WIDTH .. "s", category)  -- Left justify with -
    local timestamp = date("%H:%M:%S")
    local msg = "[" .. timestamp .. "] [" .. paddedCategory .. "] " .. table.concat({...}, " ")

    -- Display in frame
    self.debugFrame:AddMessage(msg, color[1], color[2], color[3])

    -- Store for copy functionality
    table.insert(self.debugMessages, msg)
    if #self.debugMessages > MAX_STORED_MESSAGES then
        table.remove(self.debugMessages, 1)
    end
end

--------------------------------------------------
-- Debug Commands
--------------------------------------------------

-- Command output formatting constants
local QUEUE_HEADER = "=== CPL WHO QUEUE ==="
local QUEUE_FOOTER = "====================="
local QUEUE_FORMAT = "  %d. %s (attempts: %d)"

-- Toggle debug mode on/off
-- Overrides stub from CPL.lua when Debug.lua is loaded
function CPL:toggleDebug()
    self.debugMode = not self.debugMode
    self:print("CPL Debug mode:", self.debugMode and "ON" or "OFF")
end

-- Show or hide the debug frame window
-- Overrides stub from CPL.lua when Debug.lua is loaded
function CPL:toggleDebugFrame()
    local frame = _G["CPLDebugFrame"]
    if not frame then
        return
    end

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        self:debug("SYSTEM", "- Debug frame active - Toggle with /cpl debugframe")
    end
end

-- Display WHO query queue contents to chat
-- Shows pending player lookups with attempt counts
-- Overrides stub from CPL.lua when Debug.lua is loaded
function CPL:debugQueue()
    self:print(QUEUE_HEADER)

    for i, entry in ipairs(self.WhoQueue) do
        self:print(string.format(QUEUE_FORMAT, i, entry[1], entry[2]))
    end

    self:print("Total: " .. #self.WhoQueue .. " player(s)")
    self:print(QUEUE_FOOTER)
end

-- Display currently monitored channels to debug frame
-- Called on startup when debug mode is enabled
-- Overrides stub from CPL.lua when Debug.lua is loaded
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

--------------------------------------------------
-- Command Registration
--------------------------------------------------

-- Dynamically register debug commands when module loads
-- These commands only appear in /cpl help when Debug.lua is loaded
CPL.commands.debug = {func = "toggleDebug", desc = "Toggle debug mode on/off"}
CPL.commands.queue = {func = "debugQueue", desc = "Show WHO queue contents"}
CPL.commands.debugframe = {func = "toggleDebugFrame", desc = "Toggle debug frame visibility"}

--------------------------------------------------
-- Helper Functions
--------------------------------------------------

-- Creates a styled button with consistent appearance
local function CreateStyledButton(parent, text, point, relativeFrame, relativePoint, offsetX, offsetY)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(BUTTON_SIZE.width, BUTTON_SIZE.height)
    button:SetPoint(point, relativeFrame, relativePoint, offsetX, offsetY)
    button:SetNormalFontObject(GameFontNormalSmall)
    button:SetText(text)

    -- Background
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    -- Hover effect
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.4, 0.4, 0.4, 0.5)

    return button
end

-- Creates the copy interface (EditBox with scroll frame)
local function CreateCopyInterface(parent, scrollFrame, copyButton)
    local copyScrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    copyScrollFrame:SetPoint("TOPLEFT", FRAME_PADDING.left, -FRAME_PADDING.top)
    copyScrollFrame:SetPoint("BOTTOMRIGHT", -30, FRAME_PADDING.bottom)
    copyScrollFrame:Hide()

    local copyEdit = CreateFrame("EditBox", nil, copyScrollFrame)
    copyEdit:SetMultiLine(true)
    copyEdit:SetMaxLetters(0)
    copyEdit:SetFontObject(GameFontNormalSmall)
    copyEdit:SetWidth(FRAME_DEFAULTS.width - 40)
    copyEdit:SetAutoFocus(false)

    copyEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        copyScrollFrame:Hide()
        scrollFrame:Show()
        copyButton:SetText("Copy")
        CPL.copyMode = false
    end)

    copyScrollFrame:SetScrollChild(copyEdit)

    return copyScrollFrame, copyEdit
end

-- Creates the resize grip for the frame
local function CreateResizeGrip(frame)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(RESIZE_GRIP_SIZE, RESIZE_GRIP_SIZE)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")

    -- Visual indicator
    local texture = grip:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    -- Resize handlers
    grip:SetScript("OnDragStart", function()
        frame:StartSizing("BOTTOMRIGHT")
        frame:SetScript("OnSizeChanged", function(self, width, height)
            if width < FRAME_DEFAULTS.minWidth then self:SetWidth(FRAME_DEFAULTS.minWidth) end
            if height < FRAME_DEFAULTS.minHeight then self:SetHeight(FRAME_DEFAULTS.minHeight) end
            if width > FRAME_DEFAULTS.maxWidth then self:SetWidth(FRAME_DEFAULTS.maxWidth) end
            if height > FRAME_DEFAULTS.maxHeight then self:SetHeight(FRAME_DEFAULTS.maxHeight) end
        end)
    end)

    grip:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        frame:SetScript("OnSizeChanged", nil)
    end)

    return grip
end

-- Creates the main debug frame
local function CreateDebugFrame()
    -- Main frame
    local frame = CreateFrame("Frame", "CPLDebugFrame", UIParent)
    frame:SetSize(FRAME_DEFAULTS.width, FRAME_DEFAULTS.height)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(FRAME_DEFAULTS.minWidth, FRAME_DEFAULTS.minHeight,
                          FRAME_DEFAULTS.maxWidth, FRAME_DEFAULTS.maxHeight)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)

    -- Buttons
    local copyBtn = CreateStyledButton(frame, "Copy", "TOPRIGHT", frame, "TOPRIGHT", -BUTTON_SPACING, -BUTTON_SPACING)
    local clearBtn = CreateStyledButton(frame, "Clear", "RIGHT", copyBtn, "LEFT", -BUTTON_SPACING, 0)

    -- Scrolling message frame
    local scroll = CreateFrame("ScrollingMessageFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", FRAME_PADDING.left, -FRAME_PADDING.top)
    scroll:SetPoint("BOTTOMRIGHT", -FRAME_PADDING.right, FRAME_PADDING.bottom)
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

    -- Initialize state
    CPL.debugFrame = scroll
    CPL.debugMessages = {}
    CPL.copyMode = false

    -- Copy interface
    local copyScrollFrame, copyEdit = CreateCopyInterface(frame, scroll, copyBtn)

    -- Button handlers
    copyBtn:SetScript("OnClick", function()
        if not CPL.copyMode then
            CPL.copyMode = true
            scroll:Hide()
            copyScrollFrame:Show()
            local text = table.concat(CPL.debugMessages, "\n")
            copyEdit:SetText(text)
            copyEdit:SetCursorPosition(0)
            copyEdit:HighlightText(0, #text)
            copyEdit:SetFocus()
            copyBtn:SetText("Done")
        else
            CPL.copyMode = false
            copyEdit:ClearFocus()
            copyScrollFrame:Hide()
            scroll:Show()
            copyBtn:SetText("Copy")
        end
    end)

    clearBtn:SetScript("OnClick", function()
        scroll:Clear()
        CPL.debugMessages = {}
    end)

    -- Resize grip
    CreateResizeGrip(frame)

    frame:Show()
    CPL:debug("SYSTEM", "- Debug frame active - Toggle with /cpl debugframe")
end

--------------------------------------------------
-- Module Initialization
--------------------------------------------------

-- Initialize debug module when CPL addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "CPL" then
        -- Create the debug frame UI
        CreateDebugFrame()

        -- Clean up event handler
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
