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

-- Êîíôèãóðàöèÿ ÷àñòîò äëÿ ðàçíûõ îðãàíèçàöèé
local FREQUENCIES_LIST = {
    ["91.8"] = {
        desc = u8"Ñâÿçü ìåæäó îðãàíèçàöèÿìè Ìèíèñòåðñòâà þñòèöèè (íå ïåðåêëþ÷àòüñÿ)",
        orgs = {u8"ÔÁÐ", u8"Ïîëèöèÿ ËÑ", u8"Ïîëèöèÿ ÑÔ", u8"Ïîëèöèÿ ËÂ", u8"Îáëàñòíàÿ ïîëèöèÿ", u8"S.W.A.T"}
    },
    ["100.3"] = {
        desc = u8"Ñâÿçü ìåæäó âñåìè ãîñóäàðñòâåííûìè ñòðóêòóðàìè",
        orgs = {
            u8"ÔÁÐ", u8"Ïîëèöèÿ ËÑ", u8"Ïîëèöèÿ ÑÔ", u8"Ïîëèöèÿ ËÂ", u8"Îáëàñòíàÿ ïîëèöèÿ", u8"S.W.A.T",
            u8"Àðìèÿ ËÑ", u8"ÂÌÑ", u8"Delta Force", u8"MPC", u8"Áîëüíèöà ËÑ", u8"Áîëüíèöà ÑÔ",
            u8"Áîëüíèöà ËÂ", u8"Áîëüíèöà JF", u8"Òþðüìà ËÂ", u8"Ïðàâèòåëüñòâî", u8"Ñóä", u8"Ïðîêóðàòóðà",
            u8"Öåíòð ëèöåíçèðîâàíèÿ", u8"Ïîæàðíûé äåïàðòàìåíò", u8"ÑÌÈ ËÑ", u8"ÑÌÈ ÑÔ", u8"ÑÌÈ ËÂ",
            u8"Ñòðàõîâàÿ", u8"Ïîõèòèòåëè"
        }
    },
    ["102.7"] = {
        desc = u8"Ýêñòðåííàÿ ÷àñòîòà (×Ï)",
        orgs = {
            u8"ÔÁÐ", u8"Ïîëèöèÿ ËÑ", u8"Ïîëèöèÿ ÑÔ", u8"Ïîëèöèÿ ËÂ", u8"Îáëàñòíàÿ ïîëèöèÿ", u8"S.W.A.T",
            u8"Àðìèÿ ËÑ", u8"ÂÌÑ", u8"Delta Force", u8"MPC", u8"Áîëüíèöà ËÑ", u8"Áîëüíèöà ÑÔ",
            u8"Áîëüíèöà ËÂ", u8"Áîëüíèöà JF", u8"Òþðüìà ËÂ", u8"Ïðàâèòåëüñòâî", u8"Ñóä", u8"Ïðîêóðàòóðà",
            u8"Öåíòð ëèöåíçèðîâàíèÿ", u8"Ïîæàðíûé äåïàðòàìåíò", u8"ÑÌÈ ËÑ", u8"ÑÌÈ ÑÔ", u8"ÑÌÈ ËÂ",
            u8"Ñòðàõîâàÿ", u8"Ïîõèòèòåëè"
        }
    },
    ["104.8"] = {
        desc = u8"Ñâÿçü ìåæäó Ìèíèñòåðñòâàìè îáîðîíû, çäðàâîîõðàíåíèÿ è þñòèöèè",
        orgs = {
            u8"ÔÁÐ", u8"Ïîëèöèÿ ËÑ", u8"Ïîëèöèÿ ÑÔ", u8"Ïîëèöèÿ ËÂ", u8"Îáëàñòíàÿ ïîëèöèÿ", u8"S.W.A.T",
            u8"Àðìèÿ ËÑ", u8"ÂÌÑ", u8"Delta Force", u8"Áîëüíèöà ËÑ", u8"Áîëüíèöà ÑÔ", u8"Áîëüíèöà ËÂ", u8"Áîëüíèöà JF"
        }
    },
    ["108.3"] = {
        desc = u8"Ñâÿçü ìåæäó Ìèíèñòåðñòâàìè îáîðîíû è þñòèöèè",
        orgs = {
            u8"ÔÁÐ", u8"Ïîëèöèÿ ËÑ", u8"Ïîëèöèÿ ÑÔ", u8"Ïîëèöèÿ ËÂ", u8"Îáëàñòíàÿ ïîëèöèÿ", u8"S.W.A.T",
            u8"Àðìèÿ ËÑ", u8"ÂÌÑ", u8"Delta Force", u8"MPC"
        }
    },
    ["109.6"] = {
        desc = u8"Ñâÿçü ñ òþðüìîé ñòðîãîãî ðåæèìà",
        orgs = {
            u8"ÔÁÐ", u8"Ïîëèöèÿ ËÑ", u8"Ïîëèöèÿ ÑÔ", u8"Ïîëèöèÿ ËÂ", u8"Îáëàñòíàÿ ïîëèöèÿ", u8"S.W.A.T",
            u8"Àðìèÿ ËÑ", u8"ÂÌÑ", u8"Delta Force", u8"MPC", u8"Áîëüíèöà ËÑ", u8"Áîëüíèöà ÑÔ", u8"Áîëüíèöà ËÂ",
            u8"Áîëüíèöà JF", u8"Òþðüìà ËÂ"
        }
    },
    ["115.2"] = {
        desc = u8"Ñâÿçü ìåæäó îðãàíèçàöèÿìè Ìèíèñòåðñòâà îáîðîíû (íå ïåðåêëþ÷àòüñÿ)",
        orgs = {u8"Àðìèÿ ËÑ", u8"ÂÌÑ", u8"Delta Force"}
    },
    ["111.4"] = {
        desc = u8"×àñòîòà äëÿ çàíÿòèÿ ýôèðîâ",
        orgs = {u8"ÑÌÈ ËÑ", u8"ÑÌÈ ÑÔ", u8"ÑÌÈ ËÂ"}
    },
    ["105.5"] = {
        desc = u8"×àñòîòà ïîä êîíòðîëåì Ãóáåðíàòîðà",
        orgs = {u8"Ïðàâèòåëüñòâî"}
    }
}

