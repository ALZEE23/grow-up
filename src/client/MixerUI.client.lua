local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DropItemsFolder = ReplicatedStorage:WaitForChild("DropItems")
local UpdateInventoryEvent = ReplicatedStorage:WaitForChild("UpdateInventory")
local MixerUpdateEvent = ReplicatedStorage:WaitForChild("MixerUpdate")
local ItemSlotTemplate = ReplicatedStorage.UI:WaitForChild("SlotTemplate")

-- Get UI elements
local mixerGui = playerGui:WaitForChild("Mixer")
local mixerScreen = mixerGui:WaitForChild("Mixer")
local closeButton = mixerScreen:WaitForChild("BackButton")
local result = mixerScreen:WaitForChild("Result")
local scrollingFrame = mixerScreen:WaitForChild("ScrollingFrame")
local mixButton = mixerScreen:WaitForChild("MixButton")

print("[MixerUI] Mixer UI elements loaded successfully")

-- Material slots (Image labels for ingredients)
local materialSlots = {
    mixerScreen:WaitForChild("Material1"), -- ImageLabel pertama
    mixerScreen:WaitForChild("Material2"), -- ImageLabel kedua
    mixerScreen:WaitForChild("Material3")  -- ImageLabel ketiga
}

print("[MixerUI] Material slots found:", #materialSlots)

-- Track what items are in material slots
local materialItems = {nil, nil, nil}
local inventoryData = {}

-- Function to check and show recipe result preview
local function checkRecipeResult()
    -- Clear result preview first
    for _, child in ipairs(result:GetChildren()) do
        if child:IsA("ViewportFrame") then
            child:Destroy()
        end
    end
    
    -- Get current materials
    local materialsToMix = {}
    for _, item in ipairs(materialItems) do
        if item then
            table.insert(materialsToMix, item)
        end
    end
    
    -- PERBAIKAN: Hapus minimum requirement, biarkan 1 item juga bisa dicek
    if #materialsToMix < 1 then 
        return
    end
    
    print("[MixerUI] Current materials to check:", materialsToMix)
    
    -- Try to find matching recipe
    local ListItemCombineFolder = ReplicatedStorage:WaitForChild("ListItemCombine")
    for _, combineInfo in ipairs(ListItemCombineFolder:GetChildren()) do
        local recipeName = combineInfo.Name
        
        -- Check if current materials match this recipe
        local requiredItems = {}
        for _, child in ipairs(combineInfo:GetChildren()) do
            if child.Name ~= "MeshPartOutput" then
                table.insert(requiredItems, child.Name)
            end
        end
        
        print("[MixerUI] Checking recipe:", recipeName, "requires:", requiredItems, "count:", #requiredItems)
        print("[MixerUI] Current materials:", materialsToMix, "count:", #materialsToMix)
        
        -- PERBAIKAN: Exact match untuk jumlah dan item
        if #requiredItems == #materialsToMix then
            -- Create copies untuk manipulation
            local tempRequired = {}
            for _, item in ipairs(requiredItems) do
                table.insert(tempRequired, item)
            end
            
            local tempMaterials = {}
            for _, item in ipairs(materialsToMix) do
                table.insert(tempMaterials, item)
            end
            
            -- Check if all materials match (handle duplicates)
            local allMatch = true
            for _, material in ipairs(tempMaterials) do
                local foundIndex = table.find(tempRequired, material)
                if foundIndex then
                    table.remove(tempRequired, foundIndex) -- Remove to handle duplicates
                    print("[MixerUI] Found matching material:", material)
                else
                    allMatch = false
                    print("[MixerUI] Material not found in recipe:", material)
                    break
                end
            end
            
            if allMatch and #tempRequired == 0 then -- Ensure all required items are matched
                print("[MixerUI] RECIPE MATCH FOUND:", recipeName)
                
                -- Show result preview
                local outputFolder = combineInfo:WaitForChild("MeshPartOutput")
                local outputMeshPart = outputFolder:GetChildren()[1]
                
                if outputMeshPart then
                    local viewport = Instance.new("ViewportFrame")
                    viewport.Size = UDim2.new(1, 0, 1, 0)
                    viewport.BackgroundTransparency = 1
                    viewport.Parent = result
                    
                    -- Get model from DropItems
                    local model = DropItemsFolder:FindFirstChild(outputMeshPart.Name)
                    if model then
                        model = model:Clone()
                        model.Parent = viewport
                        
                        -- PERBAIKAN: Setup camera lebih dekat (2x zoom) untuk result
                        local cam = Instance.new("Camera")
                        cam.CFrame = CFrame.new(Vector3.new(0, 0, 3), Vector3.new(0, 0, 0)) -- Dari 6 jadi 3
                        cam.Parent = viewport
                        viewport.CurrentCamera = cam
                        
                        model:PivotTo(CFrame.new(0, 0, 0))
                        viewport.Ambient = Color3.new(1, 1, 1)
                        viewport.LightDirection = Vector3.new(0, -1, -1)
                        
                        print("[MixerUI] Showing result preview:", outputMeshPart.Name)
                    else
                        warn("[MixerUI] Output model not found in DropItems:", outputMeshPart.Name)
                    end
                end
                return
            else
                print("[MixerUI] Recipe failed - allMatch:", allMatch, "remaining required:", tempRequired)
            end
        else
            print("[MixerUI] Recipe failed - wrong count. Required:", #requiredItems, "Have:", #materialsToMix)
        end
    end
    
    print("[MixerUI] No matching recipe found for current materials")
end

-- Function to add item to next available material slot
local function addToMaterialSlot(itemName)
    print("[MixerUI] Attempting to add", itemName, "to material slot")
    for i, slot in ipairs(materialSlots) do
        if not materialItems[i] then -- Slot kosong
            materialItems[i] = itemName
            
            -- Create viewport in the ImageLabel to show 3D item
            local viewport = Instance.new("ViewportFrame")
            viewport.Size = UDim2.new(1, 0, 1, 0)
            viewport.BackgroundTransparency = 1
            viewport.Parent = slot
            
            -- Get model from DropItems
            local model = DropItemsFolder:FindFirstChild(itemName)
            if model then
                model = model:Clone()
                model.Parent = viewport
                
                -- PERBAIKAN: Setup camera lebih dekat (2x zoom)
                local cam = Instance.new("Camera")
                cam.CFrame = CFrame.new(Vector3.new(0, 0, 3), Vector3.new(0, 0, 0)) -- Dari 6 jadi 3
                cam.Parent = viewport
                viewport.CurrentCamera = cam
                
                model:PivotTo(CFrame.new(0, 0, 0))
                viewport.Ambient = Color3.new(1, 1, 1)
                viewport.LightDirection = Vector3.new(0, -1, -1)
                
                print("[MixerUI] Successfully added", itemName, "to material slot", i)
                
                -- Check for recipe result after adding item
                checkRecipeResult()
                return true
            else
                print("[MixerUI] Model not found in DropItems:", itemName)
            end
        end
    end
    print("[MixerUI] All material slots are full")
    return false -- Semua slot penuh
end

-- Function to remove item from material slot
local function removeFromMaterialSlot(slotIndex)
    if materialItems[slotIndex] then
        local removedItem = materialItems[slotIndex]
        materialItems[slotIndex] = nil
        
        -- Clear the viewport
        local slot = materialSlots[slotIndex]
        for _, child in ipairs(slot:GetChildren()) do
            if child:IsA("ViewportFrame") then
                child:Destroy()
            end
        end
        
        print("[MixerUI] Removed", removedItem, "from material slot", slotIndex)
        
        -- Check for recipe result after removing item
        checkRecipeResult()
        return removedItem
    end
    return nil
end

-- Close button functionality
closeButton.MouseButton1Click:Connect(function()
    print("[MixerUI] Close button clicked")
    mixerScreen.Visible = false -- Hide mixer UI
    
    -- Optional: Clear all material slots when closing
    for i = 1, 3 do
        removeFromMaterialSlot(i)
    end
end)

-- Setup double-click removal for material slots
for i, slot in ipairs(materialSlots) do
    local clickCount = 0
    local lastClickTime = 0
    
    slot.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local currentTime = tick()
            
            if currentTime - lastClickTime < 0.5 then -- Double click dalam 0.5 detik
                clickCount = clickCount + 1
                if clickCount >= 2 then
                    removeFromMaterialSlot(i)
                    clickCount = 0
                end
            else
                clickCount = 1
            end
            
            lastClickTime = currentTime
        end
    end)
end

-- Update inventory items in mixer UI (sama seperti InventoryUI)
UpdateInventoryEvent.OnClientEvent:Connect(function(newInventoryData)
    print("[MixerUI] ========== MIXER UPDATE START ==========")
    print("[MixerUI] Received inventory data:", newInventoryData)
    print("[MixerUI] Inventory data type:", type(newInventoryData))
    print("[MixerUI] Inventory data length:", #newInventoryData)
    
    inventoryData = newInventoryData
    
    -- Debug: Print each item
    for i, itemName in ipairs(inventoryData) do
        print("[MixerUI] Item", i, ":", itemName)
    end
    
    -- Group items by count (sama seperti InventoryUI)
    local itemCounts = {}
    for _, itemName in ipairs(inventoryData) do
        itemCounts[itemName] = (itemCounts[itemName] or 0) + 1
    end
    
    print("[MixerUI] Grouped item counts:")
    for itemName, count in pairs(itemCounts) do
        print("  -", itemName, ":", count .. "x")
    end
    
    -- Clear existing inventory items in mixer
    print("[MixerUI] Clearing existing slots...")
    local clearedCount = 0
    for _, child in ipairs(scrollingFrame:GetChildren()) do
        if child:IsA("TextButton") and child.Name:find("_Slot") then
            child:Destroy()
            clearedCount = clearedCount + 1
        end
    end
    print("[MixerUI] Cleared", clearedCount, "existing slots")
    
    -- Create inventory slots in mixer UI (sama seperti InventoryUI)
    local createdCount = 0
    for itemName, count in pairs(itemCounts) do
        print("[MixerUI] Creating slot for:", itemName, "with count:", count)
        
        local slot = ItemSlotTemplate:Clone()
        slot.Name = itemName .. "_Slot"
        slot.Parent = scrollingFrame
        slot.Visible = true -- Ensure it's visible
        createdCount = createdCount + 1
        
        print("[MixerUI] Slot created:", slot.Name, "Parent:", slot.Parent.Name)
        
        -- Setup viewport for 3D model
        local viewport = slot:WaitForChild("ViewportFrame")
        print("[MixerUI] Found viewport for", itemName)
        
        -- Clear viewport
        for _, obj in ipairs(viewport:GetChildren()) do
            if not obj:IsA("UIStroke") and not obj:IsA("UICorner") then
                obj:Destroy()
            end
        end
        
        -- Add model
        local model = DropItemsFolder:FindFirstChild(itemName)
        if model then
            print("[MixerUI] Found model in DropItems:", itemName)
            model = model:Clone()
            model.Parent = viewport
            
            local cam = Instance.new("Camera")
            cam.CFrame = CFrame.new(Vector3.new(0, 0, 6), Vector3.new(0, 0, 0))
            cam.Parent = viewport
            viewport.CurrentCamera = cam
            
            model:PivotTo(CFrame.new(0, 0, 0))
            viewport.BackgroundTransparency = 1
            viewport.Ambient = Color3.new(1, 1, 1)
            viewport.LightDirection = Vector3.new(0, -1, -1)
            print("[MixerUI] Model setup complete for", itemName)
        else
            warn("[MixerUI] Model not found in DropItems:", itemName)
            print("[MixerUI] Available models in DropItems:")
            for _, child in ipairs(DropItemsFolder:GetChildren()) do
                print("  -", child.Name)
            end
        end
        
        -- Update item count
        local itemCount = slot:FindFirstChild("ItemCount")
        if itemCount then
            itemCount.Text = count .. "x"
            print("[MixerUI] Set item count:", count .. "x")
        else
            warn("[MixerUI] ItemCount label not found in slot")
        end
        
        -- Update item name
        local nameLabel = slot:FindFirstChild("ItemName")
        if nameLabel then
            nameLabel.Text = itemName
            print("[MixerUI] Set item name:", itemName)
        else
            warn("[MixerUI] ItemName label not found in slot")
        end
        
        -- Click event to add to material slot
        slot.MouseButton1Click:Connect(function()
            print("[MixerUI] Item clicked:", itemName)
            
            -- PERBAIKAN: Check if we have enough of this item
            local currentCount = 0
            for _, slotItem in ipairs(materialItems) do
                if slotItem == itemName then
                    currentCount = currentCount + 1
                end
            end
            
            -- Check available count in inventory
            local availableCount = count -- This is from the itemCounts
            
            if currentCount >= availableCount then
                print("[MixerUI] Cannot add more", itemName, "- only have", availableCount, "but trying to use", currentCount + 1)
                return
            end
            
            if addToMaterialSlot(itemName) then
                print("[MixerUI] Successfully added", itemName, "to material slots")
            else
                print("[MixerUI] Failed to add", itemName, "- All material slots are full!")
            end
        end)
        
        print("[MixerUI] Slot setup complete for:", itemName)
    end
    
    print("[MixerUI] Created", createdCount, "new slots")
    print("[MixerUI] Current children in scrollingFrame:")
    for i, child in ipairs(scrollingFrame:GetChildren()) do
        print("  -", i, child.Name, child.ClassName, "Visible:", child.Visible)
    end
    
    print("[MixerUI] ========== MIXER UPDATE END ==========")
end)

-- Mix button functionality
mixButton.MouseButton1Click:Connect(function()
    print("[MixerUI] Mix button clicked!")
    -- Check if we have any materials
    local materialsToMix = {}
    for _, item in ipairs(materialItems) do
        if item then
            table.insert(materialsToMix, item)
        end
    end
    
    print("[MixerUI] Materials to mix:", materialsToMix)
    
    if #materialsToMix == 0 then
        print("[MixerUI] No materials to mix!")
        return
    end
    
    -- Try to find matching recipe
    local ListItemCombineFolder = ReplicatedStorage:WaitForChild("ListItemCombine")
    for _, combineInfo in ipairs(ListItemCombineFolder:GetChildren()) do
        local recipeName = combineInfo.Name
        
        -- Check if current materials match this recipe
        local requiredItems = {}
        for _, child in ipairs(combineInfo:GetChildren()) do
            if child.Name ~= "MeshPartOutput" then
                table.insert(requiredItems, child.Name)
            end
        end
        
        print("[MixerUI] Checking recipe:", recipeName, "requires:", requiredItems)
        
        -- Simple check if materials match
        if #requiredItems == #materialsToMix then
            local allMatch = true
            for _, required in ipairs(requiredItems) do
                local found = false
                for _, material in ipairs(materialsToMix) do
                    if material == required then
                        found = true
                        break
                    end
                end
                if not found then
                    allMatch = false
                    break
                end
            end
            
            if allMatch then
                print("[MixerUI] Found matching recipe:", recipeName)
                MixerUpdateEvent:FireServer(recipeName)
                
                -- Clear material slots
                for i = 1, 3 do
                    removeFromMaterialSlot(i)
                end
                return
            end
        end
    end
    
    print("[MixerUI] No matching recipe found for these materials!")
end)

print("[MixerUI] Script loaded successfully")

-- Request initial inventory when mixer UI loads
local GetInventoryEvent = ReplicatedStorage:WaitForChild("GetInventory")
print("[MixerUI] Requesting initial inventory...")
GetInventoryEvent:FireServer()