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
    -- Verbrauchsg�ter und Zwischenprodukte mit regelm��igem Absatz.
    [2459] = { "Hurtigkeitstrank", "Swiftness Potion" },
    [5634] = { "Trank der freien Aktion", "Free Action Potion" },
    [118] = { "Schwacher Heiltrank", "Minor Healing Potion" },
    [858] = { "Geringer Heiltrank", "Lesser Healing Potion" },
    [929] = { "Heiltrank", "Healing Potion" },
    [1710] = { "Gro�er Heiltrank", "Greater Healing Potion" },
    [2455] = { "Schwacher Manatrank", "Minor Mana Potion" },
    [3385] = { "Geringer Manatrank", "Lesser Mana Potion" },
    [3827] = { "Manatrank", "Mana Potion" },
    [6149] = { "Gro�er Manatrank", "Greater Mana Potion" },
    [2454] = { "Elixier der schwachen St�rke", "Elixir of Minor Strength" },
    [2457] = { "Elixier der schwachen Beweglichkeit", "Elixir of Minor Agility" },
    [5997] = { "Elixier der schwachen Verteidigung", "Elixir of Minor Defense" },
    [2452] = { "Flitzdistel", "Swiftthistle" },
    [6370] = { "Schwarzmaul�l", "Blackmouth Oil" },
    [6371] = { "Feuer�l", "Fire Oil" },
    [3577] = { "Goldbarren", "Gold Bar" },
    [2997] = { "Wollstoffballen", "Bolt of Woolen Cloth" },
    [4305] = { "Seidenstoffballen", "Bolt of Silk Cloth" },
    [4339] = { "Magiestoffballen", "Bolt of Mageweave" },
    [14048] = { "Runenstoffballen", "Bolt of Runecloth" },
    [6451] = { "Schwerer Seidenverband", "Heavy Silk Bandage" },
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
    local price = addon.history(id)
    if price and type(price.soldPerDay) == "number" and price.soldPerDay >= addon.minimumDailySales then
        return price
    end
end

function addon.history(id)
    local api = AHledgerAPI
    return api and api.GetPrice(id)
end
