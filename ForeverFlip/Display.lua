local _, addon = ...
local state = addon.state
local page, pageSize = 1, 8
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
    if type(value) ~= "number" then return "-" end
    if value >= 10000 then
        return string.format("%dg %02ds %02dk", math.floor(value / 10000), math.floor(value / 100) % 100, value % 100)
    end
    if value >= 100 then return string.format("%ds %02dk", math.floor(value / 100), value % 100) end
    return string.format("%dk", value)
end

local frame = CreateFrame("Frame", "ForeverFlipPanel", UIParent, "BackdropTemplate")
frame:SetSize(680, 545)
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
    state.tab, page, showExport = tab, 1, false
end

line(16, -15, 190, "GameFontNormalLarge"):SetText("ForeverFlip")
local stageLine = line(18, -56, 640, "GameFontHighlightLarge")
local contextLine = line(18, -83, 640, "GameFontHighlight")
local notice = line(18, -105, 640, "GameFontNormalSmall")
local note = line(18, -519, 640, "GameFontDisableSmall")
local pageLine = line(304, -489, 100, "GameFontHighlightSmall")
button(356, -12, 91, "Runde", function() switchTab("flow") end)
button(451, -12, 94, "Bestand", function() switchTab("stock") end)
button(549, -12, 91, "Export", function() switchTab("export") end)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)
local primary = button(17, -481, 162, "", function() end)
local finish = button(184, -481, 116, "", function() end)
local prev = button(433, -481, 105, "Zur�ck", function()
    if not state.action then page = math.max(1, page - 1) end
end)
local forward = button(543, -481, 118, "Weiter", function()
    if not state.action then page = page + 1 end
end)

local rows = {}
for index = 1, pageSize do
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
scroll:SetSize(620, 316)
local exportBox = CreateFrame("EditBox", nil, scroll)
exportBox:SetSize(608, 312)
exportBox:SetFontObject(GameFontHighlightSmall)
exportBox:SetMultiLine(true)
exportBox:SetAutoFocus(false)
exportBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
scroll:SetScrollChild(exportBox)
scroll:Hide()

