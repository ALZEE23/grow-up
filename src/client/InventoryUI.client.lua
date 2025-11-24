local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DropItemsFolder = ReplicatedStorage:WaitForChild("DropItems")

local UpdateInventoryEvent = ReplicatedStorage:WaitForChild("UpdateInventory") -- RemoteEvent dari server

-- Track connections untuk hotbar slots
local hotbarConnections = {}
local lastInventoryData = nil

-- PERBAIKAN: Function untuk request inventory
local function requestInventory()
    local GetInventoryEvent = ReplicatedStorage:FindFirstChild("GetInventory")
    if GetInventoryEvent then
        GetInventoryEvent:FireServer()
        print("[InventoryUI] Requested inventory from server")
    else
        warn("[InventoryUI] GetInventory event not found!")
    end
end

-- PERBAIKAN: Auto-request saat character spawn
player.CharacterAdded:Connect(function(character)
    print("[InventoryUI] Character spawned! Starting inventory request sequence...")
    
    -- Multiple retry attempts
    for i = 1, 5 do
        task.spawn(function()
            task.wait(i * 1.5) -- 1.5s, 3s, 4.5s, 6s, 7.5s
            if player.Character and player.Character.Parent then
                print("[InventoryUI] Auto-request attempt", i)
                requestInventory()
            end
        end)
    end
end)

-- PERBAIKAN: Manual request pada startup
task.spawn(function()
    task.wait(2)
    if player.Character then
        print("[InventoryUI] Initial inventory request")
        requestInventory()
    end
end)

-- PERBAIKAN: Manual key untuk testing
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F5 then
        print("[InventoryUI] Manual F5 inventory request")
        requestInventory()
    end
end)

