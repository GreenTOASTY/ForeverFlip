local _, addon = ...

local function afterFee(amount)
    return math.floor(amount * 95 / 100)
end

local function directPrice(ceiling, median, item)
    return math.floor(math.min(ceiling, median or ceiling, item and item.vendor or math.huge) * 98 / 100)
end

function addon.minimumPrice(cost, count, margin)
    return math.ceil(math.ceil(cost * (100 + margin) / 100) * 100 / (95 * count))
end

function addon.priceForTrader(reference, count, margin)
    return math.floor(afterFee(reference * count) * 100 / ((100 + margin) * count))
end

function addon.purchaseTargets(hit, history, item, single, step)
    local ceiling = hit.nextPrice - 1
    local median = tonumber(history.median7d)
    local direct = directPrice(ceiling, median, item)
    local reference = math.min(ceiling, median or ceiling)
    local trader
    if single then
        trader = math.floor(math.min(reference, item.vendor or math.huge) * 85 / 100)
    else
        local buffered = math.min(math.floor(reference * 95 / 100), item.vendor or math.huge)
        trader = addon.priceForTrader(buffered, hit.quantity, addon.marginPercent)
    end
    direct, trader = math.floor(direct / step) * step, math.floor(trader / step) * step
    if hit.direct then direct = hit.post else trader = hit.post end
    return direct > 0 and direct or nil, trader > 0 and trader or nil
end

function addon.purchaseResult(lot, unitPrice)
    if not unitPrice then return end
    local gross = unitPrice * lot.quantity
    local proceeds = afterFee(gross)
    return gross - proceeds, proceeds - lot.cost - (lot.lostDeposit or 0)
end

function addon.findDeal(rows, market, item, budget, margin, options)
    local direct = options and options.direct
    local volumeMinutes = options and options.volumeMinutes or 15
    local held = options and options.held or 0
    local step = options and options.step or 1
    local count, cost = 0, 0
    local visible = 0
    for _, row in ipairs(rows) do visible = visible + row.quantity end
    local bookQuantity, refillPrice = 0, 0
    for _, row in ipairs(rows) do
        bookQuantity, refillPrice = bookQuantity + row.quantity, row.price
        if bookQuantity * 4 >= visible then break end
    end
    local cap = math.min(100, math.max(1, math.floor(visible / 5)),
        math.max(1, math.floor(market.soldPerDay * volumeMinutes / 1440))) - held
    local history = tonumber(market.median7d) or 0
    if history <= 0 then return end

    local best, lastTier
    for i = 1, #rows - 1 do
        local tier, nextTier = rows[i], rows[i + 1]
        -- A purchase cannot reliably clear this price level if it contains our own listings.
        if tier.own > 0 or (item.vendor and tier.price > item.vendor) then break end
        count = count + tier.quantity
        cost = cost + tier.price * tier.quantity
        if count > cap or cost > budget then break end

        local reference = direct and directPrice(nextTier.price - 1, history, item)
            or math.min(math.floor(math.min(nextTier.price - 1, history) * 95 / 100), item.vendor or math.huge)
        local minimumPost = addon.minimumPrice(cost, count, margin)
        local maximumPost = direct and reference or addon.priceForTrader(reference, count, margin)
        maximumPost = math.floor(maximumPost / step) * step
        if minimumPost <= maximumPost then
            local midpoint = math.floor((cost / count + reference) / 2)
            local post = direct and maximumPost or math.min(maximumPost, math.ceil(math.max(minimumPost, midpoint) / step) * step)
            local profit = afterFee(post * count) - cost
            local bulkFloor = math.min(post, refillPrice - step)
            local survivesRefill = count <= 20 or afterFee(bulkFloor * count) >= cost
            if survivesRefill and (not best or profit > best.profit) then
                lastTier = i
                best = {
                    quantity = count, maxUnit = tier.price, total = cost,
                    post = post, profit = profit, reference = reference, nextPrice = nextTier.price,
                    traderMargin = not direct and (afterFee(reference * count) - post * count) * 100 / (post * count) or nil,
                    direct = direct, minutes = volumeMinutes, salesPerDay = market.soldPerDay,
                }
            end
        end
    end
    if best then
        best.levels = {}
        for index = 1, lastTier do
            local tier = rows[index]
            best.levels[index] = { price = tier.price, quantity = tier.quantity }
        end
    end
    return best
end

function addon.findSingleDeal(asks, market, item, budget)
    local buy, nextAsk = asks[1], asks[2]
    local history = tonumber(market.median7d)
    if not buy or not nextAsk or not history or buy > budget or (item.vendor and buy > item.vendor) then return end
    local reference = math.min(nextAsk - 1, history, item.vendor or math.huge)
    local post = math.floor(reference * 85 / 100)
    local profit = afterFee(post) - buy
    if profit < math.ceil(buy * 20 / 100) then return end
    return { quantity = 1, maxUnit = buy, total = buy, post = post, profit = profit,
        reference = reference, nextPrice = nextAsk, single = true }
end

function addon.planSale(lot, lowest, marketPriceOnly)
    local market = addon.history(lot.item)
    local cost = lot.cost + (lot.lostDeposit or 0)
    local floorPrice = addon.minimumPrice(cost, lot.quantity, lot.directBuy and addon.marginPercent or 0)
    if not lowest or lowest <= floorPrice then return nil, floorPrice end
    local ceiling = lowest - 1
    local median = market and tonumber(market.median7d)
    local direct = lot.directBuy and directPrice(ceiling, median, addon.items[lot.item]) or ceiling
    if not marketPriceOnly then
        local trader = addon.priceForTrader(math.min(ceiling, median or ceiling), lot.quantity, addon.marginPercent)
        local target = math.min(ceiling, lot.target or trader, trader)
        local profitPrice = addon.minimumPrice(cost, lot.quantity, addon.marginPercent)
        if target >= profitPrice then return target, floorPrice end
    end
    if direct < floorPrice then return nil, floorPrice end
    return direct, floorPrice, true
end

function addon.exitSale(lot, lowest, step, allowLoss, matchCurrent)
    if not lowest then return end
    local price = math.floor((lowest - (matchCurrent and 0 or 1)) / step) * step
    if price <= 0 then return end
    local _, profit = addon.purchaseResult(lot, price)
    if profit >= 0 or allowLoss then return price, profit end
end
