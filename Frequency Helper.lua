require "lib.moonloader"
local samp = require 'lib.samp.events'
local encoding = require 'encoding'
local imgui = require 'mimgui'
local new = imgui.new
local ffi = require 'ffi'
encoding.default = 'CP1251'
u8 = encoding.UTF8
script_name("Frequency Helper")
script_version("1.6")

-- Конфигурация частот для разных организаций
local FREQUENCIES_LIST = {
    ["91.8"] = {
        desc = u8"Связь между организациями Министерства юстиции (не переключаться)",
        orgs = {u8"ФБР", u8"Полиция ЛС", u8"Полиция СФ", u8"Полиция ЛВ", u8"Областная полиция", u8"S.W.A.T"}
    },
    ["100.3"] = {
        desc = u8"Связь между всеми государственными структурами",
        orgs = {
            u8"ФБР", u8"Полиция ЛС", u8"Полиция СФ", u8"Полиция ЛВ", u8"Областная полиция", u8"S.W.A.T",
            u8"Армия ЛС", u8"ВМС", u8"Delta Force", u8"MPC", u8"Больница ЛС", u8"Больница СФ",
            u8"Больница ЛВ", u8"Больница JF", u8"Тюрьма ЛВ", u8"Правительство", u8"Суд", u8"Прокуратура",
            u8"Центр лицензирования", u8"Пожарный департамент", u8"СМИ ЛС", u8"СМИ СФ", u8"СМИ ЛВ",
            u8"Страховая", u8"Похитители"
        }
    },
    ["102.7"] = {
        desc = u8"Экстренная частота (ЧП)",
        orgs = {
            u8"ФБР", u8"Полиция ЛС", u8"Полиция СФ", u8"Полиция ЛВ", u8"Областная полиция", u8"S.W.A.T",
            u8"Армия ЛС", u8"ВМС", u8"Delta Force", u8"MPC", u8"Больница ЛС", u8"Больница СФ",
            u8"Больница ЛВ", u8"Больница JF", u8"Тюрьма ЛВ", u8"Правительство", u8"Суд", u8"Прокуратура",
            u8"Центр лицензирования", u8"Пожарный департамент", u8"СМИ ЛС", u8"СМИ СФ", u8"СМИ ЛВ",
            u8"Страховая", u8"Похитители"
        }
    },
    ["104.8"] = {
        desc = u8"Связь между Министерствами обороны, здравоохранения и юстиции",
        orgs = {
            u8"ФБР", u8"Полиция ЛС", u8"Полиция СФ", u8"Полиция ЛВ", u8"Областная полиция", u8"S.W.A.T",
            u8"Армия ЛС", u8"ВМС", u8"Delta Force", u8"Больница ЛС", u8"Больница СФ", u8"Больница ЛВ", u8"Больница JF"
        }
    },
    ["108.3"] = {
        desc = u8"Связь между Министерствами обороны и юстиции",
        orgs = {
            u8"ФБР", u8"Полиция ЛС", u8"Полиция СФ", u8"Полиция ЛВ", u8"Областная полиция", u8"S.W.A.T",
            u8"Армия ЛС", u8"ВМС", u8"Delta Force", u8"MPC"
        }
    },
    ["109.6"] = {
        desc = u8"Связь с тюрьмой строгого режима",
        orgs = {
            u8"ФБР", u8"Полиция ЛС", u8"Полиция СФ", u8"Полиция ЛВ", u8"Областная полиция", u8"S.W.A.T",
            u8"Армия ЛС", u8"ВМС", u8"Delta Force", u8"MPC", u8"Больница ЛС", u8"Больница СФ", u8"Больница ЛВ",
            u8"Больница JF", u8"Тюрьма ЛВ"
        }
    },
    ["115.2"] = {
        desc = u8"Связь между организациями Министерства обороны (не переключаться)",
        orgs = {u8"Армия ЛС", u8"ВМС", u8"Delta Force"}
    },
    ["111.4"] = {
        desc = u8"Частота для занятия эфиров",
        orgs = {u8"СМИ ЛС", u8"СМИ СФ", u8"СМИ ЛВ"}
    },
    ["105.5"] = {
        desc = u8"Частота под контролем Губернатора",
        orgs = {u8"Правительство"}
    }
}

