local _, addon = ...
local state = addon.state
local page, pageSize, maxRows = 1, 6, 16
local saleFilter = "all"
local periodDays, watchClass, watchSubclass = 0, nil, nil
local watchView
local rail = 154
local watchError
local nextDraw = 0
local showExport = false
local exportPages, exportPage = {}, 1
local priceCache, priceCacheTime = {}, 0

local function marketCredit()
    return AHledgerAPI and AHledgerAPI.CREDIT or "Prices from AHledger (ahledger.com)"
end

local function displayHistory(id)
    if GetTime() > priceCacheTime then
        priceCache, priceCacheTime = {}, GetTime() + 2
    end
    if priceCache[id] == nil then priceCache[id] = addon.history(id) or false end
    return priceCache[id]
end

local function money(value)
    if type(value) ~= "number" then return "–" end
    if value < 0 then return "-" .. money(-value) end
    if value >= 10000 then
        return string.format("%dg %02ds %02dk", math.floor(value / 10000), math.floor(value / 100) % 100, value % 100)
    end
    if value >= 100 then return string.format("%ds %02dk", math.floor(value / 100), value % 100) end
    return string.format("%dk", value)
end

local frame = CreateFrame("Frame", "ForeverFlipPanel", UIParent, "BackdropTemplate")
frame:SetSize(816, 550)
frame:SetResizable(true)
frame:SetResizeBounds(704, 438, 1040, 780)
frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -28, -140)
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
})
frame:SetBackdropColor(0.047, 0.065, 0.087, 0.99)
frame:SetBackdropBorderColor(0.25, 0.40, 0.46, 1)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

local function line(x, y, width, style)
    local font = frame:CreateFontString(nil, "OVERLAY", style)
    font:SetPoint("TOPLEFT", x, y)
    font:SetWidth(width)
    font:SetJustifyH("LEFT")
    font:SetWordWrap(false)
    return font
end

local function surface(parent, red, green, blue, alpha)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetColorTexture(red, green, blue, alpha or 1)
    return texture
end

local function button(x, y, width, caption, script)
    local control = CreateFrame("Button", nil, frame)
    control:SetPoint("TOPLEFT", x, y)
    control:SetSize(width, 27)
    local background = surface(control, 0.105, 0.18, 0.23)
    background:SetAllPoints()
    control:SetNormalTexture(background)
    local highlighted = surface(control, 0.15, 0.32, 0.36)
    highlighted:SetAllPoints()
    control:SetHighlightTexture(highlighted)
    local inactive = surface(control, 0.075, 0.11, 0.14)
    inactive:SetAllPoints()
    control:SetDisabledTexture(inactive)
    control:SetNormalFontObject(GameFontHighlight)
    control:SetHighlightFontObject(GameFontHighlight)
    control:SetDisabledFontObject(GameFontDisable)
    control:SetText(caption)
    control:SetScript("OnClick", script)
    return control
end

local function enabled(control, yes)
    if yes then control:Enable() else control:Disable() end
end

local function switchTab(tab)
    if state.action then return end
    addon.closeSearch()
    if tab == "watch" then addon.editSelection() end
    state.tab, page, showExport = tab, 1, false
    exportPages, exportPage = {}, 1
end

local railBackground = surface(frame, 0.063, 0.095, 0.12)
railBackground:SetPoint("TOPLEFT", 1, -1)
local brand = line(16, -20, rail - 24, "GameFontNormalLarge")
brand:SetText("ForeverFlip")
brand:SetTextColor(0.50, 0.91, 0.79)
local tradeLabel = line(16, -70, rail - 24, "GameFontDisableSmall")
tradeLabel:SetText("HANDEL")
local ledgerLabel = line(16, -249, rail - 24, "GameFontDisableSmall")
ledgerLabel:SetText("AUSWERTUNG")
local stageLine = line(18, -56, 640, "GameFontHighlightLarge")
local contextLine = line(18, -83, 400, "GameFontHighlight")
local notice = line(18, -105, 640, "GameFontNormalSmall")
local marketPriceLine = line(18, -84, 270, "GameFontHighlightLarge")
local yourPriceLine = line(300, -84, 354, "GameFontHighlightLarge")
local note = line(18, -533, 640, "GameFontDisableSmall")
local pageLine = line(304, -405, 100, "GameFontHighlightSmall")
local tabs = {}
for index, entry in ipairs({
    { "flow", "Handelsrunde" }, { "watch", "Watchlist" }, { "purchases", "Käufe" }, { "stock", "Bestand" },
    { "sales", "Verkäufe" }, { "balance", "Bilanz" }, { "stats", "Scan-Statistik" }, { "export", "Export" },
}) do
    local tab, caption = entry[1], entry[2]
    tabs[tab] = button(12, -88 - (index - 1) * 35 - (index > 4 and 42 or 0), rail - 24, caption, function() switchTab(tab) end)
end

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)
local primary = button(17, -397, 162, "", function() end)
local finish = button(184, -397, 116, "", function() end)
local saleQuantity = button(0, 0, 122, "", addon.changeSaleQuantity)
local exportPrevious = button(0, 0, 94, "Zurück", function()
    exportPage, showExport = math.max(1, exportPage - 1), false
end)
local exportNext = button(0, 0, 94, "Weiter", function()
    exportPage, showExport = math.min(#exportPages, exportPage + 1), false
end)
local listBar = CreateFrame("Slider", "ForeverFlipListScrollBar", frame, "UIPanelScrollBarTemplate")
listBar:SetOrientation("VERTICAL")
listBar:SetValueStep(1)
listBar:SetObeyStepOnDrag(true)
listBar:SetScript("OnValueChanged", function(_, value)
    if not state.action then page = math.floor(value + 0.5) end
end)
frame:EnableMouseWheel(true)
frame:SetScript("OnMouseWheel", function(_, delta)
    if not state.action and listBar:IsShown() then listBar:SetValue(page - delta * 3) end
end)

local filters = {}
for index, filter in ipairs({ { "all", "Alle" }, { "open", "Offen" }, { "sold", "Verkauft" } }) do
    filters[index] = button(0, -49, 72, filter[2], function()
        saleFilter, page = filter[1], 1
    end)
end

local budgetMode
local budgetInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
budgetInput:SetPoint("TOPLEFT", 456, -78)
budgetInput:SetSize(75, 22)
budgetInput:SetAutoFocus(false)
budgetInput:SetMaxLetters(12)
local budgetLabel = line(403, -84, 46, "GameFontHighlightSmall")
budgetLabel:SetText("Gold")

local function saveBudget()
    if addon.configureBudget(budgetInput:GetText(), budgetMode == "edit") then
        budgetInput:ClearFocus()
        budgetMode, page = nil, 1
    end
end

local budgetSave = button(537, -77, 124, "Speichern", saveBudget)
budgetInput:SetScript("OnEnterPressed", saveBudget)
budgetInput:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    budgetMode = nil
end)

local function openBudget(mode)
    if addon.isBusy() then return end
    addon.closeSearch()
    budgetMode = mode
    budgetInput:SetText(state.round and tostring(state.round.budget / 10000) or "")
    budgetInput:Show()
    budgetInput:SetFocus()
    budgetInput:HighlightText()
end

