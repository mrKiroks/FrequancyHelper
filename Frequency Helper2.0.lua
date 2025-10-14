require "lib.moonloader"
local samp = require 'lib.samp.events'
local encoding = require 'encoding'
local imgui = require 'mimgui'
local new = imgui.new
local ffi = require 'ffi'
encoding.default = 'CP1251'
u8 = encoding.UTF8
script_name("Frequency Helper")
script_version("2.0")

-- ======================================
-- Настраиваемый скрипт: организации и шаблоны
-- Всё хранится в frequency_helper.ini
-- ======================================

-- Default data (used if INI absent or to reset)
local DEFAULT_ORGANIZATIONS = {
    u8"Правительство",
    u8"Прокуратура",
    u8"Суд",
    u8"Центр лицензирования",
    u8"Пожарный департамент",
    u8"ФБР",
    u8"Полиция ЛС",
    u8"Полиция СФ",
    u8"Полиция ЛВ",
    u8"Областная полиция",
    u8"Армия ЛС",
    u8"ВМС",
    u8"Delta Force",
    u8"MPC",
    u8"Тюрьма ЛВ",
    u8"Больница ЛС",
    u8"Больница СФ",
    u8"Больница ЛВ",
    u8"Больница JF",
    u8"СМИ ЛС",
    u8"СМИ СФ",
    u8"СМИ ЛВ",
    u8"Страховая",
    u8"Похитители",
    u8"Информация",
    u8"S.W.A.T"
}

local DEFAULT_TEMPLATES = {
    techMessage = u8"/d [%s] - [Информация]: Технические неполадки",
    interviewStart = {
        u8"/b [%s] - [Информация]: Начинаю собеседование",
        u8"/b [%s] - [Информация]: Прошу не беспокоить, проводится собеседование"
    },
    interviewLeave = u8"/b [%s] - [Информация]: Завершил собеседование"
}

-- State
local ORGANIZATIONS = {}
local TEMPLATES = { techMessage = "", interviewStart = {}, interviewLeave = "" }

local windowState = new.bool(false)
local settingsTab = new.int(1) -- 1: Главное, 2: Настройки
local selectedOrg = new.int(0)
local selectedTargetOrg = new.int(0)
local messageText = new.char[1024]()
local sendWithoutTarget = new.bool(false)
local messageWindowState = new.bool(false)
local configFile = getWorkingDirectory() .. "\frequency_helper.ini"
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

-- Simple INI read/write (preserve order: general, [Organizations], [Templates])
local function saveConfig()
    local f, err = io.open(configFile, "w")
    if not f then
        sampAddChatMessage(string.format("{FF0000}[Frequency Helper]{FFFFFF} Ошибка при сохранении: %s", tostring(err)), -1)
        return false
    end

    -- General
    f:write(string.format("selectedOrg=%d\n", selectedOrg[0]))
    f:write(string.format("selectedTargetOrg=%d\n", selectedTargetOrg[0]))
    f:write(string.format("sendWithoutTarget=%s\n", tostring(sendWithoutTarget[0])))
    f:write(string.format("messageText=%s\n", ffi.string(messageText)))

    -- Organizations
    f:write("\n[Organizations]\n")
    for i, org in ipairs(ORGANIZATIONS) do
        f:write(string.format("%d=%s\n", i, ffi.string(u8:encode(org))))
    end

    -- Templates
    f:write("\n[Templates]\n")
    f:write(string.format("techMessage=%s\n", ffi.string(u8:encode(TEMPLATES.techMessage or ""))))
    for i, t in ipairs(TEMPLATES.interviewStart) do
        f:write(string.format("interviewStart%d=%s\n", i, ffi.string(u8:encode(t))))
    end
    f:write(string.format("interviewLeave=%s\n", ffi.string(u8:encode(TEMPLATES.interviewLeave or ""))))

    f:close()
    return true
end

