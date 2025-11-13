local workspace = game:GetService("Workspace")
local replicatedStorage = game:GetService("ReplicatedStorage")

local buildingsFolder = workspace:WaitForChild("Buildings")
local alamFolder = workspace:WaitForChild("Alam")
local kendaraanFolder = workspace:WaitForChild("Kendaraan")  -- Jika ada

local originalBuildingsFolder = replicatedStorage:FindFirstChild("OriginalBuildings")  -- Simpan original di ReplicatedStorage.OriginalBuildings
if not originalBuildingsFolder then
	warn("❌ OriginalBuildings folder tidak ada di ReplicatedStorage! Buat dulu & pindah original model kesini.")
	return
end

-- Fungsi respawn building (untuk Buildings/Alam/Kendaraan)
local function respawnBuilding(originalBuilding, oldCFrame, targetFolder)
	local newBuilding = originalBuilding:Clone()
	newBuilding:SetPrimaryPartCFrame(oldCFrame)  -- Kembalikan posisi & rotasi
	newBuilding.Parent = targetFolder
	newBuilding:SetAttribute("SpawnTime", tick())

	-- Reset Health ke max dari original
	local health = newBuilding:FindFirstChild("Health")
	if health then
		local maxHealth = originalBuilding:FindFirstChild("Health").Value
		health.Value = maxHealth
		print("🔄 Health reset untuk " .. newBuilding.Name .. " ke " .. maxHealth .. " di " .. targetFolder.Name)
	end

	-- Reset BillboardGui bar ke full
	local primary = newBuilding.PrimaryPart
	if primary and primary:FindFirstChild("BillboardGui") then
		local billboard = primary.BillboardGui
		local background = billboard:FindFirstChild("Background")
		if background then
			local bar = background:FindFirstChild("Bar")
			if bar then
				bar.Size = UDim2.new(1, 0, 1, 0)  -- Full
				bar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)  -- Hijau
				print("📊 Bar HP reset untuk " .. newBuilding.Name)
			end
		end
	end

	print("🏗️ Respawn: " .. newBuilding.Name .. " di " .. targetFolder.Name)
end

-- Fungsi destroyBuilding
local function destroyBuilding(building, targetFolder)
	if not building or not building.Parent then return end
	local health = building:FindFirstChild("Health")
	if not health or health.Value > 0 then
		warn("🚫 Destroy dibatalkan untuk " .. building.Name .. " karena HP >0 (" .. (health and health.Value or "no health") .. ")")
		return
	end

	print("💥 MULAI HANCUR: " .. building.Name .. " (HP: " .. health.Value .. ") di " .. targetFolder.Name)

	local oldCFrame = building:GetPrimaryPartCFrame()

	-- Animasi getar & pecah
	for i = 1, 6 do
		local offset = Vector3.new(math.random(-3,3)/10, 0, math.random(-3,3)/10)
		building:PivotTo(building:GetPivot() * CFrame.new(offset))
		task.wait(0.05)
	end

	local parts = {}
	for _, p in pairs(building:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(parts, p)
			p.Anchored = false
			p.CanCollide = true
			p:BreakJoints()
			p.Velocity = Vector3.new(math.random(-50,50), math.random(50,100), math.random(-50,50))
		end
	end

	task.wait(0.5)
	for _, part in pairs(parts) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end

	task.wait(15)
	building:Destroy()
	print("🧱 Bangunan dihapus: " .. building.Name)

	-- Respawn
	local originalBuilding = originalBuildingsFolder:FindFirstChild(building.Name)
	if originalBuilding then
		respawnBuilding(originalBuilding, oldCFrame, targetFolder)
	else
		warn("❌ Original " .. building.Name .. " tidak ada di OriginalBuildings!")
	end
end

-- Fungsi setup untuk satu building/model (umum untuk semua folder)
local function setupBuilding(building, targetFolder)
	if not building:IsA("Model") then return end
	if not building:FindFirstChild("Health") then return end
	if not building.PrimaryPart then return end

	local health = building.Health
	local maxHealth = health.Value  -- Asumsi value awal adalah max

	local primary = building.PrimaryPart
	local billboard = primary:FindFirstChild("BillboardGui")
	if not billboard then return end

	local background = billboard:FindFirstChild("Background")
	if not background then return end
	local bar = background:FindFirstChild("Bar")
	if not bar then return end

	local function updateBar()
		if not building.Parent then return end
		local ratio = math.clamp(health.Value / maxHealth, 0, 1)
		bar.Size = UDim2.new(ratio, 0, 1, 0)
		if ratio > 0.6 then bar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
		elseif ratio > 0.3 then bar.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
		else bar.BackgroundColor3 = Color3.fromRGB(255, 0, 0) end
		print("📊 Update bar: " .. building.Name .. " ratio=" .. ratio .. ", HP=" .. health.Value .. "/" .. maxHealth)
	end

	updateBar()
	health:GetPropertyChangedSignal("Value"):Connect(function()
		if not building.Parent then return end
		updateBar()
		if health.Value <= 0 then
			destroyBuilding(building, targetFolder)
		end
	end)
end

-- Setup semua folder
local function setupFolder(folder)
	for _, b in pairs(folder:GetChildren()) do
		setupBuilding(b, folder)
		b:SetAttribute("SpawnTime", tick())
	end
	folder.ChildAdded:Connect(function(newBuilding)
		task.wait(1)
		setupBuilding(newBuilding, folder)
		newBuilding:SetAttribute("SpawnTime", tick())
		print("🆕 Setup baru: " .. newBuilding.Name .. " di " .. folder.Name .. " (HP: " .. (newBuilding:FindFirstChild("Health") and newBuilding.Health.Value or "no health") .. ")")
	end)
end

setupFolder(buildingsFolder)
setupFolder(alamFolder)
if kendaraanFolder then setupFolder(kendaraanFolder) end