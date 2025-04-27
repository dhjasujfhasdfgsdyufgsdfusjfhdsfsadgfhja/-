--@ kiwi_api.lua - V1.0.4

-- Place Check
if game.PlaceId ~= 70876832253163 then
	return
end

repeat
	task.wait()
until game:IsLoaded()

warn("kiwi_api.lua - V1.0.4")

-- Services
Players = game:GetService("Players")
ReplicatedStorage = game:GetService("ReplicatedStorage")
RunService = game:GetService("RunService")

-- Main Variables
LocalPlayer = Players.LocalPlayer
Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- Asset ID's
Money_Bag_ID = "rbxassetid://71632786167654"
Table_ID = "rbxassetid://81831823492227"

-- Caching
Money_Bag = game:GetObjects(Money_Bag_ID)[1]
Money_Bag:Destroy()

Table = game:GetObjects(Table_ID)[1]
Table:Destroy()

-- Main
KiwiAPI = {}

-- API Variables
KiwiAPI.LeaderstatsSetup = false
KiwiAPI.MoneyUpdating = false
KiwiAPI.FakeMoney = 0

-- Misc Functions
KiwiAPI.GetMoney = function()
	local leaderstats: Folder = LocalPlayer.leaderstats
	local Money: IntValue = leaderstats.Money

	return Money
end

KiwiAPI.HandleLeaderstatsUpdates = function()
	if KiwiAPI.LeaderstatsSetup then return end
	KiwiAPI.LeaderstatsSetup = true

	local Money = KiwiAPI.GetMoney()

	Money:GetPropertyChangedSignal("Value"):Connect(function()
		if KiwiAPI.MoneyUpdating then
			return
		end

		KiwiAPI.MoneyUpdating = true

		Money.Value += KiwiAPI.FakeMoney

		task.wait(0.1)

		KiwiAPI.MoneyUpdating = false
	end)
end

-- Important Functions
KiwiAPI.MakeSellable = function(object: Model, amount: number)
	local function HandleSell(part: BasePart)
		if part and part:IsA("BasePart") then
			part.Touched:Connect(function(hit: BasePart)
				if hit and hit.Name == "SellZone" and object and object:IsDescendantOf(workspace) then
					object.Parent = nil

					ReplicatedStorage.StopDrag:Fire()

					local Money = KiwiAPI.GetMoney()

					local Money_Bag: Model = game:GetObjects(Money_Bag_ID)[1]
					Money_Bag.Parent = workspace.RuntimeItems
					Money_Bag.MoneyBag.CFrame = hit.CFrame * CFrame.Angles(0, math.rad(90), 0) + Vector3.new(0, 3, 0)
					Money_Bag.MoneyBag.BillboardGui.TextLabel.Text = `${amount}`
					Money_Bag.MoneyBag.CollectPrompt.Triggered:Connect(function()
						if not Money_Bag:GetAttribute("Collected") then
							Money_Bag:SetAttribute("Collected", true)

							Money_Bag.Parent = nil
							Money_Bag.MoneyBag.Collect:Play()

							KiwiAPI.MoneyUpdating = true
							Money.Value += amount
							task.wait(0.1)
							KiwiAPI.FakeMoney += amount
							KiwiAPI.MoneyUpdating = false
						end
					end)
				end
			end)
		end
	end

	KiwiAPI.HandleLeaderstatsUpdates()

	if object:IsA("Model") then
		HandleSell(object.PrimaryPart)
	elseif object:IsA("BasePart") then
		HandleSell(object)
	end
end

