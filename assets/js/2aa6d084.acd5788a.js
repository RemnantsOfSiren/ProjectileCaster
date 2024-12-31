"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[379],{16188:e=>{e.exports=JSON.parse('{"functions":[{"name":"new","desc":"Creates a new ProjectileCaster instance.","params":[{"name":"Settings:","desc":"","lua_type":"{ Size: number?, Speed: number?, MaxDistance: number?, Visual: Instance?, Config: ModuleScript?, Ignore: { Instance }?, Debug: boolean? }"}],"returns":[{"desc":"","lua_type":"ProjectileCaster"}],"function_type":"static","source":{"line":42,"path":"src/init.luau"}},{"name":"Cast","desc":"Casts a new projectile in the game world.\\nVisualOverride is an optional parameter that allows you to override the default visual of the projectile.\\nVisualOverride must be a descendant of ReplicatedStorage.","params":[{"name":"Start:","desc":"","lua_type":"Vector3"},{"name":"Direction:","desc":"","lua_type":"Vector3"},{"name":"VisualOverride:","desc":"","lua_type":"Instance?"}],"returns":[{"desc":"","lua_type":"Projectile"}],"function_type":"method","source":{"line":83,"path":"src/init.luau"}},{"name":"Destroy","desc":"Destroys the ProjectileCaster instance.","params":[],"returns":[],"function_type":"method","source":{"line":109,"path":"src/init.luau"}}],"properties":[],"types":[],"name":"ProjectileCaster","desc":"ProjectileCaster is a class that allows you to cast projectiles in the game world, and handle the logic of the projectile\'s movement and collision.\\nProjectile detection is both client and server sided, and can be configured to ignore specific instances.\\nIt utilizes a loose sanity check to ensure that the projectile is not being abused by the client.","source":{"line":34,"path":"src/init.luau"}}')}}]);