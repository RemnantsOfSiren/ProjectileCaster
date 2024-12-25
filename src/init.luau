--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Projectile = require(script.Projectile)

local ProjectileCaster = {}
ProjectileCaster.__index = ProjectileCaster

type ProjectileCasterSettings = {
	Size: number?,
	Speed: number?,
	MaxDistance: number?,
	Visual: Instance?,
	Config: ModuleScript?,
	Ignore: { Instance }?,
	Debug: boolean?,
}

local ServerProjectiles = Instance.new("Folder")
ServerProjectiles.Name = "ServerProjectiles"
ServerProjectiles:AddTag("ProjectileCasterIgnore")
ServerProjectiles.Parent = workspace.CurrentCamera

type ProjectileCaster = typeof(setmetatable({} :: ProjectileCasterSettings, ProjectileCaster))

function ProjectileCaster.new(Settings: ProjectileCasterSettings): ProjectileCaster
	if Settings.Visual then
		assert(
			Settings.Visual:IsDescendantOf(ReplicatedStorage),
			"@[ProjectileCaster] - Visual must be a descendant of ReplicatedStorage."
		)
	end

	local IgnoreList = CollectionService:GetTagged("ProjectileCasterIgnore")

	for _, Instance in pairs(Settings.Ignore or {}) do
		table.insert(IgnoreList, Instance)
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterDescendantsInstances = IgnoreList
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

	return setmetatable({
		Size = Settings.Size or 1,
		Speed = Settings.Speed or 10,
		Debug = Settings.Debug,
		Visual = Settings.Visual,
		Config = Settings.Config,
		MaxDistance = Settings.MaxDistance,
		__RaycastParams = RaycastParams,
	}, ProjectileCaster)
end

function ProjectileCaster:Cast(Start: Vector3, Direction: Vector3, VisualOverride: Instance?)
	if VisualOverride then
		assert(
			VisualOverride:IsDescendantOf(ReplicatedStorage),
			"@[ProjectileCaster] - Visual Override must be a descendant of ReplicatedStorage."
		)
	end

	return Projectile.new({
		Size = self.Size,
		Start = Start,
		Speed = self.Speed,
		Debug = self.Debug,
		Config = self.Config,
		Visual = VisualOverride or self.Visual,
		Direction = Direction,
		MaxDistance = self.MaxDistance,
	})
end

return ProjectileCaster