local settings = button(417, -49, 116, "Budget", function()
    openBudget("edit")
end)
local items = button(539, -49, 122, "Items ändern", function()
    addon.editSelection()
    page = 1
end)
local sound = button(0, -98, 80, "Ton: an", addon.toggleHitSound)
local strategyButton = button(0, 0, 147, "", function() addon.changeStrategy("mode") end)
local volumeButton = button(0, 0, 118, "", function() addon.changeStrategy("volume") end)
local function explain(control, title, description)
    control:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(description, 0.85, 0.90, 0.93, true)
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end
explain(strategyButton, "Aktive Strategie · Klicken zum Wechseln",
    "Direktverkauf: mindestens 5 % Gewinn nach AH-Provision, mit 2 % Preispuffer. Zwischenhändler: Bei Stapelware bleibt zusätzlich Gewinn für einen Weiterverkäufer. Einzelauktionen brauchen in diesem Modus 20 % Gewinn nach einem 15-%-Preispuffer.")
explain(volumeButton, "Maximale Kaufmenge pro Artikel",
    "Das Limit rechnet den geschätzten Tagesabsatz auf 15 Minuten, 1 Stunde oder 4 Stunden um. Beispiel: 960 Verkäufe pro Tag ergeben in 15 Minuten 10 Stück. Im Direktverkauf zählt offener Bestand mit. Im Zwischenhändlermodus werden Einzelauktionen einzeln bewertet.")
frame:SetScript("OnHide", addon.closeSearch)

local function input(width)
    local field = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    field:SetSize(width, 25)
    field:SetAutoFocus(false)
    field:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return field
end

local watchSearch = input(212)
watchSearch:SetScript("OnTextChanged", function() page, watchView = 1, nil end)
local searchHint = line(0, 0, 185, "GameFontDisableSmall")
searchHint:SetText("Name oder Item-ID suchen")
local minimum = input(58)
minimum:SetNumeric(true)
minimum:SetMaxLetters(7)
local minimumLabel = line(0, 0, 132, "GameFontHighlightSmall")
minimumLabel:SetText("Mindestabsatz / Tag")
local function saveMinimum()
    if addon.setDailyMinimum(minimum:GetText()) then watchError, page, watchView = nil, 1, nil
    else watchError = "Mindestabsatz zwischen 1 und 1.000.000 eingeben." end
    minimum:ClearFocus()
end
minimum:SetScript("OnEnterPressed", saveMinimum)
minimum:SetScript("OnEditFocusLost", function(self)
    if self:GetText() ~= tostring(addon.dailyMinimum()) then saveMinimum() end
end)
local customItem = input(180)
local customHint = line(0, 0, 165, "GameFontDisableSmall")
customHint:SetText("Item-ID oder Itemlink")
local function addItem()
    local ok, reason = addon.addWatchItem(customItem:GetText())
    watchError = reason
    if ok then
        page = 1
        customItem:ClearFocus()
        watchSearch:SetText("")
        customItem:SetText("")
    end
end
customItem:SetScript("OnEnterPressed", addItem)
local customButton = button(0, 0, 86, "Hinzufügen", addItem)
local selectAll = button(0, 0, 111, "Alle markieren", function() end)
local selectNone = button(0, 0, 99, "Alle abwählen", function() end)
local selectLast = button(0, 0, 103, "Letzte Suche", function()
    addon.setSelection({}, "previous")
    page, watchView = 1, nil
end)
local catalog = button(0, 0, 124, "AH-Katalog laden", function()
    watchError = nil
    addon.startCatalog()
end)
local categories = {}
local category = button(0, 0, 180, "Alle Kategorien", function(self)
    local function choose(class, subclass, label)
        watchClass, watchSubclass, watchView, page = class, subclass, nil, 1
        self:SetText(label)
    end
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(self, function(_, menu)
            menu:CreateButton("Alle Kategorien", function() choose(nil, nil, "Alle Kategorien") end)
            for _, group in ipairs(categories) do
                local parent = menu:CreateButton(group.name, function() choose(group.id, nil, group.name) end)
                if #group.subclasses > 0 then
                    parent:CreateButton("Alle " .. group.name, function() choose(group.id, nil, group.name) end)
                    for _, sub in ipairs(group.subclasses) do
                        parent:CreateButton(sub.name, function() choose(group.id, sub.id, sub.name) end)
                    end
                end
            end
        end)
    else
        local nextGroup = not watchClass and categories[1]
        for index, group in ipairs(categories) do
            if group.id == watchClass then nextGroup = categories[index + 1]; break end
        end
        if nextGroup then choose(nextGroup.id, nil, nextGroup.name)
        else choose(nil, nil, "Alle Kategorien") end
    end
end)
local periodOptions = { 0, 1, 7, 30, 90 }
local periods = {}
for index, days in ipairs(periodOptions) do
    periods[index] = button(0, 0, 74, days == 0 and "Gesamt" or days .. (days == 1 and " Tag" or " Tage"), function()
        periodDays = days
    end)
end

local separator = frame:CreateTexture(nil, "BACKGROUND")
separator:SetPoint("TOPLEFT", 17, -428)
separator:SetSize(644, 1)
separator:SetColorTexture(0.25, 0.38, 0.47, 0.75)
local rows = {}
for index = 1, maxRows do
    local y = -132 - (index - 1) * 42
    local accent = frame:CreateTexture(nil, "BACKGROUND")
    accent:SetPoint("TOPLEFT", 14, y + 3)
    accent:SetSize(652, 39)
    accent:SetColorTexture(0.11, 0.17, 0.22, index % 2 == 1 and 0.85 or 0.47)
    local hover = CreateFrame("Frame", nil, frame)
    hover:SetPoint("TOPLEFT", 19, y + 3)
    hover:SetSize(440, 38)
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(self.tip.name)
        for _, text in ipairs(self.tip.lines) do GameTooltip:AddLine(text, 0.85, 0.90, 0.93) end
        GameTooltip:Show()
    end)
    hover:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    rows[index] = {
        bg = accent, title = line(23, y, 437, "GameFontHighlight"),
        detail = line(23, y - 18, 441, "GameFontHighlightSmall"),
        button = button(468, y - 5, 189, "", function() end),
        hover = hover,
    }
end

local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 22, -145)
scroll:SetSize(620, 235)
local exportBox = CreateFrame("EditBox", nil, scroll)
exportBox:SetSize(608, 312)
exportBox:SetFontObject(GameFontHighlightSmall)
exportBox:SetMultiLine(true)
exportBox:SetAutoFocus(false)
exportBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
scroll:SetScrollChild(exportBox)
scroll:Hide()

local function place(widget, x, y)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
end

