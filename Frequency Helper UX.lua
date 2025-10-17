require "lib.moonloader"
local samp = require 'lib.samp.events'
local encoding = require 'encoding'
local imgui = require 'mimgui'
local new = imgui.new
local ffi = require 'ffi'
encoding.default = 'CP1251'
u8 = encoding.UTF8
script_name("Frequency Helper - customizable tags")
script_version("2.0")

-- ======================================
-- Íàñòðàèâàåìûé ñêðèïò: îðãàíèçàöèè è øàáëîíû
-- Âñ¸ õðàíèòñÿ â frequency_helper.ini
-- ======================================

-- Default data (used if INI absent or to reset)
local DEFAULT_ORGANIZATIONS = {
    u8"Ïðàâèòåëüñòâî",
    u8"Ïðîêóðàòóðà",
    u8"Ñóä",
    u8"Öåíòð ëèöåíçèðîâàíèÿ",
    u8"Ïîæàðíûé äåïàðòàìåíò",
    u8"ÔÁÐ",
    u8"Ïîëèöèÿ ËÑ",
    u8"Ïîëèöèÿ ÑÔ",
    u8"Ïîëèöèÿ ËÂ",
    u8"Îáëàñòíàÿ ïîëèöèÿ",
    u8"Àðìèÿ ËÑ",
    u8"ÂÌÑ",
    u8"Delta Force",
    u8"MPC",
    u8"Òþðüìà ËÂ",
    u8"Áîëüíèöà ËÑ",
    u8"Áîëüíèöà ÑÔ",
    u8"Áîëüíèöà ËÂ",
    u8"Áîëüíèöà JF",
    u8"ÑÌÈ ËÑ",
    u8"ÑÌÈ ÑÔ",
    u8"ÑÌÈ ËÂ",
    u8"Ñòðàõîâàÿ",
    u8"Ïîõèòèòåëè",
    u8"Èíôîðìàöèÿ",
    u8"S.W.A.T"
}

local DEFAULT_TEMPLATES = {
    techMessage = u8"/b [%s] - [Èíôîðìàöèÿ]: Òåõíè÷åñêèå íåïîëàäêè",
    interviewStart = {
        u8"/b [%s] - [Èíôîðìàöèÿ]: Íà÷èíàþ ñîáåñåäîâàíèå",
        u8"/b [%s] - [Èíôîðìàöèÿ]: Ïðîøó íå áåñïîêîèòü, ïðîâîäèòñÿ ñîáåñåäîâàíèå"
    },
    interviewLeave = u8"/b [%s] - [Èíôîðìàöèÿ]: Çàâåðøèë ñîáåñåäîâàíèå"
}

-- State
local ORGANIZATIONS = {}
local TEMPLATES = { techMessage = "", interviewStart = {}, interviewLeave = "" }

local windowState = new.bool(false)
local settingsTab = new.int(1) -- 1: Ãëàâíîå, 2: Íàñòðîéêè
local selectedOrg = new.int(0)
local selectedTargetOrg = new.int(0)
local messageText = new.char[1024]()
local sendWithoutTarget = new.bool(false)
local messageWindowState = new.bool(false)
local configFile = "frequency_helper.ini"
local chatMessages = {}
local maxMessages = 200

-- Helpers
local function trim(s)
    if s == nil then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function toCP1251(text)
    return encoding.UTF8:decode(text)
end

local function stripColorCodes(str)
    return str:gsub("{[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]}", "")
end

local function addChatMessageToWindow(msg)
    table.insert(chatMessages, msg)
    if #chatMessages > maxMessages then table.remove(chatMessages, 1) end
end