KiwiAPI.MakeCrafting = function(data)
	local hrp = Character:FindFirstChild("HumanoidRootPart")
	if Character and hrp then
		local forward = hrp.CFrame.LookVector
		local positionInFront = hrp.Position + (forward * data.distance)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {Character}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local origin = positionInFront + Vector3.new(0, 44, 0)
		local direction = Vector3.new(0, -200, 0)

		local result = workspace:Raycast(origin, direction, raycastParams)

		if result then
			local groundPosition = result.Position
			local spawnCFrame = CFrame.new(groundPosition)

			local Table: Model = game:GetObjects(Table_ID)[1]
			Table.Parent = workspace
			Table:PivotTo(spawnCFrame)

			local Touching = {}

			for _, grid: Part in Table.Grid:GetChildren() do
				local Expected = data.items[tonumber(grid.Name)]

				if Expected ~= "" then
					Touching[tonumber(grid.Name)] = {
						Status = false,
						Obj = nil
					}

					grid.Touched:Connect(function(hit: BasePart)
						if hit and hit.Parent.Name == Expected and not hit.Parent:GetAttribute("Set") then
							hit.Parent:SetAttribute("Set", true)

							Touching[tonumber(grid.Name)].Status = true
							Touching[tonumber(grid.Name)].Obj = hit.Parent

							local TrueGrids = 0
							local RequiredCount = 0

							for _, data in pairs(Touching) do
								if data.Status then
									TrueGrids += 1
								end
							end

							for i = 1, 9 do
								if data.items[i] ~= "" then
									RequiredCount += 1
								end
							end

							if TrueGrids == RequiredCount then
								for _, data in pairs(Touching) do
									if data.Obj then
										data.Status = false
										data.Obj:Destroy()
									end
								end

								local Reward: Model = game:GetObjects(data.reward)[1]
								Reward.Parent = workspace.RuntimeItems
								Reward:PivotTo(Table.Grid["5"].CFrame + Vector3.new(0, data.height, 0))

								Reward.ObjectInfo.Title.Text = data.name

								for _, color: Part in Reward.PrimaryPart:GetChildren() do
									if color.Name == "Color" then
										color.Color = data.color
										color.Material = data.material
										color.Transparency = data.transparency
									end
								end
								
								for _, grid: Part in Table.Grid:GetChildren() do
									for _, touchingPart in pairs(workspace:GetPartsInPart(grid)) do
										if touchingPart.Parent and touchingPart.Parent:GetAttribute("Set") then
											touchingPart.Parent:SetAttribute("Set", nil)
										end
									end
								end
								
								if data.extra then
									data.extra()
								end

								_G.KiwiAPI.MakeSellable(Reward, data.cost)
							end
						end
					end)

					grid.TouchEnded:Connect(function(hit: BasePart)
						if hit and hit.Parent and hit.Parent.Name == Expected then
							hit.Parent:SetAttribute("Set", nil)

							Touching[tonumber(grid.Name)].Status = false
							Touching[tonumber(grid.Name)].Obj = nil
						end
					end)
				end
			end
		end
	end
end

KiwiAPI.MakePickable = function(tool: Model, name: string, size_multiplier: number)
	tool:AddTag("KiwiPickable")
	tool:SetAttribute("Name", name)
	tool:SetAttribute("Size", size_multiplier)
end

-- Initialize
_G.KiwiAPI = KiwiAPI

