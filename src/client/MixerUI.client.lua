local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DropItemsFolder = ReplicatedStorage:WaitForChild("DropItems")
local UpdateInventoryEvent = ReplicatedStorage:WaitForChild("UpdateInventory")
local MixerUpdateEvent = ReplicatedStorage:WaitForChild("MixerUpdate")
local ItemSlotTemplate = ReplicatedStorage.UI:WaitForChild("SlotTemplate")
local ListItemCombineFolder = ReplicatedStorage:WaitForChild("ListItemCombine")

-- PERBAIKAN: Variables untuk track state dan connections
local materialItems = {nil, nil, nil}
local inventoryData = {}
local currentConnections = {}
local mixerInitialized = false
local isBoosterMode = false
local isFoodMode = true

local updateMixerListRecipe -- forward declaration

-- PERBAIKAN: Function to safely disconnect all connections
local function disconnectAll()
    for _, connection in pairs(currentConnections) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    currentConnections = {}
    print("[MixerUI] Disconnected all connections")
end

-- PERBAIKAN: Function to get fresh UI elements (always current)
local function getFreshMixerElements()
    local mixerGui = playerGui:FindFirstChild("Mixer")
    if not mixerGui then return nil end
    
    local mixerScreen = mixerGui:FindFirstChild("Mixer")
    if not mixerScreen then return nil end
    
    return {
        mixerGui = mixerGui,
        mixerScreen = mixerScreen,
        foodButton = mixerScreen:FindFirstChild("FoodButton"),
        boosterButton = mixerScreen:FindFirstChild("BoosterButton"),
        labelName = mixerScreen:FindFirstChild("LabelName"),
        labelRarity = mixerScreen:FindFirstChild("LabelRarity"),
        labelElement = mixerScreen:FindFirstChild("LabelElement"),
        closeButton = mixerScreen:FindFirstChild("BackButton"),
        result = mixerScreen:FindFirstChild("Result"),
        scrollingFrame = mixerScreen:FindFirstChild("ScrollingFrame"),
        mixButton = mixerScreen:FindFirstChild("MixButton"),
        materialSlots = {
            mixerScreen:FindFirstChild("Material1"),
            mixerScreen:FindFirstChild("Material2"),
            mixerScreen:FindFirstChild("Material3")
        }
    }
end