local function loadConfig()
    -- Defaults
    ORGANIZATIONS = {}
    for i, v in ipairs(DEFAULT_ORGANIZATIONS) do ORGANIZATIONS[i] = v end
    TEMPLATES = { techMessage = DEFAULT_TEMPLATES.techMessage, interviewStart = {}, interviewLeave = DEFAULT_TEMPLATES.interviewLeave }
    for i, v in ipairs(DEFAULT_TEMPLATES.interviewStart) do table.insert(TEMPLATES.interviewStart, v) end

    -- Reset UI fields
    selectedOrg[0] = 0
    selectedTargetOrg[0] = 0
    sendWithoutTarget[0] = false
    ffi.fill(messageText, 0)

    if not doesFileExist(configFile) then
        saveConfig()
        return
    end

    local section = "" -- current section
    local file = io.open(configFile, "r")
    if not file then return end
    for line in file:lines() do
        line = trim(line)
        if line == "" then goto continue end
        if line:match("^%[.+%]") then
            section = line:sub(2, -2)
            goto continue
        end

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
            if idx then
                ORGANIZATIONS[idx] = u8:decode(value)
            end
        elseif section == "Templates" then
            if key == "techMessage" then TEMPLATES.techMessage = u8:decode(value)
            elseif key:match("^interviewStart%d+$") then
                local idx = tonumber(key:match("(%d+)$"))
                TEMPLATES.interviewStart[idx] = u8:decode(value)
            elseif key == "interviewLeave" then TEMPLATES.interviewLeave = u8:decode(value)
            end
        end
        ::continue::
    end
    file:close()

    -- clean nil holes
    -- organizations: compact
    local tmp = {}
    for i=1, #ORGANIZATIONS do
        if ORGANIZATIONS[i] and trim(ORGANIZATIONS[i]) ~= "" then table.insert(tmp, ORGANIZATIONS[i]) end
    end
    ORGANIZATIONS = tmp

    -- interviewStart: compact and keep order
    local tmp2 = {}
    for i=1, #TEMPLATES.interviewStart do
        if TEMPLATES.interviewStart[i] and trim(TEMPLATES.interviewStart[i]) ~= "" then table.insert(tmp2, TEMPLATES.interviewStart[i]) end
    end
    if #tmp2 > 0 then TEMPLATES.interviewStart = tmp2 end
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
    -- We'll try to support formats with up to 3 placeholders: %s for org, %t for target, %%m for message
    -- But simplest is to replace %ORG% %TARGET% %MSG% markers (user can use these)
    if not template or trim(template) == "" then return "" end
    local out = template
    out = out:gsub("%%ORG%%", ffi.string(u8:encode(currentOrg)))
    out = out:gsub("%%TARGET%%", ffi.string(u8:encode(targetOrg or "")))
    out = out:gsub("%%MSG%%", ffi.string(u8:encode(customMessage or "")))
    -- Also support lone %s usage for backward compatibility
    -- If template contains %s and no %ORG% placeholders, we'll do classic string.format with org and maybe target/message
    if out:find("%%s") then
        -- count %s
        local cnt = 0
        for _ in out:gmatch("%%s") do cnt = cnt + 1 end
        local args = {}
        if cnt >= 1 then table.insert(args, ffi.string(u8:encode(currentOrg))) end
        if cnt >= 2 then table.insert(args, ffi.string(u8:encode(targetOrg or ""))) end
        if cnt >= 3 then table.insert(args, ffi.string(u8:encode(customMessage or ""))) end
        local success, formatted = pcall(string.format, out, table.unpack(args))
        if success then out = formatted end
    end
    return out
end

local function sendMessage()
    lua_thread.create(function()
        local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1] or ""
        local targetOrg = ORGANIZATIONS[selectedTargetOrg[0] + 1] or ""
        local message = ffi.string(messageText)
        if trim(message) == "" then return end
        local fullMessage
        -- If user wants plain send (not using templates)
        if sendWithoutTarget[0] then
            fullMessage = string.format("/b [%s] - [Информация]: %s", toCP1251(currentOrg), toCP1251(message))
        else
            fullMessage = string.format("/b [%s] - [%s]: %s", toCP1251(currentOrg), toCP1251(targetOrg), toCP1251(message))
        end
        sampSendChat(fullMessage)
        ffi.fill(messageText, 0)
        saveConfig()
    end)
end

local function startInterview()
    lua_thread.create(function()
        local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1] or ""
        for _, t in ipairs(TEMPLATES.interviewStart) do
            local line = formatTemplate(t, currentOrg, "", "")
            sampSendChat(line)
            wait(800)
        end
        sampSendChat("/lmenu")
    end)
end

