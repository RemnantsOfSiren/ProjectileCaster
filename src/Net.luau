local ByteNet = require(script.Parent.Parent.ByteNet)

return ByteNet.defineNamespace("ProjectileCastNet", function()
	return {
		packets = {
			create = ByteNet.definePacket({
				value = ByteNet.struct({
					Id = ByteNet.string,
					Size = ByteNet.int8,
					Time = ByteNet.int32,
					Speed = ByteNet.int8,
					Start = ByteNet.vec3,
					Direction = ByteNet.vec3,
					-- Optional fields
					Config = ByteNet.optional(ByteNet.inst),
					Visual = ByteNet.optional(ByteNet.inst),
					Ignore = ByteNet.optional(ByteNet.array(ByteNet.inst)),
					MaxDistance = ByteNet.optional(ByteNet.int16),
				}),
			}),

			update = ByteNet.definePacket({
				value = ByteNet.struct({
					Id = ByteNet.string,
					Time = ByteNet.int32,
					Position = ByteNet.vec3,
					Direction = ByteNet.vec3,
				}),
			}),

			hit = ByteNet.definePacket({
				value = ByteNet.struct({
					Id = ByteNet.string,
					Time = ByteNet.int32,
					Normal = ByteNet.vec3,
					Object = ByteNet.inst,
					Position = ByteNet.vec3,
				}),
			}),

			destroy = ByteNet.definePacket({
				value = ByteNet.string,
			}),
		}
	}
end)
