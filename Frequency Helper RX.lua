require "lib.moonloader"
local samp = require 'lib.samp.events'
local encoding = require 'encoding'
local imgui = require 'mimgui'
local faicons = require('fAwesome6')
local new = imgui.new
local ffi = require 'ffi'
encoding.default = 'CP1251'
u8 = encoding.UTF8
script_name("Frequency Helper")
script_version("2.0")

local DEFAULT_TEMPLATES = {
    techMessage = u8"/d [%s] - [Информация]: Технические неполадки",
    interviewStart = {
        u8"/d [%s] - [Информация]: Провожу собеседование",
        u8"/d [%s] - [Информация]: Прошу не беспокоить"
    },
    interviewLeave = u8"/d [%s] - [Информация]: Завершил собеседование",
    userMessage = u8"/d [%ORG%] - [%TARGET%]: %MSG%"
}

local ORGANIZATIONS = {}
local TEMPLATES = { techMessage = "", interviewStart = {}, interviewLeave = "" }

local windowState = new.bool(false)
local settingsTab = new.int(1) -- 1: Главное, 2: Настройки
local selectedOrg = new.int(0)
local selectedTargetOrg = new.int(0)
local messageText = new.char[1024]()
local sendWithoutTarget = new.bool(false)
local messageWindowState = new.bool(false)
local configFile = getWorkingDirectory() .. "\\config\\frequency_helper.ini"
local chatMessages = {}
local maxMessages = 200
local newStartBuf = new.char(256)
local showAllD = new.bool(true) -- показывать все [D]
local filterByOrg = new.bool(false) -- фильтровать по %ORG%

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 14, config, iconRanges) -- solid - тип иконок, так же есть thin, regular, light и duotone
end)
local fxmark = (faicons("FILE"))

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
    local f, err = io.open(configFile, "wb") -- бинарный режим
    if not f then
        sampAddChatMessage(string.format("{FF0000}[Frequency Helper]{FFFFFF} Ошибка при сохранении: %s", tostring(err)), -1)
        return false
    end

    f:write(string.char(0xEF,0xBB,0xBF))

    f:write(string.format("selectedOrg=%d\n", selectedOrg[0]))
    f:write(string.format("selectedTargetOrg=%d\n", selectedTargetOrg[0]))
    f:write(string.format("sendWithoutTarget=%s\n", tostring(sendWithoutTarget[0])))
    f:write(string.format("messageText=%s\n", ffi.string(messageText)))

    f:write("\n[Organizations]\n")
    for i, org in ipairs(ORGANIZATIONS) do
        f:write(string.format("%d=%s\n", i, org))
    end

    f:write("\n[Templates]\n")
    f:write(string.format("techMessage=%s\n", TEMPLATES.techMessage or ""))
    for i, t in ipairs(TEMPLATES.interviewStart) do
        f:write(string.format("interviewStart%d=%s\n", i, t))
    end
    f:write(string.format("userMessage=%s\n", TEMPLATES.userMessage or ""))
    f:write(string.format("interviewLeave=%s\n", TEMPLATES.interviewLeave or ""))

    f:close()
    return true
end

local function loadConfig()
    if not doesFileExist(configFile) then
        saveConfig()
        return
    end

    local file = io.open(configFile, "rb")
    if not file then return end
    local content = file:read("*a")
    file:close()
    content = content:gsub("^\239\187\191", "")

    for line in content:gmatch("[^\r\n]+") do
        line = trim(line)
        if line == "" then goto continue end
        if line:match("^%[.+%]") then goto continue end

        local key, value = line:match("^([^=]+)=(.*)$")
        if not key then goto continue end
        key, value = trim(key), trim(value)

        -- общие настройки
        if key == "selectedOrg"        then selectedOrg[0]       = tonumber(value) or 0
        elseif key == "selectedTargetOrg" then selectedTargetOrg[0] = tonumber(value) or 0
        elseif key == "sendWithoutTarget" then sendWithoutTarget[0] = (value == "true")
        elseif key == "messageText"     then ffi.copy(messageText, value)
        end
        ::continue::
    end

    for line in content:gmatch("[^\r\n]+") do
        line = trim(line)
        local sect = line:match("^%[(.+)%]$")
        if sect then section = sect; goto continue2 end
        local key, value = line:match("^([^=]+)=(.*)$")
        if not key then goto continue2 end
        key, value = trim(key), trim(value)

        if section == "Organizations" then
            local idx = tonumber(key)
            if idx then ORGANIZATIONS[idx] = value end
        elseif section == "Templates" then
            if key == "techMessage" then
                TEMPLATES.techMessage = value
            elseif key == "interviewLeave" then
                TEMPLATES.interviewLeave = value
            elseif key:match("^interviewStart%d+$") then
                local idx = tonumber(key:match("%d+$"))
                TEMPLATES.interviewStart[idx] = value
            elseif key == "userMessage" then
                TEMPLATES.userMessage = value
            end
        end
        ::continue2::
    end