local function leaveInterview()
    local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1] or ""
    local line = formatTemplate(TEMPLATES.interviewLeave, currentOrg, "", "")
    sampSendChat(line)
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
    imgui.Text(u8"Организации:")
    -- list with reorder and edit
    for i = 1, #ORGANIZATIONS do
        local org = ORGANIZATIONS[i]
        imgui.PushID(i)
        imgui.BeginGroup()
        imgui.SetNextItemWidth(260)
        local buf = ffi.new("char[128]")
        ffi.copy(buf, ffi.string(u8:encode(org)))
        if imgui.InputText("##orgname", buf, 128) then
            ORGANIZATIONS[i] = u8:decode(ffi.string(buf))
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8"?", imgui.ImVec2(30, 0)) then
            if i > 1 then
                ORGANIZATIONS[i], ORGANIZATIONS[i-1] = ORGANIZATIONS[i-1], ORGANIZATIONS[i]
                saveConfig()
            end
        end
        imgui.SameLine()
        if imgui.Button(u8"?", imgui.ImVec2(30, 0)) then
            if i < #ORGANIZATIONS then
                ORGANIZATIONS[i], ORGANIZATIONS[i+1] = ORGANIZATIONS[i+1], ORGANIZATIONS[i]
                saveConfig()
            end
        end
        imgui.SameLine()
        if imgui.Button(u8"Удалить", imgui.ImVec2(70, 0)) then
            table.remove(ORGANIZATIONS, i)
            if selectedOrg[0] >= #ORGANIZATIONS then selectedOrg[0] = math.max(0, #ORGANIZATIONS-1) end
            saveConfig()
        end
        imgui.EndGroup()
        imgui.PopID()
    end

    imgui.Separator()
    imgui.Text(u8"Добавить новую организацию:")
    imgui.SetNextItemWidth(-1)
    if imgui.InputText(u8"##neworg", newOrgNameBuf, 128) then end
    if imgui.Button(u8"Добавить", imgui.ImVec2(-1, 0)) then
        local name = trim(ffi.string(newOrgNameBuf))
        if name ~= "" then
            table.insert(ORGANIZATIONS, u8(name))
            ffi.fill(newOrgNameBuf, 0)
            saveConfig()
        end
    end
    imgui.EndChild()

    -- Templates editor
    imgui.BeginChild("templates", imgui.ImVec2(0, 260), true)
    imgui.Text(u8"Шаблоны сообщений (используйте %%ORG%% %%TARGET%% %%MSG%% или %s для совместимости):")
    imgui.Separator()
    imgui.Text(u8"Тех. неполадки:")
    local techBuf = ffi.new("char[512]")
    ffi.copy(techBuf, ffi.string(u8:encode(TEMPLATES.techMessage)))
    if imgui.InputTextMultiline(u8"##tech", techBuf, 512, imgui.ImVec2(-1, 70)) then
        TEMPLATES.techMessage = u8:decode(ffi.string(techBuf))
        saveConfig()
    end

    imgui.Separator()
    imgui.Text(u8"Начало собеседования (несколько шаблонов):")
    for i=1, #TEMPLATES.interviewStart do
        imgui.PushID(i+1000)
        local buf = ffi.new("char[512]")
        ffi.copy(buf, ffi.string(u8:encode(TEMPLATES.interviewStart[i])))
        if imgui.InputText(u8("##start"..i), buf, 512) then
            TEMPLATES.interviewStart[i] = u8:decode(ffi.string(buf))
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8"?", imgui.ImVec2(30,0)) then
            if i>1 then TEMPLATES.interviewStart[i], TEMPLATES.interviewStart[i-1] = TEMPLATES.interviewStart[i-1], TEMPLATES.interviewStart[i]; saveConfig() end
        end
        imgui.SameLine()
        if imgui.Button(u8"?", imgui.ImVec2(30,0)) then
            if i<#TEMPLATES.interviewStart then TEMPLATES.interviewStart[i], TEMPLATES.interviewStart[i+1] = TEMPLATES.interviewStart[i+1], TEMPLATES.interviewStart[i]; saveConfig() end
        end
        imgui.SameLine()
        if imgui.Button(u8"Удалить", imgui.ImVec2(80,0)) then
            table.remove(TEMPLATES.interviewStart, i); saveConfig(); break
        end
        imgui.PopID()
    end
    imgui.Separator()
    local newStartBuf = ffi.new("char[256]")
    if imgui.InputText(u8"##newstart", newStartBuf, 256) then end
    if imgui.Button(u8"Добавить шаблон начала собеседования", imgui.ImVec2(-1,0)) then
        local s = trim(ffi.string(newStartBuf))
        if s ~= "" then table.insert(TEMPLATES.interviewStart, u8(s)); ffi.fill(newStartBuf,0); saveConfig() end
    end

    imgui.Separator()
    imgui.Text(u8"Завершение собеседования:")
    local leaveBuf = ffi.new("char[512]")
    ffi.copy(leaveBuf, ffi.string(u8:encode(TEMPLATES.interviewLeave)))
    if imgui.InputText(u8"##leave", leaveBuf, 512) then
        TEMPLATES.interviewLeave = u8:decode(ffi.string(leaveBuf))
        saveConfig()
    end

    imgui.Separator()
    if imgui.Button(u8"Восстановить шаблоны по умолчанию", imgui.ImVec2(-1,0)) then
        TEMPLATES.techMessage = DEFAULT_TEMPLATES.techMessage
        TEMPLATES.interviewStart = {}
        for i,v in ipairs(DEFAULT_TEMPLATES.interviewStart) do table.insert(TEMPLATES.interviewStart, v) end
        TEMPLATES.interviewLeave = DEFAULT_TEMPLATES.interviewLeave
        saveConfig()
    end

    imgui.EndChild()
