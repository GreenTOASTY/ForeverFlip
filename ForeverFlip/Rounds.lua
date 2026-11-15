local _, addon = ...

local db

function addon.loadRounds()
    db = type(ForeverFlipRounds) == "table" and ForeverFlipRounds or {}
    ForeverFlipRounds = db
    db.rounds = db.rounds or {}
    db.selection = db.selection or {}
    db.payouts = db.payouts or {}
    return db
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
        buyMarket = position.reference, nextPrice = position.nextPrice, maxUnit = position.maxUnit }
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
                lot.needsCheck = auction == nil
            end
        end
    end
end

function addon.revenue(lot)
    if lot.receipt then return lot.receipt, true end
    return math.floor((lot.confirmedSold or 0) * (lot.listPrice or 0) * 95 / 100), false
end

function addon.exportRounds()
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
        "net_proceeds_copper", "proceeds_source", "sold_seen_unix",
    }, "\t")
    for _, round in ipairs(db.rounds) do
        for index, lot in ipairs(round.lots) do
            local amount, actual = addon.revenue(lot)
            lines[#lines + 1] = table.concat({ round.id, index, lot.item, lot.quantity,
                lot.cost, lot.maxUnit or "", lot.buyMarket or "", lot.nextPrice or "", lot.acquired,
                lot.collected, lot.status, lot.target or "", lot.listPrice or "", lot.deposit or "",
                lot.lostDeposit or 0, lot.listedAt or "", lot.confirmedSold or 0, amount,
                actual and "manual_net_receipt" or "net_estimate_from_confirmed_quantity", lot.soldAt or "",
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
    return table.concat(lines, "\n")
end