local stage = {
    select = "Items f�r die Runde ausw�hlen",
    buy = "Treffer kaufen",
    mail = "Zum Briefkasten - K�ufe abholen",
    sell = "Zur�ck zum AH - Ware einstellen",
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
            title = (addon.selected(id) and "V  " or "") .. addon.itemName(id),
            detail = string.format("~%d St�ck pro Tag im gesamten AH%s",
                item.sales, item.snapshot and "  �  AHledger-Snapshot" or ""),
            caption = addon.selected(id) and "Abw�hlen" or "Ausw�hlen",
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
        local caption = "Kauf pr�fen"
        if pending then
            caption = ({ quote = "Preis wird gepr�ft .", quoted = "Kauf best�tigen", buying = "Kauf wird verbucht ." })[pending.phase]
        end
        if hit or (pending and state.hits[id]) then
            hit = hit or state.hits[id]
            view[#view + 1] = {
                title = string.format("%d � %s   �   %s", hit.quantity, addon.itemName(id), money(hit.total)),
                detail = string.format("Bis %s/Stk.  �  Ziel %s/Stk.%s%s", money(hit.maxUnit), money(hit.post),
                    hit.vendorKnown and "" or "  �  NPC-Preis offen", hit.snapshot and "  �  Snapshot" or ""),
                caption = caption,
                click = function() addon.buyClick(id) end,
                disabled = pending and pending.phase ~= "quoted" or not pending and (addon.isBusy() or not addon.canQuery()),
            }
        else
            -- Keep the original slot until the next search so no other deal moves under the cursor.
            view[#view + 1] = { title = "Treffer abgelaufen", detail = "Suche erneut f�r frische Angebote." }
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
    if state.held[lot] then detail = "Halten - kein profitabler Preis. " .. detail end
    if pending then
        caption = ({
            saleSearch = "Markt wird gepr�ft .", saleReady = "Einstellen best�tigen",
            posting = "Auktion wird verbucht .", postWarning = "AH-Warnung best�tigen",
        })[pending.phase]
        if pending.price then
            detail = money(pending.price) .. "/Stk.  �  Kaution " .. money(pending.deposit)
                .. (pending.direct and "  �  Knapp unter Markt" or "  �  Preis f�r Zwischenh�ndler")
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
    local status = lot.needsCheck and lot.status == "posted" and "AH-Status pr�fen" or lotStatus[lot.status]
    return string.format("R%d.%d  �  %d � %s  �  %s", round.id, index, lot.quantity,
        addon.itemName(lot.item), status)
end

local function roundRows(round)
    local view = {}
    for index, lot in ipairs(round.lots) do
        local detail = "Einkauf " .. money(lot.cost) .. "  �  Ziel " .. money(lot.target) .. "/Stk."
        if lot.status == "mail" then
            detail = string.format("%d von %d St�ck abgeholt", lot.collected, lot.quantity)
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
                local detail = "Gewinnschwelle " .. money(floorPrice) .. "/Stk.  �  Kein Vergleich verf�gbar"
                if history then
                    local median, month = history.median7d, history.median30d
                    local assessment = median and "Historisch erreichbar" or "Trend offen"
                    if median and median < floorPrice then assessment = "Aktuell halten oder Ausstieg pr�fen" end
                    if history.high30d and history.high30d < floorPrice then assessment = "�ber dem 30-Tage-Hoch" end
                    detail = string.format("Schwelle %s  �  7T %s  �  30T %s  �  %s%s",
                        money(floorPrice), money(median), money(month), assessment, history.snapshot and " (Snapshot)" or "")
                end
                if lot.status == "posted" and (lot.confirmedSold or 0) > 0 then
                    detail = detail .. "  �  " .. lot.confirmedSold .. " verkauft"
                end
                local entry = saleRow(round, index, lot, lotTitle(round, index, lot), detail)
                entry.tip = { name = addon.itemName(lot.item), lines = {
                    "Seit " .. math.floor(math.max(0, GetServerTime() - lot.acquired) / 3600) .. " Stunden im Bestand",
                    "Einkauf " .. money(lot.cost) .. "  �  Gewinnschwelle " .. money(floorPrice) .. "/Stk.",
                    "Letzter AHledger-Tiefstpreis " .. money(history and history.minBuyout),
                    "30 Tage: Tief " .. money(history and history.low30d) .. " / Hoch " .. money(history and history.high30d),
                    history and history.updated and ("AHledger-Stand " .. date("%d.%m. %H:%M", history.updated)
                        .. (history.snapshot and " (Snapshot)" or "")) or "Datenstand offen",
                    marketCredit(),
                    "Historische Angebotspreise sch�tzen keine Garantie f�r k�nftige Verk�ufe.",
                } }
                view[#view + 1] = entry
            end
        end
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

local function draw()
    local round = state.round
    local view, primaryVisible, finishVisible = {}, false, false
    local message = state.notice
    scroll:SetShown(state.tab == "export")
    if state.tab ~= "export" then showExport = false end
    if state.tab == "stock" or state.tab == "export" then
        local spent, net = totals()
        stageLine:SetText(state.tab == "stock" and "Offener Bestand nach Runde" or "Handelsdaten exportieren")
        contextLine:SetText("Ausgegeben " .. money(spent) .. "  �  Rundenerl�s netto " .. money(net)
            .. "  �  Eingegangene AH-Post " .. money(addon.payoutTotal()))
        if state.tab == "stock" then
            view = stockRows()
            primaryVisible = true
            action(primary, "Auktionen pr�fen", addon.queryOwned, addon.canQuery() and not addon.isBusy() and not state.sweep)
            message = message or (#view == 0 and "Kein offener Bestand." or "�ltere K�ufe bleiben hier verf�gbar.")
        else
            exportView()
            message = message or "Strg+C kopiert die markierten Daten. Export erneut anklicken zum Aktualisieren."
        end
    elseif not round then
        stageLine:SetText("Neue Handelsrunde")
        contextLine:SetText("Gib /ff budget 4 ein und geh zum Auktionshaus.")
    else
        stageLine:SetText("Runde " .. round.id .. "   �   " .. (stage[round.stage] or stage.done))
        contextLine:SetText("Restbudget " .. money(addon.remaining()) .. " von " .. money(round.budget))
        if round.stage == "select" or round.stage == "buy" then
            local choosing = round.stage == "select"
            view = choosing and selectionRows() or hitRows()
            primaryVisible = true
            local ready = addon.canQuery() and not addon.isBusy() and not state.sweep and addon.selectedCount() > 0
            local title = choosing and "Suchen" or "Erneut suchen"
            if not state.ah then
                title = "Zum Auktionshaus"
            elseif state.sweep then
                title = string.format("Suche %d/%d .", state.sweep.index, #state.sweep.ids)
            elseif not addon.canQuery() and not addon.isBusy() then
                title = "AH wartet ."
            end
            action(primary, title, function()
                page = 1
                addon.startSweep()
            end, ready, ready)
            if choosing then
                contextLine:SetText("Budget " .. money(round.budget) .. "  �  " .. addon.selectedCount() .. " ausgew�hlt")
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
                message = message or (addon.mailLeft(round) .. " St�ck fehlen. Hole die AH-Post im Briefkasten ab.")
            elseif state.ah and round.stage == "sell" then
                stageLine:SetText("Runde " .. round.id .. "   �   Ware einstellen")
                local ready = false
                for _, lot in ipairs(round.lots) do
                    if lot.status == "ready" then ready = true end
                end
                if not ready then stageLine:SetText("Runde " .. round.id .. "   �   Ware eingestellt") end
                message = message or "Mit /ff budget X startest du die n�chste Runde."
            end
        end
    end
    if state.action and state.action.phase == "saleReady" then
        finishVisible = true
        action(finish, state.action.marketPriceOnly and "H�ndlerpreis" or "Knapp unter Markt",
            addon.toggleSalePrice, true)
    end
    notice:SetText(message or "")
    note:SetText(marketCredit())
    primary:SetShown(primaryVisible)
    finish:SetShown(finishVisible)
    local pages = math.max(1, math.ceil(#view / pageSize))
    page = math.min(page, pages)
    pageLine:SetText(pages > 1 and (page .. " / " .. pages) or "")
    prev:SetShown(pages > 1)
    forward:SetShown(pages > 1)
    enabled(prev, page > 1 and not state.action)
    enabled(forward, page < pages and not state.action)
    for index, row in ipairs(rows) do
        local entry = view[(page - 1) * pageSize + index]
        row.bg:SetShown(entry ~= nil)
        row.hover.tip = entry and entry.tip
        row.hover:SetShown(row.hover.tip ~= nil)
        row.title:SetText(entry and entry.title or "")
        row.detail:SetText(entry and entry.detail or "")
        row.button:SetShown(entry and entry.caption ~= nil or false)
        if entry and entry.caption then action(row.button, entry.caption, entry.click, not entry.disabled) end
    end
end

function addon.showPanel()
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
