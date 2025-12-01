local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MixerUpdateEvent = ReplicatedStorage:WaitForChild("MixerUpdate") -- RemoteEvent
local ListItemCombine = {}
local InventoryManager = require(game.ServerScriptService.Server.InventoryManager)

local ListItemCombineFood = {}
local ListItemCombineBooster = {}

-- Check ListItemCombine from ReplicatedStorage (only Food for now)
local ListItemCombineFolder = ReplicatedStorage:WaitForChild("ListItemCombine")
local ListItemFoodCombineFolder = ListItemCombineFolder:FindFirstChild("Food")
local ListItemBoosterCombineFolder = ListItemCombineFolder:FindFirstChild("Booster")

-- Food recipes
if not ListItemFoodCombineFolder then
    warn("[MixerManager] ListItemCombine/Food folder not found in ReplicatedStorage")
else
    for _, combineInfo in ipairs(ListItemFoodCombineFolder:GetChildren()) do
        local itemName = combineInfo.Name

        local outputFolder = combineInfo:FindFirstChild("MeshPartOutput")
        if not outputFolder then
            warn("[MixerManager] Recipe", itemName, "missing MeshPartOutput folder - skipping")
        else
            local outputMeshPart = outputFolder:GetChildren()[1]
            if not outputMeshPart then
                warn("[MixerManager] Recipe", itemName, "MeshPartOutput folder is empty - skipping")
            else
                -- PERBAIKAN: Simpan sebagai array untuk handle duplikat
                ListItemCombineFood[itemName] = {
                    MeshPartOutput = outputMeshPart,
                    RequiredItems = {}  -- Array untuk menyimpan semua item (termasuk duplikat)
                }

                -- Get all required ingredients (exclude MeshPartOutput folder)
                for _, child in ipairs(combineInfo:GetChildren()) do
                    if child.Name ~= "MeshPartOutput" then
                        table.insert(ListItemCombineFood[itemName].RequiredItems, child.Name)
                    end
                end

                print("[MixerManager] Loaded Food recipe:", itemName, "-> output:", outputMeshPart.Name, "requires:", table.concat(ListItemCombineFood[itemName].RequiredItems, ", "))
            end
        end
    end
end

-- Booster recipes (sama seperti Food)
if not ListItemBoosterCombineFolder then
    warn("[MixerManager] ListItemCombine/Booster folder not found in ReplicatedStorage")
else
    for _, combineInfo in ipairs(ListItemBoosterCombineFolder:GetChildren()) do
        local itemName = combineInfo.Name

        local outputFolder = combineInfo:FindFirstChild("MeshPartOutput")
        if not outputFolder then
            warn("[MixerManager] Recipe", itemName, "missing MeshPartOutput folder - skipping")
        else
            local outputMeshPart = outputFolder:GetChildren()[1]
            if not outputMeshPart then
                warn("[MixerManager] Recipe", itemName, "MeshPartOutput folder is empty - skipping")
            else
                ListItemCombineBooster[itemName] = {
                    MeshPartOutput = outputMeshPart,
                    RequiredItems = {}
                }

                for _, child in ipairs(combineInfo:GetChildren()) do
                    if child.Name ~= "MeshPartOutput" then
                        table.insert(ListItemCombineBooster[itemName].RequiredItems, child.Name)
                    end
                end

                print("[MixerManager] Loaded Booster recipe:", itemName, "-> output:", outputMeshPart.Name, "requires:", table.concat(ListItemCombineBooster[itemName].RequiredItems, ", "))
            end
        end
    end
end

-- Handle combine request from client
MixerUpdateEvent.OnServerEvent:Connect(function(player, recipeName)
    print("[MixerManager] Combining items for", player.Name, "to create", recipeName)
    local combineInfo = ListItemCombineFood[recipeName] or ListItemCombineBooster[recipeName]
    if not combineInfo then
        warn("[MixerManager] No combine info found for item:", recipeName)
        return
    end
    
    local inventory = InventoryManager.GetInventory(player)
    local requiredItems = combineInfo.RequiredItems  -- <-- UBAH: Ambil dari array RequiredItems
    local hasAllItems = true
    
    print("[MixerManager] Recipe requires:", table.concat(requiredItems, ", "))
    print("[MixerManager] Player inventory before mix:", table.concat(inventory, ", "))
    
    -- Hitung jumlah kebutuhan tiap item
    local requiredCounts = {}
    for _, requiredItemName in ipairs(requiredItems) do
        requiredCounts[requiredItemName] = (requiredCounts[requiredItemName] or 0) + 1
    end
    
    print("[MixerManager] Required counts:", requiredCounts)
    
    -- Check if player has all required items
    local invCounts = {}
    for _, invItem in ipairs(inventory) do
        invCounts[invItem] = (invCounts[invItem] or 0) + 1
    end
    
    for reqItem, needed in pairs(requiredCounts) do
        if (invCounts[reqItem] or 0) < needed then
            warn("[MixerManager] Player", player.Name, "needs", needed, reqItem, "but only has", (invCounts[reqItem] or 0))
            hasAllItems = false
        end
    end
    
    if not hasAllItems then
        return
    end

    -- Hapus item dari inventory sesuai jumlah yang dibutuhkan
    for reqItemName, countNeeded in pairs(requiredCounts) do
        local removed = 0
        for i = #inventory, 1, -1 do
            if inventory[i] == reqItemName then
                table.remove(inventory, i)
                removed = removed + 1
                print("[MixerManager] Removed", reqItemName, "from", player.Name, "'s inventory (", removed, "/", countNeeded, ")")
                if removed == countNeeded then
                    break
                end
            end
        end
        if removed < countNeeded then
            warn("[MixerManager] Not enough", reqItemName, "to remove from inventory for", player.Name)
        end
    end
    
    print("[MixerManager] Player inventory after removal:", table.concat(inventory, ", "))
    
    -- Add the output item to inventory
    local outputItemName = combineInfo.MeshPartOutput.Name
    table.insert(inventory, outputItemName)
    
    print("[MixerManager] Player inventory after adding result:", table.concat(inventory, ", "))
    
    local UpdateInventoryEvent = ReplicatedStorage:WaitForChild("UpdateInventory")
    UpdateInventoryEvent:FireClient(player, inventory)
    
    InventoryManager.SavePlayerData(player)
    print("[MixerManager] Successfully combined items for", player.Name, "to create", outputItemName)
end)