-- Pickup System
task.spawn(function()
	ReplicatedStorage:WaitForChild("Client"):WaitForChild("Handlers"):WaitForChild("DraggableItemHandlers"):WaitForChild("ClientToolObjectHandler"):Destroy()
	
	local l_LocalPlayer_0 = game:GetService("Players").LocalPlayer
	local l_HoveringObject_0 = ReplicatedStorage.Client.Handlers.DraggableItemHandlers.ClientDraggableObjectHandler.HoveringObject
	local v3 = require(ReplicatedStorage.Shared.Utils.DraggableObjectUtil)
	local l_isValidDraggableObject_0 = v3.isValidDraggableObject
	local l_isDraggableObjectWelded_0 = v3.isDraggableObjectWelded
	local v6 = require(ReplicatedStorage.Client.Controllers.ActionController)
	local v7 = require(ReplicatedStorage.Client.DataBanks.ActionData)
	local l_PickUpTool_0 = ReplicatedStorage.Remotes.Tool.PickUpTool
	local l_DropTool_0 = ReplicatedStorage.Remotes.Tool.DropTool
	local v10 = nil
	local function v14(v11) --[[ Line: 27 ]] --[[ Name: getCurrentlyHeldTool ]]
		if not v11 then
			return nil
		else
			for _, v13 in v11:GetChildren() do
				if v13:IsA("Tool") and v13:HasTag("Droppable") then
					return v13
				end
			end
			return nil
		end
	end
	local function v17(_, v16) --[[ Line: 41 ]] --[[ Name: pickObjectActionCallback ]]
		-- upvalues: v10 (ref), l_PickUpTool_0 (copy)
		if v16 ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		else
			if v10 then
				if v10:HasTag("KiwiPickable") then
					local RandomNum = math.random(1, 100000000)
					
					local Tool = Instance.new("Tool", l_LocalPlayer_0.Backpack)
					Tool.Name = v10:GetAttribute("Name")
					Tool.CanBeDropped = false
					Tool:AddTag("Droppable")
					Tool:AddTag("KiwiPickable")
					Tool:SetAttribute("Random", RandomNum)
					
					local Handle = v10.PrimaryPart:Clone()
					Handle.Name = "Handle"
					Handle.Size *= v10:GetAttribute("Size")
					Handle.Parent = Tool

					v10.Parent = ReplicatedStorage
					v10:SetAttribute("OGName", v10.Name)
					
					v10.Name = v10:GetAttribute("Name") .. RandomNum

					return
				end
				l_PickUpTool_0:FireServer(v10)
			end
			return Enum.ContextActionResult.Sink
		end
	end
	local function v21(_, v19) --[[ Line: 53 ]] --[[ Name: dropObjectActionCallback ]]
		-- upvalues: v14 (copy), l_LocalPlayer_0 (copy), l_DropTool_0 (copy)
		if v19 ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		else
			local v20 = v14(l_LocalPlayer_0.Character)
			if v20 then
				if v20:HasTag("KiwiPickable") then
					local RandomAttribute = v20:GetAttribute("Random")
					
					if RandomAttribute then
						local Model = ReplicatedStorage:FindFirstChild(v20.Name .. RandomAttribute)
						if Model then
							local forwardVector = Character.HumanoidRootPart.CFrame.LookVector
							local spawnPosition = Character.HumanoidRootPart.Position + (forwardVector * 7)
							
							Model.Name = Model:GetAttribute("OGName")
							Model.Parent = workspace.RuntimeItems
							Model.PrimaryPart.CFrame = CFrame.new(spawnPosition)
						end
					end
					
					v20:Destroy()
					
					return
				end
				l_DropTool_0:FireServer(v20)
			end
			return Enum.ContextActionResult.Sink
		end
	end
	local function v24(v22) --[[ Line: 66 ]] --[[ Name: updatePickBound ]]
		-- upvalues: v6 (copy), v7 (copy), v17 (copy)
		local v23 = v6.isBound(v7.Action.PickUpObject)
		if v22 and not v23 then
			v6.bindAction(v7.Action.PickUpObject, v17, v7.ActionContext[v7.Action.PickUpObject], Enum.KeyCode.E, Enum.KeyCode.DPadLeft, v7.ActionPriority.Low)
			return
		else
			if not v22 and v23 then
				v6.unbindAction(v7.Action.PickUpObject)
			end
			return
		end
	end
	local function v27(v25) --[[ Line: 83 ]] --[[ Name: updateDropBound ]]
		-- upvalues: v6 (copy), v7 (copy), v21 (copy)
		local v26 = v6.isBound(v7.Action.DropObject)
		if v25 and not v26 then
			v6.bindAction(v7.Action.DropObject, v21, v7.ActionContext[v7.Action.DropObject], Enum.KeyCode.Backspace, Enum.KeyCode.DPadLeft, v7.ActionPriority.Low)
			return
		else
			if not v25 and v26 then
				v6.unbindAction(v7.Action.DropObject)
			end
			return
		end
	end
	local function v31() --[[ Line: 100 ]] --[[ Name: update ]]
		-- upvalues: l_LocalPlayer_0 (copy), v24 (copy), v27 (copy), l_HoveringObject_0 (copy), v14 (copy), l_isValidDraggableObject_0 (copy), l_isDraggableObjectWelded_0 (copy), v10 (ref)
		local l_Character_0 = l_LocalPlayer_0.Character
		if not l_Character_0 then
			v24(false)
			v27(false)
			return
		else
			local l_Value_0 = l_HoveringObject_0.Value
			local v30 = v14(l_Character_0)
			if l_Value_0 and l_isValidDraggableObject_0(l_Value_0) and not l_isDraggableObjectWelded_0(l_Value_0) and l_Value_0:HasTag("ToolObject") and (not l_Value_0:GetAttribute("OwnerId") or l_Value_0:GetAttribute("OwnerId") == l_LocalPlayer_0.UserId) then
				v10 = l_Value_0
				if l_Value_0:HasTag("ShopItem") then
					v10 = nil
				end
			else
				v10 = nil
			end
			v24(v10 ~= nil)
			v27(v30 ~= nil)
			return
		end
	end
	local function v36(v32) --[[ Line: 130 ]] --[[ Name: onCharacterAdded ]]
		-- upvalues: v31 (copy), v24 (copy), v27 (copy)
		local function v33() --[[ Line: 131 ]] --[[ Name: handleChildChanged ]]
			-- upvalues: v31 (ref)
			v31()
		end
		local v34 = v32.ChildAdded:Connect(v33)
		local v35 = v32.ChildRemoved:Connect(v33)
		v32.Destroying:Once(function() --[[ Line: 138 ]]
			-- upvalues: v34 (copy), v35 (copy), v24 (ref), v27 (ref)
			v34:Disconnect()
			v35:Disconnect()
			v24(false)
			v27(false)
		end)
		v31()
	end
	if l_LocalPlayer_0.Character then
		v36(l_LocalPlayer_0.Character)
	end
	l_HoveringObject_0.Changed:Connect(v31)
	l_LocalPlayer_0.CharacterAdded:Connect(v36)
end)

