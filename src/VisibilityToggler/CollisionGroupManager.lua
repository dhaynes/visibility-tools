local PhysicsService = game:GetService("PhysicsService")
local Globals = require(script.Parent.Globals)

local CollisionGroupMgr = {}

function CollisionGroupMgr:HiddenCollisionGroupExists()
	return PhysicsService:IsCollisionGroupRegistered(Globals.HIDDEN)
end

function CollisionGroupMgr:MaxCollisionGroupsReached()
	if
		#PhysicsService:GetRegisteredCollisionGroups() == PhysicsService:GetMaxCollisionGroups()
		and not self:HiddenCollisionGroupExists()
	then
		warn(
			"VisibilityTools: Cannot hide object because you've reached the max allowable CollisionGroups (32). Remove a CollisionGroup to proceed"
		)
		return true
	else
		return false
	end
end

function CollisionGroupMgr:CreateHiddenCollisionGroup()
	if not self:HiddenCollisionGroupExists() then
		PhysicsService:RegisterCollisionGroup(Globals.HIDDEN)
		PhysicsService:CollisionGroupSetCollidable("Default", Globals.HIDDEN, false)
	end
end

function CollisionGroupMgr:AddToHiddenCollisionGroup(obj)
	if obj:IsA("BasePart") == false then
		return
	end
	self:CreateHiddenCollisionGroup()
	--stash the name of the existing collision group as an attribute.
	local collisionGroupName = obj.CollisionGroup
	--if it's nil, then that means it belongs to a collision group that doesn't exist. So put it in default.
	if collisionGroupName == Globals.HIDDEN then
		collisionGroupName = "Default"
	end
	obj:SetAttribute(Globals.COLLISION_GROUP, collisionGroupName)
	obj.CollisionGroup = Globals.HIDDEN
end

function CollisionGroupMgr:RemoveFromHiddenCollisionGroup(obj)
	if obj:IsA("BasePart") == false then
		return
	end

	if self:HiddenCollisionGroupExists() then
		local containsPart = (obj.CollisionGroup == Globals.HIDDEN)
		if containsPart then
			local attribute = obj:GetAttribute(Globals.COLLISION_GROUP)
			if not attribute then
				attribute = "Default"
			end
			obj.CollisionGroup = attribute
			obj:SetAttribute(Globals.COLLISION_GROUP, nil)
		end
	end
end
function CollisionGroupMgr:RemoveHiddenCollisionGroup()
	if self:HiddenCollisionGroupExists() then
		PhysicsService:UnregisterCollisionGroup(Globals.HIDDEN)
	end
end

return CollisionGroupMgr