local function saveConfig()
    local f, err = io.open(configFile, "wb") -- áèíàðíûé ðåæèì
    if not f then
        sampAddChatMessage(string.format("{FF0000}[Frequency Helper]{FFFFFF} Îøèáêà ïðè ñîõðàíåíèè: %s", tostring(err)), -1)
        return false
    end

    -- UTF-8 BOM
    f:write(string.char(0xEF,0xBB,0xBF))

    -- General
    f:write(string.format("selectedOrg=%d\n", selectedOrg[0]))
    f:write(string.format("selectedTargetOrg=%d\n", selectedTargetOrg[0]))
    f:write(string.format("sendWithoutTarget=%s\n", tostring(sendWithoutTarget[0])))
    f:write(string.format("messageText=%s\n", ffi.string(messageText)))

    -- Organizations
    f:write("\n[Organizations]\n")
    for i, org in ipairs(ORGANIZATIONS) do
        f:write(string.format("%d=%s\n", i, org))
    end

    -- Templates
    f:write("\n[Templates]\n")
    f:write(string.format("techMessage=%s\n", TEMPLATES.techMessage or ""))
    for i, t in ipairs(TEMPLATES.interviewStart) do
        f:write(string.format("interviewStart%d=%s\n", i, t))
    end
    f:write(string.format("interviewLeave=%s\n", TEMPLATES.interviewLeave or ""))

    f:close()
    return true
end

local function loadConfig()
    if not doesFileExist(configFile) then saveConfig() return end
    local file = io.open(configFile, "rb")
    if not file then return end

    local content = file:read("*a")
    file:close()
    -- óáèðàåì BOM
    content = content:gsub("^\239\187\191", "")

    -- Defaults
    ORGANIZATIONS = {}
    for i,v in ipairs(DEFAULT_ORGANIZATIONS) do ORGANIZATIONS[i] = v end
    TEMPLATES = { techMessage = DEFAULT_TEMPLATES.techMessage, interviewStart = {}, interviewLeave = DEFAULT_TEMPLATES.interviewLeave }
    for i,v in ipairs(DEFAULT_TEMPLATES.interviewStart) do table.insert(TEMPLATES.interviewStart, v) end

    selectedOrg[0] = 0
    selectedTargetOrg[0] = 0
    sendWithoutTarget[0] = false
    ffi.fill(messageText, 0)

    local section = ""
    for line in content:gmatch("[^\r\n]+") do
        line = trim(line)
        if line == "" then goto continue end
        if line:match("^%[.+%]") then section = line:sub(2,-2); goto continue end

        local key, value = line:match("^([^=]+)=(.*)$")
        if not key then goto continue end
        key = trim(key)
        value = trim(value)

        if section == "" then
            if key == "selectedOrg" then selectedOrg[0] = tonumber(value) or 0
            elseif key == "selectedTargetOrg" then selectedTargetOrg[0] = tonumber(value) or 0
            elseif key == "sendWithoutTarget" then sendWithoutTarget[0] = (value == "true")
            elseif key == "messageText" then ffi.copy(messageText, value)
            end
        elseif section == "Organizations" then
            local idx = tonumber(key)
            if idx then ORGANIZATIONS[idx] = value end
        elseif section == "Templates" then
            if key == "techMessage" then TEMPLATES.techMessage = toCP1251(value)
            elseif key:match("^interviewStart%d+$") then
                local idx = tonumber(key:match("(%d+)$"))
                TEMPLATES.interviewStart[idx] = encoding.CP1251:encode(value)
            elseif key == "interviewLeave" then TEMPLATES.interviewLeave = encoding.CP1251:encode(value)
            end
        end
        ::continue::
    end
end

-- UI style
local function applyStyle()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    style.WindowPadding = imgui.ImVec2(12,12)
    style.WindowRounding = 8.0
    style.FramePadding = imgui.ImVec2(8,4)
    style.FrameRounding = 4.0
    style.ItemSpacing = imgui.ImVec2(10,6)

    colors[clr.Text] = imgui.ImVec4(1,1,1,1)
    colors[clr.WindowBg] = imgui.ImVec4(0.06,0.06,0.10,0.98)
    colors[clr.FrameBg] = imgui.ImVec4(0.12,0.12,0.18,1.0)
    colors[clr.Button] = imgui.ImVec4(0.25,0.25,0.45,0.9)
end
imgui.OnInitialize(function() applyStyle() end)