-- Dragging System
ReplicatedStorage:WaitForChild("Client"):WaitForChild("Handlers"):WaitForChild("DraggableItemHandlers"):WaitForChild("ClientDraggableObjectHandler").Enabled = false

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RequestStartDrag = Remotes.Events.RequestStartDrag
local UpdateDrag = Remotes.Events.UpdateDrag
local RequestStopDrag = Remotes.Events.RequestStopDrag
local RequestWeld = Remotes.Events.RequestWeld
local RequestUnweld = Remotes.Events.RequestUnweld
local FeatureFlags = require(ReplicatedStorage.Shared.SharedConstants.FeatureFlags)
local HoveringObject = ReplicatedStorage.Client.Handlers.DraggableItemHandlers.ClientDraggableObjectHandler:FindFirstChild("HoveringObject")
local DraggingObject = ReplicatedStorage.Client.Handlers.DraggableItemHandlers.ClientDraggableObjectHandler:FindFirstChild("DraggingObject")
local ActionController = require(ReplicatedStorage.Client.Controllers.ActionController)
local InputCategorizer = require(ReplicatedStorage.Client.Controllers.ActionController.InputCategorizer)
local DraggableObjectUtil = require(ReplicatedStorage.Shared.Utils.DraggableObjectUtil)
local TagUtil = require(ReplicatedStorage.Shared.Utils.TagUtil)
local Tag = require(ReplicatedStorage.Shared.SharedConstants.Tag)
local ActionData = require(ReplicatedStorage.Client.DataBanks.ActionData)
local RotationGizmo = require(ReplicatedStorage.Client.Handlers.DraggableItemHandlers.ClientDraggableObjectHandler.RotationGizmo)
local isValidDraggableObject = DraggableObjectUtil.isValidDraggableObject
local isValidWeldTarget = DraggableObjectUtil.isValidWeldTarget
local isDraggableObjectWelded = DraggableObjectUtil.isDraggableObjectWelded
local findFirstAncestorOfClassWithTag = TagUtil.findFirstAncestorOfClassWithTag
local CurrentCamera = workspace.CurrentCamera
local DragHighlight = ReplicatedStorage.Client.Handlers.DraggableItemHandlers.ClientDraggableObjectHandler:FindFirstChild("DragHighlight")
local v32 = false
local v33 = nil
local v34 = nil
local v35 = nil
local v36 = nil
local v37 = false
local v38 = 0
local XAxis = Enum.Axis.X
local v40 = nil
local v41 = nil
local v42 = nil
local v43 = nil
local v44 = nil
local function raycastInFrontOfCamera()
	local l_Position_0 = CurrentCamera.CFrame.Position
	local v46 = CurrentCamera.CFrame.LookVector * 10
	local v47 = RaycastParams.new()
	v47.FilterType = Enum.RaycastFilterType.Exclude
	v47.FilterDescendantsInstances = {
		LocalPlayer.Character
	}
	return workspace:Raycast(l_Position_0, v46, v47)
