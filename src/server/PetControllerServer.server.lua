-- PetControllerServer.lua (Clean version - no debug output)
-- Place in ServerScriptService
-- Controls pet (Workspace.Monster.Monster1) via RemoteEvent "PetCommand"

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local COMMAND_EVENT_NAME = "PetCommand"
local PetCommandEvent = ReplicatedStorage:FindFirstChild(COMMAND_EVENT_NAME)
if not PetCommandEvent then
	PetCommandEvent = Instance.new("RemoteEvent")
	PetCommandEvent.Name = COMMAND_EVENT_NAME
	PetCommandEvent.Parent = ReplicatedStorage
end

local function getPetModel()
	local container = Workspace:FindFirstChild("Monster")
	if not container then return nil end
	return container:FindFirstChild("Monster1")
end

local function ensurePrimaryPart(model)
	if not model or not model:IsA("Model") then return nil end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return model.PrimaryPart end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			pcall(function() model.PrimaryPart = d end)
			return d
		end
	end
	return nil
end

-- CONFIG
local buildingFolder = Workspace:FindFirstChild("Buildings")
local followDistance = 6
local minDistance = 3
local followLerpAlpha = 0.16
local petMoveAlpha = 0.22
local attackRange = 20
local attackCooldown = 2
local damage = 10

local teleportOnFollow = false
local modeSwitchCooldown = 0.45
local lastModeSwitch = 0

-- STATE
local pet = getPetModel()
local primaryPart = pet and ensurePrimaryPart(pet)
local humanoid = pet and pet:FindFirstChildOfClass("Humanoid")

local isAttackingBuilding = false
local lastAttack = 0

local mode = "follow"
local overridePlayer = nil

local followTargetPos = nil
local returningToPlayer = false
local attackAbort = false

local attackSession = 0
local followSession = 0
local _currentTargetBuilding = nil

-- Utilities
local function getClosestPlayer()
	local closestDistance = math.huge
	local closestPlayer = nil
	local mpos = (primaryPart and primaryPart.Position) or (pet and pet:GetPivot() and pet:GetPivot().Position)
	if not mpos then return nil, math.huge end
	for _, p in pairs(Players:GetPlayers()) do
		if p.Character and p.Character.PrimaryPart then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart") or p.Character.PrimaryPart
			if hrp then
				local dist = (Vector3.new(hrp.Position.X,0,hrp.Position.Z) - Vector3.new(mpos.X,0,mpos.Z)).Magnitude
				if dist < closestDistance then
					closestDistance = dist
					closestPlayer = p
				end
			end
		end
	end
	return closestPlayer, closestDistance
end

local function getClosestBuilding()
	local closestDistance = math.huge
	local closestBuilding = nil
	local mpos = (primaryPart and primaryPart.Position) or (pet and pet:GetPivot() and pet:GetPivot().Position)
	if not mpos or not buildingFolder then return nil, math.huge end
	for _, b in pairs(buildingFolder:GetChildren()) do
		if b:IsA("Model") and b:FindFirstChild("Health") then
			local bp = b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart")
			if bp then
				local age = b:GetAttribute("SpawnTime") or 0
				if tick() - age > 0.8 then
					local dist = (Vector3.new(bp.Position.X,0,bp.Position.Z) - Vector3.new(mpos.X,0,mpos.Z)).Magnitude
					if dist < closestDistance then
						closestDistance = dist
						closestBuilding = b
					end
				end
			end
		end
	end
	return closestBuilding, closestDistance
end

local function smoothMoveTo(targetPosition, faceDir)
	if not pet or not pet.Parent then return end
	primaryPart = ensurePrimaryPart(pet)
	if not primaryPart then return end

	local curPos = primaryPart.Position
	local targetXZ = Vector3.new(targetPosition.X, curPos.Y, targetPosition.Z)
	local newPos = curPos:Lerp(targetXZ, petMoveAlpha)

	local lookAt
	if faceDir and typeof(faceDir) == "Vector3" and faceDir.Magnitude > 0.001 then
		lookAt = newPos + faceDir.Unit
	else
		lookAt = Vector3.new(targetPosition.X, curPos.Y, targetPosition.Z)
	end

	pcall(function()
		pet:SetPrimaryPartCFrame(CFrame.new(newPos, lookAt))
	end)