-- Sending messages
local function formatTemplate(template, currentOrg, targetOrg, customMessage)
    if not template or trim(template) == "" then return "" end
    local out = template
    out = out:gsub("%%ORG%%", currentOrg)
    out = out:gsub("%%TARGET%%", targetOrg or "")
    out = out:gsub("%%MSG%%", customMessage or "")

    -- Ïîääåðæêà %s äëÿ îáðàòíîé ñîâìåñòèìîñòè
    if out:find("%%s") then
        local cnt = 0
        for _ in out:gmatch("%%s") do cnt = cnt + 1 end
        local args = {}
        if cnt >= 1 then table.insert(args, currentOrg) end
        if cnt >= 2 then table.insert(args, targetOrg or "") end
        if cnt >= 3 then table.insert(args, customMessage or "") end
        local success, formatted = pcall(string.format, out, table.unpack(args))
        if success then out = formatted end
    end

    return out
end

local function sendMessage()
    lua_thread.create(function()
        local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1] or ""
        local targetOrg  = ORGANIZATIONS[selectedTargetOrg[0] + 1] or ""
        local message    = ffi.string(messageText)

        if trim(message) == "" then return end

        local fullMessage
        if sendWithoutTarget[0] then
            fullMessage = string.format("/b [%s] - [Èíôîðìàöèÿ]: %s",
                                        currentOrg, message)
        else
            fullMessage = string.format("/b [%s] - [%s]: %s",
                                        currentOrg, targetOrg, message)
        end
        -- óõîäÿò â ÷àò óæå â CP1251
        sampSendChat(toCP1251(fullMessage))
        ffi.fill(messageText, 0)
        saveConfig()
    end)
end

local function startInterview()
    lua_thread.create(function()
        local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1] or ""
        for _, t in ipairs(TEMPLATES.interviewStart) do
            local line = formatTemplate(t, currentOrg, "", "")
            sampSendChat(toCP1251(line))
            wait(800)
        end
        sampSendChat("/lmenu")
    end)
end

local function leaveInterview()
    local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1] or ""
    local line = formatTemplate(TEMPLATES.interviewLeave, currentOrg, "", "")
    sampSendChat(toCP1251(line))
end

-- Server messages -> chat window
function samp.onServerMessage(color, text)
    local cleaned = stripColorCodes(text)
    addChatMessageToWindow(cleaned)
end

-- UI: Settings tab - Organizations editor
local newOrgNameBuf = new.char[128]()