end
local function getDraggableObjectInFrontOfCamera()
	local v49 = raycastInFrontOfCamera()
	if v49 and v49.Instance then
		local v50 = findFirstAncestorOfClassWithTag(v49.Instance, "Model", Tag.DraggableObject)
		if v50 and isValidDraggableObject(v50) then
			if not v32 and v36 then
				v36.Enabled = HoveringObject.Value == v50
			end
			v36 = v50:FindFirstChild("ObjectInfo")
			return v50
		end
	elseif v36 then
		v36.Enabled = false
		v36 = nil
	end
	return nil
end
local function getWeldTargetTouchingObject(v52)
	if not v52 then
		return nil
	else
		local l_v52_BoundingBox_0 = v52:GetBoundingBox()
		local l_v52_ExtentsSize_0 = v52:GetExtentsSize()
		local v55 = OverlapParams.new()
		v55.FilterType = Enum.RaycastFilterType.Exclude
		v55.FilterDescendantsInstances = {
			v52
		}
		local l_workspace_PartBoundsInBox_0 = workspace:GetPartBoundsInBox(l_v52_BoundingBox_0, l_v52_ExtentsSize_0 * 1.05, v55)
		local v57 = nil
		for _, v59 in l_workspace_PartBoundsInBox_0 do
			if v59:IsA("BasePart") and isValidWeldTarget(v59) then
				return v59
			end
		end
		return v57
	end
end
local function requestStopDrag()
	if v33 and v33.PrimaryPart then
		RequestStopDrag:FireServer()
		if v43 then
			v43:Destroy()
		end
		if v44 then
			v44:Destroy()
		end
		if v42 then
			v42:Destroy()
		end
	end
	if DragHighlight then
		DragHighlight.Adornee = nil
	end
	v32 = false
	v33 = nil
	v43 = nil
	v44 = nil
	v42 = nil
	v37 = false
	v38 = 0
	v40 = nil
	if v41 then
		v41:destroy()
	end
end
local function onServerDragRequestResponse(v86, v88)
	if not v86 or not isValidDraggableObject(v88) then
		v32 = false
		v33 = nil
		return
	else
		v32 = true
		v33 = v88
		v37 = false
		v41 = RotationGizmo.new(v88)
		if not FeatureFlags.Experimental.ServerOwnedDragging then
			if v88:HasTag(Tag.RopedObject) then
				return
			else
				v42 = Instance.new("Attachment")
				v43 = Instance.new("AlignPosition")
				v44 = Instance.new("AlignOrientation")
				if v33 and v42 and v43 and v44 then
					v42.Name = "DragAttachment"
					v42.Parent = v33.PrimaryPart
					v43.Name = "DragAlignPosition"
					v43.Mode = Enum.PositionAlignmentMode.OneAttachment
					v43.ApplyAtCenterOfMass = false
					v43.MaxForce = 100000
					v43.Responsiveness = 50
					v43.Attachment0 = v42
					v43.Parent = v33.PrimaryPart
					v43.Position = v33.PrimaryPart.Position
					v44.Name = "DragAlignOrientation"
					v44.Mode = Enum.OrientationAlignmentMode.OneAttachment
					v44.MaxTorque = 10000
					v44.Responsiveness = 50
					v44.Attachment0 = v42
					v44.Parent = v33.PrimaryPart
				end
			end
		end
		return
	end