end

local function returnToPlayerSmoothNonBlocking(player, sessionId)
	if not player or not player.Character or not player.Character.PrimaryPart then return end
	returningToPlayer = true

	local hrp = player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart
	if not hrp then returningToPlayer = false; return end

	primaryPart = ensurePrimaryPart(pet)
	local petPos = primaryPart and primaryPart.Position or Vector3.new(0,0,0)
	followTargetPos = followTargetPos or petPos

	local startTime = tick()
	spawn(function()
		while tick() - startTime < 10 do
			if sessionId ~= followSession then
				break
			end
			if mode == "follow" and overridePlayer ~= player then break end
			if not pet or not pet.Parent then break end
			if not player or not player.Character or not player.Character.PrimaryPart then break end

			local desired = hrp.Position - hrp.CFrame.LookVector * followDistance
			desired = Vector3.new(desired.X, petPos.Y, desired.Z)

			local curPet = primaryPart and primaryPart.Position or petPos
			local horizDistToPlayer = (Vector3.new(curPet.X,0,curPet.Z) - Vector3.new(hrp.Position.X,0,hrp.Position.Z)).Magnitude
			if horizDistToPlayer < minDistance then
				local pushBack = hrp.Position - hrp.CFrame.LookVector * (followDistance + (minDistance - horizDistToPlayer) + 1)
				pushBack = Vector3.new(pushBack.X, curPet.Y, pushBack.Z)
				followTargetPos = (followTargetPos or curPet):Lerp(pushBack, followLerpAlpha)
			else
				followTargetPos = (followTargetPos or curPet):Lerp(desired, followLerpAlpha)
			end

			primaryPart = ensurePrimaryPart(pet)
			local hrpLook = hrp.CFrame.LookVector
			smoothMoveTo(followTargetPos, hrpLook)

			primaryPart = ensurePrimaryPart(pet)
			curPet = primaryPart and primaryPart.Position or petPos
			local horizNow = (Vector3.new(curPet.X,0,curPet.Z) - Vector3.new(hrp.Position.X,0,hrp.Position.Z)).Magnitude
			if horizNow <= 2 then break end

			task.wait(0.06)
		end
		returningToPlayer = false
	end)
end

local function attackBuildingSequence(building, sessionId)
	if not building or not building.Parent or not building:FindFirstChild("Health") then
		isAttackingBuilding = false
		return
	end

	if returningToPlayer or mode == "follow" or attackAbort or sessionId ~= attackSession or (humanoid and humanoid.PlatformStand) then
		isAttackingBuilding = false
		return
	end

	local bp = building.PrimaryPart or building:FindFirstChildWhichIsA("BasePart")
	if not bp then isAttackingBuilding = false; return end

	local targetPos = bp.Position
	primaryPart = ensurePrimaryPart(pet)
	if primaryPart then
		followTargetPos = followTargetPos or primaryPart.Position
	end

	currentTargetBuilding = building

	for i = 1, 24 do
		if returningToPlayer or mode == "follow" or attackAbort or sessionId ~= attackSession or (humanoid and humanoid.PlatformStand) then break end
		if not building or not building.Parent then break end

		followTargetPos = followTargetPos:Lerp(targetPos, 0.28)
		local faceDir = (bp.Position - (followTargetPos or primaryPart.Position))
		if faceDir.Magnitude < 0.001 then faceDir = bp.Position - (primaryPart and primaryPart.Position or targetPos) end
		smoothMoveTo(followTargetPos, faceDir)
		task.wait(0.05)
	end

	currentTargetBuilding = nil

	if returningToPlayer or mode == "follow" or attackAbort or sessionId ~= attackSession or (humanoid and humanoid.PlatformStand) then
		isAttackingBuilding = false
		return
	end

	if tick() - lastAttack >= attackCooldown and not attackAbort and mode == "attack" and sessionId == attackSession then
		lastAttack = tick()
		local health = building:FindFirstChild("Health")
		if health then
			health.Value = math.max(0, health.Value - damage)
			if health.Value <= 0 then
				local p = getClosestPlayer()
				if p then
					returningToPlayer = true
					returnToPlayerSmoothNonBlocking(p, followSession)
				end
				isAttackingBuilding = false
				return
			end
		end
	end

	isAttackingBuilding = false
