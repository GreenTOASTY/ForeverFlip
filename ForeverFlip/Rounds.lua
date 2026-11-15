local _, addon = ...

local db
local scanFields = { "replies", "timeouts", "hits", "attempts", "quotes", "quoteMillis", "priceChanged",
    "unavailable", "quoteErrors", "quoteTimeouts", "confirms", "buyErrors", "failed", "uncertain", "bought", "finishedMillis",
    "timedBuys", "multiAttempts", "multiConfirms", "multiBuyErrors", "multiFailed", "multiBought" }

function addon.loadRounds()
    db = type(ForeverFlipRounds) == "table" and ForeverFlipRounds or {}
    ForeverFlipRounds = db
    db.rounds = db.rounds or {}
    db.selection = db.selection or {}
    db.payouts = db.payouts or {}
    db.scanStats = db.scanStats or {}
    db.hitLog = db.hitLog or {}
    db.catalog = db.catalog or {}
    for _, hit in ipairs(db.hitLog) do
        if hit.outcome == "open" or hit.outcome == "checking_price" or hit.outcome == "quoted" then
            hit.outcome = "session_ended"
        end
    end
    return db
end

function addon.logHit(hit, round, live, queryMillis)
    local id = #db.hitLog + 1
    db.hitLog[id] = { round = round, item = hit.id, found = GetServerTime(),
        quantity = hit.quantity, total = hit.total, maxUnit = hit.maxUnit, target = hit.post,
        mode = live and "live" or "manual", kind = hit.single and "item" or "commodity",
        queryMillis = queryMillis, outcome = "open" }
    return id
end

function addon.updateHit(id, outcome, field, value)
    local hit = db.hitLog[id]
    if not hit then return end
    if outcome then
        hit.outcome = outcome
        hit.updated = GetServerTime()
    end
    if field then hit[field] = value end
end

function addon.closeOpenHits(hits, reason)
    for _, hit in pairs(hits) do
        local logged = db.hitLog[hit.logID]
        if logged and logged.outcome == "open" then addon.updateHit(hit.logID, reason) end
    end
end

function addon.scanCount(id, field, value)
    local row = db.scanStats[id]
    if not row then
        row = {}
        db.scanStats[id] = row
    end
    row[field] = (row[field] or 0) + (value or 1)
end