local function drawSettings()
    imgui.BeginChild("orgs", imgui.ImVec2(0, 220), true)
    imgui.Text(u8:encode("Îðãàíèçàöèè:"))

    for i = 1, #ORGANIZATIONS do
        local org = ORGANIZATIONS[i]
        imgui.BeginGroup()
        imgui.SetNextItemWidth(260)

        local buf = ffi.new("char[128]")
        ffi.copy(buf, org)
        if imgui.InputText("##org"..i, buf, 128) then
            ORGANIZATIONS[i] = ffi.string(buf)
            saveConfig()
        end

        imgui.SameLine()
        if imgui.Button(u8:encode("UP##up"..i), imgui.ImVec2(30,0)) and i>1 then
            ORGANIZATIONS[i], ORGANIZATIONS[i-1] = ORGANIZATIONS[i-1], ORGANIZATIONS[i]
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8:encode("Down##down"..i), imgui.ImVec2(30,0)) and i<#ORGANIZATIONS then
            ORGANIZATIONS[i], ORGANIZATIONS[i+1] = ORGANIZATIONS[i+1], ORGANIZATIONS[i]
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8:encode("Óäàëèòü##del"..i), imgui.ImVec2(70,0)) then
            table.remove(ORGANIZATIONS, i)
            if selectedOrg[0] >= #ORGANIZATIONS then selectedOrg[0] = math.max(0,#ORGANIZATIONS-1) end
            saveConfig()
            break
        end
        imgui.EndGroup()
    end

    imgui.Separator()
    imgui.Text(u8:encode("Äîáàâèòü íîâóþ îðãàíèçàöèþ:"))
    imgui.SetNextItemWidth(-1)
    imgui.InputText("##neworg", newOrgNameBuf, 128)
    if imgui.Button(u8:encode("Äîáàâèòü"), imgui.ImVec2(-1,0)) then
        local name = trim(ffi.string(newOrgNameBuf))
        if name ~= "" then
            table.insert(ORGANIZATIONS, (name))
            ffi.fill(newOrgNameBuf,0)
            saveConfig()
        end
    end
    imgui.EndChild()

    ------------------------------------------------------------------
    -- Templates
    ------------------------------------------------------------------
    imgui.BeginChild("templates", imgui.ImVec2(0, 260), true)
    imgui.Text(u8:encode("Øàáëîíû ñîîáùåíèé (%%ORG%% %%TARGET%% %%MSG%%):"))
    imgui.Separator()
    imgui.Text(u8:encode("Òåõ. íåïîëàäêè:"))

    local techBuf = ffi.new("char[512]")
    ffi.copy(techBuf, TEMPLATES.techMessage)
    if imgui.InputTextMultiline("##tech", techBuf, 512, imgui.ImVec2(-1,70)) then
        TEMPLATES.techMessage = ffi.string(techBuf)
        saveConfig()
    end

    imgui.Separator()
    imgui.Text(u8:encode("Íà÷àëî ñîáåñåäîâàíèÿ:"))
    for i = 1, #TEMPLATES.interviewStart do
        local buf = ffi.new("char[512]")
        ffi.copy(buf, TEMPLATES.interviewStart[i])
        if imgui.InputText("##start"..i, buf, 512) then
            TEMPLATES.interviewStart[i] = ffi.string(buf)
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8:encode("UP##up"..i+1000), imgui.ImVec2(30,0)) and i>1 then
            TEMPLATES.interviewStart[i], TEMPLATES.interviewStart[i-1] =
                TEMPLATES.interviewStart[i-1], TEMPLATES.interviewStart[i]
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8:encode("DOWN##down"..i+1000), imgui.ImVec2(30,0)) and i<#TEMPLATES.interviewStart then
            TEMPLATES.interviewStart[i], TEMPLATES.interviewStart[i+1] =
                TEMPLATES.interviewStart[i+1], TEMPLATES.interviewStart[i]
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8:encode("Óäàëèòü##del"..i+1000), imgui.ImVec2(80,0)) then
            table.remove(TEMPLATES.interviewStart, i)
            saveConfig()
            break
        end
    end

    imgui.Separator()
    local newStartBuf = ffi.new("char[256]")
    imgui.InputText("##newstart", newStartBuf, 256)
    if imgui.Button(u8:encode("Äîáàâèòü øàáëîí íà÷àëà ñîáåñåäîâàíèÿ"), imgui.ImVec2(-1,0)) then
        local s = trim(ffi.string(newStartBuf))
        if s ~= "" then
            table.insert(TEMPLATES.interviewStart, (s))
            ffi.fill(newStartBuf,0)
            saveConfig()
        end
    end

    imgui.Separator()
    imgui.Text(u8:encode("Çàâåðøåíèå ñîáåñåäîâàíèÿ:"))
    local leaveBuf = ffi.new("char[512]")
    ffi.copy(leaveBuf, TEMPLATES.interviewLeave)
    if imgui.InputText("##leave", leaveBuf, 512) then
        TEMPLATES.interviewLeave = ffi.string(leaveBuf)
        saveConfig()
    end

    imgui.Separator()
    if imgui.Button(u8:encode("Âîññòàíîâèòü øàáëîíû ïî óìîë÷àíèþ"), imgui.ImVec2(-1,0)) then
        TEMPLATES.techMessage = DEFAULT_TEMPLATES.techMessage
        TEMPLATES.interviewStart = {}
        for _,v in ipairs(DEFAULT_TEMPLATES.interviewStart) do table.insert(TEMPLATES.interviewStart, v) end
        TEMPLATES.interviewLeave = DEFAULT_TEMPLATES.interviewLeave
        saveConfig()
    end
    imgui.EndChild()
