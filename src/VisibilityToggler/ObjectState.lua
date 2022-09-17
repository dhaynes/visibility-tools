local Globals = require(script.Parent.Globals)
local ObjectState = {}

----------------

function ObjectState.isContainerObject(obj)
	return obj:IsA("Model") or obj:IsA("Folder")
end

function ObjectState.hasEnabledProperty(obj)
	local bool = obj:IsA("Beam")
		or obj:IsA("Light")
		or obj:IsA("ParticleEmitter")
		or obj:IsA("Trail")
		or obj:IsA("Smoke")
		or obj:IsA("Fire")
		or obj:IsA("Sparkles")
		or obj:IsA("LayerCollector")
	return bool
end

function ObjectState.hasTransparencyProperty(obj)
	return obj:IsA("BasePart") or obj:IsA("Decal")
end

function ObjectState.isValidObject(obj)
	local state, errorMessage = pcall(function()
		return obj:IsDescendantOf(game.Workspace)
	end)
	if state == false or obj == game.Workspace or obj:IsA("Terrain") then
		return false
	else
		return true
	end
end

function ObjectState.isHideableObject(obj)
	if not ObjectState.isValidObject(obj) then
		return false
	end

	return ObjectState.hasTransparencyProperty(obj)
		or ObjectState.hasEnabledProperty(obj)
		or ObjectState.isContainerObject(obj)
end

function ObjectState.isInvisible(obj)
	return obj:GetAttribute(Globals.INVISIBLE) == 1
end

function ObjectState.isHidden(obj)
	return obj:GetAttribute(Globals.HIDDEN) == 1
end

function ObjectState.parentIsNotHidden(obj, ignore)
	--walk upwards in the hierarchy to check for a parent that is hidden.
	local parent = obj.Parent
	while true do
		if parent ~= ignore and ObjectState.isHidden(parent) then
			return false
		elseif parent == game.Workspace then
			return true
		else
			parent = parent.Parent
		end
	end
end

----------------
-- State management --
----------------

function ObjectState.makeHidden(obj)
	--mark the HIDDEN attribute and the name of the obj
	obj:SetAttribute(Globals.HIDDEN, 1)
end

function ObjectState.makeNotHidden(obj)
	obj:SetAttribute(Globals.HIDDEN, nil)
end

function ObjectState.makeTransparent(obj)
	--Save the current transparency in an attribute.
	obj:SetAttribute(Globals.TRANSPARENCY, obj.Transparency)
	obj.Transparency = 1
	ObjectState.markAsInvisible(obj)
	--obj.LocalTransparencyModifier = 1
end

function ObjectState.makeUnTransparent(obj)
	--Restore saved Transparency.
	if obj:GetAttribute(Globals.TRANSPARENCY) then
		obj.Transparency = obj:GetAttribute(Globals.TRANSPARENCY)
		obj:SetAttribute(Globals.TRANSPARENCY, nil)
	end
	ObjectState.markAsVisible(obj)
	--obj.LocalTransparencyModifier = 0
end

function ObjectState.makeUnEnabled(obj)
	obj.Enabled = obj:GetAttribute(Globals.ENABLED)
	obj:SetAttribute(Globals.ENABLED, true)
	if obj:IsA("ParticleEmitter") then
		obj:Clear()
	end
	ObjectState.markAsInvisible(obj)
end

function ObjectState.makeEnabled(obj)
	if obj:GetAttribute(Globals.ENABLED) then
		obj.Enabled = obj:GetAttribute(Globals.ENABLED)
		obj:SetAttribute(Globals.ENABLED, nil)
	end
	ObjectState.markAsVisible(obj)
end

function ObjectState.markAsVisible(obj)
	obj:SetAttribute(Globals.INVISIBLE, nil)
end

function ObjectState.markAsInvisible(obj)
	obj:SetAttribute(Globals.INVISIBLE, 1)
end

function ObjectState.updateObjectName(obj)
	obj.Name = string.gsub(obj.Name, "*", "")
	obj.Name = string.gsub(obj.Name, "%[HIDDEN%]% ", "")
	if ObjectState.isHidden(obj) then
		obj.Name = "[HIDDEN] " .. obj.Name -- Hidden
	end
	if ObjectState.isInvisible(obj) then
		obj.Name = "*" .. obj.Name -- Invisible
	end
end

return ObjectState