-- Список всех организаций
local ORGANIZATIONS = {
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

local function trim(s)
    if s == nil then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Переменные для ImGui
local windowState = new.bool(false)
local selectedOrg = new.int(0)
local selectedFreq = new.int(0)
local selectedTargetOrg = new.int(0)
local messageText = new.char[1024]()
local sendWithoutTarget = new.bool(false)
local messageWindowState = new.bool(false)

local configFile = getWorkingDirectory() .. "\\frequency_helper.ini"

local chatMessages = {}  -- тут будут сообщения окна сообщений
local maxMessages = 100  -- максимум сообщений в окне
local selectedConfig = new.int(6) -- По умолчанию конфиг №6

-- Система конфигураций
local CONFIGS = {
    [6] = {
        name = u8"Конфиг №6 (основной)",
        hasFrequencies = true,
        techMessage = u8"Технические неполадки.",
        interviewStart = {
            u8"/b [%s] - [Информация]: Перехожу на частоту 103.9",
            u8"/b [%s] - [103.9]: Занимаю гос. волну на время для",
            u8"/b [%s] - [103.9]: .. проведения собеседования."
        },
        interviewLeave = u8"/b [%s] - [Информация]: Покидаю частоту 103.9"
    },
    [2] = {
        name = u8"Конфиг №2 (без частот)",
        hasFrequencies = false,
        techMessage = u8"Проблемы с оборудованием, связь временно недоступна.",
        interviewStart = {
            u8"/b [%s]: Провожу собеседование, просьба не беспокоить."
        },
        interviewLeave = u8"/b [%s]: Завершил собеседование, частота свободна."
    }
}

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

imgui.OnInitialize(function()
    applyStyle()
end)

local function cleanOrgName(org)
    if not org then return "" end
    org = org:gsub("^.*%]", "")
    org = org:gsub("[%[%]:%-]", "")
    return trim(org)
end

local function cleanFrequency(freq)
    if not freq then return "" end
    return freq:gsub("[^%d%.]", ""):gsub("%.?$", "")  -- Убираем все символы, кроме цифр и точки, и удаляем точку в конце
end

local activeFrequencies = {}

local function toCP1251(text)
    return encoding.UTF8:decode(text)
end

-- Сохранение конфигурации в файл
local function saveConfig()
    local file = io.open(configFile, "w")
    if file then
        file:write(string.format("selectedOrg=%d\n", selectedOrg[0]))
        file:write(string.format("selectedFreq=%d\n", selectedFreq[0]))
        file:write(string.format("selectedTargetOrg=%d\n", selectedTargetOrg[0]))
        file:write(string.format("sendWithoutTarget=%s\n", tostring(sendWithoutTarget[0])))
        file:write(string.format("messageText=%s\n", ffi.string(messageText)))
        file:write(string.format("selectedConfig=%d\n", selectedConfig[0]))
        file:close()
        return true
    end
    return false
end

-- Загрузка конфигурации из файла
local function loadConfig()
    -- Устанавливаем значения по умолчанию
    selectedOrg[0] = 0
    selectedFreq[0] = 0
    selectedTargetOrg[0] = 0
    sendWithoutTarget[0] = false
    ffi.fill(messageText, 0)
    
    if not doesFileExist(configFile) then
        saveConfig()
        return
    end
    
    local file = io.open(configFile, "r")
    if file then
        for line in file:lines() do
            local key, value = line:match("^([^=]+)=(.+)$")
            if key then
                key = trim(key)
                value = trim(value or "")
                
                if key == "selectedOrg" then
                    selectedOrg[0] = tonumber(value) or 0
                elseif key == "selectedFreq" then
                    selectedFreq[0] = tonumber(value) or 0
                elseif key == "selectedTargetOrg" then
                    selectedTargetOrg[0] = tonumber(value) or 0
                elseif key == "sendWithoutTarget" then
                    sendWithoutTarget[0] = value == "true"
                elseif key == "messageText" then
                    ffi.fill(messageText, 0)
                    ffi.copy(messageText, value)
                elseif key == "selectedConfig" then
                    selectedConfig[0] = tonumber(value) or 6
                end
            end
        end
        file:close()
    end
end

local function getAvailableFrequencies(orgName)
    local available = {}
    for freq, data in pairs(FREQUENCIES_LIST) do
        for _, org in ipairs(data.orgs) do
            if org == orgName then
                table.insert(available, freq)
                break
            end
        end
    end
    table.sort(available, function(a, b) return tonumber(a) < tonumber(b) end)
    return available
end

local function getFrequencyDescription(freq)
    return FREQUENCIES_LIST[freq] and FREQUENCIES_LIST[freq].desc or u8""
end

local function addChatMessageToWindow(msg)
    table.insert(chatMessages, msg)
    if #chatMessages > maxMessages then
        table.remove(chatMessages, 1)
    end
end

local function getCurrentFrequency()
    local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1]
    local freqs = getAvailableFrequencies(currentOrg)
    return freqs[selectedFreq[0] + 1]
