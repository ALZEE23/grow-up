local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MixerUpdateEvent = ReplicatedStorage:WaitForChild("MixerUpdate") -- RemoteEvent
local ListItemCombine = {}
local InventoryManager = require(game.ServerScriptService.Server.InventoryManager)

-- Check ListItemCombine from ReplicatedStorage (only Food for now)
local ListItemCombineFolder = ReplicatedStorage:WaitForChild("ListItemCombine")
local ListItemFoodCombineFolder = ListItemCombineFolder:FindFirstChild("Food")
local ListItemBoosterCombineFolder = ListItemCombineFolder:FindFirstChild("Booster")

if not ListItemFoodCombineFolder then
    warn("[MixerManager] ListItemCombine/Food folder not found in ReplicatedStorage")
else
    for _, combineInfo in ipairs(ListItemFoodCombineFolder:GetChildren()) do
        local itemName = combineInfo.Name

        -- Get output from MeshPartOutput folder (safe check, don't WaitForChild)
        local outputFolder = combineInfo:FindFirstChild("MeshPartOutput")
        if not outputFolder then
            warn("[MixerManager] Recipe", itemName, "missing MeshPartOutput folder - skipping")
        else
            local outputMeshPart = outputFolder:GetChildren()[1]
            if not outputMeshPart then
                warn("[MixerManager] Recipe", itemName, "MeshPartOutput folder is empty - skipping")
            else
                -- store recipe info
                ListItemCombine[itemName] = {
                    MeshPartOutput = outputMeshPart,
                }

                -- Get all required ingredients (exclude MeshPartOutput folder)
                for _, child in ipairs(combineInfo:GetChildren()) do
                    if child.Name ~= "MeshPartOutput" then
                        -- store the instance under its name for later use
                        ListItemCombine[itemName][child.Name] = child
                    end
                end

                print("[MixerManager] Loaded Food recipe:", itemName, "-> output:", outputMeshPart.Name)
            end
        end
    end
end

if not ListItemBoosterCombineFolder then
    warn("[MixerManager] ListItemCombine/Booster folder not found in ReplicatedStorage")
else
    for _, combineInfo in ipairs(ListItemBoosterCombineFolder:GetChildren()) do
        local itemName = combineInfo.Name

        -- Get output from MeshPartOutput folder (safe check, don't WaitForChild)
        local outputFolder = combineInfo:FindFirstChild("MeshPartOutput")
        if not outputFolder then
            warn("[MixerManager] Recipe", itemName, "missing MeshPartOutput folder - skipping")
        else
            local outputMeshPart = outputFolder:GetChildren()[1]
            if not outputMeshPart then
                warn("[MixerManager] Recipe", itemName, "MeshPartOutput folder is empty - skipping")
            else
                -- store recipe info
                ListItemCombine[itemName] = {
                    MeshPartOutput = outputMeshPart,
                }

                -- Get all required ingredients (exclude MeshPartOutput folder)
                for _, child in ipairs(combineInfo:GetChildren()) do
                    if child.Name ~= "MeshPartOutput" then
                        -- store the instance under its name for later use
                        ListItemCombine[itemName][child.Name] = child
                    end
                end

                print("[MixerManager] Loaded Booster recipe:", itemName, "-> output:", outputMeshPart.Name)
            end
        end
    end
end

-- Handle combine request from client
MixerUpdateEvent.OnServerEvent:Connect(function(player, itemName)
    print("[MixerManager] Combining items for", player.Name, "to create", itemName)
    local combineInfo = ListItemCombine[itemName]
    if not combineInfo then
        warn("[MixerManager] No combine info found for item:", itemName)
        return
    end
    
    local inventory = InventoryManager.GetInventory(player)
    local requiredItems = {}
    local hasAllItems = true
    
    -- Collect all required items (excluding MeshPartOutput)
    for partName, meshPart in pairs(combineInfo) do
        if partName ~= "MeshPartOutput" then
            table.insert(requiredItems, meshPart.Name) -- Use the actual item name
        end
    end
    
    -- Check if player has all required items
    for _, requiredItemName in ipairs(requiredItems) do
        local hasItem = false
        for _, invItem in ipairs(inventory) do
            if invItem == requiredItemName then
                hasItem = true
                break
            end
        end
        
        if not hasItem then
            warn("[MixerManager] Player", player.Name, "is missing item:", requiredItemName)
            hasAllItems = false
        end
    end
    
    if not hasAllItems then
        return
    end
    
    -- Remove required items from inventory
    for _, requiredItemName in ipairs(requiredItems) do
        local itemIndex = table.find(inventory, requiredItemName)
        if itemIndex then
            table.remove(inventory, itemIndex)
            print("[MixerManager] Removed", requiredItemName, "from", player.Name, "'s inventory")
        end
    end
    
    -- Add the output item to inventory
    local outputItemName = combineInfo.MeshPartOutput.Name
    table.insert(inventory, outputItemName)
    
    -- PERBAIKAN: Update inventory immediately di client
    local UpdateInventoryEvent = ReplicatedStorage:WaitForChild("UpdateInventory")
    UpdateInventoryEvent:FireClient(player, inventory)
    
    InventoryManager.SavePlayerData(player)
    print("[MixerManager] Successfully combined items for", player.Name, "to create", outputItemName)
end)