end

local function applyStyle()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col

    style.WindowPadding = imgui.ImVec2(15, 15)
    style.WindowRounding = 10.0
    style.FramePadding = imgui.ImVec2(10, 5)
    style.FrameRounding = 5.0
    style.ItemSpacing = imgui.ImVec2(12, 8)
    style.ItemInnerSpacing = imgui.ImVec2(8, 6)
    style.ScrollbarSize = 15.0
    style.ScrollbarRounding = 9.0
    style.GrabRounding = 5.0

    colors[clr.Text] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[clr.WindowBg] = imgui.ImVec4(0.06, 0.06, 0.10, 0.98)
    colors[clr.Border] = imgui.ImVec4(0.20, 0.20, 0.40, 0.50)
    colors[clr.FrameBg] = imgui.ImVec4(0.15, 0.15, 0.25, 1.00)
    colors[clr.FrameBgHovered] = imgui.ImVec4(0.20, 0.20, 0.40, 0.40)
    colors[clr.FrameBgActive] = imgui.ImVec4(0.25, 0.25, 0.45, 0.67)
    colors[clr.TitleBg] = imgui.ImVec4(0.10, 0.10, 0.15, 1.00)
    colors[clr.TitleBgActive] = imgui.ImVec4(0.15, 0.15, 0.30, 1.00)
    colors[clr.ScrollbarGrab] = imgui.ImVec4(0.30, 0.30, 0.60, 0.31)
    colors[clr.ScrollbarGrabHovered] = imgui.ImVec4(0.35, 0.35, 0.65, 0.67)
    colors[clr.ScrollbarGrabActive] = imgui.ImVec4(0.40, 0.40, 0.80, 1.00)
    colors[clr.CheckMark] = imgui.ImVec4(0.40, 0.40, 0.80, 1.00)
    colors[clr.Button] = imgui.ImVec4(0.25, 0.25, 0.45, 0.40)
    colors[clr.ButtonHovered] = imgui.ImVec4(0.35, 0.35, 0.65, 0.67)
    colors[clr.ButtonActive] = imgui.ImVec4(0.40, 0.40, 0.80, 1.00)
    colors[clr.Header] = imgui.ImVec4(0.25, 0.25, 0.45, 0.40)
    colors[clr.HeaderHovered] = imgui.ImVec4(0.35, 0.35, 0.65, 0.67)
    colors[clr.HeaderActive] = imgui.ImVec4(0.40, 0.40, 0.80, 1.00)
end
imgui.OnInitialize(function() applyStyle() end)

local function formatTemplate(template, currentOrg, targetOrg, customMessage)
    if not template or trim(template) == "" then return "" end
    local out = template

    -- стандартные подстановки
    out = out:gsub("%%ORG%%",   currentOrg or "")
    out = out:gsub("%%TARGET%%", targetOrg or "")
    out = out:gsub("%%MSG%%",   customMessage or "")

    -- поддержка старого %s
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

    out = out:gsub("%[%]", "")
    out = out:gsub("%s*%%MSG%%", " %%MSG%%")
    out = out:gsub("%%MSG%%", customMessage or "")

    return out
end

local function sendMessage()
    lua_thread.create(function()
        local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1] or ""
        local targetOrg  = sendWithoutTarget[0] and "" or ORGANIZATIONS[selectedTargetOrg[0] + 1] or ""
        local message    = ffi.string(messageText)

        if trim(message) == "" then return end

        local fullMessage = formatTemplate(TEMPLATES.userMessage, currentOrg, targetOrg, message)

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

function samp.onServerMessage(color, text)
    local cleaned = stripColorCodes(text)
    addChatMessageToWindow(cleaned)
end

local newOrgNameBuf = new.char[128]()