local function tradeHistoryPanel()
    local panel = CreateFrame("Frame", "ForeverFlipTradeHistory", frame)
    panel:SetPoint("TOPLEFT", frame, "TOPLEFT", rail + 19, -190)
    panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -25, 72)
    panel:Hide()

    local function label(parent, style)
        local font = parent:CreateFontString(nil, "OVERLAY", style or "GameFontHighlightSmall")
        font:SetJustifyH("LEFT")
        font:SetWordWrap(false)
        return font
    end
    local title = label(panel, "GameFontHighlight")
    title:SetPoint("TOPLEFT")
    local empty = label(panel, "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", 0, -48)
    empty:SetText("Noch keine bestätigten Käufe")
    local columns = {
        { "Item / Menge", 0.25 }, { "Bezahlt gesamt", 0.16 }, { "Markt / Stk.", 0.16 },
        { "Zwischenhändler", 0.215 }, { "Direktverkauf", 0.215 },
    }
    local headers, entries = {}, {}
    for i, column in ipairs(columns) do
        headers[i] = label(panel, "GameFontNormalSmall")
        headers[i]:SetText(column[1])
    end
    local bar = CreateFrame("Slider", "ForeverFlipTradeHistoryScrollBar", panel, "UIPanelScrollBarTemplate")
    bar:SetPoint("TOPRIGHT", -1, -44)
    bar:SetPoint("BOTTOMRIGHT", -1, 8)
    bar:SetWidth(14)
    bar:SetOrientation("VERTICAL")
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)

    local history, offset, refreshAt = {}, 1, 0
    local function wheel(_, delta)
        if bar:IsShown() then bar:SetValue(offset - delta * 3) end
    end
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", wheel)
    bar:SetScript("OnValueChanged", function(_, value)
        offset, refreshAt = math.floor(value + 0.5), 0
    end)
    local rowHeight, rowStart = 43, 40
    for index = 1, 12 do
        local row = CreateFrame("Frame", nil, panel)
        row:SetPoint("TOPLEFT", 0, -rowStart - (index - 1) * rowHeight)
        row:SetPoint("TOPRIGHT", -20, -rowStart - (index - 1) * rowHeight)
        row:SetHeight(rowHeight - 1)
        local background = surface(row, 0.10, 0.14, 0.19, index % 2 == 0 and 0.65 or 0.35)
        background:SetAllPoints(row)
        row:EnableMouse(true)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", wheel)
        row:SetScript("OnEnter", function(self)
            if not self.lot then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(addon.itemName(self.lot.item))
            GameTooltip:AddLine("Runde " .. self.round .. " · " .. date("%d.%m. %H:%M", self.lot.acquired))
            GameTooltip:AddLine(self.marketSource)
            GameTooltip:AddLine("Verkaufspreise sind Schätzungen vom Kaufzeitpunkt.", 0.8, 0.9, 1, true)
            local lot = self.lot
            if lot.deposit then GameTooltip:AddLine("Kaution: " .. money(lot.deposit)) end
            if (lot.lostDeposit or 0) > 0 then
                GameTooltip:AddLine("Verlorene Kaution im Gewinn abgezogen: " .. money(lot.lostDeposit))
            end
            if not lot.directTarget or not lot.traderTarget then
                GameTooltip:AddLine("Zu diesem älteren Kauf wurde nur der damalige Zielpreis gespeichert.", 0.8, 0.9, 1, true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        local cells = {}
        for i = 1, #columns do
            cells[i] = { label(row), label(row, "GameFontDisableSmall"), label(row) }
        end
        entries[index] = { row = row, cells = cells }
    end
    local layoutWidth, layoutHeight, visibleRows
    local function fit()
        local width, height = panel:GetWidth(), panel:GetHeight()
        if width == layoutWidth and height == layoutHeight then return end
        layoutWidth, layoutHeight = width, height
        local x, available = 5, math.max(1, width - 24)
        for i, column in ipairs(columns) do
            local span = available * column[2]
            headers[i]:ClearAllPoints()
            headers[i]:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -23)
            headers[i]:SetWidth(math.max(1, span - 4))
            for _, entry in ipairs(entries) do
                for n, font in ipairs(entry.cells[i]) do
                    font:ClearAllPoints()
                    font:SetPoint("TOPLEFT", entry.row, "TOPLEFT", x, -3 - (n - 1) * 12)
                    font:SetWidth(math.max(1, span - 4))
                end
            end
            x = x + span
        end
        visibleRows = math.min(#entries, math.max(0, math.floor((height - rowStart) / rowHeight)))
        refreshAt = 0
    end
    local function setCell(cell, first, second, third)
        cell[1]:SetText(first or "")
        cell[2]:SetText(second or "")
        cell[3]:SetText(third or "")
    end
    local function paintSale(cell, lot, price)
        local fee, profit = addon.purchaseResult(lot, price)
        setCell(cell, money(price), fee and ("AH: " .. money(fee)), profit and ("Gewinn: " .. money(profit)))
        if profit and profit < 0 then cell[3]:SetTextColor(1, 0.48, 0.43)
        else cell[3]:SetTextColor(0.50, 0.88, 0.75) end
    end
    local function marketInfo(id)
        local scan, known = addon.marketScan(id), displayHistory(id)
        local updated = known and tonumber(known.updated)
        if scan and (not updated or scan.at >= updated) then
            return scan.price, "AH " .. date("%H:%M", scan.at), "AH-Scan vom " .. date("%d.%m. %H:%M", scan.at)
        end
        if known then
            local source = known.snapshot and "AHledger-Snapshot" or "AHledger"
            return tonumber(known.minBuyout), known.snapshot and "Snapshot" or "AHledger",
                source .. (updated and (" vom " .. date("%d.%m. %H:%M", updated)) or " · Datenstand offen")
        end
        return nil, "Kein Preisstand", "Kein Marktpreis verfügbar"
    end
    local function paint(entry, record)
        local round, lot = record[1], record[2]
        local row, cells = entry.row, entry.cells
        local market, source, sourceDetail = marketInfo(lot.item)
        row.lot, row.round, row.marketSource = lot, round, sourceDetail
        local original = lot
        if lot.purchaseQuantity then original = { quantity = lot.purchaseQuantity, cost = lot.purchaseCost } end
        setCell(cells[1], addon.itemName(lot.item), original.quantity .. " Stück")
        setCell(cells[2], money(original.cost), "Ø " .. money(math.floor(original.cost / original.quantity + 0.5)) .. "/Stk.")
        setCell(cells[3], money(market), source)
        paintSale(cells[4], original, lot.traderTarget or (not lot.directBuy and lot.target or nil))
        paintSale(cells[5], original, lot.directTarget or (lot.directBuy and lot.target or nil))
    end
    return function(show)
        if not show then panel:Hide(); return end
        panel:Show()
        fit()
        local newest
        addon.walkRecentPurchases(1, function(_, _, lot) newest = lot end)
        if newest ~= (history[1] and history[1][2]) then
            history, offset, refreshAt = {}, 1, 0
            addon.walkRecentPurchases(math.huge, function(index, round, lot)
                history[index] = { round, lot }
            end)
        end
        local time = GetTime()
        if time < refreshAt then return end
        refreshAt = time + 1
        local limit = math.max(1, #history - visibleRows + 1)
        local start = math.min(offset, limit)
        bar:SetShown(visibleRows > 0 and limit > 1)
        bar:SetMinMaxValues(1, limit)
        if bar:GetValue() ~= start then bar:SetValue(start) end
        offset = start
        title:SetText("Letzte Käufe (" .. #history .. ") · Verkaufsschätzung beim Kauf")
        empty:SetShown(#history == 0)
        for index, entry in ipairs(entries) do
            local record = index <= visibleRows and history[offset + index - 1]
            entry.row:SetShown(record ~= nil and record ~= false)
            if record then paint(entry, record) end
        end
    end
end

local showTradeHistory = tradeHistoryPanel()

local function layout(width, height)
    local x, content = rail + 19, width - rail - 40
    railBackground:SetSize(rail - 1, height - 2)
    place(stageLine, x, -23)
    place(contextLine, x, -57)
    place(notice, x, -101)
    for _, widget in ipairs({ stageLine, notice, note, contextLine }) do widget:SetWidth(content) end
    marketPriceLine:SetWidth(content * 0.47)
    place(marketPriceLine, x, -65)
    place(yourPriceLine, x + content * 0.46, -65)
    yourPriceLine:SetWidth(content * 0.54)
    for index, filter in ipairs(filters) do place(filter, width - 275 + (index - 1) * 76, -20) end
    place(settings, width - 289, -20)
    place(items, width - 167, -20)
    place(saleQuantity, width - 167, -20)
    place(budgetLabel, width - 270, -84)
    place(budgetInput, width - 224, -78)
    place(budgetSave, width - 143, -77)
    place(sound, width - 100, -98)
    place(strategyButton, width - 296, -61)
    place(volumeButton, width - 142, -61)
    place(primary, x, 59 - height)
    place(finish, x + 171, 59 - height)
    place(exportPrevious, x, 59 - height)
    place(exportNext, x + 100, 59 - height)
    place(pageLine, width - 100, 51 - height)
    pageLine:SetWidth(65)
    place(separator, x, 69 - height)
    separator:SetWidth(content)
    place(note, x, 21 - height)
    place(watchSearch, x + 3, -91)
    place(searchHint, x + 10, -98)
    place(minimumLabel, width - 207, -98)
    place(minimum, width - 72, -91)
    place(customItem, x + 3, -126)
    place(customHint, x + 10, -133)
    place(customButton, x + 189, -126)
    place(category, x + 286, -124)
    place(selectAll, x, -164)
    place(selectNone, x + 117, -164)
    place(selectLast, x + 222, -164)
    place(catalog, width - 147, -164)
    for index, period in ipairs(periods) do place(period, x + (index - 1) * 80, -61) end
    for _, row in ipairs(rows) do
        row.bg:SetWidth(content - 17)
        row.hover:SetWidth(content - 183)
        row.title:SetWidth(content - 194)
        row.detail:SetWidth(content - 194)
        row.button:SetWidth(160)
    end
    place(scroll, x + 3, -131)
    scroll:SetSize(content - 28, height - 209)
    exportBox:SetWidth(content - 40)
end

local lastListLayout
local function listLayout(watching)
    local width, height = frame:GetWidth(), frame:GetHeight()
    local key = table.concat({ width, height, watching and 1 or 0 }, ":")
    if lastListLayout == key then return end
    lastListLayout = key
    local top = watching and 205 or 133
    pageSize = math.max(1, math.min(maxRows, math.floor((height - top - 72) / 42)))
    place(listBar, width - 36, -top - 8)
    listBar:SetSize(14, math.max(30, pageSize * 42 - 14))
    for index, row in ipairs(rows) do
        local y = -top - (index - 1) * 42
        place(row.bg, rail + 18, y)
        place(row.title, rail + 30, y - 5)
        place(row.detail, rail + 30, y - 23)
        place(row.hover, rail + 20, y)
        place(row.button, width - 205, y - 5)
    end
end

local resize = button(0, 0, 22, "◢", function() end)
resize:ClearAllPoints()
resize:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
resize:SetSize(22, 19)
resize:SetScript("OnMouseDown", function(_, key)
    if key == "LeftButton" and not state.action then frame:StartSizing("BOTTOMRIGHT") end
end)
resize:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    if ForeverFlipRounds then
        ForeverFlipRounds.windowWidth = frame:GetWidth()
        ForeverFlipRounds.windowHeight = frame:GetHeight()
    end
end)
frame:SetScript("OnSizeChanged", function(_, width, height) layout(width, height) end)
layout(frame:GetWidth(), frame:GetHeight())

local stage = {
    select = "Items für die Runde auswählen",
    buy = "Treffer kaufen",
    mail = "Zum Briefkasten – Käufe abholen",
    sell = "Zurück zum AH – Ware einstellen",
    done = "Runde abgeschlossen",
}

local function selectionRows()
    local stamp, revision = GetTime(), state.catalogRevision or 0
    if watchView and watchView.expires >= stamp and watchView.revision == revision then
        return watchView.view, watchView.matching, watchView.all
    end
    local available, matching, all, groups = {}, {}, {}, {}
    local filter = string.lower(watchSearch:GetText():match("^%s*(.-)%s*$"))
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local threshold = addon.dailyMinimum()
    for id, item in pairs(addon.items) do
        local _, itemType, subtype, _, _, class, subclass
        if instant then _, itemType, subtype, _, _, class, subclass = instant(id) end
        if class and itemType then
            local group = groups[class] or { id = class, name = itemType, byID = {} }
            groups[class] = group
            if subclass and subtype and subtype ~= itemType then group.byID[subclass] = subtype end
        end
        all[#all + 1] = id
        if (not watchClass or class == watchClass) and (not watchSubclass or subclass == watchSubclass) then
            local name = addon.itemName(id)
            if filter == "" or string.lower(name):find(filter, 1, true) or
                string.lower(item[2]):find(filter, 1, true) or tostring(id):find(filter, 1, true) then
                local market = displayHistory(id)
                local sales = market and tonumber(market.soldPerDay)
                local eligible = sales and sales >= threshold and (tonumber(market.median7d) or 0) > 0
                available[#available + 1] = { id = id, name = name, sales = sales, eligible = eligible,
                    snapshot = market and market.snapshot, itemType = itemType, price = market and tonumber(market.minBuyout) }
                if eligible then matching[#matching + 1] = id end
            end
        end
    end
    categories = {}
    for _, group in pairs(groups) do
        group.subclasses = {}
        for subclass, label in pairs(group.byID) do
            group.subclasses[#group.subclasses + 1] = { id = subclass, name = label }
        end
        table.sort(group.subclasses, function(a, b) return a.name < b.name end)
        categories[#categories + 1] = group
    end
    table.sort(categories, function(a, b) return a.name < b.name end)
    table.sort(available, function(a, b)
        local first, second = a.sales or 0, b.sales or 0
        return first == second and a.id < b.id or first > second
    end)
    local view = {}
    for _, item in ipairs(available) do
        local id = item.id
        view[#view + 1] = {
            title = (addon.selected(id) and "✓  " or "") .. item.name,
            detail = (item.sales and ("~" .. math.floor(item.sales) .. " / Tag") or "Absatz offen")
                .. "  ·  " .. money(item.price and item.price > 0 and item.price or nil) .. "/Stk."
                .. (item.snapshot and "  ·  Snapshot" or "") .. (item.eligible and "" or "  ·  nicht scanbar"),
            tip = { name = item.name, lines = {
                item.itemType or "Kategorie offen", "Stückpreis: zuletzt erfasster AHledger-Sofortkauf", marketCredit(),
            } },
            caption = addon.selected(id) and "Abwählen" or "Markieren",
            disabled = not item.eligible and not addon.selected(id),
            click = function() addon.toggleItem(id); watchView = nil end,
        }
    end
    watchView = { view = view, matching = matching, all = all, revision = revision, expires = stamp + 3 }
    return view, matching, all
end

local function hitRows()
    local view = {}
    for _, id in ipairs(state.hitOrder) do
        local hit = addon.freshHit(id)
        local pending = state.action and state.action.id == id and state.action
        local caption = "Kauf prüfen"
        if pending then
            caption = ({
                quote = "Preis wird geprüft …", quoted = "Kauf bestätigen", buying = "Kauf wird verbucht …",
                singleCheck = "Angebot wird geprüft …", singleReady = "1 × für " .. money(pending.total) .. " kaufen",
            })[pending.phase]
        end
        if hit or (pending and state.hits[id]) then
            hit = hit or state.hits[id]
            if hit.single and not pending then caption = "Sofortkauf prüfen" end
            local detail = {
                hit.direct and "Direktverkauf" or "Zwischenhändler",
                "Einkauf bis " .. money(hit.maxUnit) .. "/Stk. · Ziel " .. money(hit.post) .. "/Stk.",
                "Nächster Preis nach vollständigem Kauf: " .. money(hit.nextPrice) .. "/Stk.",
                "Geschätzter Gewinn nach AH-Provision: " .. money(hit.profit),
            }
            if hit.minutes then
                detail[#detail + 1] = string.format("Absatz: ~%d/Tag · Mengenlimit: %d Min.", hit.salesPerDay, hit.minutes)
            end
            if hit.bought then detail[#detail + 1] = hit.bought .. " gekauft · Preisstufen des ursprünglichen Treffers:" end
            for index, level in ipairs(hit.levels or {}) do
                if index > 12 then
                    detail[#detail + 1] = "Weitere Preisstufen stehen im Export."
                    break
                end
                detail[#detail + 1] = level.quantity .. " × " .. money(level.price)
            end
            if hit.single then detail[#detail + 1] = "Jede Einzelauktion am selben Button bestätigen." end
            if not hit.vendorKnown then detail[#detail + 1] = "NPC-Preis offen." end
            if hit.snapshot then detail[#detail + 1] = "AHledger-Snapshot" end
            detail[#detail + 1] = marketCredit()
            view[#view + 1] = {
                title = string.format("%d × %s   ·   %s", hit.quantity, addon.itemName(id), money(hit.total)),
                detail = string.format("Ziel %s/Stk. · +%s netto%s", money(hit.post), money(hit.profit),
                    hit.vendorKnown and "" or " · NPC-Preis offen"),
                tip = { name = addon.itemName(id), lines = detail },
                caption = caption,
                click = function()
                    addon.buyClick(id)
                    addon.refreshDealUI()
                end,
                onPress = true,
                disabled = pending and pending.phase ~= "quoted" and
                    (pending.phase ~= "singleReady" or not addon.canQuery())
                    or not pending and (addon.isBusy() or not addon.canQuery()),
            }
        else
            -- Keep the original slot until the next search so no other deal moves under the cursor.
            view[#view + 1] = { title = "Treffer abgelaufen", detail = "Suche erneut für frische Angebote." }
        end
    end
    return view
end

local lotStatus = {
    mail = "Unterwegs zum Briefkasten", ready = "Im Beutel", posted = "Im AH", sold = "Verkauft",
}

local function purchaseRows()
    local view = {}
    addon.walkRecentPurchases(math.huge, function(index, round, lot)
        local name = addon.itemName(lot.item)
        local quantity, cost = lot.purchaseQuantity or lot.quantity, lot.purchaseCost or lot.cost
        local average = cost / quantity
        local net = addon.revenue(lot)
        view[index] = {
            title = string.format("%d × %s  ·  %s", quantity, name, money(cost)),
            detail = string.format("Runde %d  ·  %s%s/Stk.  ·  %s", round,
                average % 1 ~= 0 and "~" or "", money(math.floor(average + 0.5)),
                lot.purchaseQuantity and "In Teilmengen verkauft/eingestellt" or lotStatus[lot.status]),
            tip = { name = name, lines = {
                "Gekauft: " .. date("%d.%m. %H:%M", lot.acquired),
                "Menge: " .. quantity .. "  ·  Einkauf gesamt: " .. money(cost),
                lot.purchaseQuantity and "Die einzelnen Auktionen stehen unter Verkäufe."
                    or ("Verkaufspreis: " .. money(lot.listPrice) .. "/Stk.  ·  Nettoerlös: " .. money(net)),
            } },
        }
    end)
    return view
end

local function saleRow(round, index, lot, title, detail)
    local action = state.action
    local pending = action and action.lot == lot and action
    local caption = "Verkauf vorbereiten"
    if state.held[lot] then
        detail = "Halten · Alt+Klick: Verlustvorschau"
        caption = "Erneut prüfen"
    end
    if pending then
        caption = ({
            saleSearch = "Markt wird geprüft …", saleReady = "Einstellen bestätigen",
            posting = "Auktion wird verbucht …", postWarning = "AH-Warnung bestätigen",
        })[pending.phase]
        if pending.price then
            local portion = addon.salePortion(lot, pending.quantity)
            detail = string.format("%d von %d  ·  Einstand %s  ·  Kaution %s", pending.quantity, lot.quantity,
                money(portion.cost + (portion.lostDeposit or 0)), money(pending.deposit))
            if pending.phase == "saleReady" and pending.exit == "loss" then caption = "Verlust bestätigen" end
        end
    end
    local history, tip = displayHistory(lot.item)
    if history or state.held[lot] then
        local threshold = addon.minimumPrice(lot.cost + (lot.lostDeposit or 0), lot.quantity, 0)
        local high = history and history.high30d
        tip = { name = addon.itemName(lot.item), lines = {
            "Kostendeckend ab " .. money(threshold) .. "/Stk. nach AH-Abzug",
            "7-Tage-Median: " .. money(history and history.median7d),
            "30-Tage-Median / Hoch: " .. money(history and history.median30d) .. " / " .. money(high),
            high and (high >= threshold and "Schwelle lag innerhalb der erfassten Preisspanne."
                or "Schwelle lag über dem erfassten 30-Tage-Hoch.") or "Historischer Vergleich fehlt.",
        } }
    end
    return {
        title = title, detail = detail, caption = lot.status == "ready" and caption or nil,
        click = function() addon.sellClick(round, index, IsAltKeyDown and IsAltKeyDown()) end,
        tip = tip,
        disabled = not addon.canQuery() or
            (pending and pending.phase ~= "saleReady" and pending.phase ~= "postWarning") or
            (not pending and addon.isBusy()),
    }
end

local function lotTitle(round, index, lot)
    local status = lot.needsCheck and lot.status == "posted" and "AH-Status prüfen" or lotStatus[lot.status]
    return string.format("R%d.%d  ·  %d × %s  ·  %s", round.id, index, lot.quantity,
        addon.itemName(lot.item), status)
end

local function roundRows(round)
    local view = {}
    for index, lot in ipairs(round.lots) do
        -- Keep held rows in place, but let the next ready lot replace a posted one.
        if round.stage ~= "sell" or lot.status == "ready" then
            local detail = "Einkauf " .. money(lot.cost) .. "  ·  Ziel " .. money(lot.target) .. "/Stk."
            if lot.status == "mail" then
                detail = string.format("%d von %d Stück abgeholt", lot.collected, lot.quantity)
            end
            view[#view + 1] = saleRow(round, index, lot, lotTitle(round, index, lot), detail)
        end
    end
    return view
end

local function stockRows()
    local view = {}
    for _, round in ipairs(addon.rounds()) do
        for index, lot in ipairs(round.lots) do
            if lot.status ~= "sold" then
                local history = displayHistory(lot.item)
                local floorPrice = addon.minimumPrice(lot.cost + (lot.lostDeposit or 0), lot.quantity, 0)
                local detail = "Gewinnschwelle " .. money(floorPrice) .. "/Stk.  ·  Kein Vergleich verfügbar"
                if history then
                    local median, month = history.median7d, history.median30d
                    local assessment = median and "Historisch erreichbar" or "Trend offen"
                    if median and median < floorPrice then assessment = "Aktuell halten oder Ausstieg prüfen" end
                    if history.high30d and history.high30d < floorPrice then assessment = "Über dem 30-Tage-Hoch" end
                    detail = string.format("Schwelle %s  ·  7T %s  ·  30T %s  ·  %s%s",
                        money(floorPrice), money(median), money(month), assessment, history.snapshot and " (Snapshot)" or "")
                end
                if lot.status == "posted" and (lot.confirmedSold or 0) > 0 then
                    detail = detail .. "  ·  " .. lot.confirmedSold .. " verkauft"
                end
                local entry = saleRow(round, index, lot, lotTitle(round, index, lot), detail)
                entry.tip = { name = addon.itemName(lot.item), lines = {
                    "Seit " .. math.floor(math.max(0, GetServerTime() - lot.acquired) / 3600) .. " Stunden im Bestand",
                    "Einkauf " .. money(lot.cost) .. "  ·  Gewinnschwelle " .. money(floorPrice) .. "/Stk.",
                    "Letzter AHledger-Tiefstpreis " .. money(history and history.minBuyout),
                    "30 Tage: Tief " .. money(history and history.low30d) .. " / Hoch " .. money(history and history.high30d),
                    history and history.updated and ("AHledger-Stand " .. date("%d.%m. %H:%M", history.updated)
                        .. (history.snapshot and " (Snapshot)" or "")) or "Datenstand offen",
                    marketCredit(),
                    "Historische Angebotspreise schätzen keine Garantie für künftige Verkäufe.",
                } }
                view[#view + 1] = entry
            end
        end
    end
    return view
end

local function salesRows()
    local entries = {}
    for _, round in ipairs(addon.rounds()) do
        for index, lot in ipairs(round.lots) do
            local sold = lot.confirmedSold or (lot.status == "sold" and lot.quantity or 0)
            local open = lot.status == "posted"
            if (open and saleFilter ~= "sold") or (sold > 0 and saleFilter ~= "open") then
                entries[#entries + 1] = { round = round, index = index, lot = lot, sold = sold,
                    time = lot.soldAt or lot.listedAt or lot.acquired }
            end
        end
    end
    table.sort(entries, function(a, b)
        if a.time ~= b.time then return a.time > b.time end
        if a.round.id ~= b.round.id then return a.round.id > b.round.id end
        return a.index > b.index
    end)
    local view = {}
    for _, sale in ipairs(entries) do
        local lot, sold = sale.lot, sale.sold
        local status = lot.status == "sold" and "Verkauft" or "Offen"
        if lot.needsCheck and lot.status == "posted" then status = "Status offen" end
        local detail = (lot.status == "posted" and (lot.needsCheck and "AH-Status prüfen" or
            (lot.openQuantity or lot.quantity - sold) .. " offen") or (sold .. " verkauft"))
        if sold > 0 then
            local total, actual = addon.revenue(lot)
            if lot.status == "posted" then detail = detail .. "  ·  " .. sold .. " verkauft" end
            detail = detail .. "  ·  " .. (actual and "Netto " or "Netto ≈ ") .. money(total)
        end
        view[#view + 1] = {
            title = string.format("%s  ·  %s/Stk.  ·  %s", addon.itemName(lot.item), money(lot.listPrice), status),
            detail = "R" .. sale.round.id .. "." .. sale.index .. "  ·  " .. detail,
            tip = { name = addon.itemName(lot.item), lines = {
                "Eingestellt: " .. (lot.listedAt and date("%d.%m. %H:%M", lot.listedAt) or "–"),
                "Markt beim Einstellen: " .. money(lot.listMarket) .. "/Stk.",
                "Preisart: " .. (not lot.listMarket and "–" or
                    (lot.listDirect and "Knapp unter Markt" or "Preis für Zwischenhändler")),
            } },
        }
    end
    return view
end

local function scanRows()
    local view = {}
    for _, stats in ipairs(addon.scanSummary()) do
        local rate = stats.replies > 0 and stats.hits * 100 / stats.replies or 0
        local profit = stats.soldLots > 0 and math.floor(stats.profit * 100 / math.max(1, stats.replies) + 0.5)
        local quote = stats.quotes > 0 and math.floor(stats.quoteMillis / stats.quotes + 0.5) .. " ms" or "–"
        local buy = stats.timedBuys > 0 and math.floor(stats.finishedMillis / stats.timedBuys + 0.5) .. " ms" or "–"
        local name = addon.itemName(stats.id)
        view[#view + 1] = {
            title = string.format("%s  ·  %.1f Treffer/100 Antworten", name, rate),
            detail = string.format("%d Antworten  ·  %d Käufe  ·  Gewinn/100: %s",
                stats.replies, stats.bought, money(profit)),
            tip = { name = name, lines = {
                string.format("%d Treffer, %d Preisabfragen, %d Bestätigungen", stats.hits, stats.attempts, stats.confirms),
                string.format("%d Preisänderungen, %d ohne Preis, %d Preisfehler, %d Preis-Timeouts",
                    stats.priceChanged, stats.unavailable, stats.quoteErrors, stats.quoteTimeouts),
                string.format("%d AH-Fehlermeldungen nach Bestätigung, %d abgelehnt, %d unklar",
                    stats.buyErrors, stats.failed, stats.uncertain),
                string.format("Ab 2 Stück: %d bestätigt, %d gekauft, %d AH-Fehler, %d abgelehnt",
                    stats.multiConfirms, stats.multiBought, stats.multiBuyErrors, stats.multiFailed),
                "Ø Serverantwort: Preisabfrage " .. quote .. ", Kauf nach Bestätigung " .. buy,
                string.format("%d Such-Timeouts. Gewinn aus %d vollständig verkauften Positionen.",
                    stats.timeouts, stats.soldLots),
            } },
        }
    end
    return view
end

local function periodStart()
    return periodDays > 0 and GetServerTime() - periodDays * 86400 or nil
end

local function exportView()
    if showExport then return end
    showExport = true
    if #exportPages == 0 then
        local data = addon.exportRounds(periodStart())
        local lines, bytes = {}, 0
        for line in (data .. "\n"):gmatch("([^\n]*\n)") do
            if bytes + #line > 28000 and bytes > 0 then
                exportPages[#exportPages + 1], lines, bytes = table.concat(lines), {}, 0
            end
            lines[#lines + 1], bytes = line, bytes + #line
        end
        exportPages[#exportPages + 1] = table.concat(lines)
    end
    local data = exportPages[exportPage]
    local _, breaks = data:gsub("\n", "")
    exportBox:SetHeight(math.max(310, 15 * (breaks + 1)))
    exportBox:SetText(data)
    scroll:SetVerticalScroll(0)
    exportBox:SetFocus()
    exportBox:HighlightText()
end

local function totals()
    local spent, net = 0, 0
    for _, round in ipairs(addon.rounds()) do
        spent = spent + round.spent
        for _, lot in ipairs(round.lots) do
            net = net + addon.revenue(lot)
        end
    end
    return spent, net
end

local function action(control, caption, click, ready, pulse)
    control:SetText(caption)
    control:SetScript("OnClick", click)
    enabled(control, ready)
    control:SetAlpha(pulse and (0.80 + 0.20 * math.abs(math.sin(GetTime() * 5))) or 1)
    if pulse then control:LockHighlight() else control:UnlockHighlight() end
    control:Show()
end

local function searchAction(choosing)
    local scan = state.sweep
    local ready = addon.canQuery() and not addon.isBusy() and not (scan and (scan.waiting or scan.paused))
        and not state.catalogScan and addon.selectedCount() > 0
    local caption = choosing and "Suchen" or "Erneut suchen"
    if not state.ah then
        caption = "Zum Auktionshaus"
    elseif scan and scan.waiting then
        caption = string.format("Suche %d/%d …", scan.index, #scan.ids)
    elseif not addon.canQuery() and not addon.isBusy() then
        caption = "AH wartet …"
    elseif scan then
        caption = string.format("Nächstes Item %d/%d", scan.index + 1, #scan.ids)
    end
    return {
        title = addon.selectedCount() .. " Items ausgewählt",
        detail = choosing and "Items auswählen und Suche starten." or "Hier bekommt der nächste Treffer seinen Kaufbutton.",
        caption = caption, disabled = not ready, pulse = ready,
        onPress = true,
        click = function()
            page = 1
            addon.startSweep()
        end,
    }
end

local function drawControls(flow, watching, round)
    listLayout(watching)
    for tab, control in pairs(tabs) do
        if state.tab == tab then control:LockHighlight() else control:UnlockHighlight() end
    end
    for _, control in ipairs({ watchSearch, minimumLabel, minimum, customItem, customButton, selectAll, selectNone,
        selectLast, catalog, category }) do
        control:SetShown(watching)
    end
    for index, period in ipairs(periods) do
        period:SetShown(state.tab == "balance")
        if periodDays == periodOptions[index] then period:LockHighlight() else period:UnlockHighlight() end
    end
    searchHint:SetShown(watching and watchSearch:GetText() == "" and not watchSearch:HasFocus())
    customHint:SetShown(watching and customItem:GetText() == "" and not customItem:HasFocus())
    if watching and not minimum:HasFocus() then minimum:SetText(tostring(addon.dailyMinimum())) end
    local shopping = round and (round.stage == "select" or round.stage == "buy")
    if not flow and budgetMode then budgetMode = nil; budgetInput:ClearFocus() end
    settings:SetShown(flow)
    items:SetShown(flow and (shopping or budgetMode ~= nil))
    enabled(settings, not addon.isBusy())
    if flow then
        settings:SetText(shopping and "Budget ändern" or "Neue Runde")
        settings:SetScript("OnClick", function() openBudget(shopping and "edit" or "new") end)
        action(items, budgetMode and "Abbrechen" or "Items ändern", function()
            if budgetMode then
                budgetMode = nil
                budgetInput:ClearFocus()
            else
                switchTab("watch")
            end
        end, budgetMode ~= nil or (shopping and not addon.isBusy()))
        items:SetShown(shopping or budgetMode ~= nil)
    end
    local editing = flow and budgetMode ~= nil
    budgetInput:SetShown(editing)
    budgetLabel:SetShown(editing)
    budgetSave:SetShown(editing)
    budgetSave:SetText(budgetMode == "new" and "Runde anlegen" or "Speichern")
    enabled(budgetSave, not addon.isBusy())
    local showSearchControls = flow and shopping and not editing
    sound:SetShown(showSearchControls)
    strategyButton:SetShown(showSearchControls)
    volumeButton:SetShown(showSearchControls)
    notice:SetWidth(frame:GetWidth() - rail - (showSearchControls and 218 or 36))
    if showSearchControls then
        local strategy, minutes = addon.strategy()
        strategyButton:SetText(strategy == "direct" and "Direktverkauf" or "Zwischenhändler")
        volumeButton:SetText("Limit: " .. (minutes >= 60 and minutes / 60 .. " Std." or minutes .. " Min."))
        enabled(strategyButton, not addon.isBusy())
        enabled(volumeButton, not addon.isBusy())
        sound:SetText(addon.hitSoundEnabled() and "Ton: an" or "Ton: aus")
    end
    stageLine:SetWidth(frame:GetWidth() - rail - (flow and shopping and 312 or 40))
    for index, filter in ipairs(filters) do
        filter:SetShown(state.tab == "sales")
        local selected = saleFilter == ({ "all", "open", "sold" })[index]
        if selected then filter:LockHighlight() else filter:UnlockHighlight() end
    end
    scroll:SetShown(state.tab == "export")
    place(notice, rail + 19, watching and -76 or -101)
    if state.tab ~= "export" then showExport = false end
    return editing
end

local function draw()
    local round = state.round
    local view, primaryVisible, finishVisible = {}, false, false
    local message = state.notice
    local search
    local flow = state.tab == "flow"
    local watching = state.tab == "watch"
    local editing = drawControls(flow, watching, round)
    showTradeHistory(flow and round and (round.stage == "buy" or round.stage == "select"))
    if watching then
        local matching, all
        view, matching, all = selectionRows()
        stageLine:SetText("Watchlist")
        contextLine:SetText(addon.selectedCount() .. " markiert  ·  " .. #matching .. " im aktuellen Filter scanbar")
        primaryVisible = true
        action(primary, "Zur Handelsrunde", function() switchTab("flow") end, not addon.isBusy())
        message = watchError or message
        selectAll:SetText((watchClass or watchSearch:GetText() ~= "") and "Treffer markieren" or "Alle markieren")
        selectAll:SetScript("OnClick", function() addon.setSelection(matching, "add"); watchError, watchView = nil, nil end)
        selectNone:SetScript("OnClick", function() addon.setSelection(all, "clear"); watchError, watchView = nil, nil end)
        catalog:SetText(state.catalogScan and state.catalogScan.more and "Nächste AH-Seite" or "AH-Katalog laden")
        enabled(catalog, addon.canBrowseCatalog())
        enabled(selectAll, #matching > 0 and not addon.isBusy())
        enabled(selectNone, addon.selectedCount() > 0 and not addon.isBusy())
        enabled(selectLast, not addon.isBusy())
    elseif state.tab == "purchases" then
        view = purchaseRows()
        local spent = totals()
        stageLine:SetText("Käufe")
        contextLine:SetText(#view .. " Positionen  ·  " .. money(spent) .. " ausgegeben")
        message = #view == 0 and "Noch keine bestätigten Käufe." or "Neueste zuerst  ·  Details beim Darüberfahren"
    elseif state.tab == "stock" or state.tab == "export" then
        local spent, net = totals()
        stageLine:SetText(state.tab == "stock" and "Offener Bestand nach Runde" or "Handelsdaten exportieren")
        contextLine:SetText("Ausgegeben " .. money(spent) .. "  ·  Rundenerlös netto " .. money(net)
            .. "  ·  Eingegangene AH-Post " .. money(addon.payoutTotal()))
        if state.tab == "stock" then
            view = stockRows()
            primaryVisible = true
            action(primary, "Auktionen prüfen", addon.queryOwned, addon.canQuery() and not addon.isBusy() and not state.sweep)
            message = message or (#view == 0 and "Kein offener Bestand." or "Ältere Käufe bleiben hier verfügbar.")
        else
            exportView()
            message = "Strg+C kopiert Teil " .. exportPage .. " von " .. #exportPages .. ". Export erneut anklicken zum Aktualisieren."
        end
    elseif state.tab == "sales" then
        view = salesRows()
        stageLine:SetText("Verkäufe")
        contextLine:SetText(#view .. " Positionen  ·  Preis je Stück  ·  Netto nach Provision")
        primaryVisible = true
        action(primary, "Auktionen prüfen", addon.queryOwned, addon.canQuery() and not addon.isBusy() and not state.sweep)
        if #view == 0 then message = "Für diesen Filter gibt es noch keine Verkäufe." end
    elseif state.tab == "balance" then
        local since = periodStart()
        local spent, net, balance, lost, undated = addon.balance(since)
        stageLine:SetText("Handelsbilanz")
        view = {
            { title = "Ausgegeben   " .. money(spent), detail = "Bestätigte Käufe im Zeitraum" },
            { title = "Eingenommen   " .. money(net), detail = "Nettoerlös bestätigter Verkäufe · Beleg oder Schätzung" },
            { title = "Bilanz   " .. money(balance), detail = "Erlös abzüglich Käufe und verlorener Kautionen (" .. money(lost) .. ")" },
        }
        message = undated ~= 0 and ("Älterer Erlös ohne Datum: " .. money(undated) .. " · unter Gesamt enthalten.")
            or "Verkäufe zählen ab dem Tag, an dem ForeverFlip sie erkannt hat."
    elseif state.tab == "stats" then
        view = scanRows()
        stageLine:SetText("Scan-Auswertung")
        contextLine:SetText("Treffer und Netto-Gewinn je 100 beantwortete AH-Abfragen")
        message = #view == 0 and "Die Messung startet mit der nächsten Suche." or "Maus über eine Zeile für Kaufzeiten und Fehler."
    elseif not round then
        stageLine:SetText("Neue Handelsrunde")
        contextLine:SetText("Budget festlegen und Items auswählen.")
    else
        stageLine:SetText("Runde " .. round.id .. "   ·   " .. (stage[round.stage] or stage.done))
        contextLine:SetText("Restbudget " .. money(addon.remaining()) .. " von " .. money(round.budget))
        if round.stage == "select" or round.stage == "buy" then
            local choosing = round.stage == "select"
            view = choosing and {} or hitRows()
            search = searchAction(choosing)
            if state.sweep and state.sweep.paused then
                primaryVisible = true
                action(primary, "Treffer überspringen", addon.skipHit, not addon.isBusy())
                message = message or "Treffer gefunden. Suche pausiert."
            end
            if choosing then
                contextLine:SetText("Budget " .. money(round.budget) .. "  ·  " .. addon.selectedCount() .. " ausgewählt")
                message = message or (addon.selectedCount() == 0 and "Wähle die Items in der Watchlist." or nil)
            elseif #round.lots > 0 then
                finishVisible = true
                local reminder = GetServerTime() - round.firstBuy >= 300
                action(finish, reminder and "Zum Briefkasten?" or "Einkauf fertig", function()
                    page = 1
                    addon.endShopping()
                end, not addon.isBusy(), reminder and not addon.isBusy())
            end
        else
            view = roundRows(round)
            if round.stage == "mail" then
                message = message or (addon.mailLeft(round) .. " Stück fehlen. Hole die AH-Post im Briefkasten ab.")
            elseif state.ah and round.stage == "sell" then
                stageLine:SetText("Runde " .. round.id .. "   ·   Ware einstellen")
                local ready = false
                for _, lot in ipairs(round.lots) do
                    if lot.status == "ready" then ready = true end
                end
                if not ready then stageLine:SetText("Runde " .. round.id .. "   ·   Ware eingestellt") end
                message = message or "Weitere Käufe über „Neue Runde“."
            end
        end
    end
    local quote = state.action and state.action.lot and state.action.price and state.action
    saleQuantity:SetShown(quote and quote.phase == "saleReady" and quote.lot.quantity > 5 and not quote.lot.itemKey or false)
    if quote then saleQuantity:SetText("Menge: " .. quote.quantity) end
    marketPriceLine:SetShown(quote ~= nil and quote ~= false)
    yourPriceLine:SetShown(quote ~= nil and quote ~= false)
    contextLine:SetShown(not quote and not editing and state.tab ~= "balance")
    if quote then
        stageLine:SetText(addon.itemName(quote.lot.item) .. " verkaufen")
        settings:Hide()
        items:Hide()
        marketPriceLine:SetText("Markt: " .. money(quote.marketLowest) .. "/Stk.")
        yourPriceLine:SetText("Dein Preis: " .. money(quote.price) .. "/Stk.")
        yourPriceLine:SetTextColor(0.50, 1, 0.78)
        message = quote.direct and "Gewählt: Knapp unter Markt" or "Gewählt: Preis für Zwischenhändler"
        if quote.lot.directBuy and quote.direct and quote.marketPriceOnly then
            message = "Direktverkauf mit 2 % Preispuffer."
        end
        if quote.direct and not quote.marketPriceOnly then
            message = message .. "  ·  Händlermarge zu klein"
        end
        if quote.exit then
            local _, profit = addon.purchaseResult(addon.salePortion(quote.lot, quote.quantity), quote.price)
            message = (profit < 0 and "Verlustvorschau" or "Kostendeckender Ausstieg")
                .. " · " .. quote.quantity .. " Stück · Ergebnis nach AH-Abzug: " .. money(profit)
        end
        if quote.phase == "saleReady" and not quote.exit and (not quote.direct or quote.marketPriceOnly) then
            finishVisible = true
            action(finish, quote.marketPriceOnly and "Händlerpreis" or "Knapp unter Markt",
                addon.toggleSalePrice, true)
        end
    end
    notice:Show()
    notice:SetText(message or "")
    note:SetText(marketCredit())
    finish:SetShown(finishVisible)
    local multiPart = state.tab == "export" and #exportPages > 1
    exportPrevious:SetShown(multiPart)
    exportNext:SetShown(multiPart)
    enabled(exportPrevious, exportPage > 1)
    enabled(exportNext, exportPage < #exportPages)
    local selling = flow and round and round.stage == "sell"
    local lastOffset = math.max(1, selling and #view or #view - pageSize + 1)
    page = search and 1 or math.min(page, lastOffset)
    listBar:SetShown(not search and lastOffset > 1)
    listBar:SetMinMaxValues(1, lastOffset)
    if listBar:GetValue() ~= page then listBar:SetValue(page) end
    primary:SetShown(primaryVisible)
    pageLine:SetText(lastOffset > 1 and (page .. "–" .. math.min(#view, page + pageSize - 1) .. " / " .. #view) or "")
    for index, row in ipairs(rows) do
        local entry
        if index <= pageSize then entry = view[page + index - 1] end
        if index == 1 and search and (not entry or not entry.caption) then entry = search end
        row.bg:SetShown(entry ~= nil)
        row.hover.tip = entry and entry.tip
        row.hover:SetShown(row.hover.tip ~= nil)
        row.title:SetText(entry and entry.title or "")
        row.detail:SetText(entry and entry.detail or "")
        row.button:SetShown(entry and entry.caption ~= nil or false)
        if entry and entry.caption then
            local clickPhase = entry.onPress and "LeftButtonDown" or "LeftButtonUp"
            if row.clickPhase ~= clickPhase then
                row.button:RegisterForClicks(clickPhase)
                row.clickPhase = clickPhase
            end
            action(row.button, entry.caption, entry.click, not entry.disabled, entry.pulse)
        end
    end
end

local restoredSize
function addon.showPanel()
    if not restoredSize then
        restoredSize = true
        local saved = ForeverFlipRounds
        if saved and tonumber(saved.windowWidth) and tonumber(saved.windowHeight) then
            frame:SetSize(math.max(704, math.min(1040, tonumber(saved.windowWidth))),
                math.max(438, math.min(780, tonumber(saved.windowHeight))))
        end
    end
    draw()
    frame:Show()
end

function addon.refreshDealUI()
    if frame:IsShown() and state.tab == "flow" then draw() end
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
    local time = GetTime()
    if time < nextDraw then return end
    nextDraw = time + 0.12
    addon.tick()
    if frame:IsShown() then draw() end
end)