function addon.scanSummary()
    local byItem = {}
    for id, counts in pairs(db.scanStats) do
        local summary = { id = id, profit = 0, soldLots = 0 }
        for _, field in ipairs(scanFields) do summary[field] = counts[field] or 0 end
        byItem[id] = summary
    end
    for _, round in ipairs(db.rounds) do
        for _, lot in ipairs(round.lots) do
            local summary = byItem[lot.item]
            if summary and lot.scanMeasured and lot.status == "sold" then
                summary.profit = summary.profit + addon.revenue(lot) - lot.cost - (lot.lostDeposit or 0)
                summary.soldLots = summary.soldLots + 1
            end
        end
    end
    local result = {}
    for _, summary in pairs(byItem) do result[#result + 1] = summary end
    table.sort(result, function(a, b)
        local left = a.profit * math.max(1, b.replies)
        local right = b.profit * math.max(1, a.replies)
        if left ~= right then return left > right end
        if a.hits ~= b.hits then return a.hits > b.hits end
        if a.replies ~= b.replies then return a.replies > b.replies end
        return a.id < b.id
    end)
    return result
end

function addon.recordPayout(invoice, now)
    db.payouts[#db.payouts + 1] = {
        received = now, item = invoice.item or "", quantity = invoice.quantity or "",
        money = invoice.money, returnedDeposit = invoice.deposit,
    }
end

function addon.payoutTotal()
    local total = 0
    for _, payout in ipairs(db.payouts) do total = total + payout.money end
    return total
end

function addon.newRound(budget, now)
    local previous = db.rounds[#db.rounds]
    if previous then previous.stage = "done" end
    local round = { id = #db.rounds + 1, budget = budget, spent = 0, stage = "select",
        started = now, lots = {} }
    db.rounds[round.id] = round
    return round
end

function addon.recordPurchase(position, now)
    local round = db.rounds[position.round]
    if not round or position.total > round.budget - round.spent then return end
    round.spent = round.spent + position.total
    round.firstBuy = round.firstBuy or now
    round.lots[#round.lots + 1] = { item = position.id, cost = position.total, quantity = position.quantity,
        collected = 0, target = position.target, acquired = now, status = "mail",
        buyMarket = position.reference, nextPrice = position.nextPrice, maxUnit = position.maxUnit,
        scanMeasured = position.scanMeasured, hitID = position.logID }
    return round
end

function addon.mailLeft(round)
    local left = 0
    for _, lot in ipairs(round.lots) do
        if lot.status == "mail" then left = left + lot.quantity - lot.collected end
    end
    return left
end

function addon.walkRecentPurchases(limit, visit)
    local count = 0
    for roundIndex = #db.rounds, 1, -1 do
        local round = db.rounds[roundIndex]
        for lotIndex = #round.lots, 1, -1 do
            count = count + 1
            visit(count, round.id, round.lots[lotIndex])
            if count == limit then return count end
        end
    end
    return count
end

function addon.addCollected(item, quantity)
    for _, round in ipairs(db.rounds) do
        for _, lot in ipairs(round.lots) do
            if lot.item == item and lot.status == "mail" and quantity > 0 then
                local taken = math.min(quantity, lot.quantity - lot.collected)
                lot.collected = lot.collected + taken
                quantity = quantity - taken
                if lot.collected == lot.quantity then lot.status = "ready" end
            end
        end
    end
end

function addon.checkOwned(owned, now)
    for _, round in ipairs(db.rounds) do
        for _, lot in ipairs(round.lots) do
            if lot.status == "posted" then
                local auction = owned[lot.auction]
                local previous = addon.revenue(lot)
                local previouslySoldAt = lot.soldAt
                if auction and auction.status == 1 then
                    lot.status = "sold"
                    lot.confirmedSold = lot.quantity
                    lot.soldAt = lot.soldAt or now
                elseif auction and auction.status == 0 then
                    lot.openQuantity = auction.quantity
                    if type(auction.quantity) == "number" then
                        lot.confirmedSold = math.max(lot.confirmedSold or 0, lot.quantity - auction.quantity)
                    end
                end
                addon.trackSale(lot, previous, now, previouslySoldAt)
                lot.needsCheck = auction == nil
            end
        end
    end
end

function addon.trackSale(lot, previous, now, previousDate)
    local difference = addon.revenue(lot) - previous
    if difference == 0 then return end
    if not lot.saleEvents then
        lot.saleEvents = {}
        lot.legacySaleAt = previousDate or false
    end
    lot.saleEvents[#lot.saleEvents + 1] = { at = now, net = difference }
end

function addon.balance(since, untilTime)
    local spent, net, lost, undated = 0, 0, 0, 0
    local function within(at)
        return (not since or (at and at >= since)) and (not untilTime or (at and at < untilTime))
    end
    for _, round in ipairs(db.rounds) do
        for _, lot in ipairs(round.lots) do
            if within(lot.acquired) then spent = spent + lot.cost end
            local legacy = addon.revenue(lot)
            for _, sale in ipairs(lot.saleEvents or {}) do
                legacy = legacy - sale.net
                if within(sale.at) then net = net + sale.net end
            end
            local legacyDate = lot.soldAt
            if lot.saleEvents then legacyDate = lot.legacySaleAt end
            if within(legacyDate) then net = net + legacy
            elseif not legacyDate then undated = undated + legacy end
            local legacyLoss = lot.lostDeposit or 0
            for _, fee in ipairs(lot.depositLosses or {}) do
                legacyLoss = legacyLoss - fee.amount
                if within(fee.at) then lost = lost + fee.amount end
            end
            if not since and not untilTime then lost = lost + legacyLoss end
        end
    end
    return spent, net, net - spent - lost, lost, undated
end

function addon.revenue(lot)
    if lot.receipt then return lot.receipt, true end
    return math.floor((lot.confirmedSold or 0) * (lot.listPrice or 0) * 95 / 100), false
end

function addon.exportRounds(since)
    local lines = {
        "round\tbudget_copper\tspent_copper\tstage\tstarted_unix",
    }
    for _, round in ipairs(db.rounds) do
        lines[#lines + 1] = table.concat({ round.id, round.budget, round.spent, round.stage, round.started }, "\t")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = table.concat({
        "round", "lot", "item_id", "quantity", "cost_copper", "max_buy_unit_copper",
        "buy_reference_copper", "next_ask_copper", "bought_unix", "collected", "status", "target_unit_copper",
        "listed_unit_copper", "deposit_copper", "lost_deposits_copper", "listed_unix", "confirmed_sold_quantity",
        "net_proceeds_copper", "proceeds_source", "sold_seen_unix", "hit_id",
    }, "\t")
    for _, round in ipairs(db.rounds) do
        for index, lot in ipairs(round.lots) do
            local amount, actual = addon.revenue(lot)
            lines[#lines + 1] = table.concat({ round.id, index, lot.item, lot.quantity,
                lot.cost, lot.maxUnit or "", lot.buyMarket or "", lot.nextPrice or "", lot.acquired,
                lot.collected, lot.status, lot.target or "", lot.listPrice or "", lot.deposit or "",
                lot.lostDeposit or 0, lot.listedAt or "", lot.confirmedSold or 0, amount,
                actual and "manual_net_receipt" or "net_estimate_from_confirmed_quantity", lot.soldAt or "", lot.hitID or "",
            }, "\t")
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "ah_mail_claimed_unix\titem_id\tquantity\tpayout_copper\treturned_deposit_copper"
    for _, payout in ipairs(db.payouts) do
        lines[#lines + 1] = table.concat({
            payout.received, payout.item, payout.quantity, payout.money, payout.returnedDeposit,
        }, "\t")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "scan_item_id\t" .. table.concat(scanFields, "\t")
        .. "\tclosed_lot_profit_copper\tclosed_lots"
    for _, summary in ipairs(addon.scanSummary()) do
        local fields = { summary.id }
        for _, field in ipairs(scanFields) do fields[#fields + 1] = summary[field] end
        fields[#fields + 1] = summary.profit
        fields[#fields + 1] = summary.soldLots
        lines[#lines + 1] = table.concat(fields, "\t")
    end
    local columns = {
        {"round", "round"}, {"item_id", "item"}, {"detected_unix", "found"}, {"quantity", "quantity"},
        {"total_copper", "total"}, {"max_unit_copper", "maxUnit"}, {"target_unit_copper", "target"},
        {"mode", "mode"}, {"kind", "kind"}, {"scan_reply_ms", "queryMillis"},
        {"hit_to_quote_request_ms", "attemptMs"}, {"quote_request_to_reply_ms", "quoteMs"},
        {"quote_reply_to_confirm_ms", "confirmMs"}, {"confirm_to_result_ms", "resultMs"},
        {"hit_to_error_ms", "errorMs"}, {"ah_error_event", "errorEvent"}, {"ah_error_code", "errorCode"},
        {"ah_error_name", "errorName"}, {"ui_error_code", "uiErrorCode"}, {"ui_error_name", "uiErrorName"},
        {"updated_unix", "updated"}, {"outcome", "outcome"},
    }
    lines[#lines + 1] = ""
    local header = { "hit_id" }
    for _, column in ipairs(columns) do header[#header + 1] = column[1] end
    lines[#lines + 1] = table.concat(header, "\t")
    for id, hit in ipairs(db.hitLog) do
        local fields = {id}
        for _, column in ipairs(columns) do fields[#fields + 1] = hit[column[2]] or "" end
        lines[#lines + 1] = table.concat(fields, "\t")
    end
    local spent, net, balance, lost, undated = addon.balance(since)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "balance_since_unix\tpurchases_copper\tnet_sales_copper\tlost_deposits_copper\tbalance_copper\texcluded_undated_net_copper"
    lines[#lines + 1] = table.concat({ since or "all", spent, net, lost, balance, undated }, "\t")
    lines[#lines + 1] = ""
    lines[#lines + 1] = "sale_observed_unix\tround\tlot\titem_id\tnet_change_copper"
    for _, round in ipairs(db.rounds) do
        for index, lot in ipairs(round.lots) do
            for _, sale in ipairs(lot.saleEvents or {}) do
                lines[#lines + 1] = table.concat({ sale.at, round.id, index, lot.item, sale.net }, "\t")
            end
        end
    end
    return table.concat(lines, "\n")
end