end

local function sendMessage()
    lua_thread.create(function()
        local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1]
        local frequencies = getAvailableFrequencies(currentOrg)
        local frequency = frequencies[selectedFreq[0] + 1]
        
        if not frequency then return end
        
        local message = ffi.string(messageText)
        if message == "" then return end

        local fullMessage
        if sendWithoutTarget[0] then
            fullMessage = string.format("/b [%s] - [%s]: %s",
                toCP1251(currentOrg),
                frequency,
                toCP1251(message))
        else
            local targetOrg = ORGANIZATIONS[selectedTargetOrg[0] + 1]
            fullMessage = string.format("/b [%s] - [%s] - [%s]: %s",
                toCP1251(currentOrg),
                frequency,
                toCP1251(targetOrg),
                toCP1251(message))
        end

        sampSendChat(fullMessage)
        ffi.fill(messageText, 0)
        saveConfig()
    end)
end

local function switchFrequency()
    local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1]
    local frequencies = getAvailableFrequencies(currentOrg)
    local frequency = frequencies[selectedFreq[0] + 1]

    if frequency then
        local msg = string.format("b [%s] - [Информация]: Перехожу на частоту %s",
            toCP1251(currentOrg),
            frequency)
        sampSendChat(msg)

        messageWindowState[0] = true
        windowState[0] = false
    end
end

local function leaveFrequency()
    local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1]
    local frequencies = getAvailableFrequencies(currentOrg)
    local frequency = frequencies[selectedFreq[0] + 1]

    if frequency then
        local msg = string.format("/b [%s] - [Информация]: Покидаю частоту %s",
            toCP1251(currentOrg),
            frequency)
        sampSendChat(msg)
    end
end

local function startInterview()
    lua_thread.create(function()
        local cfg = CONFIGS[selectedConfig[0]]
        local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1]
        for _, line in ipairs(cfg.interviewStart) do
            sampSendChat(string.format(line, toCP1251(currentOrg)))
            wait(1000)
        end
        sampSendChat("/lmenu")
    end)
end


local function leaveInterview()
    local cfg = CONFIGS[selectedConfig[0]]
    local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1]
    sampSendChat(string.format(cfg.interviewLeave, toCP1251(currentOrg)))
end


function matchAny(str, patterns)
    for _, pattern in ipairs(patterns) do
        local result = str:match(pattern)
        if result then
            return result
        end
    end
    return nil
end

local function stripColorCodes(str)
    return str:gsub("{[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]}", "")
end

function samp.onServerMessage(color, text)
    local cleanText = text:gsub('{[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]}', '')
    cleanText = cleanText:gsub(",", ".")

    -- Обработка входа на частоту
    local verbEnter = matchAny(cleanText, {
        "[Пп]ерехожу?[лa]?",
        "[Пп]ерешел?",
        "[Пп]ерешёл?",        
        "[Пп]ерешла?"
    })

    if verbEnter then
        local patternEnter = "%[D%].*%[(.-)%].+%[Информация%].+" .. verbEnter .. "%s+на%s+частоту%s+([0-9%.,]+)"
        local org, freq = cleanText:match(patternEnter)
        if org and freq then
            activeFrequencies[cleanOrgName(org)] = cleanFrequency(freq)
            return
        end
    end

    -- Обработка выхода с частоты
    local verbLeave = matchAny(cleanText, {
        "[Пп]окидаю?",
        "[Пп]окидал?",
        "[Пп]окидала?",
        "[Пп]окинул?",
        "[Пп]окидало?",
        "[Пп]окинула?"
    })

    if verbLeave then
        local patternLeave = "%[D%].*%[(.-)%].+%[Информация%].+" .. verbLeave .. "%s+частоту%s+([0-9%.]+)"
        local orgLeave, freqLeave = cleanText:match(patternLeave)
        if orgLeave and freqLeave then
            local cleanOrg = cleanOrgName(orgLeave)
            local cleanFreq = cleanFrequency(freqLeave)
            if activeFrequencies[cleanOrg] == cleanFreq then
                activeFrequencies[cleanOrg] = nil
            end
        end
    end

    local currentFreq = getCurrentFrequency()
    if currentFreq and cleanText:find("%[" .. currentFreq .. "%]") then
        local strippedMsg = stripColorCodes(text)
        addChatMessageToWindow(strippedMsg)
    end
