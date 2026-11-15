local _, addon = ...
local freshFor = 20
local maxRows = 7
local results, announced = {}, {}
local isOpen = false
local budget = 40000
local marketCredit = "AHledger (ahledger.com)"

local function coins(value)
    if value >= 10000 then
        return string.format("%dg %02ds %02dk", math.floor(value / 10000), math.floor(value / 100) % 100, value % 100)
    elseif value >= 100 then
        return string.format("%ds %02dk", math.floor(value / 100), value % 100)
    end
    return string.format("%dk", value)
end

local frame = CreateFrame("Frame", "ForeverFlipPanel", UIParent, "BackdropTemplate")
frame:SetSize(590, 330)
frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -30, -155)
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
})
frame:SetBackdropColor(0.07, 0.08, 0.10, 0.98)
frame:SetBackdropBorderColor(0.26, 0.31, 0.37, 1)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

local function label(y, template)
    local line = frame:CreateFontString(nil, "OVERLAY", template)
    line:SetPoint("TOPLEFT", 14, y)
    line:SetWidth(562)
    line:SetJustifyH("LEFT")
    line:SetWordWrap(false)
    return line
end

label(-12, "GameFontNormalLarge"):SetText("ForeverFlip")
local status = label(-37, "GameFontHighlightSmall")
local credit = label(-310, "GameFontDisableSmall")
local lines = {}
for i = 1, maxRows do
    local y = -68 - (i - 1) * 34
    lines[i] = { label(y, "GameFontNormal"), label(y - 15, "GameFontHighlightSmall") }
end

