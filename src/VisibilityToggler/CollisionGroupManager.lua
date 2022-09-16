local PhysicsService = game:GetService("PhysicsService")
local Globals = require(script.Parent.Globals)

local CollisionGroupMgr = {}

function CollisionGroupMgr:HiddenCollisionGroupExists()
	local hiddenGroupExists = false
	local groups = PhysicsService:GetCollisionGroups()
	for _, group in ipairs(groups) do
		if group.name == Globals.HIDDEN then
			hiddenGroupExists = true
		end
	end
	return hiddenGroupExists
end

function CollisionGroupMgr:CreateHiddenCollisionGroup()
	if not self:HiddenCollisionGroupExists() then
		PhysicsService:CreateCollisionGroup(Globals.HIDDEN)
		PhysicsService:CollisionGroupSetCollidable("Default", Globals.HIDDEN, false)
	end
end

function CollisionGroupMgr:AddToHiddenCollisionGroup(obj)
	if obj:IsA("BasePart") == false then
		return
	end
	self:CreateHiddenCollisionGroup()
	--stash the name of the existing collision group as an attribute.
	local collisionGroupName = PhysicsService:GetCollisionGroupName(obj.CollisionGroupId)
	--if it's nil, then that means it belongs to a collision group that doesn't exist. So put it in default.
	if collisionGroupName == Globals.HIDDEN then
		collisionGroupName = "Default"
	end
	obj:SetAttribute(Globals.COLLISION_GROUP, collisionGroupName)
	PhysicsService:SetPartCollisionGroup(obj, Globals.HIDDEN)
end

function CollisionGroupMgr:RemoveFromHiddenCollisionGroup(obj)
	if obj:IsA("BasePart") == false then
		return
	end

	if self:HiddenCollisionGroupExists() then
		local containsPart = PhysicsService:CollisionGroupContainsPart(Globals.HIDDEN, obj)
		if containsPart then
			local attribute = obj:GetAttribute(Globals.COLLISION_GROUP)
			if not attribute then
				attribute = "Default"
			end
			PhysicsService:SetPartCollisionGroup(obj, attribute)
			obj:SetAttribute(Globals.COLLISION_GROUP, nil)
		end
	end
end

return CollisionGroupMgr