local function drawSettings()
    imgui.BeginChild("orgs", imgui.ImVec2(0, 220), true)
    imgui.Text(u8:encode("Организации:"))

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
        if imgui.Button(u8:encode("Вверх##up" .. i), imgui.ImVec2(50, 0)) and i>1 then
            ORGANIZATIONS[i], ORGANIZATIONS[i-1] = ORGANIZATIONS[i-1], ORGANIZATIONS[i]
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8:encode("Вниз##down"..i), imgui.ImVec2(50,0)) and i<#ORGANIZATIONS then
            ORGANIZATIONS[i], ORGANIZATIONS[i+1] = ORGANIZATIONS[i+1], ORGANIZATIONS[i]
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8:encode("Удалить##del"..i), imgui.ImVec2(70,0)) then
            table.remove(ORGANIZATIONS, i)
            if selectedOrg[0] >= #ORGANIZATIONS then selectedOrg[0] = math.max(0,#ORGANIZATIONS-1) end
            saveConfig()
            break
        end
        imgui.EndGroup()
    end

    imgui.Separator()
    imgui.Text(u8:encode("Добавить новую организацию:"))
    imgui.SetNextItemWidth(-1)
    imgui.InputText("##neworg", newOrgNameBuf, 128)
    if imgui.Button(u8:encode("Добавить"), imgui.ImVec2(-1,0)) then
        local name = trim(ffi.string(newOrgNameBuf))
        if name ~= "" then
            table.insert(ORGANIZATIONS, (name))
            ffi.fill(newOrgNameBuf,0)
            saveConfig()
        end
    end
    imgui.EndChild()

    -- Templates
    imgui.BeginChild("templates", imgui.ImVec2(0, imgui.GetContentRegionAvail().y - 0), true)
    imgui.Text(u8:encode("Шаблоны сообщений (%%ORG%% %%TARGET%% %%MSG%%)"))
    imgui.SameLine()
    imgui.TextDisabled(u8"Подсказка")          -- маленький значок
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"ORG - Ваша организация\nTARGET - Организация для связи\nMSG - Введенное сообщение")
    end
    imgui.Separator()

    imgui.Text(u8"Шаблон обычного сообщения:")
    local userBuf = ffi.new("char[512]")
    local tpl = TEMPLATES.userMessage or DEFAULT_TEMPLATES.userMessage or ""
    ffi.copy(userBuf, tpl)
    if imgui.InputTextMultiline("##userTpl", userBuf, 512, imgui.ImVec2(-1,60)) then
        TEMPLATES.userMessage = ffi.string(userBuf)
        saveConfig()
    end
    imgui.Text(u8:encode("Тех. неполадки:"))

    local techBuf = ffi.new("char[512]")
    ffi.copy(techBuf, TEMPLATES.techMessage)
    if imgui.InputTextMultiline("##tech", techBuf, 512, imgui.ImVec2(-1,70)) then
        TEMPLATES.techMessage = ffi.string(techBuf)
        saveConfig()
    end

    imgui.Separator()
    imgui.Text(u8:encode("Начало собеседования:"))
    for i = 1, #TEMPLATES.interviewStart do
        imgui.BeginGroup()
        imgui.SetNextItemWidth(260) 
        local buf = ffi.new("char[512]")
        ffi.copy(buf, TEMPLATES.interviewStart[i])
        if imgui.InputText("##start"..i, buf, 512) then
            TEMPLATES.interviewStart[i] = ffi.string(buf)
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8:encode("Вверх##up"..i+1000), imgui.ImVec2(50,0)) and i>1 then
            TEMPLATES.interviewStart[i], TEMPLATES.interviewStart[i-1] =
                TEMPLATES.interviewStart[i-1], TEMPLATES.interviewStart[i]
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8:encode("Вниз##down"..i+1000), imgui.ImVec2(50,0)) and i<#TEMPLATES.interviewStart then
            TEMPLATES.interviewStart[i], TEMPLATES.interviewStart[i+1] =
                TEMPLATES.interviewStart[i+1], TEMPLATES.interviewStart[i]
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8:encode("Удалить##del"..i+1000), imgui.ImVec2(80,0)) then
            table.remove(TEMPLATES.interviewStart, i)
            saveConfig()
            break
        end
    end

    imgui.Separator()
    imgui.InputText("##newstart", newStartBuf, 256)
    if imgui.Button(u8:encode("Добавить строчку"), imgui.ImVec2(-1,0)) then
        local s = trim(ffi.string(newStartBuf))
        if s ~= "" then
            table.insert(TEMPLATES.interviewStart, s)
            ffi.fill(newStartBuf, 0)
            saveConfig()
        end
    end

    imgui.Separator()
    imgui.Text(u8:encode("Завершение собеседования:"))
    local leaveBuf = ffi.new("char[512]")
    ffi.copy(leaveBuf, TEMPLATES.interviewLeave)
    if imgui.InputText("##leave", leaveBuf, 512) then
        TEMPLATES.interviewLeave = ffi.string(leaveBuf)
        saveConfig()
    end

    imgui.Separator()
    if imgui.Button(u8:encode("Восстановить шаблоны по умолчанию"), imgui.ImVec2(-1,0)) then
        TEMPLATES.techMessage = DEFAULT_TEMPLATES.techMessage
        TEMPLATES.interviewStart = {}
        for _,v in ipairs(DEFAULT_TEMPLATES.interviewStart) do table.insert(TEMPLATES.interviewStart, v) end
        TEMPLATES.interviewLeave = DEFAULT_TEMPLATES.interviewLeave
        saveConfig()
    end
    imgui.EndChild()
