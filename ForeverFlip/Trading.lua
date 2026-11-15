local _, addon = ...
local house = C_AuctionHouse
local state = { hits = {}, hitOrder = {}, held = {}, tab = "flow" }
addon.state = state
local buyTTL, searchTTL, saleTTL = 20, 5, 6
local sweepTTL = 8
local liveDelay = 5
local duration = 1
local db, mail

local function say(message)
    state.notice = message
end

local function now()
    return GetServerTime()
end

function addon.remaining()
    local round = state.round
    return round and round.budget - round.spent or 0
end

function addon.isBusy()
    return state.action ~= nil or (db and (db.pendingBuy ~= nil or db.pendingPost ~= nil))
end

function addon.canQuery()
    return state.ah and house.IsThrottledMessageSystemReady()
end

local function resetHits()
    state.hits, state.hitOrder = {}, {}
end

local function stopSweep()
    state.sweep = nil
end

function addon.stopLive()
    if not state.live then return end
    state.live, state.liveNext, state.ignoredHits = nil, nil, nil
    stopSweep()
end

function addon.hitSoundEnabled()
    return db and db.hitSound ~= false
end

function addon.toggleHitSound()
    db.hitSound = not addon.hitSoundEnabled()
end

local function playHitSound()
    if addon.hitSoundEnabled() and PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        PlaySound(SOUNDKIT.RAID_WARNING)
    end
end

function addon.endShopping()
    if addon.isBusy() then return end
    local round = state.round
    addon.stopLive()
    stopSweep()
    resetHits()
    round.stage = addon.mailLeft(round) > 0 and "mail" or "sell"
    say(nil)
end

local function startRound(budget)
    if addon.isBusy() then
        say("Ein Kauf oder eine Auktion ist noch offen. Prüfe zuerst den Bestand.")
        return
    end
    addon.stopLive()
    stopSweep()
    resetHits()
    state.round = addon.newRound(budget, now())
    state.tab = "flow"
    say(nil)
end

function addon.configureBudget(amount, update)
    local gold = tonumber((amount:gsub(",", ".")))
    if not gold or gold < 0.0001 or gold > 1000000 then
        say("Budget in Gold eingeben, z. B. 3,50.")
        return false
    end
    if addon.isBusy() then
        say("Warte, bis die laufende Transaktion geklärt ist.")
        return false
    end
    local budget = math.floor(gold * 10000 + 0.5)
    local round = state.round
    if update and round and (round.stage == "select" or round.stage == "buy") then
        if budget < round.spent then
            say("Das Budget muss mindestens die bisherigen Ausgaben decken.")
            return false
        end
        round.budget = budget
        addon.stopLive()
        stopSweep()
        resetHits()
        say("Budget gespeichert. Suche mit dem neuen Limit starten.")
    else
        startRound(budget)
    end
    return true
end

function addon.editSelection()
    local round = state.round
    if not round or round.stage ~= "buy" or addon.isBusy() then return end
    addon.stopLive()
    stopSweep()
    resetHits()
    round.stage = "select"
    say(nil)
end

