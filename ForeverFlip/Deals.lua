local _, addon = ...

local function afterFee(amount)
    return math.floor(amount * 95 / 100)
end

function addon.minimumPrice(cost, count, margin)
    return math.ceil(math.ceil(cost * (100 + margin) / 100) * 100 / (95 * count))
end

function addon.priceForTrader(reference, count, margin)
    return math.floor(afterFee(reference * count) * 100 / ((100 + margin) * count))
end

function addon.findDeal(rows, market, item, budget, margin)
    local count, cost = 0, 0
    local cap = math.max(1, math.floor(market.soldPerDay / 96))
    local history = tonumber(market.median7d) or 0
    if history <= 0 then return end

    local best
    for i = 1, #rows - 1 do
        local tier, nextTier = rows[i], rows[i + 1]
        -- A purchase cannot reliably clear this price level if it contains our own listings.
        if tier.own > 0 or (item.vendor and tier.price > item.vendor) then break end
        count = count + tier.quantity
        cost = cost + tier.price * tier.quantity
        if count > cap or cost > budget then break end

        -- Leave one copper for the next trader to undercut the remaining floor.
        local reference = math.floor(math.min(nextTier.price - 1, history) * 95 / 100)
        if item.vendor then reference = math.min(reference, item.vendor) end
        local minimumPost = addon.minimumPrice(cost, count, margin)
        local maximumPost = addon.priceForTrader(reference, count, margin)
        if minimumPost <= maximumPost then
            local midpoint = math.floor((cost / count + reference) / 2)
            local post = math.min(maximumPost, math.max(minimumPost, midpoint))
            local profit = afterFee(post * count) - cost
            if not best or profit > best.profit then
                best = {
                    quantity = count, maxUnit = tier.price, total = cost,
                    post = post, profit = profit, reference = reference, nextPrice = nextTier.price,
                    traderMargin = (afterFee(reference * count) - post * count) * 100 / (post * count),
                }
            end
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
    local floorPrice = addon.minimumPrice(cost, lot.quantity, 0)
    if not lowest or lowest <= floorPrice then return nil, floorPrice end
    local ceiling = lowest - 1
    if marketPriceOnly then return ceiling, floorPrice, true end
    local reference = math.min(ceiling, market and market.median7d or ceiling)
    local trader = addon.priceForTrader(reference, lot.quantity, addon.marginPercent)
    local target = math.min(ceiling, lot.target or trader, trader)
    local profitPrice = addon.minimumPrice(cost, lot.quantity, addon.marginPercent)
    if target >= profitPrice then return target, floorPrice end
    return ceiling, floorPrice, true
end
