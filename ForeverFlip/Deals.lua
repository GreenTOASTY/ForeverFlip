local _, addon = ...

local function afterFee(amount)
    return math.floor(amount * 95 / 100)
end

function addon.findDeal(rows, market, item, budget, margin)
    local count, cost = 0, 0
    local cap = math.floor(market.soldPerDay / 96)
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
        local reference = math.min(nextTier.price - 1, math.floor(history))
        if item.vendor then reference = math.min(reference, item.vendor) end
        local minimumPost = math.ceil(math.ceil(cost * (100 + margin) / 100) * 100 / (95 * count))
        local maximumPost = math.floor(afterFee(reference * count) * 100 / ((100 + margin) * count))
        if minimumPost <= maximumPost then
            local midpoint = math.floor((cost / count + reference) / 2)
            local post = math.min(maximumPost, math.max(minimumPost, midpoint))
            local profit = afterFee(post * count) - cost
            if not best or profit > best.profit then
                best = {
                    quantity = count, maxUnit = tier.price, total = cost,
                    post = post, profit = profit, reference = reference,
                    traderMargin = (afterFee(reference * count) - post * count) * 100 / (post * count),
                }
            end
        end
    end
    return best
end