local function readTiers(id)
    local tiers, prices = {}, {}
    local count = math.min(40, house.GetNumCommoditySearchResults(id) or 0)
    for i = 1, count do
        local entry = house.GetCommoditySearchResultInfo(id, i)
        if entry and entry.unitPrice and entry.unitPrice > 0 and entry.quantity and entry.quantity > 0 then
            local tier = prices[entry.unitPrice]
            if not tier then
                tier = { price = entry.unitPrice, quantity = 0, own = 0 }
                prices[entry.unitPrice] = tier
                tiers[#tiers + 1] = tier
            end
            tier.quantity = tier.quantity + entry.quantity
            tier.own = tier.own + (entry.numOwnerItems or 0)
        end
    end
    table.sort(tiers, function(a, b) return a.price < b.price end)
    return tiers
end

local function sendQuery(id)
    house.SendSearchQuery(house.MakeItemKey(id), {
        { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false },
    }, true)
end

function addon.selected(id)
    return db.selection[id] == true
end

function addon.toggleItem(id)
    if state.round.stage ~= "select" then return end
    db.selection[id] = not db.selection[id] or nil
end

function addon.selectedCount()
    local count = 0
    for _ in pairs(db.selection) do count = count + 1 end
    return count
end

local function processSweep()
    local scan = state.sweep
    if not scan or scan.paused or addon.isBusy() then return end
    if scan.waiting then
        if GetTime() < scan.deadline then return end
        addon.scanCount(scan.waiting, "timeouts")
        scan.skipped[#scan.skipped + 1] = addon.itemName(scan.waiting)
        scan.waiting = nil
        say(scan.skipped[#scan.skipped] .. ": AH antwortet nicht. Suche läuft weiter.")
    end
    local nextID = scan.ids[scan.index + 1]
    if not nextID then
        stopSweep()
        if state.live then
            if #scan.skipped == #scan.ids then
                addon.stopLive()
                say("Live gestoppt: keine Antwort vom Auktionshaus.")
                return
            end
            if #scan.skipped > 0 then state.liveNext = GetTime() + liveDelay end
        end
        if #scan.skipped > 0 then
            say(string.format("%d Treffer · %d ohne AH-Antwort (%s).", scan.found, #scan.skipped, scan.skipped[1]))
        else
            say(scan.found == 0 and "Durchlauf fertig. Kein Treffer zu deinen Regeln." or nil)
        end
        return
    end
    if addon.canQuery() then
        scan.index = scan.index + 1
        scan.waiting, scan.deadline = nextID, GetTime() + sweepTTL
        sendQuery(nextID)
    end
end

function addon.startSweep()
    if not state.round or not addon.canQuery() or state.sweep or addon.isBusy() then return end
    if state.round.stage ~= "select" and state.round.stage ~= "buy" then return end
    local ids = {}
    for id in pairs(db.selection) do
        if addon.items[id] and addon.marketPrice(id) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    if #ids == 0 then
        say("Wähle Artikel mit ausreichenden AHledger-Absatzdaten.")
        return
    end
    state.round.stage = "buy"
    resetHits()
    state.sweep = { ids = ids, index = 0, found = 0, skipped = {} }
    if state.live then state.liveNext = GetTime() + liveDelay end
    say(nil)
    processSweep()
    return true
end

function addon.toggleLive()
    if state.live then
        addon.stopLive()
        say("Live aus. Suche bei Bedarf manuell starten.")
        return
    end
    local round = state.round
    if not state.ah or not round or addon.isBusy() or addon.selectedCount() == 0 then return end
    if round.stage ~= "select" and round.stage ~= "buy" then return end
    state.live, state.liveNext, state.ignoredHits = true, GetTime(), {}
    say(nil)
end

local function saveHit(id, tiers)
    local market = addon.marketPrice(id)
    local budget = math.min(addon.remaining(), GetMoney())
    local hit = market and addon.findDeal(tiers, market, addon.items[id], budget, addon.marginPercent)
    if not hit then
        if state.ignoredHits then state.ignoredHits[id] = nil end
        return
    end
    hit.signature = table.concat({ hit.quantity, hit.total, hit.maxUnit, hit.nextPrice }, ":")
    if state.ignoredHits and state.ignoredHits[id] == hit.signature then return end
    local item = addon.items[id]
    hit.id, hit.time = id, GetTime()
    hit.vendorKnown = item.noCheaperVendor or item.vendor ~= nil
    hit.snapshot = market.snapshot
    state.hits[id] = hit
    state.hitOrder[#state.hitOrder + 1] = id
    state.sweep.found = state.sweep.found + 1
    addon.scanCount(id, "hits")
    state.sweep.paused = id
    say(nil)
    playHitSound()
end

function addon.freshHit(id)
    local hit = state.hits[id]
    if hit and GetTime() - hit.time < buyTTL and hit.total <= math.min(addon.remaining(), GetMoney()) then
        return hit
    end
end

local function resumeAfterHit(id, ignore)
    local scan = state.sweep
    if not scan or scan.paused ~= id then return end
    local hit = state.hits[id]
    if ignore and hit and state.ignoredHits then state.ignoredHits[id] = hit.signature end
    scan.paused = nil
    resetHits()
end

function addon.skipHit()
    local scan = state.sweep
    if not scan or not scan.paused or addon.isBusy() then return end
    resumeAfterHit(scan.paused, true)
    say(nil)
end

local function rejectQuote(message, field)
    local action = state.action
    if action and (action.phase == "quote" or action.phase == "quoted") then
        if field then addon.scanCount(action.id, field) end
        state.action = nil
        resumeAfterHit(action.id, true)
        state.hits[action.id] = nil
        house.CancelCommoditiesPurchase()
    end
    say(message)
end

function addon.buyClick(id)
    if not state.ah or not state.round or state.round.stage ~= "buy" then return end
    local action = state.action
    if action then
        if action.id ~= id or action.phase ~= "quoted" then return end
        local seconds = house.GetQuoteDurationRemaining and house.GetQuoteDurationRemaining()
        if (seconds and seconds <= 0) or GetTime() >= action.deadline or
            action.total > math.min(addon.remaining(), GetMoney()) then
            rejectQuote("Preisangebot abgelaufen oder Budget zu knapp.")
            return
        end
        action.phase, action.deadline = "buying", GetTime() + 10
        action.confirmedAt = GetTime()
        addon.scanCount(id, "confirms")
        if action.quantity > 1 then addon.scanCount(id, "multiConfirms") end
        db.pendingBuy = { round = state.round.id, id = id, quantity = action.quantity,
            total = action.total, maxUnit = action.maxUnit, reference = action.reference,
            nextPrice = action.nextPrice, target = action.target, scanMeasured = true }
        house.ConfirmCommoditiesPurchase(id, action.quantity)
        return
    end
    if addon.isBusy() or not addon.canQuery() then return end
    local hit = addon.freshHit(id)
    if not hit then return end
    state.action = {
        phase = "quote", id = id, quantity = hit.quantity, total = hit.total, maxUnit = hit.maxUnit,
        reference = hit.reference, nextPrice = hit.nextPrice, target = hit.post,
        startedAt = GetTime(), deadline = GetTime() + searchTTL,
    }
    addon.scanCount(id, "attempts")
    if hit.quantity > 1 then addon.scanCount(id, "multiAttempts") end
    say(nil)
    house.StartCommoditiesPurchase(id, hit.quantity)
end

local function purchased()
    local position = db.pendingBuy
    if not position then return end
    local round = addon.recordPurchase(position, now())
    if not round then return end
    if position.scanMeasured then
        addon.scanCount(position.id, "bought")
        if position.quantity > 1 then addon.scanCount(position.id, "multiBought") end
        local action = state.action
        if action and action.confirmedAt then
            addon.scanCount(position.id, "finishedMillis", math.floor((GetTime() - action.confirmedAt) * 1000 + 0.5))
            addon.scanCount(position.id, "timedBuys")
        end
    end
    db.pendingBuy, state.action = nil, nil
    resumeAfterHit(position.id)
    state.hits[position.id] = nil
    if round == state.round and addon.remaining() <= 500 then addon.endShopping() end
    say("Kauf bestätigt. Die Ware kommt per AH-Post.")
end

local function bagInventory()
    local counts, locations = {}, {}
    for bag = 0, math.max(4, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and addon.items[info.itemID] then
                local id = info.itemID
                counts[id] = (counts[id] or 0) + info.stackCount
                if state.ah and not info.isLocked and not locations[id] then
                    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    if location:IsValid() and house.IsSellItemValid(location, false) then
                        locations[id] = location
                    end
                end
            end
        end
    end
    return counts, locations
end

local function saleInvoice(index)
    local _, _, _, _, money = GetInboxHeaderInfo(index)
    if type(money) ~= "number" or money <= 0 then return end
    local kind, name, _, _, _, deposit, _, _, _, _, quantity = GetInboxInvoiceInfo(index)
    if kind ~= "seller" or not name then return end
    local item
    for id in pairs(addon.items) do
        if addon.itemName(id) == name then
            item = id
            break
        end
    end
    local key = table.concat({ name, money, deposit or 0, quantity or "" }, "\t")
    return key, { item = item, quantity = quantity, money = money, deposit = deposit or 0 }
end

local function readMail()
    local counts, sales = {}, {}
    for index = 1, GetInboxNumItems() do
        if GetInboxInvoiceInfo(index) == "buyer" then
            for attachment = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
                local _, id, _, count = GetInboxItem(index, attachment)
                if id and count and addon.items[id] then
                    counts[id] = (counts[id] or 0) + count
                end
            end
        end
        local key = saleInvoice(index)
        if key then sales[key] = (sales[key] or 0) + 1 end
    end
    return counts, sales
end

local function watchPayout(index)
    if not mail then return end
    local key, invoice = saleInvoice(index)
    if key and not mail.claims[key] then
        mail.claims[key] = invoice
    end
end

local function reconcileMail()
    if not mail then return end
    local inbox, sales = readMail()
    local bags = bagInventory()
    for key, invoice in pairs(mail.claims) do
        local received = (mail.sales[key] or 0) - (sales[key] or 0)
        if received > 0 then
            for _ = 1, received do addon.recordPayout(invoice, now()) end
            mail.claims[key] = nil
        end
    end
    for id in pairs(addon.items) do
        mail.increased[id] = (mail.increased[id] or 0) + math.max(0, (bags[id] or 0) - (mail.bags[id] or 0))
        mail.removed[id] = (mail.removed[id] or 0) + math.max(0, (mail.inbox[id] or 0) - (inbox[id] or 0))
        local collected = math.min(mail.increased[id], mail.removed[id])
        if collected > 0 then
            addon.addCollected(id, collected)
            mail.increased[id] = mail.increased[id] - collected
            mail.removed[id] = mail.removed[id] - collected
        end
    end
    mail.inbox, mail.bags, mail.sales = inbox, bags, sales
    if state.round and state.round.stage == "mail" and addon.mailLeft(state.round) == 0 then
        state.round.stage = "sell"
        say("Alles abgeholt. Zurück zum AH.")
    end
end

local function sellPrice(action, tiers)
    local cheapest = tiers[1] and tiers[1].price
    local price, floorPrice, direct = addon.planSale(action.lot, cheapest, action.marketPriceOnly)
    local step = house.SupportsCopperValues() and 1 or 100
    price = price and math.floor(price / step) * step
    if not price or price < floorPrice or price < 1 then return end
    return price, direct, cheapest
end

function addon.toggleSalePrice()
    local action = state.action
    if not action or action.phase ~= "saleReady" then return end
    local choice = not action.marketPriceOnly
    action.marketPriceOnly = choice
    local price, direct, cheapest = sellPrice(action, readTiers(action.id))
    if price then
        action.price, action.direct, action.marketLowest = price, direct, cheapest
    else
        state.action = nil
        state.held[action.lot] = true
        say("Marktpreis zu niedrig. Ware bleibt im Bestand.")
    end
end

function addon.sellClick(round, index)
    if not state.ah or not addon.canQuery() then return end
    local lot = round.lots[index]
    local action = state.action
    if action then
        if action.lot ~= lot then return end
        if action.phase == "postWarning" then
            local counts, locations = bagInventory()
            local location = locations[lot.item]
            if not location or (counts[lot.item] or 0) < lot.quantity or GetTime() >= action.deadline then
                return
            end
            local bag, slot = location:GetBagAndSlot()
            local current = sellPrice(action, readTiers(lot.item))
            if bag ~= action.bag or slot ~= action.slot or current ~= action.price or action.deposit > GetMoney() then return end
            action.phase, action.deadline = "posting", GetTime() + 10
            house.ConfirmPostCommodity(action.location, duration, lot.quantity, action.price)
            return
        end
        if action.phase ~= "saleReady" or GetTime() >= action.deadline then return end
        local counts, locations = bagInventory()
        local location = locations[lot.item]
        if not location or (counts[lot.item] or 0) < lot.quantity or action.deposit > GetMoney() then
            state.action = nil
            say("Ware oder Gold für die Einstellgebühr fehlt.")
            return
        end
        local current = sellPrice(action, readTiers(lot.item))
        if current ~= action.price then
            state.action = nil
            say("Marktpreis hat sich geändert. Stelle den Verkauf erneut bereit.")
            return
        end
        action.location = location
        action.bag, action.slot = location:GetBagAndSlot()
        action.phase, action.deadline = "posting", GetTime() + 10
        db.pendingPost = { round = round.id, index = index, price = action.price, deposit = action.deposit,
            market = action.marketLowest, direct = action.direct }
        local needsConfirmation = house.PostCommodity(location, duration, lot.quantity, action.price)
        if needsConfirmation and state.action == action then
            action.phase, action.deadline = "postWarning", GetTime() + 10
        end
        return
    end
    if addon.isBusy() or lot.status ~= "ready" then return end
    addon.stopLive()
    stopSweep()
    state.held[lot] = nil
    state.action = { phase = "saleSearch", id = lot.item, lot = lot, deadline = GetTime() + searchTTL }
    say(nil)
    sendQuery(lot.item)
end

local function posted(auction)
    local pending = db.pendingPost
    if not pending or type(auction) ~= "number" then return end
    local lot = db.rounds[pending.round].lots[pending.index]
    lot.status, lot.auction, lot.listPrice = "posted", auction, pending.price
    lot.deposit, lot.listedAt, lot.needsCheck = pending.deposit, now(), nil
    lot.listMarket, lot.listDirect = pending.market, pending.direct == true
    db.pendingPost, state.action = nil, nil
    say("Auktion eingestellt.")
end

local function searchResult(id)
    if not state.ah then return end
    id = type(id) == "table" and id.itemID or id
    local action = state.action
    if action and action.id == id and action.phase == "saleSearch" then
        local price, direct, cheapest = sellPrice(action, readTiers(id))
        local deposit = price and house.CalculateCommodityDeposit(id, duration, action.lot.quantity)
        if not price or type(deposit) ~= "number" then
            state.held[action.lot] = true
            state.action = nil
            say("Halten – kein bestätigter Tiefstpreis oberhalb deiner Gewinnschwelle.")
        else
            action.phase, action.deadline = "saleReady", GetTime() + saleTTL
            action.price, action.deposit, action.direct, action.marketLowest = price, deposit, direct, cheapest
        end
    elseif not action and state.sweep and state.sweep.waiting == id then
        addon.scanCount(id, "replies")
        saveHit(id, readTiers(id))
        state.sweep.waiting = nil
    end
end

function addon.rounds()
    return db.rounds
end

local function readOwnedAuctions()
    local owned = {}
    for index = 1, house.GetNumOwnedAuctions() do
        local auction = house.GetOwnedAuctionInfo(index)
        if auction then owned[auction.auctionID] = auction end
    end
    return owned
end

function addon.queryOwned()
    if not addon.canQuery() or state.sweep or addon.isBusy() then return end
    house.QueryOwnedAuctions({ { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false } })
    say("Eigene Auktionen werden geprüft.")
end

function addon.tick()
    local action = state.action
    if action and GetTime() >= action.deadline then
        if action.phase == "quote" or action.phase == "quoted" then
            rejectQuote("Preisprüfung abgelaufen. Erneut suchen.", "quoteTimeouts")
        else
            if action.phase == "buying" then addon.scanCount(action.id, "uncertain") end
            state.action = nil
            say(addon.isBusy() and "Bestätigung fehlt. Prüfe die Transaktion, bevor du weiterhandelst."
                or "Preisprüfung abgelaufen. Bitte erneut anklicken.")
        end
    end
    local paused = state.sweep and state.sweep.paused
    if paused and not addon.isBusy() and not addon.freshHit(paused) then
        resumeAfterHit(paused, true)
    end
    if state.live and not state.sweep and not addon.isBusy() and state.liveNext
        and GetTime() >= state.liveNext and addon.canQuery() then
        if not addon.startSweep() then addon.stopLive() end
    end
    processSweep()
end

local function onEvent(_, event, first, second)
    if event == "ADDON_LOADED" and first == "ForeverFlip" then
        db = addon.loadRounds()
        state.round = db.rounds[#db.rounds]
    elseif event == "AUCTION_HOUSE_SHOW" then
        state.ah = true
        addon.showPanel()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        state.ah = false
        addon.stopLive()
        stopSweep()
        resetHits()
        rejectQuote(nil)
        state.action = nil
    elseif event == "MAIL_SHOW" then
        local inbox, sales = readMail()
        mail = { bags = bagInventory(), inbox = inbox, sales = sales, claims = {}, removed = {}, increased = {} }
        if state.round and state.round.stage == "mail" then addon.showPanel() end
    elseif event == "MAIL_INBOX_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        reconcileMail()
    elseif event == "MAIL_CLOSED" then
        reconcileMail()
        mail = nil
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "COMMODITY_SEARCH_RESULTS_ADDED" then
        searchResult(first)
    elseif event == "COMMODITY_PRICE_UPDATED" then
        local action = state.action
        if action and (action.phase == "quote" or action.phase == "quoted") then
            if type(second) ~= "number" or second ~= action.total or (type(first) == "number" and first > action.maxUnit) then
                rejectQuote("Preis geändert. Der Kauf wurde verworfen.", "priceChanged")
            else
                if action.phase == "quote" then
                    addon.scanCount(action.id, "quotes")
                    addon.scanCount(action.id, "quoteMillis", math.floor((GetTime() - action.startedAt) * 1000 + 0.5))
                end
                action.phase, action.deadline = "quoted", GetTime() + buyTTL
            end
        end
    elseif event == "COMMODITY_PRICE_UNAVAILABLE" then
        rejectQuote("Der Preis ist nicht mehr verfügbar.", "unavailable")
    elseif event == "COMMODITY_PURCHASE_FAILED" then
        if db.pendingBuy then
            if db.pendingBuy.scanMeasured then
                addon.scanCount(db.pendingBuy.id, "failed")
                if db.pendingBuy.quantity > 1 then addon.scanCount(db.pendingBuy.id, "multiFailed") end
            end
            resumeAfterHit(db.pendingBuy.id, true)
            state.hits[db.pendingBuy.id] = nil
            db.pendingBuy, state.action = nil, nil
            say("Kauf fehlgeschlagen. Das Budget wurde freigegeben.")
        end
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        purchased()
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        posted(first)
    elseif event == "AUCTION_HOUSE_POST_ERROR" or event == "AUCTION_HOUSE_SHOW_ERROR" then
        if db.pendingPost and state.action then
            db.pendingPost, state.action = nil, nil
            say("Das AH hat das Einstellen abgelehnt.")
        elseif state.action and (state.action.phase == "quote" or state.action.phase == "quoted") then
            rejectQuote("Das AH hat die Preisabfrage abgelehnt.", "quoteErrors")
        elseif state.action and state.action.phase == "buying" and not state.action.serverError then
            state.action.serverError = true
            addon.scanCount(state.action.id, "buyErrors")
            if state.action.quantity > 1 then addon.scanCount(state.action.id, "multiBuyErrors") end
            say("AH meldet einen Fehler. Warte auf das Ergebnis des Kaufs.")
        end
    elseif event == "OWNED_AUCTIONS_UPDATED" then
        addon.checkOwned(readOwnedAuctions(), now())
    end
    if state.ah and (event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "COMMODITY_SEARCH_RESULTS_ADDED"
        or event == "COMMODITY_PRICE_UPDATED" or event == "COMMODITY_PRICE_UNAVAILABLE"
        or event == "COMMODITY_PURCHASE_SUCCEEDED" or event == "COMMODITY_PURCHASE_FAILED"
        or event == "AUCTION_HOUSE_SHOW_ERROR"
        or (event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" and state.sweep and state.sweep.paused)) then
        addon.refreshDealUI()
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "ADDON_LOADED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED",
    "BAG_UPDATE_DELAYED", "COMMODITY_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_ADDED",
    "COMMODITY_PRICE_UPDATED", "COMMODITY_PRICE_UNAVAILABLE", "COMMODITY_PURCHASE_FAILED",
    "COMMODITY_PURCHASE_SUCCEEDED", "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_POST_ERROR",
    "AUCTION_HOUSE_SHOW_ERROR", "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", onEvent)
for _, name in ipairs({ "TakeInboxMoney", "AutoLootMailItem" }) do
    if _G[name] then hooksecurefunc(name, watchPayout) end
end

SLASH_FOREVERFLIP1 = "/ff"
SLASH_FOREVERFLIP2 = "/foreverflip"
SlashCmdList.FOREVERFLIP = function(message)
    local amount = message:match("^%s*budget%s+([%d.,]+)%s*$")
    local command, roundID, lotID, copper = message:match("^%s*(%a+)%s+(%d+)%s+(%d+)%s*(%d*)%s*$")
    local auctionID = tonumber(message:match("^resolve listed%s+(%d+)$"))
    if amount then
        addon.configureBudget(amount, false)
    elseif command then
        local round = db.rounds[tonumber(roundID)]
        local lot = round and round.lots[tonumber(lotID)]
        if lot and not addon.isBusy() and command == "receipt" and tonumber(copper)
            and (lot.status == "posted" or lot.status == "sold") then
            lot.status, lot.receipt = "sold", tonumber(copper)
            lot.confirmedSold, lot.soldAt = lot.quantity, lot.soldAt or now()
            say("Nettoerlös aus deinem Beleg verbucht.")
        elseif lot and not addon.isBusy() and command == "collect" and
            (lot.status == "mail" or (lot.status == "posted" and lot.needsCheck and (lot.confirmedSold or 0) == 0)) then
            local bags = bagInventory()
            local reserved = 0
            for _, other in ipairs(db.rounds) do
                for _, entry in ipairs(other.lots) do
                    if entry ~= lot and entry.item == lot.item and entry.status == "ready" then
                        reserved = reserved + entry.quantity
                    end
                end
            end
            if (bags[lot.item] or 0) - reserved >= lot.quantity then
                if lot.status == "posted" then
                    lot.lostDeposit = (lot.lostDeposit or 0) + (lot.deposit or 0)
                    lot.auction, lot.listPrice, lot.deposit, lot.listedAt, lot.needsCheck = nil, nil, nil, nil, nil
                end
                lot.status, lot.collected = "ready", lot.quantity
                if state.round == round and round.stage == "mail" and addon.mailLeft(round) == 0 then
                    round.stage = "sell"
                end
                say("Ware aus deinem Beutel zugeordnet.")
            end
        end
    elseif message == "resolve bought" and not state.action and db.pendingBuy then
        purchased()
    elseif message == "resolve failed" and not state.action and db.pendingBuy then
        resumeAfterHit(db.pendingBuy.id, true)
        state.hits[db.pendingBuy.id] = nil
        db.pendingBuy = nil
        say("Ungeklärten Kauf als fehlgeschlagen verbucht.")
    elseif message == "resolve unlisted" and not state.action and db.pendingPost then
        db.pendingPost = nil
        say("Ungeklärten Einstellversuch als fehlgeschlagen verbucht.")
    elseif auctionID and state.ah and not state.action and db.pendingPost then
        local pending = db.pendingPost
        local lot = db.rounds[pending.round].lots[pending.index]
        local linked
        for _, round in ipairs(db.rounds) do
            for _, entry in ipairs(round.lots) do
                if entry.auction == auctionID then linked = true end
            end
        end
        local auction = not linked and readOwnedAuctions()[auctionID]
        if auction and auction.itemKey.itemID == lot.item and auction.quantity > 0 and auction.quantity <= lot.quantity then
            posted(auctionID)
            addon.checkOwned({ [auctionID] = auction }, now())
        end
        if db.pendingPost then say("Auktion-ID nicht eindeutig gefunden. Lade deine Auktionen im AH.") end
    elseif not state.action and (db.pendingBuy or db.pendingPost) then
        say("Transaktion ungeklärt. Prüfe AH und Post. Auflösung siehe README.")
    end
    addon.showPanel()
end
