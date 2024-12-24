local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectileCaster = require(ReplicatedStorage.Packages.ProjectileCaster)

local Caster = ProjectileCaster.new({
    Size = 2,
    Speed = 10,
    Visual = ReplicatedStorage.Projectile,
    MaxDistance = 1000,
})

Caster.Hit:Connect(function(Hit, Position, Normal)
    print(`Hit {Hit} at {Position} with {Normal}`)
end)

task.wait(5)

local Start = Vector3.new(0, 0, 0)
local End = Vector3.new(0, 0, 1000)

while true do
    Caster:Cast(Start, (End - Start).Unit)
    task.wait(.5)
end