end

local function showActiveFrequencies()
    if not next(activeFrequencies) then
        sampAddChatMessage("{3F40B7}[Frequency Helper]{FFFFFF} На данный момент нет организаций на частотах.", -1)
        return
    end

    sampAddChatMessage("{3F40B7}[Frequency Helper]{FFFFFF} Активные частоты организаций:", -1)
    sampAddChatMessage("--------------------------------", -1)

    local sortedOrgs = {}
    for org in pairs(activeFrequencies) do
        table.insert(sortedOrgs, org)
    end
    table.sort(sortedOrgs)

    for _, org in ipairs(sortedOrgs) do
        local freq = activeFrequencies[org]
        sampAddChatMessage(string.format("{3F40B7}%s{FFFFFF} находится на частоте {3F40B7}%s",
            cleanOrgName(org),
            cleanFrequency(freq)), -1)
    end

    sampAddChatMessage("--------------------------------", -1)
end

local function drawMessageWindow()
    imgui.SetNextWindowSize(imgui.ImVec2(450, 350), imgui.Cond.FirstUseEver)
    imgui.Begin(u8"Отправка сообщения", messageWindowState)

    imgui.BeginChild("ChatMessages", imgui.ImVec2(-1, 200), true)
    for i, msg in ipairs(chatMessages) do
        imgui.TextWrapped(ffi.string(u8:encode(msg)))
    end
    imgui.EndChild()

    if imgui.Button(u8"Очистить чат", imgui.ImVec2(-1, 30)) then
        -- Очистить все сообщения
        chatMessages = {}
    end

    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Очистить все сообщения в чате")
    end

    -- Галочка "Отправить без указания организации"
    if imgui.Checkbox(u8"Отправить без указания организации", sendWithoutTarget) then
        saveConfig()
    end

    -- Выбор организации для связи (если галочка не стоит)
    if not sendWithoutTarget[0] then
    imgui.Text(u8"Организация для связи:")
        if imgui.BeginCombo(u8"##target", ORGANIZATIONS[selectedTargetOrg[0] + 1]) then
            for i, org in ipairs(ORGANIZATIONS) do
                if imgui.Selectable(org, selectedTargetOrg[0] == i - 1) then
                selectedTargetOrg[0] = i - 1
                saveConfig()
                end
            end
        imgui.EndCombo()
        end
    end

    -- Поле ввода сообщения
    imgui.Text(u8"Сообщение:")
    imgui.SetNextItemWidth(-1)
    if imgui.InputText(u8"##msg", messageText, 1024) then
        saveConfig()
    end

    -- Кнопки внизу
    if imgui.Button(u8"Отправить сообщение", imgui.ImVec2(150, 30)) then
        sendMessage()
    end

    imgui.SameLine()

    if imgui.Button(u8"Покинуть частоту", imgui.ImVec2(150, 30)) then
        -- Отправляем команду выхода с частоты
        leaveFrequency()
        -- Закрываем окно сообщений и открываем основное
        messageWindowState[0] = false
        windowState[0] = true
    end
        if imgui.IsItemHovered() then
            imgui.SetTooltip(u8"Покинуть текущую частоту и закрыть окно сообщений")
        end

    imgui.SameLine()

    if imgui.Button(u8"Закрыть", imgui.ImVec2(120, 30)) then
        messageWindowState[0] = false
        windowState[0] = true
    end
    
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Закрыть окно сообщений без выхода с частоты")
    end

    imgui.End()
end