-- Ñïèñîê âñåõ îðãàíèçàöèé
local ORGANIZATIONS = {
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

local function trim(s)
    if s == nil then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Ïåðåìåííûå äëÿ ImGui
local windowState = new.bool(false)
local selectedOrg = new.int(0)
local selectedFreq = new.int(0)
local selectedTargetOrg = new.int(0)
local messageText = new.char[1024]()
local sendWithoutTarget = new.bool(false)
local messageWindowState = new.bool(false)

local configFile = getWorkingDirectory() .. "\\frequency_helper.ini"

local chatMessages = {}  -- òóò áóäóò ñîîáùåíèÿ îêíà ñîîáùåíèé
local maxMessages = 100  -- ìàêñèìóì ñîîáùåíèé â îêíå

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
    return freq:gsub("[^%d%.]", ""):gsub("%.?$", "")  -- Óáèðàåì âñå ñèìâîëû, êðîìå öèôð è òî÷êè, è óäàëÿåì òî÷êó â êîíöå
end

local activeFrequencies = {}

local function toCP1251(text)
    return encoding.UTF8:decode(text)
end

-- Ñîõðàíåíèå êîíôèãóðàöèè â ôàéë
local function saveConfig()
    local file = io.open(configFile, "w")
    if file then
        file:write(string.format("selectedOrg=%d\n", selectedOrg[0]))
        file:write(string.format("selectedFreq=%d\n", selectedFreq[0]))
        file:write(string.format("selectedTargetOrg=%d\n", selectedTargetOrg[0]))
        file:write(string.format("sendWithoutTarget=%s\n", tostring(sendWithoutTarget[0])))
        file:write(string.format("messageText=%s\n", ffi.string(messageText)))
        file:close()
        return true
    end
    return false
end

-- Çàãðóçêà êîíôèãóðàöèè èç ôàéëà
local function loadConfig()
    -- Óñòàíàâëèâàåì çíà÷åíèÿ ïî óìîë÷àíèþ
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
            fullMessage = string.format("/d [%s] - [%s]: %s",
                toCP1251(currentOrg),
                frequency,
                toCP1251(message))
        else
            local targetOrg = ORGANIZATIONS[selectedTargetOrg[0] + 1]
            fullMessage = string.format("/d [%s] - [%s] - [%s]: %s",
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
        local msg = string.format("/d [%s] - [Èíôîðìàöèÿ]: Ïåðåõîæó íà ÷àñòîòó %s",
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
        local msg = string.format("/d [%s] - [Èíôîðìàöèÿ]: Ïîêèäàþ ÷àñòîòó %s",
            toCP1251(currentOrg),
            frequency)
        sampSendChat(msg)
    end
end

local function startInterview()
    lua_thread.create(function()
        local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1]
        sampSendChat(string.format("/d [%s] - [Èíôîðìàöèÿ]: Ïåðåõîæó íà ÷àñòîòó 103.9",
            toCP1251(currentOrg)))
        wait(1000)
        sampSendChat(string.format("/d [%s] - [103.9]: Çàíèìàþ ãîñ. âîëíó íà âðåìÿ äëÿ",
            toCP1251(currentOrg)))
        wait(1000)
        sampSendChat(string.format("/d [%s] - [103.9]: .. ïðîâåäåíèÿ ñîáåñåäîâàíèÿ.",
            toCP1251(currentOrg)))
        wait(1000)
        sampSendChat("/lmenu")
    end)
end

local function leaveInterview()
    local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1]
    sampSendChat(string.format("/d [%s] - [Èíôîðìàöèÿ]: Ïîêèäàþ ÷àñòîòó 103.9",
        toCP1251(currentOrg)))
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

    -- Îáðàáîòêà âõîäà íà ÷àñòîòó
    local verbEnter = matchAny(cleanText, {
        "[Ïï]åðåõîæó?[ëa]?",
        "[Ïï]åðåøåë?",
        "[Ïï]åðåø¸ë?",        
        "[Ïï]åðåøëà?"
    })

    if verbEnter then
        local patternEnter = "%[D%].*%[(.-)%].+%[Èíôîðìàöèÿ%].+" .. verbEnter .. "%s+íà%s+÷àñòîòó%s+([0-9%.,]+)"
        local org, freq = cleanText:match(patternEnter)
        if org and freq then
            activeFrequencies[cleanOrgName(org)] = cleanFrequency(freq)
            return
        end
    end

    -- Îáðàáîòêà âûõîäà ñ ÷àñòîòû
    local verbLeave = matchAny(cleanText, {
        "[Ïï]îêèäàþ?",
        "[Ïï]îêèäàë?",
        "[Ïï]îêèäàëà?",
        "[Ïï]îêèíóë?",
        "[Ïï]îêèäàëî?",
        "[Ïï]îêèíóëà?"
    })

    if verbLeave then
        local patternLeave = "%[D%].*%[(.-)%].+%[Èíôîðìàöèÿ%].+" .. verbLeave .. "%s+÷àñòîòó%s+([0-9%.]+)"
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
        sampAddChatMessage("{3F40B7}[Frequency Helper]{FFFFFF} Íà äàííûé ìîìåíò íåò îðãàíèçàöèé íà ÷àñòîòàõ.", -1)
        return
    end

    sampAddChatMessage("{3F40B7}[Frequency Helper]{FFFFFF} Àêòèâíûå ÷àñòîòû îðãàíèçàöèé:", -1)
    sampAddChatMessage("--------------------------------", -1)

    local sortedOrgs = {}
    for org in pairs(activeFrequencies) do
        table.insert(sortedOrgs, org)
    end
    table.sort(sortedOrgs)

    for _, org in ipairs(sortedOrgs) do
        local freq = activeFrequencies[org]
        sampAddChatMessage(string.format("{3F40B7}%s{FFFFFF} íàõîäèòñÿ íà ÷àñòîòå {3F40B7}%s",
            cleanOrgName(org),
            cleanFrequency(freq)), -1)
    end

    sampAddChatMessage("--------------------------------", -1)
end

local function drawMessageWindow()
    imgui.SetNextWindowSize(imgui.ImVec2(450, 350), imgui.Cond.FirstUseEver)
    imgui.Begin(u8"Îòïðàâêà ñîîáùåíèÿ", messageWindowState)

    imgui.BeginChild("ChatMessages", imgui.ImVec2(-1, 200), true)
    for i, msg in ipairs(chatMessages) do
        imgui.TextWrapped(ffi.string(u8:encode(msg)))
    end
    imgui.EndChild()

    if imgui.Button(u8"Î÷èñòèòü ÷àò", imgui.ImVec2(-1, 30)) then
        -- Î÷èñòèòü âñå ñîîáùåíèÿ
        chatMessages = {}
    end

    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Î÷èñòèòü âñå ñîîáùåíèÿ â ÷àòå")
    end

    -- Ãàëî÷êà "Îòïðàâèòü áåç óêàçàíèÿ îðãàíèçàöèè"
    if imgui.Checkbox(u8"Îòïðàâèòü áåç óêàçàíèÿ îðãàíèçàöèè", sendWithoutTarget) then
        saveConfig()
    end

    -- Âûáîð îðãàíèçàöèè äëÿ ñâÿçè (åñëè ãàëî÷êà íå ñòîèò)
    if not sendWithoutTarget[0] then
    imgui.Text(u8"Îðãàíèçàöèÿ äëÿ ñâÿçè:")
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

    -- Ïîëå ââîäà ñîîáùåíèÿ
    imgui.Text(u8"Ñîîáùåíèå:")
    imgui.SetNextItemWidth(-1)
    if imgui.InputText(u8"##msg", messageText, 1024) then
        saveConfig()
    end

    -- Êíîïêè âíèçó
    if imgui.Button(u8"Îòïðàâèòü ñîîáùåíèå", imgui.ImVec2(150, 30)) then
        sendMessage()
    end

    imgui.SameLine()

    if imgui.Button(u8"Ïîêèíóòü ÷àñòîòó", imgui.ImVec2(150, 30)) then
        -- Îòïðàâëÿåì êîìàíäó âûõîäà ñ ÷àñòîòû
        leaveFrequency()
        -- Çàêðûâàåì îêíî ñîîáùåíèé è îòêðûâàåì îñíîâíîå
        messageWindowState[0] = false
        windowState[0] = true
    end
        if imgui.IsItemHovered() then
            imgui.SetTooltip(u8"Ïîêèíóòü òåêóùóþ ÷àñòîòó è çàêðûòü îêíî ñîîáùåíèé")
        end

    imgui.SameLine()

    if imgui.Button(u8"Çàêðûòü", imgui.ImVec2(120, 30)) then
        messageWindowState[0] = false
        windowState[0] = true
    end
    
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Çàêðûòü îêíî ñîîáùåíèé áåç âûõîäà ñ ÷àñòîòû")
    end

    imgui.End()
end

local function drawWindow()
    imgui.SetNextWindowSize(imgui.ImVec2(450, 500), imgui.Cond.FirstUseEver)
    imgui.Begin(u8"Frequency Helper v1.4", windowState)

    imgui.Text(u8"Âàøà îðãàíèçàöèÿ:")
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

imgui.Text(u8"Âûáåðèòå ÷àñòîòó:")
local currentFreq = availableFrequencies[selectedFreq[0] + 1] or u8"Íåò äîñòóïíûõ ÷àñòîò"
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

    if imgui.Button(u8"Ïåðåéòè íà ÷àñòîòó") then
        switchFrequency()
    end

    imgui.SameLine()

    if imgui.Button(u8"Ïîêèíóòü ÷àñòîòó") then
        leaveFrequency()
    end

    if imgui.Button(u8"Îòêðûòü îêíî ñîîáùåíèé", imgui.ImVec2(-1, 30)) then
        messageWindowState[0] = true
        windowState[0] = false
    end

    imgui.Separator()
    if imgui.Button(u8"Òåõ íåïîëàäêè", imgui.ImVec2(-1, 30)) then
        local currentOrg = ORGANIZATIONS[selectedOrg[0] + 1]
        local msg = string.format("/d [%s] - [Èíôîðìàöèÿ]: Òåõíè÷åñêèå íåïîëàäêè.",
            toCP1251(currentOrg))
        sampSendChat(msg)
    end
    
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Íàïèñàòü â /d î òåõ. íåïîëàäêàõ.")
    end

    imgui.Separator()
    imgui.Text(u8"Ñîáåñåäîâàíèå:")

    if imgui.Button(u8"Çàáèòü ñîáåñåäîâàíèå", imgui.ImVec2(-1, 30)) then
        startInterview()
    end
    
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Âûéòè íà 103.9 è íàïèñàòü î çàíÿòèè âîëíû äëÿ ñîáåñåäîâàíèÿ. (Ïîñëå ýòîãî îòêðûâàò /lmenu)")
    end
    
    if imgui.Button(u8"Âûéòè ñ ñîáåñêè", imgui.ImVec2(-1, 30)) then
        leaveInterview()
    end

    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8"Âûéòè ñ ñîáåñåäîâàíèÿ è ïîêèíóòü ÷àñòîòó")
    end

    imgui.Separator()
    
    if imgui.Button(u8"Ïîêàçàòü àêòèâíûå ÷àñòîòû", imgui.ImVec2(-1, 30)) then
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

    sampAddChatMessage("{3F40B7}[Frequency Helper]{FFFFFF} Èñïîëüçóéòå /freq äëÿ îòêðûòèÿ ìåíþ | /activefreq äëÿ ïðîñìîòðà àêòèâíûõ ÷àñòîò | By MrKiroks", -1)

    while true do
        wait(0)
        end
end

imgui.OnFrame(function() return windowState[0] and not messageWindowState[0] end, drawWindow)
imgui.OnFrame(function() return messageWindowState[0] end, drawMessageWindow)