end

-- COMMAND HANDLER
PetCommandEvent.OnServerEvent:Connect(function(player, command)
	if not player then return end
	if command == "Follow" then
		attackSession = attackSession + 1
		followSession = followSession + 1
		attackAbort = true
		mode = "follow"
		overridePlayer = player
		returningToPlayer = true

		currentTargetBuilding = nil
		isAttackingBuilding = false
		lastAttack = 0

		primaryPart = ensurePrimaryPart(pet)
		local desiredBehind = nil
		local hrp = player.Character and (player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart)
		if hrp then
			desiredBehind = hrp.Position - hrp.CFrame.LookVector * followDistance
		end

		if primaryPart then
			if desiredBehind then
				followTargetPos = Vector3.new(desiredBehind.X, primaryPart.Position.Y, desiredBehind.Z)
			else
				followTargetPos = primaryPart.Position
			end
			pcall(function()
				primaryPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
				primaryPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
			end)
		else
			followTargetPos = nil
		end

		if humanoid then
			pcall(function() humanoid.PlatformStand = true end)
		end

		local hrpLook = hrp and hrp.CFrame.LookVector or Vector3.new(0,0,1)
		for i = 1, 6 do
			if not pet or not pet.Parent then break end
			if followTargetPos then
				pcall(function() smoothMoveTo(followTargetPos, hrpLook) end)
			end
			task.wait(0.03)
		end

		if teleportOnFollow and primaryPart and followTargetPos then
			pcall(function()
				pet:SetPrimaryPartCFrame(CFrame.new(followTargetPos, followTargetPos + hrpLook))
				primaryPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
				primaryPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
			end)
		end

		lastModeSwitch = tick()

		task.spawn(function()
			task.wait(0.08)
			if humanoid then
				pcall(function() humanoid.PlatformStand = false end)
			end
		end)

		returnToPlayerSmoothNonBlocking(player, followSession)

	elseif command == "Attack" then
		attackSession = attackSession + 1
		followSession = followSession + 1
		mode = "attack"
		overridePlayer = nil
		attackAbort = false
		returningToPlayer = false

		primaryPart = ensurePrimaryPart(pet)
		if primaryPart then
			followTargetPos = primaryPart.Position
			pcall(function()
				primaryPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
				primaryPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
			end)
		else
			followTargetPos = nil
		end

		if humanoid then
			pcall(function() humanoid.PlatformStand = false end)
		end

		isAttackingBuilding = false
		lastAttack = 0
		lastModeSwitch = tick()

		local building, distB = getClosestBuilding()
		if building and distB and distB < 60 and primaryPart then
			local bp = building.PrimaryPart or building:FindFirstChildWhichIsA("BasePart")
			if bp then
				local targetPos = bp.Position
				for i = 1, 6 do
					if not pet or not pet.Parent then break end
					followTargetPos = followTargetPos:Lerp(targetPos, 0.25)
					local faceDir = (bp.Position - followTargetPos)
					pcall(function() smoothMoveTo(followTargetPos, faceDir) end)
					task.wait(0.03)
				end
			end
		end
	end
end)