UpdateInventoryEvent.OnClientEvent:Connect(function(inventoryData)
    print("[InventoryUI] ========== INVENTORY UPDATE START ==========")
    print("[InventoryUI] Received inventory data:", inventoryData)
    print("[InventoryUI] Data type:", type(inventoryData))
    print("[InventoryUI] Data length:", inventoryData and #inventoryData or "NIL")

    -- PERBAIKAN: Handle empty or nil data dengan cache
    if not inventoryData or #inventoryData == 0 then
        if lastInventoryData and #lastInventoryData > 0 then
            print("[InventoryUI] Using cached inventory data")
            inventoryData = lastInventoryData
        else
            warn("[InventoryUI] No inventory data and no cache - skipping update")
            return
        end
    else
        -- Cache valid data
        lastInventoryData = inventoryData
    end

    -- PERBAIKAN: Use FindFirstChild untuk avoid infinite yield
    local inventoryGui = playerGui:FindFirstChild("Inventory")
    if not inventoryGui then
        warn("[InventoryUI] Inventory GUI not found! Available GUIs:")
        for _, child in ipairs(playerGui:GetChildren()) do
            print("  -", child.Name, child.ClassName)
        end
        return
    end

    local hotbar = inventoryGui:FindFirstChild("Hotbar")
    local inventoryInside = inventoryGui:FindFirstChild("Inventory")
    
    if not hotbar then
        warn("[InventoryUI] Hotbar not found in Inventory GUI!")
        print("[InventoryUI] Available children:")
        for _, child in ipairs(inventoryGui:GetChildren()) do
            print("  -", child.Name, child.ClassName)
        end
    end
    
    if not inventoryInside then
        warn("[InventoryUI] Inventory frame not found!")
        return
    end

    local inventoryItemScroll = inventoryInside:FindFirstChild("ItemsScroll")
    if not inventoryItemScroll then
        warn("[InventoryUI] ItemsScroll not found!")
        return
    end
    
    local slotTemplate = ReplicatedStorage.UI:FindFirstChild("SlotTemplate")
    if not slotTemplate then
        warn("[InventoryUI] SlotTemplate not found!")
        return
    end

    -- 💡 Kelompokkan item yang sama jadi count
    local itemCounts = {}
    for _, itemName in ipairs(inventoryData) do
        itemCounts[itemName] = (itemCounts[itemName] or 0) + 1
        print("[InventoryUI] Processing item:", itemName)
    end

    print("[InventoryUI] Item counts:", itemCounts)

    -- Convert jadi list untuk iterasi urutan slot
    local uniqueItems = {}
    for name, count in pairs(itemCounts) do
        table.insert(uniqueItems, { name = name, count = count })
    end
    
    print("[InventoryUI] Unique items:", #uniqueItems)
    
    -- PERBAIKAN: Only update hotbar if it exists
    if hotbar then
        -- Disconnect semua event lama di hotbar
        for i = 1, 10 do
            if hotbarConnections[i] then
                hotbarConnections[i]:Disconnect()
                hotbarConnections[i] = nil
            end
        end
        
        -- Clear hotbar slots first
        for i = 1, 10 do
            local slot = hotbar:FindFirstChild("Slot" .. i)
            if slot then
                local viewport = slot:FindFirstChild("ViewportFrame")
                if viewport then
                    -- Clear viewport
                    for _, obj in ipairs(viewport:GetChildren()) do
                        if not obj:IsA("UIStroke") and not obj:IsA("UICorner") then
                            obj:Destroy()
                        end
                    end
                end
                
                -- Clear count label
                local countLabel = slot:FindFirstChild("ItemCount")
                if countLabel then
                    countLabel.Text = ""
                end
            end
        end
        
        -- Update hotbar with current inventory
        for i, itemInfo in ipairs(uniqueItems) do
            print("[InventoryUI] Creating hotbar slot", i, "for:", itemInfo.name)
            local slot = hotbar:FindFirstChild("Slot" .. i)
            if slot then
                local viewport = slot:FindFirstChild("ViewportFrame")
                if viewport then
                    -- Clear viewport
                    for _, obj in ipairs(viewport:GetChildren()) do
                        if not obj:IsA("UIStroke") and not obj:IsA("UICorner") then
                            obj:Destroy()
                        end
                    end

                    -- Ambil model dari folder DropItems
                    local model = DropItemsFolder:FindFirstChild(itemInfo.name)
                    if model then
                        model = model:Clone()
                        model.Parent = viewport

                        -- Kamera viewport
                        local cam = Instance.new("Camera")
                        cam.CFrame = CFrame.new(Vector3.new(0, 0, 6), Vector3.new(0, 0, 0))
                        cam.Parent = viewport
                        viewport.CurrentCamera = cam

                        model:PivotTo(CFrame.new(0, 0, 0))
                        viewport.BackgroundTransparency = 1
                        viewport.Ambient = Color3.new(1, 1, 1)
                        viewport.LightDirection = Vector3.new(0, -1, -1)
                        
                        print("[InventoryUI] Successfully setup hotbar slot", i)
                    else
                        warn("[InventoryUI] Item model not found:", itemInfo.name)
                    end

                    -- Add count label
                    local countLabel = slot:FindFirstChild("ItemCount")
                    if countLabel then
                        countLabel.Text = itemInfo.count .. "x"
                    end
                    
                    local EquipItemEvent = ReplicatedStorage:FindFirstChild("EquipItem")
                    if EquipItemEvent then
                        -- Event click
                        local currentItemName = itemInfo.name
                        hotbarConnections[i] = slot.MouseButton1Click:Connect(function()
                            print("Hotbar slot", i, "clicked - equipping:", currentItemName)
                            EquipItemEvent:FireServer(currentItemName)
                        end)
                    end
                end
            end
        end
        
        print("[InventoryUI] Hotbar update completed")
    else
        print("[InventoryUI] Skipping hotbar update - not found")
    end
    
    -- Bersihkan inventory lama
    local clearedCount = 0
    for _, child in ipairs(inventoryItemScroll:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
            clearedCount = clearedCount + 1
        end
    end
    print("[InventoryUI] Cleared", clearedCount, "old inventory slots")
    
    -- Create new inventory slots
    local createdCount = 0
    for name, count in pairs(itemCounts) do
        local slot = slotTemplate:Clone()
        slot.Name = name .. "_Slot"
        slot.Parent = inventoryItemScroll
        createdCount = createdCount + 1

        local viewport = slot:FindFirstChild("ViewportFrame")
        if viewport then
            -- Clear viewport
            for _, obj in ipairs(viewport:GetChildren()) do
                if not obj:IsA("UIStroke") and not obj:IsA("UICorner") then
                    obj:Destroy()
                end
            end

            -- Add model
            local model = DropItemsFolder:FindFirstChild(name)
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
                warn("[InventoryUI] Item model not found:", name)
            end

            -- Add count and name labels
            local countLabel = slot:FindFirstChild("ItemCount")
            if countLabel then
                countLabel.Text = count .. "x"
            end
            
            local nameLabel = slot:FindFirstChild("ItemName")
            if nameLabel then
                nameLabel.Text = name
            end
            
            local EquipItemEvent = ReplicatedStorage:FindFirstChild("EquipItem")
            if EquipItemEvent then
                -- Event click
                local currentItemName = name
                slot.MouseButton1Click:Connect(function()
                    print("Inventory item clicked:", currentItemName)
                    EquipItemEvent:FireServer(currentItemName)
                end)
            end
        end
    end
    
    print("[InventoryUI] Created", createdCount, "new inventory slots")
    print("[InventoryUI] ========== INVENTORY UPDATE END ==========")
end)