end

-- UI: Main tab
local function drawMain()
    imgui.Text(u8"Ваша организация:")
    if imgui.BeginCombo(u8"##org", ORGANIZATIONS[selectedOrg[0] + 1] or u8"-") then
        for i, org in ipairs(ORGANIZATIONS) do
            if imgui.Selectable(org, selectedOrg[0] == i-1) then selectedOrg[0] = i-1; saveConfig() end
        end
        imgui.EndCombo()
    end

    imgui.Text(u8"Организация для связи:")
    if imgui.BeginCombo(u8"##target", ORGANIZATIONS[selectedTargetOrg[0] + 1] or u8"-") then
        for i, org in ipairs(ORGANIZATIONS) do
            if imgui.Selectable(org, selectedTargetOrg[0] == i-1) then selectedTargetOrg[0] = i-1; saveConfig() end
        end
        imgui.EndCombo()
    end

    imgui.Checkbox(u8"Отправить без указания организации", sendWithoutTarget)

    imgui.Separator()
    imgui.Text(u8"Сообщение:")
    imgui.SetNextItemWidth(-1)
    if imgui.InputText(u8"##msg", messageText, 1024) then saveConfig() end

    if imgui.Button(u8"Отправить сообщение", imgui.ImVec2(180,30)) then sendMessage() end
    imgui.SameLine()
    if imgui.Button(u8"Открыть окно сообщений", imgui.ImVec2(180,30)) then messageWindowState[0] = true; windowState[0] = false end

    imgui.Separator()
    if imgui.Button(u8"Тех неполадки (шаблон)", imgui.ImVec2(-1, 30)) then
        local cur = ORGANIZATIONS[selectedOrg[0] + 1] or ""
        local line = formatTemplate(TEMPLATES.techMessage, cur, "", "")
        sampSendChat(line)
    end

    if imgui.Button(u8"Начать собеседование", imgui.ImVec2(-1, 30)) then startInterview() end
    if imgui.Button(u8"Завершить собеседование", imgui.ImVec2(-1, 30)) then leaveInterview() end

    imgui.Separator()
    imgui.BeginChild("ChatMessagesMain", imgui.ImVec2(-1,150), true)
    for i, msg in ipairs(chatMessages) do imgui.TextWrapped(ffi.string(u8:encode(msg))) end
    imgui.EndChild()
end

local function drawMessageWindow()
    imgui.SetNextWindowSize(imgui.ImVec2(520,380), imgui.Cond.FirstUseEver)
    imgui.Begin(u8"Окно сообщений", messageWindowState)
    imgui.BeginChild("msgs", imgui.ImVec2(-1, -60), true)
    for i, msg in ipairs(chatMessages) do imgui.TextWrapped(ffi.string(u8:encode(msg))) end
    imgui.EndChild()
    if imgui.Button(u8"Очистить чат", imgui.ImVec2(140,30)) then chatMessages = {}; saveConfig() end
    imgui.SameLine()
    if imgui.Button(u8"Закрыть", imgui.ImVec2(140,30)) then messageWindowState[0] = false; windowState[0] = true end
    imgui.End()
end

local function drawWindow()
    imgui.SetNextWindowSize(imgui.ImVec2(540, 720), imgui.Cond.FirstUseEver)
    imgui.Begin(u8"Frequency Helper — редактор тегов и шаблонов", windowState)

    if imgui.BeginTabBar(u8"MainTabs") then
        if imgui.BeginTabItem(u8"Главная") then
            settingsTab[0] = 1
            drawMain()
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(u8"Настройки") then
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
    sampAddChatMessage("{3F40B7}[Frequency Helper]{FFFFFF} Используйте /freq для открытия меню | Теги и шаблоны сохраняются в frequency_helper.ini", -1)

    while true do wait(0) end
end

imgui.OnFrame(function() return windowState[0] and not messageWindowState[0] end, drawWindow)
imgui.OnFrame(function() return messageWindowState[0] end, drawMessageWindow)