end
local function handleDragAction(_, v69, v70)
	if InputCategorizer.getLastInputCategory() == "Gamepad" and v70.UserInputType == Enum.UserInputType.MouseButton1 then
		return Enum.ContextActionResult.Pass
	else
		if v69 == Enum.UserInputState.Begin then
			if v34 then
				if isDraggableObjectWelded(v34) then
					return Enum.ContextActionResult.Pass
				else
					local l_v34_0 = v34
					if not v32 and LocalPlayer.Character then
						onServerDragRequestResponse(true, l_v34_0)
						RequestStartDrag:FireServer(l_v34_0)
					end
					return Enum.ContextActionResult.Sink
				end
			end
		elseif v69 == Enum.UserInputState.End and v32 then
			requestStopDrag()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
end
local function handleWeldAction(_, v74)
	if v74 ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	elseif v32 then
		if v35 then
			RequestWeld:FireServer(v33, v35)
		end
		return Enum.ContextActionResult.Pass
	else
		if v34 then
			RequestUnweld:FireServer(v34)
		end
		return Enum.ContextActionResult.Sink
	end
end
local function handleSwitchAxisAction(_, v77)
	if v77 == Enum.UserInputState.Begin then
		if XAxis == Enum.Axis.X then
			XAxis = Enum.Axis.Y
		elseif XAxis == Enum.Axis.Y then
			XAxis = Enum.Axis.Z
		elseif XAxis == Enum.Axis.Z then
			XAxis = Enum.Axis.X
		end
		if v41 then
			v41:setCurrentAxis(XAxis)
		end
		v38 = tick()
		return Enum.ContextActionResult.Sink
	else
		return Enum.ContextActionResult.Pass
	end
end
local function updateDrag(v79)
	if not v32 or not v33 or not v33.PrimaryPart then
		return
	else
		local l_CFrame_0 = CurrentCamera.CFrame
		local l_LookVector_0 = l_CFrame_0.LookVector
		local v82 = l_CFrame_0.Position + l_LookVector_0 * 10
		local l_v33_Pivot_0 = v33:GetPivot()
		if ActionController.isBound(ActionData.Action.RotateObject) and ActionController.isPressed(ActionData.Action.RotateObject) then
			v37 = true
			v38 = tick()
			if not v40 then
				v40 = l_v33_Pivot_0 - l_v33_Pivot_0.Position
			elseif v40 then
				local v84 = v79 * 4
				if XAxis == Enum.Axis.X then
					v40 = v40 * CFrame.Angles(v84, 0, 0)
				elseif XAxis == Enum.Axis.Y then
					v40 = v40 * CFrame.Angles(0, v84, 0)
				elseif XAxis == Enum.Axis.Z then
					v40 = v40 * CFrame.Angles(0, 0, v84)
				end
			end
		end
		if FeatureFlags.Experimental.ServerOwnedDragging or v33:HasTag(Tag.RopedObject) then
			UpdateDrag:FireServer(l_LookVector_0, v82)
			return
		else
			if v43 and v44 then
				v43.Position = v82
				if not v37 then
					v44.CFrame = CFrame.new(v82, v82 + l_LookVector_0)
					return
				else
					v44.CFrame = CFrame.new(v82) * v40
				end
			end
			return
		end
	end