-- PERBAIKAN: Function to setup all mixer functionality
local function setupMixerFunctionality()
    print("[MixerUI] Setting up mixer functionality...")
    
    -- Clear previous state
    materialItems = {nil, nil, nil}
    disconnectAll()
    
    local elements = getFreshMixerElements()
    if not elements or not elements.closeButton or not elements.result or 
       not elements.scrollingFrame or not elements.mixButton or
       not elements.materialSlots[1] or not elements.materialSlots[2] or not elements.materialSlots[3] then
        warn("[MixerUI] Failed to get mixer elements")
        return false
    end

    
    
    -- local mixerScreen = elements.mixerScreen
    local closeButton = elements.closeButton
    local foodButton = elements.foodButton
    local boosterButton = elements.boosterButton
    local slotCreatedCount = 0
    -- local result = elements.result
    -- local scrollingFrame = elements.scrollingFrame
    local mixButton = elements.mixButton
    local materialSlots = elements.materialSlots

    print("[MixerUI] All mixer elements found successfully")

    -- Function to check and show recipe result preview
    local function checkRecipeResult()
        -- Get fresh elements for result
        local freshElements = getFreshMixerElements()
        if not freshElements or not freshElements.result then return end
        local currentResult = freshElements.result
        
        -- Clear result preview first
        for _, child in ipairs(currentResult:GetChildren()) do
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
        
        if #materialsToMix < 1 then 
            -- No materials, disable mix button and make it gray/transparan
            if freshElements.mixButton then
                freshElements.mixButton.Interactable = false
                freshElements.mixButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)  -- Gray
                freshElements.mixButton.BackgroundTransparency = 0.5  -- Transparan
            end
            return
        end
        
        print("[MixerUI] Current materials to check:", materialsToMix)
        
        -- Default: disable mix button and make it gray/transparan
        if freshElements.mixButton then
            freshElements.mixButton.Interactable = false
            freshElements.mixButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)  -- Gray
            freshElements.mixButton.BackgroundTransparency = 0.5  -- Transparan
        end
        
        -- Try to find matching recipe
        local ListItemCombineTargetFolder
        if isFoodMode then
            ListItemCombineTargetFolder = ListItemCombineFolder:WaitForChild("Food")
        elseif isBoosterMode then
            ListItemCombineTargetFolder = ListItemCombineFolder:WaitForChild("Booster")
        else
            warn("[MixerUI] Tidak ada mode aktif!")
            return
        end

        for _, combineInfo in ipairs(ListItemCombineTargetFolder:GetChildren()) do
            local recipeName = combineInfo.Name
            
            -- Check if current materials match this recipe
            local requiredItems = {}
            for _, child in ipairs(combineInfo:GetChildren()) do
                if child.Name ~= "MeshPartOutput" then
                    table.insert(requiredItems, child.Name)
                end
            end
            
            if #requiredItems == #materialsToMix then
                local tempRequired = {}
                for _, item in ipairs(requiredItems) do
                    table.insert(tempRequired, item)
                end
                
                local tempMaterials = {}
                for _, item in ipairs(materialsToMix) do
                    table.insert(tempMaterials, item)
                end
                
                local allMatch = true
                for _, material in ipairs(tempMaterials) do
                    local foundIndex = table.find(tempRequired, material)
                    if foundIndex then
                        table.remove(tempRequired, foundIndex)
                    else
                        allMatch = false
                        break
                    end
                end
                
                if allMatch and #tempRequired == 0 then
                    print("[MixerUI] RECIPE MATCH FOUND:", recipeName)
                    
                    -- Check if player has enough items in inventory
                    local invCounts = {}
                    for _, item in ipairs(inventoryData) do
                        invCounts[item] = (invCounts[item] or 0) + 1
                    end
                    
                    local hasEnough = true
                    for _, reqItem in ipairs(requiredItems) do
                        if (invCounts[reqItem] or 0) < 1 then
                            hasEnough = false
                            break
                        end
                    end
                    
                    -- Enable mix button and make it normal if has enough items
                    if freshElements.mixButton then
                        freshElements.mixButton.Interactable = hasEnough
                        if hasEnough then
                            freshElements.mixButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)  -- Normal
                            freshElements.mixButton.BackgroundTransparency = 0  -- Normal opacity
                        else
                            freshElements.mixButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)  -- Gray
                            freshElements.mixButton.BackgroundTransparency = 0.5  -- Transparan
                        end
                        print("[MixerUI] Mix button interactable:", hasEnough)
                    end
                    
                    local outputFolder = combineInfo:WaitForChild("MeshPartOutput")
                    local outputMeshPart = outputFolder:GetChildren()[1]
                    
                    if outputMeshPart then
                        local viewport = Instance.new("ViewportFrame")
                        viewport.Size = UDim2.new(1, 0, 1, 0)
                        viewport.BackgroundTransparency = 1
                        viewport.Parent = currentResult
                        
                        local foodItemsFolder = DropItemsFolder:FindFirstChild("FoodItems")
                        
                        if foodItemsFolder then
                            local model = foodItemsFolder:FindFirstChild(outputMeshPart.Name)
                            
                            if model then
                                model = model:Clone()
                                model.Parent = viewport
                            
                                -- Ambil MeshPart di dalam model
                                local rarity = "Unknown"
                                local element = "Neutral"

                                if model then
                                    rarity = model:GetAttribute("rarity") or "Unknown"
                                    element = model:GetAttribute("element") or "Neutral"
                                end
                            
                                -- Update label
                                if freshElements.labelName then
                                    freshElements.labelName.Text = model.Name
                                end
                                if freshElements.labelRarity then
                                    freshElements.labelRarity.Text = "Rarity: " .. rarity
                                end
                                if freshElements.labelElement then
                                    freshElements.labelElement.Text = "Element: " .. element
                                end
                                
                                local cam = Instance.new("Camera")
                                cam.CFrame = CFrame.new(Vector3.new(0, 0, 3), Vector3.new(0, 0, 0))
                                cam.Parent = viewport
                                viewport.CurrentCamera = cam

                                model:PivotTo(CFrame.new(0, 0, 0))
                                viewport.Ambient = Color3.new(1, 1, 1)
                                viewport.LightDirection = Vector3.new(0, -1, -1)
                                
                                print("[MixerUI] Showing result preview:", outputMeshPart.Name, "- Rarity:", rarity, "- Element:", element)
                            else
                                warn("[MixerUI] Model not found in FoodItems:", outputMeshPart.Name)
                            end
                        else
                            warn("[MixerUI] FoodItems folder not found")
                        end
                    end
                    return
                end
            end
        end
    end

    -- Function to add item to next available material slot
    local function addToMaterialSlot(itemName)
        print("[MixerUI] Attempting to add", itemName, "to material slot")
        
        -- Get fresh material slots
        local freshElements = getFreshMixerElements()
        if not freshElements or not freshElements.materialSlots then return false end
        local currentMaterialSlots = freshElements.materialSlots
        
        for i, slot in ipairs(currentMaterialSlots) do
            if not materialItems[i] then
                materialItems[i] = itemName
                
                local viewport = Instance.new("ViewportFrame")
                viewport.Size = UDim2.new(1, 0, 1, 0)
                viewport.BackgroundTransparency = 1
                viewport.Parent = slot
                
                local model = DropItemsFolder:FindFirstChild(itemName)
                if model then
                    model = model:Clone()
                    model.Parent = viewport
                    
                    local cam = Instance.new("Camera")
                    cam.CFrame = CFrame.new(Vector3.new(0, 0, 3), Vector3.new(0, 0, 0))
                    cam.Parent = viewport
                    viewport.CurrentCamera = cam
                    
                    model:PivotTo(CFrame.new(0, 0, 0))
                    viewport.Ambient = Color3.new(1, 1, 1)
                    viewport.LightDirection = Vector3.new(0, -1, -1)
                    
                    print("[MixerUI] Successfully added", itemName, "to material slot", i)
                    
                    checkRecipeResult()
                    return true
                end
            end
        end
        print("[MixerUI] All material slots are full")
        return false
    end

    -- Function to remove item from material slot
    local function removeFromMaterialSlot(slotIndex)
        if materialItems[slotIndex] then
            local removedItem = materialItems[slotIndex]
            materialItems[slotIndex] = nil
            
            -- Get fresh material slots
            local freshElements = getFreshMixerElements()
            if freshElements and freshElements.materialSlots and freshElements.materialSlots[slotIndex] then
                local slot = freshElements.materialSlots[slotIndex]
                for _, child in ipairs(slot:GetChildren()) do
                    if child:IsA("ViewportFrame") then
                        child:Destroy()
                    end
                end
            end
            
            print("[MixerUI] Removed", removedItem, "from material slot", slotIndex)
            checkRecipeResult()
            return removedItem
        end
        return nil
    end

    -- PERBAIKAN: Setup connections dengan fresh references
    local function setupConnections()
        -- Close button
        if closeButton then
            currentConnections["closeButton"] = closeButton.MouseButton1Click:Connect(function()
                print("[MixerUI] Close button clicked")
                local freshElements = getFreshMixerElements()
                if freshElements and freshElements.mixerScreen then
                    freshElements.mixerScreen.Visible = false
                end
                
                for i = 1, 3 do
                    removeFromMaterialSlot(i)
                end
            end)
        end

        if foodButton then
            currentConnections["foodButton"] = foodButton.MouseButton1Click:Connect(function()
                isFoodMode = true
                isBoosterMode = false
                updateMixerListRecipe(inventoryData) -- <-- WAJIB DIPANGGIL!
                print("[MixerUI] Food button clicked")
            end)
        end

        if boosterButton then
            currentConnections["boosterButton"] = boosterButton.MouseButton1Click:Connect(function()
                isBoosterMode = true
                isFoodMode = false
                updateMixerListRecipe(inventoryData) -- <-- WAJIB DIPANGGIL!
                print("[MixerUI] Booster button clicked")
            end)
        end
        
        -- Material slots double-click
        for i, slot in ipairs(materialSlots) do
            if slot then
                local clickCount = 0
                local lastClickTime = 0
                
                currentConnections["materialSlot" .. i] = slot.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local currentTime = tick()
                        
                        if currentTime - lastClickTime < 0.5 then
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
        end
        
        -- Mix button
        if mixButton then
            currentConnections["mixButton"] = mixButton.MouseButton1Click:Connect(function()
                print("[MixerUI] Mix button clicked!")
                local materialsToMix = {}
                for _, item in ipairs(materialItems) do
                    if item then
                        table.insert(materialsToMix, item)
                    end
                end
                
                if #materialsToMix == 0 then
                    print("[MixerUI] No materials to mix!")
                    return
                end
                
                -- Find matching recipe
                local ListItemFoodCombineFolder = ListItemCombineFolder:WaitForChild("Food")  -- UBAH: Gunakan Food folder
                for _, combineInfo in ipairs(ListItemFoodCombineFolder:GetChildren()) do  -- UBAH: Loop melalui Food children
                    local recipeName = combineInfo.Name
                    
                    local requiredItems = {}
                    for _, child in ipairs(combineInfo:GetChildren()) do
                        if child.Name ~= "MeshPartOutput" then
                            table.insert(requiredItems, child.Name)
                        end
                    end
                    
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
                            -- TAMBAHAN: Check if player has enough items in inventory
                            local invCounts = {}
                            for _, item in ipairs(inventoryData) do
                                invCounts[item] = (invCounts[item] or 0) + 1
                            end
                            
                            local hasEnough = true
                            for _, reqItem in ipairs(requiredItems) do
                                if (invCounts[reqItem] or 0) < 1 then
                                    hasEnough = false
                                    break
                                end
                            end
                            
                            if not hasEnough then
                                print("[MixerUI] Not enough items in inventory for recipe:", recipeName)
                                return
                            end
                            
                            print("[MixerUI] Found matching recipe:", recipeName)
                            MixerUpdateEvent:FireServer(recipeName)
                            
                            for i = 1, 3 do
                                removeFromMaterialSlot(i)
                            end
                            return
                        end
                    end
                end
                
                print("[MixerUI] No matching recipe found!")
            end)
        end
    end

    -- Function to update mixer list with recipes from ListItemCombine
    updateMixerListRecipe = function(newInventoryData)
        print("[MixerUI] ========== MIXER UPDATE START (recipes) ==========")
        print("[MixerUI] Received inventory data:", newInventoryData)
        
        -- Store inventory data for availability check
        inventoryData = newInventoryData or {}
        
        -- Get fresh scrolling frame
        local freshElements = getFreshMixerElements()
        if not freshElements or not freshElements.scrollingFrame then
            warn("[MixerUI] ScrollingFrame not found!")
            return
        end
        local currentScrollingFrame = freshElements.scrollingFrame

        -- PERBAIKAN: Sembunyikan atau hapus SlotTemplate asli agar tidak ditampilkan
        for _, child in ipairs(currentScrollingFrame:GetChildren()) do
            if child.Name == "SlotTemplate" then
                child.Visible = false  -- Atau child:Destroy() jika ingin hapus permanen
            end
        end

        -- Clear existing slots (hanya clone)
        local clearedCount = 0
        for _, child in ipairs(currentScrollingFrame:GetChildren()) do
            if child:IsA("TextButton") and child.Name:find("_Slot") then
                child:Destroy()
                clearedCount = clearedCount + 1
            end
        end
        print("[MixerUI] Cleared", clearedCount, "existing slots")
        
        -- Get recipes from ListItemCombine/Food
        local ListItemCombineTargetFolder
        if isFoodMode then
            ListItemCombineTargetFolder = ListItemCombineFolder:FindFirstChild("Food")
        elseif isBoosterMode then
            ListItemCombineTargetFolder = ListItemCombineFolder:FindFirstChild("Booster")
        else
            warn("[MixerUI] No active mode for recipe listing!")
            return
        end

        -- Gunakan ListItemCombineTargetFolder untuk loop resep
        for _, combineInfo in ipairs(ListItemCombineTargetFolder:GetChildren()) do
            local recipeName = combineInfo.Name
            
            -- Get required ingredients
            local requiredItems = {}
            for _, child in ipairs(combineInfo:GetChildren()) do
                if child.Name ~= "MeshPartOutput" then
                    table.insert(requiredItems, child.Name)
                end
            end
            
            -- TAMBAHAN: Check if player has all required items for visual feedback (optional, bisa dihapus jika tidak mau)
            local invCounts = {}
            for _, item in ipairs(inventoryData) do
                invCounts[item] = (invCounts[item] or 0) + 1
            end
            
            local hasAllItems = true
            for _, reqItem in ipairs(requiredItems) do
                if (invCounts[reqItem] or 0) < 1 then
                    hasAllItems = false
                    break
                end
            end

            
            -- Always create slot, but change color and transparency if not available
            local slot = ItemSlotTemplate:Clone()
            slot.Name = recipeName .. "_Slot"
            slot.Parent = currentScrollingFrame
            slot.Visible = true
            slotCreatedCount = slotCreatedCount + 1

            -- Change color and transparency if not available
            if not hasAllItems then
                slot.BackgroundColor3 = Color3.fromRGB(100, 100, 100)  -- Lebih gray
                slot.BackgroundTransparency = 0.5  -- Lebih transparan (opacity kurang)
            else
                slot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)  -- White if available
                slot.BackgroundTransparency = 0  -- Normal opacity
            end
            
            local viewport = slot:FindFirstChild("ViewportFrame")
            
            -- Clear viewport
            for _, obj in ipairs(viewport:GetChildren()) do
                if not obj:IsA("UIStroke") and not obj:IsA("UICorner") then
                    obj:Destroy()
                end
            end
            
            -- Add model from DropItems/FoodItems based on MeshPartOutput
            local outputFolder = combineInfo:FindFirstChild("MeshPartOutput")
            if outputFolder then
                local outputMeshPart = outputFolder:GetChildren()[1]
                if outputMeshPart then
                    local foodItemsFolder = DropItemsFolder:FindFirstChild("FoodItems")
                    if foodItemsFolder then
                        local model = foodItemsFolder:FindFirstChild(outputMeshPart.Name)
                        if model then
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
                        else
                            warn("[MixerUI] Model not found for recipe:", recipeName, "output:", outputMeshPart.Name)
                        end
                    end
                end
            end
            
            -- Update labels
            local itemCount = slot:FindFirstChild("ItemCount")
            if itemCount then
                itemCount.Text = "1x"  -- Recipes are single items
            end
            
            local nameLabel = slot:FindFirstChild("ItemName")
            if nameLabel then
                nameLabel.Text = recipeName
            end
            
            -- Click event to auto-fill materials
            slot.MouseButton1Click:Connect(function()
                print("[MixerUI] Recipe clicked:", recipeName)
                
                -- Clear current material slots
                for i = 1, 3 do
                    removeFromMaterialSlot(i)
                end
                
                -- Add required items to material slots
                for _, reqItem in ipairs(requiredItems) do
                    addToMaterialSlot(reqItem)
                end
                
                print("[MixerUI] Auto-filled materials for recipe:", recipeName)
            end)
        end
        
        print("[MixerUI] Created", slotCreatedCount, "recipe slots")
        print("[MixerUI] ========== MIXER UPDATE END ==========")
    end

    -- Setup connections
    setupConnections()
    
    -- Store update function globally
    _G.updateMixerListRecipe = updateMixerListRecipe

    return true
