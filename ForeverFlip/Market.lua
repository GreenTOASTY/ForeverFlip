local _, addon = ...

-- Startliste. Der aktuelle AHledger-Absatz entscheidet, welche Artikel hineinkommen.
addon.items = {
    [2589] = { "Leinenstoff", "Linen Cloth" },
    [2592] = { "Wollstoff", "Wool Cloth", noCheaperVendor = true },
    [4306] = { "Seidenstoff", "Silk Cloth" },
    [4338] = { "Magiestoff", "Mageweave Cloth" },
    [14047] = { "Runenstoff", "Runecloth" },
    [2770] = { "Kupfererz", "Copper Ore", noCheaperVendor = true },
    [2771] = { "Zinnerz", "Tin Ore" },
    [2772] = { "Eisenerz", "Iron Ore" },
    [3858] = { "Mithrilerz", "Mithril Ore" },
    [10620] = { "Thoriumerz", "Thorium Ore" },
    [2840] = { "Kupferbarren", "Copper Bar" },
    [3576] = { "Zinnbarren", "Tin Bar" },
    [2841] = { "Bronzebarren", "Bronze Bar" },
    [3575] = { "Eisenbarren", "Iron Bar" },
    [3860] = { "Mithrilbarren", "Mithril Bar" },
    [12359] = { "Thoriumbarren", "Thorium Bar" },
    [2318] = { "Leichtes Leder", "Light Leather" },
    [2319] = { "Mittleres Leder", "Medium Leather" },
    [4234] = { "Schweres Leder", "Heavy Leather" },
    [4304] = { "Dickes Leder", "Thick Leather" },
    [8170] = { "Unverw�stliches Leder", "Rugged Leather", vendor = 2000 },
    [2447] = { "Friedensblume", "Peacebloom" },
    [765] = { "Silberblatt", "Silverleaf" },
    [2449] = { "Erdwurzel", "Earthroot", vendor = 72 },
    [785] = { "Magusk�nigskraut", "Mageroyal" },
    [2450] = { "Wilddornrose", "Briarthorn" },
    [3356] = { "K�nigsblut", "Kingsblood" },
    [3820] = { "W�rgetang", "Stranglekelp" },
    [4625] = { "Feuerbl�te", "Firebloom" },
    [13464] = { "Goldener Sansam", "Golden Sansam" },
    [13465] = { "Bergsilbersalbei", "Mountain Silversage" },
    [10940] = { "Seltsamer Staub", "Strange Dust" },
    [11083] = { "Seelenstaub", "Soul Dust" },
    [11137] = { "Visionsstaub", "Vision Dust" },
    [11176] = { "Traumstaub", "Dream Dust" },
    [16204] = { "Illusionsstaub", "Illusion Dust" },
    [2835] = { "Rauer Stein", "Rough Stone" },
    [2836] = { "Grober Stein", "Coarse Stone", noCheaperVendor = true },
    [2838] = { "Schwerer Stein", "Heavy Stone" },
    [7912] = { "Robuster Stein", "Solid Stone" },
    [12365] = { "Verdichteter Stein", "Dense Stone" },
}

addon.minimumDailySales = 1000
addon.marginPercent = 5

function addon.itemName(id)
    if GetItemInfo then
        local name = GetItemInfo(id)
        if name then return name end
    end
    return addon.items[id][GetLocale() == "deDE" and 1 or 2]
end

function addon.marketPrice(id)
    local api = AHledgerAPI
    local price = api and api.GetPrice(id)
    if price and type(price.soldPerDay) == "number" and price.soldPerDay >= addon.minimumDailySales then
        return price
    end
end
