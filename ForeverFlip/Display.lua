local _, addon = ...
local state = addon.state
local page, pageSize, maxRows = 1, 4, 10
local saleFilter = "all"
local nextDraw = 0
local showExport = false
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
    if value >= 10000 then
        return string.format("%dg %02ds %02dk", math.floor(value / 10000), math.floor(value / 100) % 100, value % 100)
    end
    if value >= 100 then return string.format("%ds %02dk", math.floor(value / 100), value % 100) end
    return string.format("%dk", value)
end

local frame = CreateFrame("Frame", "ForeverFlipPanel", UIParent, "BackdropTemplate")
frame:SetSize(640, 480)
frame:SetResizable(true)
frame:SetResizeBounds(560, 420, 1040, 780)
frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -28, -140)
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
})
frame:SetBackdropColor(0.055, 0.073, 0.095, 0.98)
frame:SetBackdropBorderColor(0.25, 0.38, 0.47, 1)
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

local function button(x, y, width, caption, script)
    local control = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    control:SetPoint("TOPLEFT", x, y)
    control:SetSize(width, 24)
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
    state.tab, page, showExport = tab, 1, false
end

line(16, -15, 190, "GameFontNormalLarge"):SetText("ForeverFlip")
local stageLine = line(18, -56, 640, "GameFontHighlightLarge")
local contextLine = line(18, -83, 400, "GameFontHighlight")
local notice = line(18, -105, 640, "GameFontNormalSmall")
local marketPriceLine = line(18, -84, 270, "GameFontHighlightLarge")
local yourPriceLine = line(300, -84, 354, "GameFontHighlightLarge")
local note = line(18, -533, 640, "GameFontDisableSmall")
local pageLine = line(304, -405, 100, "GameFontHighlightSmall")
local tabs = {
    button(280, -12, 77, "Runde", function() switchTab("flow") end),
    button(362, -12, 84, "Bestand", function() switchTab("stock") end),
    button(451, -12, 100, "Verkäufe", function() switchTab("sales") end),
    button(556, -12, 84, "Export", function() switchTab("export") end),
}

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)
local primary = button(17, -397, 162, "", function() end)
local finish = button(184, -397, 116, "", function() end)
local prev = button(433, -397, 105, "Zurück", function()
    if not state.action then page = math.max(1, page - 1) end
end)
local forward = button(543, -397, 118, "Weiter", function()
    if not state.action then page = page + 1 end
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

local separator = frame:CreateTexture(nil, "BACKGROUND")
separator:SetPoint("TOPLEFT", 17, -428)
separator:SetSize(644, 1)
separator:SetColorTexture(0.25, 0.38, 0.47, 0.75)
local recentTitle = line(18, -438, 640, "GameFontNormal")
recentTitle:SetText("Letzte Käufe")
local purchases = {}
for index = 1, 4 do
    purchases[index] = line(18, -455 - (index - 1) * 17, 640, "GameFontHighlightSmall")
end

local function showRecentPurchases()
    local count = addon.walkRecentPurchases(#purchases, function(index, round, lot)
        local average = lot.cost / lot.quantity
        purchases[index]:SetText(string.format("R%d   ·   %d × %s   ·   %s gesamt   ·   %s%s/Stk.",
            round, lot.quantity, addon.itemName(lot.item), money(lot.cost),
            average % 1 ~= 0 and "~" or "", money(math.floor(average + 0.5))))
    end)
    for index = count + 1, #purchases do purchases[index]:SetText("") end
    if count == 0 then purchases[1]:SetText("Noch kein bestätigter Kauf.") end
end

local rows = {}
for index = 1, maxRows do
    local y = -132 - (index - 1) * 42
    local accent = frame:CreateTexture(nil, "BACKGROUND")
    accent:SetPoint("TOPLEFT", 14, y + 3)
    accent:SetSize(652, 39)
    accent:SetColorTexture(0.13, 0.20, 0.27, index % 2 == 1 and 0.48 or 0.27)
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
    pageSize = math.max(2, math.min(maxRows, math.floor((height - 294) / 42)))
    for _, widget in ipairs({ stageLine, notice, note, recentTitle }) do widget:SetWidth(width - 36) end
    contextLine:SetWidth(width - 36)
    marketPriceLine:SetWidth(math.floor(width * 0.43) - 22)
    place(yourPriceLine, math.floor(width * 0.43), -84)
    yourPriceLine:SetWidth(math.ceil(width * 0.57) - 18)
    place(tabs[1], width - 400, -12)
    place(tabs[2], width - 318, -12)
    place(tabs[3], width - 229, -12)
    place(tabs[4], width - 124, -12)
    for index, filter in ipairs(filters) do place(filter, width - 245 + (index - 1) * 76, -49) end
    place(settings, width - 263, -49)
    place(items, width - 141, -49)
    place(budgetLabel, width - 270, -84)
    place(budgetInput, width - 224, -78)
    place(budgetSave, width - 143, -77)
    place(live, width - 192, -98)
    place(sound, width - 100, -98)
    place(primary, 17, 157 - height)
    place(finish, 184, 157 - height)
    place(prev, width - 217, 157 - height)
    place(forward, width - 108, 157 - height)
    forward:SetWidth(89)
    place(pageLine, width - 271, 149 - height)
    pageLine:SetWidth(49)
    place(separator, 17, 126 - height)
    separator:SetWidth(width - 36)
    place(recentTitle, 18, 116 - height)
    for index, purchase in ipairs(purchases) do
        place(purchase, 18, 99 - height - (index - 1) * 17)
        purchase:SetWidth(width - 36)
    end
    place(note, 18, 21 - height)
    for index, row in ipairs(rows) do
        row.bg:SetWidth(width - 28)
        row.hover:SetWidth(width - 232)
        row.title:SetWidth(width - 234)
        row.detail:SetWidth(width - 234)
        place(row.button, width - 212, -137 - (index - 1) * 42)
    end
    scroll:SetSize(width - 60, height - 319)
    exportBox:SetWidth(width - 72)
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
    local available = {}
    for id in pairs(addon.items) do
        local market = displayHistory(id)
        if market and type(market.soldPerDay) == "number" and market.soldPerDay >= addon.minimumDailySales then
            available[#available + 1] = { id = id, sales = market.soldPerDay, snapshot = market.snapshot }
        end
    end
    table.sort(available, function(a, b)
        return a.sales == b.sales and a.id < b.id or a.sales > b.sales
    end)
    local view = {}
    for _, item in ipairs(available) do
        local id = item.id
        view[#view + 1] = {
            title = (addon.selected(id) and "✓  " or "") .. addon.itemName(id),
            detail = string.format("~%d Stück pro Tag im gesamten AH%s",
                item.sales, item.snapshot and "  ·  AHledger-Snapshot" or ""),
            caption = addon.selected(id) and "Abwählen" or "Auswählen",
            click = function() addon.toggleItem(id) end,
        }
    end
    return view
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
            view[#view + 1] = {
                title = string.format("%d × %s   ·   %s", hit.quantity, addon.itemName(id), money(hit.total)),
                detail = string.format("Bis %s/Stk.  ·  Ziel %s/Stk.%s%s", money(hit.maxUnit), money(hit.post),
                    hit.vendorKnown and "" or "  ·  NPC-Preis offen", hit.snapshot and "  ·  Snapshot" or ""),
                caption = caption,
                click = function() addon.buyClick(id) end,
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

local function exportView()
    if showExport then return end
    showExport = true
    local data = addon.exportRounds()
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
        and not state.live and addon.selectedCount() > 0
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
    local search, reserveSearchRow
    local flow = state.tab == "flow"
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
                addon.editSelection()
                page = 1
            end
        end, budgetMode ~= nil or (round and round.stage == "buy" and not addon.isBusy()))
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
    notice:SetWidth(frame:GetWidth() - (showSearchControls and 218 or 36))
    if showSearchControls then
        live:SetText(state.live and "Live: an" or "Live: aus")
        sound:SetText(addon.hitSoundEnabled() and "Ton: an" or "Ton: aus")
        enabled(live, state.ah and not addon.isBusy() and addon.selectedCount() > 0)
        if state.live then live:LockHighlight() else live:UnlockHighlight() end
    end
    for index, filter in ipairs(filters) do
        filter:SetShown(state.tab == "sales")
        local selected = saleFilter == ({ "all", "open", "sold" })[index]
        if selected then filter:LockHighlight() else filter:UnlockHighlight() end
    end
    scroll:SetShown(state.tab == "export")
    if state.tab ~= "export" then showExport = false end
    if state.tab == "stock" or state.tab == "export" then
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
            message = message or "Strg+C kopiert die markierten Daten. Export erneut anklicken zum Aktualisieren."
        end
    elseif state.tab == "sales" then
        view = salesRows()
        stageLine:SetText("Verkäufe")
        contextLine:SetText(#view .. " Positionen  ·  Preis je Stück  ·  Netto nach Provision")
        primaryVisible = true
        action(primary, "Auktionen prüfen", addon.queryOwned, addon.canQuery() and not addon.isBusy() and not state.sweep)
        if #view == 0 then message = "Für diesen Filter gibt es noch keine Verkäufe." end
    elseif not round then
        stageLine:SetText("Neue Handelsrunde")
        contextLine:SetText("Budget festlegen und Items auswählen.")
    else
        stageLine:SetText("Runde " .. round.id .. "   ·   " .. (stage[round.stage] or stage.done))
        contextLine:SetText("Restbudget " .. money(addon.remaining()) .. " von " .. money(round.budget))
        if round.stage == "select" or round.stage == "buy" then
            local choosing = round.stage == "select"
            view = choosing and selectionRows() or hitRows()
            search, reserveSearchRow = searchAction(choosing), choosing
            if state.sweep and state.sweep.paused then
                primaryVisible = true
                action(primary, "Treffer überspringen", addon.skipHit, not addon.isBusy())
                message = message or "Treffer gefunden. Suche pausiert."
            end
            if choosing then
                contextLine:SetText("Budget " .. money(round.budget) .. "  ·  " .. addon.selectedCount() .. " ausgewählt")
                message = message or (#view == 0 and "AHledger liefert aktuell keine passenden Absatzdaten." or nil)
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
    contextLine:SetShown(not quote and not editing)
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
    showRecentPurchases()
    notice:SetText(message or "")
    note:SetText(marketCredit())
    finish:SetShown(finishVisible)
    local entriesPerPage = reserveSearchRow and pageSize - 1 or pageSize
    local pages = math.max(1, math.ceil(#view / entriesPerPage))
    page = math.min(page, pages)
    local first = view[(page - 1) * entriesPerPage + 1]
    if search and not reserveSearchRow and first and first.caption and not search.disabled then
        primaryVisible = true
        action(primary, search.caption, search.click, true)
    end
    primary:SetShown(primaryVisible)
    pageLine:SetText(pages > 1 and (page .. " / " .. pages) or "")
    prev:SetShown(pages > 1)
    forward:SetShown(pages > 1)
    enabled(prev, page > 1 and not state.action)
    enabled(forward, page < pages and not state.action)
    for index, row in ipairs(rows) do
        local offset = (page - 1) * entriesPerPage
        local entry
        if index <= pageSize then
            entry = reserveSearchRow and view[offset + index - 1] or view[offset + index]
        end
        if index == 1 and search and (reserveSearchRow or not entry or not entry.caption) then entry = search end
        row.bg:SetShown(entry ~= nil)
        row.hover.tip = entry and entry.tip
        row.hover:SetShown(row.hover.tip ~= nil)
        row.title:SetText(entry and entry.title or "")
        row.detail:SetText(entry and entry.detail or "")
        row.button:SetShown(entry and entry.caption ~= nil or false)
        if entry and entry.caption then action(row.button, entry.caption, entry.click, not entry.disabled, entry.pulse) end
    end
end

local restoredSize
function addon.showPanel()
    if not restoredSize then
        restoredSize = true
        local saved = ForeverFlipRounds
        if saved and tonumber(saved.windowWidth) and tonumber(saved.windowHeight) then
            frame:SetSize(math.max(560, math.min(1040, tonumber(saved.windowWidth))),
                math.max(420, math.min(780, tonumber(saved.windowHeight))))
        end
    end
    draw()
    frame:Show()
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
    local time = GetTime()
    if time < nextDraw then return end
    nextDraw = time + 0.12
    addon.tick()
    if frame:IsShown() then draw() end
end)