-- MAIN LOOP
RunService.Heartbeat:Connect(function(dt)
	if (not pet) or (not pet.Parent) then
		pet = getPetModel()
		if pet then
			primaryPart = ensurePrimaryPart(pet)
			humanoid = pet:FindFirstChildOfClass("Humanoid")
		else
			return
		end
	else
		primaryPart = ensurePrimaryPart(pet)
		humanoid = pet:FindFirstChildOfClass("Humanoid")
	end

	if mode == "follow" and overridePlayer then
		if not overridePlayer.Parent or not overridePlayer.Character then
			mode = "attack"
			overridePlayer = nil
			returningToPlayer = false
			return
		end
		attackAbort = true
		primaryPart = ensurePrimaryPart(pet)
		if primaryPart and not followTargetPos then
			followTargetPos = primaryPart.Position
		end
		returnToPlayerSmoothNonBlocking(overridePlayer, followSession)
		return
	end

	if returningToPlayer then return end

	local building, distB = getClosestBuilding()
	local player, distP = getClosestPlayer()

	if mode ~= "attack" then
		if player and player.Character and player.Character.PrimaryPart then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart
			local desired = hrp.Position - hrp.CFrame.LookVector * followDistance
			desired = Vector3.new(desired.X, (primaryPart and primaryPart.Position.Y) or desired.Y, desired.Z)
			if not followTargetPos then followTargetPos = primaryPart and primaryPart.Position or desired end
			local petPos = primaryPart and primaryPart.Position or Vector3.new(0,0,0)
			local horizDistToPlayer = (Vector3.new(petPos.X,0,petPos.Z) - Vector3.new(hrp.Position.X,0,hrp.Position.Z)).Magnitude
			if horizDistToPlayer < minDistance then
				local pushPos = hrp.Position - hrp.CFrame.LookVector * (followDistance + (minDistance - horizDistToPlayer) + 1)
				pushPos = Vector3.new(pushPos.X, petPos.Y, pushPos.Z)
				followTargetPos = followTargetPos:Lerp(pushPos, followLerpAlpha)
			else
				followTargetPos = followTargetPos:Lerp(desired, followLerpAlpha)
			end
			smoothMoveTo(followTargetPos, hrp.CFrame.LookVector)
		end
		return
	end

	if building and distB and distB < 40 then
		if distB > attackRange then
			local bp = building.PrimaryPart or building:FindFirstChildWhichIsA("BasePart")
			if bp then
				if not followTargetPos then followTargetPos = primaryPart and primaryPart.Position or bp.Position end
				followTargetPos = followTargetPos:Lerp(bp.Position, 0.28)
				local faceDir = (bp.Position - (followTargetPos or primaryPart.Position))
				smoothMoveTo(followTargetPos, faceDir)
			end
		else
			if (tick() - lastModeSwitch) < modeSwitchCooldown then
				return
			end
			if not isAttackingBuilding and not attackAbort then
				isAttackingBuilding = true
				local thisSession = attackSession
				currentTargetBuilding = building
				coroutine.wrap(function()
					attackBuildingSequence(building, thisSession)
				end)()
			end
		end
	else
		if player and player.Character and player.Character.PrimaryPart then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart
			local desired = hrp.Position - hrp.CFrame.LookVector * followDistance
			desired = Vector3.new(desired.X, (primaryPart and primaryPart.Position.Y) or desired.Y, desired.Z)
			if not followTargetPos then followTargetPos = primaryPart and primaryPart.Position or desired end
			local petPos = primaryPart and primaryPart.Position or Vector3.new(0,0,0)
			local horizDistToPlayer = (Vector3.new(petPos.X,0,petPos.Z) - Vector3.new(hrp.Position.X,0,hrp.Position.Z)).Magnitude
			if horizDistToPlayer < minDistance then
				local pushPos = hrp.Position - hrp.CFrame.LookVector * (followDistance + (minDistance - horizDistToPlayer) + 1)
				pushPos = Vector3.new(pushPos.X, petPos.Y, pushPos.Z)
				followTargetPos = followTargetPos:Lerp(pushPos, followLerpAlpha)
			else
				followTargetPos = followTargetPos:Lerp(desired, followLerpAlpha)
			end
			smoothMoveTo(followTargetPos, hrp.CFrame.LookVector)
		end
	end
end)