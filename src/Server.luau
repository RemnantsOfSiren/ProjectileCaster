--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Projectile = require(script.Parent.Projectile)

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

--[=[
	@class ProjectileCaster

	ProjectileCaster is a class that allows you to cast projectiles in the game world, and handle the logic of the projectile's movement and collision.
	Projectile detection is both client and server sided, and can be configured to ignore specific instances.
	It utilizes a loose sanity check to ensure that the projectile is not being abused by the client.
]=]

--[=[
	@function new
	@within ProjectileCaster
	@param Settings: { Size: number?, Speed: number?, MaxDistance: number?, Visual: Instance?, Config: ModuleScript?, Ignore: { Instance }?, Debug: boolean? }
	@return ProjectileCaster
	Creates a new ProjectileCaster instance.
]=]
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

--[=[
	@method Cast
	@within ProjectileCaster
	@param Start: Vector3
	@param Direction: Vector3
	@param VisualOverride: Instance?
	@return Projectile
	
	Casts a new projectile in the game world.
	VisualOverride is an optional parameter that allows you to override the default visual of the projectile.
	VisualOverride must be a descendant of ReplicatedStorage.
]=]
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
		__RaycastParams = self.__RaycastParams
	})
end

--[=[
	@method Destroy
	@within ProjectileCaster
	Destroys the ProjectileCaster instance.
]=]
function ProjectileCaster:Destroy()
	table.clear(self)
end

return ProjectileCaster