local function render()
    local now, deals = GetTime(), {}
    local active, newest = 0, nil
    for id, observed in pairs(results) do
        local age = now - observed.time
        if age <= freshFor then
            active = active + 1
            newest = newest and math.min(newest, age) or age
            local deal = observed.deal
            if deal then deals[#deals + 1] = deal end
        end
    end
    table.sort(deals, function(a, b)
        if a.profit == b.profit then return a.id < b.id end
        return a.profit > b.profit
    end)
    if not AHledgerAPI then
        status:SetText("AHledger fehlt. F�r die Auswahl wird der gesch�tzte Absatz ben�tigt.")
    elseif active == 0 then
        status:SetText("AH-Suche starten oder in auxForever Suchliste, Full und Live verwenden.")
    else
        status:SetText(string.format("%d frische Artikel  �  %d Treffer  �  j�ngstes Ergebnis vor %ds  �  max. %s je Kauf",
            active, #deals, math.floor(newest), coins(budget)))
    end
    credit:SetText("Absatz und 7-Tage-Median: " .. (AHledgerAPI and AHledgerAPI.CREDIT or marketCredit)
        .. "  �  /ff budget 4")
    for i, line in ipairs(lines) do
        local deal = deals[i]
        if deal then
            local vendor = not deal.vendorKnown and "  �  NPC-Preis ungekl�rt" or ""
            local dataAge = deal.snapshot and "  �  AHledger-Snapshot" or ""
            line[1]:SetText(string.format("%s  �  %d Stk. bis %s/Stk.  �  max. %s",
                addon.itemName(deal.id), deal.quantity, coins(deal.maxUnit), coins(deal.total)))
            line[2]:SetText(string.format("Einstellen %s/Stk.  �  +%s  �  H�ndler +%.1f%% bei %s  �  vor %ds%s%s",
                coins(deal.post), coins(deal.profit), deal.traderMargin, coins(deal.reference),
                math.floor(now - deal.time), vendor, dataAge))
        else
            line[1]:SetText("")
            line[2]:SetText("")
        end
    end
end

local listBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
listBox:SetPoint("TOPLEFT", 20, -35)
listBox:SetSize(548, 22)
listBox:SetAutoFocus(false)
listBox:SetScript("OnEscapePressed", function(self) self:Hide() end)
listBox:SetScript("OnEditFocusLost", function(self) self:Hide() end)
listBox:Hide()

local function showSearchList()
    local watch = {}
    for id in pairs(addon.items) do
        local market = addon.marketPrice(id)
        if market then watch[#watch + 1] = { id = id, sales = market.soldPerDay } end
    end
    table.sort(watch, function(a, b)
        if a.sales == b.sales then return a.id < b.id end
        return a.sales > b.sales
    end)
    local terms = {}
    for _, item in ipairs(watch) do
        terms[#terms + 1] = addon.itemName(item.id) .. "/exact"
    end
    if #terms == 0 then
        print("ForeverFlip: AHledger liefert noch keine passenden Absatzdaten.")
        return
    end
    listBox:SetText(table.concat(terms, ";"))
    listBox:Show()
    listBox:SetFocus()
    listBox:HighlightText()
end

local list = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
list:SetSize(95, 22)
list:SetPoint("TOPRIGHT", -36, -9)
list:SetText("Suchliste")
list:SetScript("OnClick", showSearchList)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -3)
close:SetScript("OnClick", function() frame:Hide() end)

local function updateItem(id)
    local item = addon.items[id]
    if not item then return end
    local market = addon.marketPrice(id)
    results[id] = nil
    local house = C_AuctionHouse
    if not market or not house or not house.GetNumCommoditySearchResults or not house.GetCommoditySearchResultInfo then
        return
    end
    local rows, byPrice = {}, {}
    -- Read only rows exposed by the client. A next price tier must actually be visible.
    local count = math.min(40, house.GetNumCommoditySearchResults(id) or 0)
    for i = 1, count do
        local row = house.GetCommoditySearchResultInfo(id, i)
        if row and row.unitPrice and row.unitPrice > 0 and row.quantity and row.quantity > 0 then
            local tier = byPrice[row.unitPrice]
            if not tier then
                tier = { price = row.unitPrice, quantity = 0, own = 0 }
                byPrice[row.unitPrice] = tier
                rows[#rows + 1] = tier
            end
            tier.quantity = tier.quantity + row.quantity
            tier.own = tier.own + (row.numOwnerItems or 0)
        end
    end
    table.sort(rows, function(a, b) return a.price < b.price end)
    local now = GetTime()
    local deal = addon.findDeal(rows, market, item, budget, addon.marginPercent)
    results[id] = { time = now, deal = deal }
    if deal then
        deal.id, deal.time, deal.snapshot = id, now, market.snapshot
        deal.vendorKnown = item.noCheaperVendor or item.vendor ~= nil
        local signature = table.concat({ deal.quantity, deal.total, deal.post }, ":")
        if announced[id] ~= signature then
            announced[id] = signature
            if frame:IsShown() and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
        end
    else
        announced[id] = nil
    end
end

local elapsed = 0
frame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.5 then return end
    elapsed = 0
    render()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
events:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" then
        if arg == "ForeverFlip" then
            ForeverFlipDB = type(ForeverFlipDB) == "table" and ForeverFlipDB or {}
            local saved = tonumber(ForeverFlipDB.budget)
            if saved and saved >= 1 and saved <= 10000000000 then
                budget = math.floor(saved)
            end
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        isOpen = true
        render()
        frame:Show()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        isOpen = false
        results, announced = {}, {}
        frame:Hide()
    elseif isOpen then
        updateItem(type(arg) == "table" and arg.itemID or arg)
    end
end)

SLASH_FOREVERFLIP1 = "/ff"
SLASH_FOREVERFLIP2 = "/foreverflip"
SlashCmdList.FOREVERFLIP = function(message)
    local amount = message:match("^%s*budget%s+([%d.,]+)%s*$")
    if amount then
        local gold = tonumber((amount:gsub(",", ".")))
        if not gold or gold < 0.0001 or gold > 1000000 then
            print("ForeverFlip: Beispiel /ff budget 4 oder /ff budget 3,50")
            return
        end
        budget = math.floor(gold * 10000 + 0.5)
        ForeverFlipDB.budget = budget
        results, announced = {}, {}
        print("ForeverFlip: Limit pro Kauf " .. coins(budget))
    end
    if isOpen then
        render()
        frame:Show()
    end
end
