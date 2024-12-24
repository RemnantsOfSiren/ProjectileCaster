--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
}

type ProjectileCaster = typeof(setmetatable({} :: ProjectileCasterSettings, ProjectileCaster))

function ProjectileCaster.new(Settings: ProjectileCasterSettings): ProjectileCaster
    if Settings.Visual then
        assert(Settings.Visual:IsDescendantOf(ReplicatedStorage), "@[ProjectileCaster] - Visual must be a descendant of ReplicatedStorage.")
    end

    local RaycastParams = RaycastParams.new()
    RaycastParams.FilterDescendantsInstances = Settings.Ignore or {}
    RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

    return setmetatable({
        Size = Settings.Size or 1,
        Speed = Settings.Speed or 10,
        Visual = Settings.Visual,
        Config = Settings.Config,
        MaxDistance = Settings.MaxDistance,
        __RaycastParams = RaycastParams,
    }, ProjectileCaster)
end


function ProjectileCaster:Cast(Start: Vector3, Direction: Vector3, VisualOverride: Instance?)
    if VisualOverride then
        assert(VisualOverride:IsDescendantOf(ReplicatedStorage), "@[ProjectileCaster] - Visual Override must be a descendant of ReplicatedStorage.")
    end

    return Projectile.new({
        Size = self.Size,
        Speed = self.Speed,
        Start = Start,
        Direction = Direction,
        MaxDistance = self.MaxDistance,
        Visual = VisualOverride or self.Visual,
        Config = self.Config,   
    })
end

return ProjectileCaster