end
-- UI: Main tab
local function drawMain()
    imgui.Text(u8"Âàøà îðãàíèçàöèÿ:")
    if imgui.BeginCombo(u8"##org", ORGANIZATIONS[selectedOrg[0] + 1] or u8"-") then
        for i, org in ipairs(ORGANIZATIONS) do
            if imgui.Selectable(org, selectedOrg[0] == i-1) then selectedOrg[0] = i-1; saveConfig() end
        end
        imgui.EndCombo()
    end

    imgui.Text(u8"Îðãàíèçàöèÿ äëÿ ñâÿçè:")
    if imgui.BeginCombo(u8"##target", ORGANIZATIONS[selectedTargetOrg[0] + 1] or u8"-") then
        for i, org in ipairs(ORGANIZATIONS) do
            if imgui.Selectable(org, selectedTargetOrg[0] == i-1) then selectedTargetOrg[0] = i-1; saveConfig() end
        end
        imgui.EndCombo()
    end

    imgui.Checkbox(u8"Îòïðàâèòü áåç óêàçàíèÿ îðãàíèçàöèè", sendWithoutTarget)

    imgui.Separator()
    imgui.Text(u8"Ñîîáùåíèå:")
    imgui.SetNextItemWidth(-1)
    if imgui.InputText(u8"##msg", messageText, 1024) then saveConfig() end

    if imgui.Button(u8"Îòïðàâèòü ñîîáùåíèå", imgui.ImVec2(180,30)) then sendMessage() end
    imgui.SameLine()
    if imgui.Button(u8"Îòêðûòü îêíî ñîîáùåíèé", imgui.ImVec2(180,30)) then messageWindowState[0] = true; windowState[0] = false end

    imgui.Separator()
    if imgui.Button(u8"Òåõ íåïîëàäêè (øàáëîí)", imgui.ImVec2(-1, 30)) then
        local cur = ORGANIZATIONS[selectedOrg[0] + 1] or ""
        local line = formatTemplate(TEMPLATES.techMessage, cur, "", "")
        sampSendChat(toCP1251(line))
    end

    if imgui.Button(u8"Íà÷àòü ñîáåñåäîâàíèå", imgui.ImVec2(-1, 30)) then startInterview() end
    if imgui.Button(u8"Çàâåðøèòü ñîáåñåäîâàíèå", imgui.ImVec2(-1, 30)) then leaveInterview() end

    imgui.Separator()
    imgui.BeginChild("ChatMessagesMain", imgui.ImVec2(-1,150), true)
    for i, msg in ipairs(chatMessages) do imgui.TextWrapped(ffi.string(u8:encode(msg))) end
    imgui.EndChild()
end

local function drawMessageWindow()
    imgui.SetNextWindowSize(imgui.ImVec2(520,380), imgui.Cond.FirstUseEver)
    imgui.Begin(u8"Îêíî ñîîáùåíèé", messageWindowState)
    imgui.BeginChild("msgs", imgui.ImVec2(-1, -60), true)
    for i, msg in ipairs(chatMessages) do imgui.TextWrapped(ffi.string(u8:encode(msg))) end
    imgui.EndChild()
    if imgui.Button(u8"Î÷èñòèòü ÷àò", imgui.ImVec2(140,30)) then chatMessages = {}; saveConfig() end
    imgui.SameLine()
    if imgui.Button(u8"Çàêðûòü", imgui.ImVec2(140,30)) then messageWindowState[0] = false; windowState[0] = true end
    imgui.End()
end

local function drawWindow()
    imgui.SetNextWindowSize(imgui.ImVec2(540, 720), imgui.Cond.FirstUseEver)
    imgui.Begin(u8"Frequency Helper  ðåäàêòîð òåãîâ è øàáëîíîâ", windowState)

    if imgui.BeginTabBar(u8"MainTabs") then
        if imgui.BeginTabItem(u8"Ãëàâíàÿ") then
            settingsTab[0] = 1
            drawMain()
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(u8"Íàñòðîéêè") then
            settingsTab[0] = 2
            drawSettings()
            imgui.EndTabItem()
        end
        imgui.EndTabBar()
    end

    imgui.End()
end

function main()
    if not isSampfuncsLoaded() or not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end

    loadConfig()

    sampRegisterChatCommand("freq", function() windowState[0] = not windowState[0]; messageWindowState[0] = false end)
    sampAddChatMessage("{3F40B7}[Frequency Helper]{FFFFFF} Èñïîëüçóéòå /freq äëÿ îòêðûòèÿ ìåíþ | Òåãè è øàáëîíû ñîõðàíÿþòñÿ â frequency_helper.ini", -1)

    while true do wait(0) end
end

imgui.OnFrame(function() return windowState[0] and not messageWindowState[0] end, drawWindow)
imgui.OnFrame(function() return messageWindowState[0] end, drawMessageWindow)
