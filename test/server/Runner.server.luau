local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectileCaster = require(ReplicatedStorage.Packages.ProjectileCaster)

local Caster = ProjectileCaster.new({
    Size = 2,
    Speed = 60,
    Visual = ReplicatedStorage.Projectile,
    MaxDistance = 1000,
})

task.wait(5)

local Start = Vector3.new(0, 0, 0)
local End = Vector3.new(0, 50, 1000)

while true do
    local Projectile = Caster:Cast(Start, (End - Start).Unit)
    
    Projectile.Hit:Connect(function(Hit, Position, Normal)
        local Direction = Projectile:GetDirection()
        Projectile:UpdateDirection(Direction - (2 * Direction:Dot(Normal) * Normal))
    end)

    task.wait(.5)
end