end

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
    imgui.SameLine()
    imgui.TextDisabled(u8"(?)")          -- маленький значок
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Убирает [TARGET] вместе с квадратными скобками")
    end

    imgui.Separator()
    imgui.Text(u8"Сообщение:")
    imgui.SetNextItemWidth(-1)
    if imgui.InputTextMultiline("##msg", messageText, 1024, imgui.ImVec2(-1, 70)) then
        saveConfig()
    end

    if imgui.Button(u8"Отправить сообщение " .. faicons("envelope"), imgui.ImVec2(-1,30)) then sendMessage() end

    imgui.Separator()
    if imgui.Button(u8"Тех неполадки " .. faicons("wifi_exclamation"), imgui.ImVec2(-1, 30)) then
        local cur = ORGANIZATIONS[selectedOrg[0] + 1] or ""
        local line = formatTemplate(TEMPLATES.techMessage, cur, "", "")
        sampSendChat(toCP1251(line))
    end

    if imgui.Button(u8"Сообщение о собеседовании | Начало", imgui.ImVec2(-1, 30)) then startInterview() end
    if imgui.Button(u8"Сообщение о собеседовании | Конец", imgui.ImVec2(-1, 30)) then leaveInterview() end

    imgui.Separator()
    imgui.Text(u8"Фильтр департамента [D]:")
    if imgui.RadioButtonBool(u8"Все [D]", showAllD[0]) then
        showAllD[0] = true
        filterByOrg[0] = false
    end
    imgui.SameLine()
    if imgui.RadioButtonBool(u8"Только с моей организацией", filterByOrg[0]) then
        filterByOrg[0] = true
        showAllD[0] = false
    end
    imgui.BeginChild("ChatMessagesMain", imgui.ImVec2(-1, imgui.GetContentRegionAvail().y - 30), true)
    local currentOrg = toCP1251(ORGANIZATIONS[selectedOrg[0] + 1] or "")
    for _, msg in ipairs(chatMessages) do
        local show = false
        if showAllD[0] then
            show = msg:sub(1, 3) == "[D]"
        elseif filterByOrg[0] then
            show = msg:sub(1, 3) == "[D]" and msg:find(currentOrg, 1, true)
        end
        
        if show then
            imgui.TextWrapped(ffi.string(u8:encode(msg)))
        end
    end
    imgui.EndChild()
end

local function drawMessageWindow()
    imgui.SetNextWindowSize(imgui.ImVec2(540, 820), imgui.Cond.FirstUseEver)
    imgui.Begin(u8"Окно сообщений", messageWindowState)

    -- Радио-кнопки
    if imgui.RadioButton(u8"Показать все [D]", showAllD[0]) then
        showAllD[0] = true
        filterByOrg[0] = false
    end
    imgui.SameLine()
    if imgui.RadioButton(u8"Фильтр по своей организации", filterByOrg[0]) then
        filterByOrg[0] = true
        showAllD[0] = false
    end

    imgui.BeginChild("msgs", imgui.ImVec2(-1, -60), true)

    local currentOrg = toCP1251(ORGANIZATIONS[selectedOrg[0] + 1] or "")
    for _, msg in ipairs(chatMessages) do
        local show = false
        if showAllD[0] then
            show = msg:sub(1, 3) == "[D]"
        elseif filterByOrg[0] then
            show = msg:sub(1, 3) == "[D]" and msg:find(currentOrg, 1, true)
        end

        if show then
            imgui.TextWrapped(ffi.string(u8:encode(msg)))
        end
    end

    imgui.EndChild()
    if imgui.Button(u8"Очистить чат", imgui.ImVec2(140,30)) then chatMessages = {}; saveConfig() end
    imgui.SameLine()
    if imgui.Button(u8"Закрыть", imgui.ImVec2(140,30)) then
        messageWindowState[0] = false
        windowState[0] = true
    end
    imgui.End()
end

local function drawWindow()
    imgui.SetNextWindowSize(imgui.ImVec2(540, 720), imgui.Cond.FirstUseEver)
    imgui.Begin(u8"Frequency Helper | Помощник департамента", windowState)

    if imgui.BeginTabBar(u8"MainTabs") then
        if imgui.BeginTabItem(u8"Главная " .. faicons("sparkles")) then
            settingsTab[0] = 1
            drawMain()
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(u8"Настройки " .. faicons("sliders")) then
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
    sampAddChatMessage("{3F40B7}[Frequency Helper]{FFFFFF} Используйте /freq для открытия меню.", -1)

    while true do wait(0) end
end

imgui.OnFrame(function() return windowState[0] and not messageWindowState[0] end, drawWindow)
imgui.OnFrame(function() return messageWindowState[0] end, drawMessageWindow)
