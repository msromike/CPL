-- CPL Debug Module
-- Provides visual debug frame with message scrolling and copy functionality
-- To disable: Comment out "Debug.lua" in CPL.toc

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
-- Initialization
--------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "CPL" then
        CreateDebugFrame()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