local function drawWindow()
    imgui.SetNextWindowSize(imgui.ImVec2(450, 500), imgui.Cond.FirstUseEver)
    imgui.Begin(u8"Frequency Helper v1.4", windowState)
    local cfg = CONFIGS[selectedConfig[0]]

    imgui.Text(u8"Выберите конфигурацию:")
    if imgui.BeginCombo(u8"##config", cfg.name) then
        for id, data in pairs(CONFIGS) do
            if imgui.Selectable(data.name, selectedConfig[0] == id) then
                selectedConfig[0] = id
                saveConfig()
            end
        end
        imgui.EndCombo()
    end

imgui.Separator()

    imgui.Text(u8"Ваша организация:")
    if imgui.BeginCombo(u8"##org", ORGANIZATIONS[selectedOrg[0] + 1]) then
        for i, org in ipairs(ORGANIZATIONS) do
            if imgui.Selectable(org, selectedOrg[0] == i - 1) then
                selectedOrg[0] = i - 1
                selectedFreq[0] = 0
                saveConfig()
            end
        end
        imgui.EndCombo()
    end

    local frequencies = getAvailableFrequencies()
local freqKeys = {}
for k in pairs(frequencies) do table.insert(freqKeys, k) end
table.sort(freqKeys)

local orgName = ORGANIZATIONS[selectedOrg[0] + 1]
local availableFrequencies = getAvailableFrequencies(orgName)

if cfg.hasFrequencies then
    imgui.Text(u8"Выберите частоту:")
    local currentFreq = availableFrequencies[selectedFreq[0] + 1] or u8"Нет доступных частот"
    if imgui.BeginCombo(u8"##freq", currentFreq) then
        for i, freq in ipairs(availableFrequencies) do
            if imgui.Selectable(freq, selectedFreq[0] == i - 1) then
                selectedFreq[0] = i - 1
                saveConfig()
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(getFrequencyDescription(freq))
            end
        end
        imgui.EndCombo()
    end

        if imgui.Button(u8"Перейти на частоту") then
            switchFrequency()
        end

        imgui.SameLine()

        if imgui.Button(u8"Покинуть частоту") then
            leaveFrequency()
        end
end
    
    if imgui.Button(u8"Открыть окно сообщений", imgui.ImVec2(-1, 30)) then
        messageWindowState[0] = true
        windowState[0] = false
    end

    imgui.Separator()
    if imgui.Button(u8"Тех неполадки", imgui.ImVec2(-1, 30)) then
        local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1]
        local msg = string.format("/b [%s] - [Информация]: %s",
            toCP1251(currentOrg),
            toCP1251(cfg.techMessage))
        sampSendChat(msg)
    end
    
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Написать в /b о тех. неполадках.")
    end

    imgui.Separator()
    imgui.Text(u8"Собеседование:")

    if imgui.Button(u8"Забить собеседование", imgui.ImVec2(-1, 30)) then
        startInterview()
    end
    
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Выйти на 103.9 и написать о занятии волны для собеседования. (После этого открыват /lmenu)")
    end
    
    if imgui.Button(u8"Выйти с собески", imgui.ImVec2(-1, 30)) then
        leaveInterview()
    end

    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Выйти с собеседования и покинуть частоту")
    end

    imgui.Separator()
    
    if imgui.Button(u8"Показать активные частоты", imgui.ImVec2(-1, 30)) then
        showActiveFrequencies()
    end

    imgui.End()
end

function main()
    if not isSampfuncsLoaded() or not isSampLoaded() then
        return
    end
    while not isSampAvailable() do
        wait(100)
    end

    loadConfig()

    sampRegisterChatCommand("freq", function()
        if windowState[0] or messageWindowState[0] then
            windowState[0] = false
            messageWindowState[0] = false
        else
            windowState[0] = true
            messageWindowState[0] = false
        end
    end)

    sampRegisterChatCommand("activefreq", function()
        showActiveFrequencies()
    end)

    sampAddChatMessage("{3F40B7}[Frequency Helper]{FFFFFF} Используйте /freq для открытия меню | /activefreq для просмотра активных частот | By MrKiroks", -1)

    while true do
        wait(0)
        end
end

imgui.OnFrame(function() return windowState[0] and not messageWindowState[0] end, drawWindow)
imgui.OnFrame(function() return messageWindowState[0] end, drawMessageWindow)