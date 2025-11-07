-- CPL Debug Module
-- All debug-related functionality isolated here
-- Comment out "Debug.lua" in CPL.toc to disable all debug features

-- Create debug frame on ADDON_LOADED
local debugFrame = CreateFrame("Frame")
debugFrame:RegisterEvent("ADDON_LOADED")
debugFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "CPL" then
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

        -- Create copy button in top right corner
        local copyBtn = CreateFrame("Button", nil, f)
        copyBtn:SetSize(60, 20)
        copyBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
        copyBtn:SetNormalFontObject(GameFontNormalSmall)
        copyBtn:SetText("Copy")

        -- Button background
        local copyBtnBg = copyBtn:CreateTexture(nil, "BACKGROUND")
        copyBtnBg:SetAllPoints()
        copyBtnBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

        -- Button hover
        local copyBtnHighlight = copyBtn:CreateTexture(nil, "HIGHLIGHT")
        copyBtnHighlight:SetAllPoints()
        copyBtnHighlight:SetColorTexture(0.4, 0.4, 0.4, 0.5)

        -- Create clear button next to copy button
        local clearBtn = CreateFrame("Button", nil, f)
        clearBtn:SetSize(60, 20)
        clearBtn:SetPoint("RIGHT", copyBtn, "LEFT", -5, 0)
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

        -- Store messages for copy functionality
        CPL.debugMessages = {}

        -- Create EditBox for copying (hidden by default)
        local copyBox = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        copyBox:SetPoint("TOPLEFT", 10, -30)
        copyBox:SetPoint("BOTTOMRIGHT", -30, 10)
        copyBox:Hide()

        local copyEdit = CreateFrame("EditBox", nil, copyBox)
        copyEdit:SetMultiLine(true)
        copyEdit:SetMaxLetters(0)
        copyEdit:SetFontObject(GameFontNormalSmall)
        copyEdit:SetWidth(370)
        copyEdit:SetAutoFocus(false)
        copyEdit:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            copyBox:Hide()
            scroll:Show()
            copyBtn:SetText("Copy")
            CPL.copyMode = false
        end)

        copyBox:SetScrollChild(copyEdit)
        CPL.copyMode = false

        -- Copy button functionality
        copyBtn:SetScript("OnClick", function()
            if not CPL.copyMode then
                CPL.copyMode = true
                scroll:Hide()
                copyBox:Show()
                local text = table.concat(CPL.debugMessages, "\n")
                copyEdit:SetText(text)
                copyEdit:SetCursorPosition(0)
                copyEdit:HighlightText(0, #text)
                copyEdit:SetFocus()
                copyBtn:SetText("Done")
            else
                CPL.copyMode = false
                copyEdit:ClearFocus()
                copyBox:Hide()
                scroll:Show()
                copyBtn:SetText("Copy")
            end
        end)

        -- Clear button functionality
        clearBtn:SetScript("OnClick", function()
            scroll:Clear()
            CPL.debugMessages = {}
        end)

        f:Show()

        CPL:debug("SYSTEM", "- Debug frame active - Toggle with /cpl debugframe")
    end
end)
