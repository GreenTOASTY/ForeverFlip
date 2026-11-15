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
    if tab ~= "flow" then addon.stopLive() end
    if tab == "watch" then addon.editSelection() end
    state.copyItem = nil
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
    addon.stopLive()
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
local live = button(0, -98, 87, "Live: aus", addon.toggleLive)
local sound = button(0, -98, 80, "Ton: an", addon.toggleHitSound)
frame:SetScript("OnHide", addon.stopLive)

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
local copyItem = input(235)
copyItem:SetScript("OnEscapePressed", function(self) self:ClearFocus(); state.copyItem = nil end)
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
    place(budgetLabel, width - 270, -84)
    place(budgetInput, width - 224, -78)
    place(budgetSave, width - 143, -77)
    place(live, width - 192, -98)
    place(sound, width - 100, -98)
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
    place(copyItem, x, -92)
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
            caption = ({ quote = "Preis wird geprüft …", quoted = "Kauf bestätigen", buying = "Kauf wird verbucht …" })[pending.phase]
        end
        if hit or (pending and state.hits[id]) then
            hit = hit or state.hits[id]
            if hit.single then caption = "Name für AH kopieren" end
            view[#view + 1] = {
                title = string.format("%d × %s   ·   %s", hit.quantity, addon.itemName(id), money(hit.total)),
                detail = string.format("Bis %s/Stk.  ·  Ziel %s/Stk.%s%s", money(hit.maxUnit), money(hit.post),
                    hit.vendorKnown and "" or "  ·  NPC-Preis offen", (hit.single and "  ·  WoW-AH" or "")
                        .. (hit.snapshot and "  ·  Snapshot" or "")),
                caption = caption,
                click = function()
                    if hit.single then
                        addon.updateHit(hit.logID, "native_ah_handoff")
                        state.copyItem = id
                        copyItem:Show()
                        copyItem:SetText(addon.itemName(id))
                        copyItem:SetFocus()
                        copyItem:HighlightText()
                    else
                        addon.buyClick(id)
                    end
                    addon.refreshDealUI()
                end,
                onPress = not hit.single,
                disabled = pending and pending.phase ~= "quoted" or not pending and (addon.isBusy() or not addon.canQuery()),
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
        local average = lot.cost / lot.quantity
        local net = addon.revenue(lot)
        view[index] = {
            title = string.format("%d × %s  ·  %s", lot.quantity, name, money(lot.cost)),
            detail = string.format("Runde %d  ·  %s%s/Stk.  ·  %s", round,
                average % 1 ~= 0 and "~" or "", money(math.floor(average + 0.5)), lotStatus[lot.status]),
            tip = { name = name, lines = {
                "Gekauft: " .. date("%d.%m. %H:%M", lot.acquired),
                "Menge: " .. lot.quantity .. "  ·  Einkauf gesamt: " .. money(lot.cost),
                "Verkaufspreis: " .. money(lot.listPrice) .. "/Stk.  ·  Nettoerlös: " .. money(net),
            } },
        }
    end)
    return view
end

local function saleRow(round, index, lot, title, detail)
    local action = state.action
    local pending = action and action.lot == lot and action
    local caption = "Verkauf vorbereiten"
    if state.held[lot] then detail = "Halten – kein profitabler Preis. " .. detail end
    if pending then
        caption = ({
            saleSearch = "Markt wird geprüft …", saleReady = "Einstellen bestätigen",
            posting = "Auktion wird verbucht …", postWarning = "AH-Warnung bestätigen",
        })[pending.phase]
        if pending.price then
            detail = string.format("%d Stück  ·  Kaution %s", lot.quantity, money(pending.deposit))
        end
    end
    return {
        title = title, detail = detail, caption = lot.status == "ready" and caption or nil,
        click = function() addon.sellClick(round, index) end,
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
        local detail = "Einkauf " .. money(lot.cost) .. "  ·  Ziel " .. money(lot.target) .. "/Stk."
        if lot.status == "mail" then
            detail = string.format("%d von %d Stück abgeholt", lot.collected, lot.quantity)
        end
        view[#view + 1] = saleRow(round, index, lot, lotTitle(round, index, lot), detail)
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
    local ready = addon.canQuery() and not addon.isBusy() and not state.sweep
        and not state.live and not state.catalogScan and addon.selectedCount() > 0
    local caption = choosing and "Suchen" or "Erneut suchen"
    if not state.ah then
        caption = "Zum Auktionshaus"
    elseif state.sweep then
        caption = string.format("Suche %d/%d …", state.sweep.index, #state.sweep.ids)
    elseif state.live then
        local left = math.max(0, math.ceil((state.liveNext or GetTime()) - GetTime()))
        caption = left > 0 and ("Live in " .. left .. " s") or "Live wartet auf AH …"
    elseif not addon.canQuery() and not addon.isBusy() then
        caption = "AH wartet …"
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

local function draw()
    local round = state.round
    local view, primaryVisible, finishVisible = {}, false, false
    local message = state.notice
    local search
    local flow = state.tab == "flow"
    local watching = state.tab == "watch"
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
    if state.copyItem and not addon.freshHit(state.copyItem) then
        state.copyItem = nil
        copyItem:ClearFocus()
    end
    copyItem:SetShown(flow and state.copyItem ~= nil)
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
    live:SetShown(showSearchControls)
    sound:SetShown(showSearchControls)
    notice:SetWidth(frame:GetWidth() - rail - (showSearchControls and 218 or 36))
    if showSearchControls then
        live:SetText(state.live and "Live: an" or "Live: aus")
        sound:SetText(addon.hitSoundEnabled() and "Ton: an" or "Ton: aus")
        enabled(live, state.ah and not state.catalogScan and not addon.isBusy() and addon.selectedCount() > 0)
        if state.live then live:LockHighlight() else live:UnlockHighlight() end
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
        if quote.direct and not quote.marketPriceOnly then
            message = message .. "  ·  Händlermarge zu klein"
        end
        if quote.phase == "saleReady" and (not quote.direct or quote.marketPriceOnly) then
            finishVisible = true
            action(finish, quote.marketPriceOnly and "Händlerpreis" or "Knapp unter Markt",
                addon.toggleSalePrice, true)
        end
    end
    if state.copyItem then message = "Name mit Strg+C kopieren und im WoW-AH suchen." end
    notice:SetShown(not state.copyItem)
    notice:SetText(message or "")
    note:SetText(state.copyItem and "Strg+C kopiert den Namen · Einkauf erfolgt im WoW-AH." or marketCredit())
    finish:SetShown(finishVisible)
    local multiPart = state.tab == "export" and #exportPages > 1
    exportPrevious:SetShown(multiPart)
    exportNext:SetShown(multiPart)
    enabled(exportPrevious, exportPage > 1)
    enabled(exportNext, exportPage < #exportPages)
    local lastOffset = math.max(1, #view - pageSize + 1)
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