end

-- PERBAIKAN: Handle respawn
player.CharacterAdded:Connect(function(character)
    print("[MixerUI] Character spawned - reinitializing mixer...")
    
    -- Wait for UI to load
    task.wait(3)
    
    -- Retry initialization
    local maxAttempts = 5
    local attempt = 0
    
    local function trySetup()
        attempt = attempt + 1
        print("[MixerUI] Setup attempt", attempt)
        
        if setupMixerFunctionality() then
            mixerInitialized = true
            print("[MixerUI] Mixer successfully reinitialized!")
            
            -- Request inventory
            local GetInventoryEvent = ReplicatedStorage:FindFirstChild("GetInventory")
            if GetInventoryEvent then
                GetInventoryEvent:FireServer()
                print("[MixerUI] Requested inventory after reinit")
            end
        else
            if attempt < maxAttempts then
                print("[MixerUI] Retry in 2 seconds...")
                task.wait(2)
                trySetup()
            else
                warn("[MixerUI] Failed to reinitialize after", maxAttempts, "attempts")
            end
        end
    end
    
    trySetup()
end)

-- Initial setup
task.spawn(function()
    task.wait(2)
    
    if setupMixerFunctionality() then
        mixerInitialized = true
        print("[MixerUI] Initial setup successful")
        
        -- Request initial inventory
        local GetInventoryEvent = ReplicatedStorage:WaitForChild("GetInventory")
        GetInventoryEvent:FireServer()
        print("[MixerUI] Requested initial inventory")
    else
        warn("[MixerUI] Initial setup failed")
    end
end)

-- Update inventory
UpdateInventoryEvent.OnClientEvent:Connect(function(newInventoryData)
    if mixerInitialized and _G.updateMixerListRecipe then  -- UBAH INI: dari updateMixerInventory ke updateMixerListRecipe
        _G.updateMixerListRecipe(newInventoryData)
    else
        print("[MixerUI] Mixer not ready, caching inventory data")
        inventoryData = newInventoryData
    end
end)

print("[MixerUI] Script loaded successfully")