end
local function updateInteractionText()
	local l_Character_0 = LocalPlayer.Character
	if not l_Character_0 then
		return
	else
		local l_Humanoid_0 = l_Character_0:FindFirstChildOfClass("Humanoid")
		if not l_Humanoid_0 or l_Humanoid_0 and l_Humanoid_0.Sit then
			return
		else
			local v95 = false
			local v96 = false
			local v97 = false
			local v98 = "Drag"
			local v99 = "Weld"
			if v32 then
				v98 = "Drop"
				v95 = true
				v97 = true
				if v35 then
					v96 = true
				end
			elseif v34 then
				if isDraggableObjectWelded(v34) then
					v99 = "Unweld"
					v96 = true
				else
					v95 = true
				end
			end
			if v34 and v34:GetAttribute("OwnerId") and v34:GetAttribute("OwnerId") ~= LocalPlayer.UserId then
				v95 = false
			end
			if ActionController.isBound(ActionData.Action.DragObject) ~= v95 then
				if v95 then
					ActionController.bindAction(ActionData.Action.DragObject, handleDragAction, ActionData.ActionContext[ActionData.Action.DragObject], Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2, ActionData.ActionPriority.High)
				else
					ActionController.unbindAction(ActionData.Action.DragObject)
				end
			end
			if ActionController.isBound(ActionData.Action.RotateObject) ~= v97 then
				if v97 then
					ActionController.bindAction(ActionData.Action.RotateObject, ActionData.noOp, ActionData.ActionContext[ActionData.Action.RotateObject], Enum.KeyCode.R, Enum.KeyCode.ButtonL2, ActionData.ActionPriority.Low)
				else
					ActionController.unbindAction(ActionData.Action.RotateObject)
				end
			end
			if ActionController.isBound(ActionData.Action.ChangeRotationAxis) ~= v97 then
				if v97 then
					ActionController.bindAction(ActionData.Action.ChangeRotationAxis, handleSwitchAxisAction, ActionData.ActionContext[ActionData.Action.ChangeRotationAxis], Enum.KeyCode.T, Enum.KeyCode.ButtonY, ActionData.ActionPriority.Low)
				else
					ActionController.unbindAction(ActionData.Action.ChangeRotationAxis)
				end
			end
			if v96 ~= ActionController.isBound(ActionData.Action.WeldObject) then
				if v96 then
					ActionController.bindAction(ActionData.Action.WeldObject, handleWeldAction, ActionData.ActionContext[ActionData.Action.WeldObject], Enum.KeyCode.Z, Enum.KeyCode.ButtonX, ActionData.ActionPriority.Medium)
				else
					ActionController.unbindAction(ActionData.Action.WeldObject)
				end
			end
			if ActionController.isBound(ActionData.Action.DragObject) then
				ActionController.setButtonText(ActionData.Action.DragObject, v98)
			end
			if ActionController.isBound(ActionData.Action.WeldObject) then
				ActionController.setButtonText(ActionData.Action.WeldObject, v99)
			end
			return
		end
	end
end
local function updateVisuals()
	if v32 and v33 then
		DragHighlight.Adornee = v33
		if v33:HasTag("ShopItem") then
			DragHighlight.OutlineColor = Color3.fromRGB(255, 247, 0)
		else
			DragHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		end
		if v41 then
			v41:setParent(CurrentCamera)
		end
	elseif v34 then
		DragHighlight.Adornee = v34
		if v34:HasTag("ShopItem") then
			DragHighlight.OutlineColor = Color3.fromRGB(255, 247, 0)
		else
			DragHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		end
		if v41 then
			v41:setParent(nil)
		end
	else
		DragHighlight.Adornee = nil
		if v41 then
			v41:setParent(nil)
		end
	end
	if v41 then
		if tick() > v38 + 1.5 then
			v41:hide()
			return
		else
			v41:show()
		end
	end
end
RequestWeld.OnClientEvent:Connect(function(v102)
	if v102 then
		requestStopDrag()
	end
end)

local StopDrag = Instance.new("BindableEvent", ReplicatedStorage)
StopDrag.Name = "StopDrag"
StopDrag.Event:Connect(function()
	requestStopDrag()
end)

RunService.RenderStepped:Connect(function(v103)
	v34 = getDraggableObjectInFrontOfCamera()
	v35 = getWeldTargetTouchingObject(DraggingObject.Value)
	updateDrag(v103)
	updateInteractionText()
	updateVisuals()
	HoveringObject.Value = if v34 ~= v33 then v34 else nil
	DraggingObject.Value = v33
end)
