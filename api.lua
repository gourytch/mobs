-- Mobs Api (4th April 2015)
mobs = {}
mobs.mod = "redo"

-- Do mobs spawn in protected areas (0=yes, 1=no)
mobs.protected = 0

-- Initial check to see if damage is enabled and peaceful mode active
local damage_enabled = minetest.setting_getbool("enable_damage")
local peaceful_only = minetest.setting_getbool("only_peaceful_mobs")

function mobs:register_mob(name, def)
	minetest.register_entity(name, {
		name = name,

		owner = def.owner,
		order = def.order or "",
on_die = def.on_die,
jump_height = def.jump_height or 6,
		hp_min = def.hp_min or 5,
		hp_max = def.hp_max or 10,
		physical = true,
		collisionbox = def.collisionbox,
		visual = def.visual,
		visual_size = def.visual_size or {x=1, y=1},
		mesh = def.mesh,
		makes_footstep_sound = def.makes_footstep_sound,
		view_range = def.view_range or 5,
		walk_velocity = def.walk_velocity,
		run_velocity = def.run_velocity,
		damage = def.damage,
		light_damage = def.light_damage,
		water_damage = def.water_damage,
		lava_damage = def.lava_damage,
		fall_damage = def.fall_damage or 1,
		fall_speed = def.fall_speed or -10, -- must be lower than -2
		drops = def.drops,
		armor = def.armor,
		drawtype = def.drawtype,
		on_rightclick = def.on_rightclick,
		type = def.type,
		attack_type = def.attack_type,
		arrow = def.arrow,
		shoot_interval = def.shoot_interval,
		sounds = def.sounds or {},
		animation = def.animation,
		follow = def.follow or "",
		jump = def.jump or true,
		walk_chance = def.walk_chance or 50,
		attacks_monsters = def.attacks_monsters or false,
		group_attack = def.group_attack or false,
		--fov = def.fov or 120,
		passive = def.passive or false,
		recovery_time = def.recovery_time or 0.5,
		knock_back = def.knock_back or 3,
		blood_amount = def.blood_amount or 5,
		blood_texture = def.blood_texture or "mobs_blood.png",
		shoot_offset = def.shoot_offset or 0,
		floats = def.floats or 1, -- floats in water by default
		replace_rate = def.replace_rate,
		replace_what = def.replace_what,
		replace_with = def.replace_with,
		replace_offset = def.replace_offset or 0,

		stimer = 0,
		timer = 0,
		env_damage_timer = 0, -- only if state = "attack"
		attack = {player=nil, dist=nil},
		state = "stand",
		v_start = false,
		old_y = nil,
		lifetimer = 600,
		tamed = false,
		last_state = nil,
		pause_timer = 0,
		horny = false,
		hornytimer = 0,
		child = false,
		gotten = false,

		do_attack = function(self, player, dist)
			if self.state ~= "attack" then
					if math.random(0,100) < 90  and self.sounds.war_cry then
						minetest.sound_play(self.sounds.war_cry,{ object = self.object })
					end
				self.state = "attack"
				self.attack.player = player
				self.attack.dist = dist
			end
		end,
		
		set_velocity = function(self, v)
			if not v then v = 0 end -- added
			local yaw = self.object:getyaw()
			if self.drawtype == "side" then
				yaw = yaw+(math.pi/2)
			end
			local x = math.sin(yaw) * -v
			local z = math.cos(yaw) * v
			self.object:setvelocity({x=x, y=self.object:getvelocity().y, z=z})
		end,
		
		get_velocity = function(self)
			local v = self.object:getvelocity()
			return (v.x^2 + v.z^2)^(0.5)
		end,
--[[
		in_fov = function(self,pos)
			-- checks if POS is in self's FOV
			local yaw = self.object:getyaw()
			if self.drawtype == "side" then
				yaw = yaw+(math.pi/2)
			end
			local vx = math.sin(yaw)
			local vz = math.cos(yaw)
			local ds = math.sqrt(vx^2 + vz^2)
			local ps = math.sqrt(pos.x^2 + pos.z^2)
			local d = { x = vx / ds, z = vz / ds }
			local p = { x = pos.x / ps, z = pos.z / ps }
			
			local an = ( d.x * p.x ) + ( d.z * p.z )
			
			a = math.deg( math.acos( an ) )
			
			if a > ( self.fov / 2 ) then
				return false
			else
				return true
			end
		end,
]]
		set_animation = function(self, type)
			if not self.animation then
				return
			end
			if not self.animation.current then
				self.animation.current = ""
			end
			if type == "stand" and self.animation.current ~= "stand" then
				if self.animation.stand_start and self.animation.stand_end and self.animation.speed_normal then
					self.object:set_animation({x=self.animation.stand_start,
						y=self.animation.stand_end},self.animation.speed_normal, 0)
					self.animation.current = "stand"
				end
			elseif type == "walk" and self.animation.current ~= "walk"  then
				if self.animation.walk_start and self.animation.walk_end and self.animation.speed_normal then
					self.object:set_animation({x=self.animation.walk_start,y=self.animation.walk_end},
						self.animation.speed_normal, 0)
					self.animation.current = "walk"
				end
			elseif type == "run" and self.animation.current ~= "run"  then
				if self.animation.run_start and self.animation.run_end and self.animation.speed_run then
					self.object:set_animation({x=self.animation.run_start,y=self.animation.run_end},
						self.animation.speed_run, 0)
					self.animation.current = "run"
				end
			elseif type == "punch" and self.animation.current ~= "punch"  then
				if self.animation.punch_start and self.animation.punch_end and self.animation.speed_normal then
					self.object:set_animation({x=self.animation.punch_start,y=self.animation.punch_end},
						self.animation.speed_normal, 0)
					self.animation.current = "punch"
				end
			end
		end,
		
		on_step = function(self, dtime)

			local yaw = 0

			if self.type == "monster" and peaceful_only then
				self.object:remove()
			end
			
			self.lifetimer = self.lifetimer - dtime
			if self.lifetimer <= 0 and not self.tamed and self.type ~= "npc" then
				local player_count = 0
				for _,obj in ipairs(minetest.get_objects_inside_radius(self.object:getpos(), 10)) do
					if obj:is_player() then
						player_count = player_count + 1
						break -- only really need 1 player to be found
					end
				end
				if player_count == 0 and self.state ~= "attack" then
					minetest.log("action","lifetimer expired, removed mob "..self.name)
					self.object:remove()
					return
				end
			end

			-- check for mob drop/replace (used for chicken egg and sheep eating grass/wheat)
			if self.replace_rate and math.random(1,self.replace_rate) == 1 and self.child == false then
				local pos = self.object:getpos() ; pos.y = pos.y + self.replace_offset
				if #minetest.find_nodes_in_area(pos,pos,self.replace_what) > 0
				and self.object:getvelocity().y == 0 and self.state == "stand" then
					minetest.set_node(pos, {name = self.replace_with})
				end
			end

			-- gravity, falling or floating in water
			if self.floats == 1 then
				if minetest.get_item_group(minetest.get_node(self.object:getpos()).name, "water") ~= 0 then
					self.object:setacceleration({x = 0, y = 1.5, z = 0})
				else
					self.object:setacceleration({x = 0, y = self.fall_speed, z = 0})
				end
			else
				self.object:setacceleration({x = 0, y = self.fall_speed, z = 0})
			end

			-- fall damage
			if self.fall_damage == 1 and self.object:getvelocity().y == 0 then
				local d = self.old_y - self.object:getpos().y
				if d > 5 then
					self.object:set_hp(self.object:get_hp() - math.floor(d - 5))
					check_for_death(self)
				end
				self.old_y = self.object:getpos().y
			end
			
			-- if pause state then this is where the loop ends
			-- pause is only set after a monster is hit
			if self.pause_timer > 0 then
				self.pause_timer = self.pause_timer - dtime
				if self.pause_timer < 1 then
					self.pause_timer = 0
				end
				return
			end
			
			self.timer = self.timer + dtime
			if self.state ~= "attack" then
				if self.timer < 1 then
					return
				end
				self.timer = 0
			end

			if self.sounds and self.sounds.random and math.random(1, 100) <= 1 then
				minetest.sound_play(self.sounds.random, {object = self.object})
			end
			
			local do_env_damage = function(self)

				local pos = self.object:getpos()
				local n = minetest.get_node(pos)
				local tod = minetest.get_timeofday()
				pos.y = pos.y + (self.collisionbox[2] + self.collisionbox[5]) / 2

				if self.light_damage and self.light_damage ~= 0
				and pos.y > 0
				and (minetest.get_node_light(pos) or 0) > 10 -- direct sunlight (was 4)
				and tod > 0.2 and tod < 0.8 then
					self.object:set_hp(self.object:get_hp()-self.light_damage)
					effect(pos, 5, "tnt_smoke.png")
				end

				if self.water_damage and self.water_damage ~= 0
				and minetest.get_item_group(n.name, "water") ~= 0 then
					self.object:set_hp(self.object:get_hp()-self.water_damage)
					effect(pos, 5, "bubble.png")
				end
				
				if self.lava_damage and self.lava_damage ~= 0
				and minetest.get_item_group(n.name, "lava") ~= 0 then
					self.object:set_hp(self.object:get_hp()-self.lava_damage)
					effect(pos, 5, "fire_basic_flame.png")
				end

				check_for_death(self)
			end
			
			self.env_damage_timer = self.env_damage_timer + dtime
			if self.state == "attack" and self.env_damage_timer > 1 then
				self.env_damage_timer = 0
				do_env_damage(self)
			elseif self.state ~= "attack" then
				do_env_damage(self)
			end
			
			-- FIND SOMEONE TO ATTACK
			if self.type == "monster" and damage_enabled and self.state ~= "attack" then

				local s = self.object:getpos()
				local player = nil
				local type = nil
				local obj = nil

				for _,oir in ipairs(minetest.get_objects_inside_radius(s,self.view_range)) do

					if oir:is_player() then
						player = oir
						type = "player"
					else
						obj = oir:get_luaentity()
						if obj then
							player = obj.object
							type = obj.type
						end
					end
					
					if type == "player" or type == "npc" then
						local s = self.object:getpos()
						local p = player:getpos()
						local sp = s
						p.y = p.y + 1
						sp.y = sp.y + 1		-- aim higher to make looking up hills more realistic
						local dist = ((p.x-s.x)^2 + (p.y-s.y)^2 + (p.z-s.z)^2)^0.5
						if dist < self.view_range then -- and self.in_fov(self,p) then
							if minetest.line_of_sight(sp,p,2) == true then
								self.do_attack(self,player,dist)
								break
							end
						end
					end
				end
			end
			
			-- NPC FIND A MONSTER TO ATTACK
			if self.type == "npc" and self.attacks_monsters and self.state ~= "attack" then
				local s = self.object:getpos()
				local obj = nil
				local p, dist
				for _, oir in pairs(minetest.get_objects_inside_radius(s,self.view_range)) do
					obj = oir:get_luaentity()
					if obj and obj.type == "monster" then
						-- attack monster
						p = obj.object:getpos()
						dist = ((p.x-s.x)^2 + (p.y-s.y)^2 + (p.z-s.z)^2)^0.5
						self.do_attack(self,obj.object,dist)
						break
					end
				end
			end

			-- horny animal can mate for 40 seconds, afterwards horny animal cannot mate again for 200 seconds
			if self.horny == true and self.hornytimer < 240 and self.child == false then
				self.hornytimer = self.hornytimer + 1
				if self.hornytimer >= 240 then
					self.hornytimer = 0
					self.horny = false
				end
			end

			-- if animal is child take 240 seconds before growing into adult
			if self.child == true then
				self.hornytimer = self.hornytimer + 1
				if self.hornytimer > 240 then
					self.child = false
					self.hornytimer = 0
					self.object:set_properties({
						textures = self.base_texture,
						mesh = self.base_mesh,
						visual_size = {x=self.visual_size.x,y=self.visual_size.y},
						collisionbox = self.collisionbox,
					})
				end
			end

			-- if animal is horny, find another same animal who is horny and mate
			if self.horny == true and self.hornytimer <= 40 then
				local pos = self.object:getpos()
				effect(pos, 4, "heart.png")
				local ents = minetest.get_objects_inside_radius(pos, self.view_range)
				local num = 0
				local ent = nil
				for i,obj in ipairs(ents) do

					ent = obj:get_luaentity()
					if ent and ent.name == self.name and ent.horny == true and ent.hornytimer <= 40 then num = num + 1 end

					if num > 1 then
						self.following = ent
						ent.following = self
						self.horny = false
						self.hornytimer = 0
						self.following = nil
						ent.horny = false
						ent.following = nil
						ent.hornytimer = 0
						minetest.after(7, function(dtime)
							local mob = minetest.add_entity(pos, self.name)
							local ent2 = mob:get_luaentity()
							local textures = self.base_texture
							if def.child_texture then
								textures = def.child_texture[1]
							end
							mob:set_properties({
								textures = textures,
								visual_size = {x=self.visual_size.x/2,y=self.visual_size.y/2},
								collisionbox = {self.collisionbox[1]/2, self.collisionbox[2]/2, self.collisionbox[3]/2,
												self.collisionbox[4]/2, self.collisionbox[5]/2, self.collisionbox[6]/2},
							})
							ent2.child = true
							ent2.tamed = true
							ent2.following = ent -- follow mother
						end)
						num = 0
						break
					end
				end
			end

			if (self.follow ~= "" or self.order == "follow") and not self.following and self.state ~= "attack" then
				local s, p, dist
				for _,player in pairs(minetest.get_connected_players()) do
					s = self.object:getpos()
					p = player:getpos()
					dist = ((p.x-s.x)^2 + (p.y-s.y)^2 + (p.z-s.z)^2)^0.5
					if dist < self.view_range then
						self.following = player
						break
					end
				end
			end

			if self.type == "npc" and self.order == "follow" and self.state ~= "attack" then
				-- npc stop following player if not owner
				if self.following and self.type == "npc" and self.owner and self.owner ~= self.following:get_player_name() then
					self.following = nil
					self.v_start = false
				end
			else
				-- stop following player if not holding specific item
				if self.following and self.following.is_player and self.following:get_wielded_item():get_name() ~= self.follow then
					self.following = nil
					self.v_start = false
				end
			end

			if self.following then

				local s = self.object:getpos()
				local p

				if self.following.is_player and self.following:is_player() then
					p = self.following:getpos()
				elseif self.following.object then
					p = self.following.object:getpos()
				end

				if p then
					local dist = ((p.x-s.x)^2 + (p.y-s.y)^2 + (p.z-s.z)^2)^0.5
					if dist > self.view_range then
						self.following = nil
						self.v_start = false
					else
						local vec = {x=p.x-s.x, y=p.y-s.y, z=p.z-s.z}
						local yaw = math.atan(vec.z/vec.x)+math.pi/2
						if self.drawtype == "side" then
							yaw = yaw+(math.pi/2)
						end
						if p.x > s.x then
							yaw = yaw+math.pi
						end
						self.object:setyaw(yaw)

						-- anyone but standing npc's can move along
						if dist > 2 and self.order ~= "stand" then
							if not self.v_start then
								self.v_start = true
								self.set_velocity(self, self.walk_velocity)
							else
								if self.jump and self.get_velocity(self) <= 0.5 and self.object:getvelocity().y == 0 then
									local v = self.object:getvelocity()
									v.y = self.jump_height + 1
									self.object:setvelocity(v)
								end
								self.set_velocity(self, self.walk_velocity)
							end
							self:set_animation("walk")
						else
							self.v_start = false
							self.set_velocity(self, 0)
							self:set_animation("stand")

						end
						return
					end
				end
			end

			if self.state == "stand" then
				-- randomly turn
				if math.random(1, 4) == 1 then
					-- if there is a player nearby look at them
					local lp = nil
					local s = self.object:getpos()

					if self.type == "npc" then
						local o = minetest.get_objects_inside_radius(self.object:getpos(), 3)
						
						local yaw = 0
						for _,o in ipairs(o) do
							if o:is_player() then
								lp = o:getpos()
								break
							end
						end
					end

					if lp ~= nil then
						local vec = {x=lp.x-s.x, y=lp.y-s.y, z=lp.z-s.z}
						yaw = math.atan(vec.z/vec.x)+math.pi/2
						if self.drawtype == "side" then
							yaw = yaw+(math.pi/2)
						end
						if lp.x > s.x then
							yaw = yaw+math.pi
						end
					else 
						yaw = self.object:getyaw()+((math.random(0,360)-180)/180*math.pi)
					end
					self.object:setyaw(yaw)
				end

				self.set_velocity(self, 0)
				self.set_animation(self, "stand")

				-- npc's ordered to stand stay standing
				if self.type == "npc" and self.order == "stand" then
					self.set_velocity(self, 0)
					self.state = "stand"
					self:set_animation("stand")
				else
					if math.random(1, 100) <= self.walk_chance then
						self.set_velocity(self, self.walk_velocity)
						self.state = "walk"
						self.set_animation(self, "walk")
					end
				end

			elseif self.state == "walk" then

				if math.random(1, 100) <= 30 then
					self.object:setyaw(self.object:getyaw()+((math.random(0,360)-180)/180*math.pi))
				end
				if self.jump and self.get_velocity(self) <= 0.5 and self.object:getvelocity().y == 0 then
					local v = self.object:getvelocity()
					v.y = self.jump_height
					self.object:setvelocity(v)
				end
				self:set_animation("walk")
				self.set_velocity(self, self.walk_velocity)
				if math.random(1, 100) <= 30 then
					self.set_velocity(self, 0)
					self.state = "stand"
					self:set_animation("stand")
				end

			elseif self.state == "attack" and self.attack_type == "dogfight" then

				if not self.attack.player or not self.attack.player:getpos() then
					print("stop attacking")
					self.state = "stand"
					self:set_animation("stand")
					return
				end
				local s = self.object:getpos()
				local p = self.attack.player:getpos()
				local dist = ((p.x-s.x)^2 + (p.y-s.y)^2 + (p.z-s.z)^2)^0.5
				if dist > self.view_range or self.attack.player:get_hp() <= 0 then
					self.state = "stand"
					self.v_start = false
					self.set_velocity(self, 0)
					self.attack = {player=nil, dist=nil}
					self:set_animation("stand")
					return
				else
					self.attack.dist = dist
				end
				
				local vec = {x=p.x-s.x, y=p.y-s.y, z=p.z-s.z}
				local yaw = math.atan(vec.z/vec.x)+math.pi/2
				if self.drawtype == "side" then
					yaw = yaw+(math.pi/2)
				end
				if p.x > s.x then
					yaw = yaw+math.pi
				end
				self.object:setyaw(yaw)
				if self.attack.dist > 2 then
					if not self.v_start then
						self.v_start = true
						self.set_velocity(self, self.run_velocity)
					else
						if self.jump and self.get_velocity(self) <= 0.5 and self.object:getvelocity().y == 0 then
							local v = self.object:getvelocity()
							v.y = self.jump_height
							self.object:setvelocity(v)
						end
						self.set_velocity(self, self.run_velocity)
					end
					self:set_animation("run")
				else
					self.set_velocity(self, 0)
					self:set_animation("punch")
					self.v_start = false
					if self.timer > 1 then
						self.timer = 0
						local p2 = p
						local s2 = s
						p2.y = p2.y + 1.5
						s2.y = s2.y + 1.5
						if minetest.line_of_sight(p2,s2) == true then
							if self.sounds and self.sounds.attack then
								minetest.sound_play(self.sounds.attack, {object = self.object})
							end
							self.attack.player:punch(self.object, 1.0,  {
								full_punch_interval=1.0,
								damage_groups = {fleshy=self.damage}
							}, vec)
							if self.attack.player:get_hp() <= 0 then
								self.state = "stand"
								self:set_animation("stand")
							end
						end
					end
				end

			elseif self.state == "attack" and self.attack_type == "shoot" then

				if not self.attack.player or not self.attack.player:is_player() then
					self.state = "stand"
					self:set_animation("stand")
					return
				end
				local s = self.object:getpos()
				local p = self.attack.player:getpos()
				p.y = p.y - .5
				s.y = s.y + .5
				local dist = ((p.x-s.x)^2 + (p.y-s.y)^2 + (p.z-s.z)^2)^0.5
				if dist > self.view_range or self.attack.player:get_hp() <= 0 then
					self.state = "stand"
					self.v_start = false
					self.set_velocity(self, 0)
					if self.type ~= "npc" then
						self.attack = {player=nil, dist=nil}
					end
					self:set_animation("stand")
					return
				else
					self.attack.dist = dist
				end
				
				local vec = {x=p.x-s.x, y=p.y-s.y, z=p.z-s.z}
				local yaw = math.atan(vec.z/vec.x)+math.pi/2
				if self.drawtype == "side" then
					yaw = yaw+(math.pi/2)
				end
				if p.x > s.x then
					yaw = yaw+math.pi
				end
				self.object:setyaw(yaw)
				self.set_velocity(self, 0)
				
				if self.shoot_interval and self.timer > self.shoot_interval and math.random(1, 100) <= 60 then
					self.timer = 0

					self:set_animation("punch")

					if self.sounds and self.sounds.attack then
						minetest.sound_play(self.sounds.attack, {object = self.object})
					end

					local p = self.object:getpos()
					p.y = p.y + (self.collisionbox[2]+self.collisionbox[5])/2
					local obj = minetest.add_entity(p, self.arrow)
					local amount = (vec.x^2+vec.y^2+vec.z^2)^0.5
					local v = obj:get_luaentity().velocity
					vec.y = vec.y + self.shoot_offset -- this makes shoot aim accurate
					vec.x = vec.x*v/amount
					vec.y = vec.y*v/amount
					vec.z = vec.z*v/amount
					obj:setvelocity(vec)
				end
			end
		end,

		on_activate = function(self, staticdata, dtime_s)
			local pos = self.object:getpos()
			self.object:set_hp( math.random(self.hp_min, self.hp_max) ) -- set HP
			self.object:set_armor_groups({fleshy=self.armor})
			self.object:setacceleration({x=0, y= self.fall_speed, z=0})
			self.state = "stand"
			self.object:setvelocity({x=0, y=self.object:getvelocity().y, z=0}) ; self.old_y = self.object:getpos().y
			self.object:setyaw(math.random(1, 360)/180*math.pi)
			if self.type == "monster" and peaceful_only then
				self.object:remove()
			end
			if self.type ~= "npc" then
				self.lifetimer = 600 - dtime_s
			end
			if staticdata then
				local tmp = minetest.deserialize(staticdata)
				if tmp then
					if tmp.lifetimer then
						self.lifetimer = tmp.lifetimer - dtime_s
					end
					if tmp.tamed then
						self.tamed = tmp.tamed
					end
					if tmp.gotten then
						self.gotten = tmp.gotten
					end
					if tmp.child then
						self.child = tmp.child
					end
					if tmp.horny then
						self.horny = tmp.horny
					end
					if tmp.hornytimer then
						self.hornytimer = tmp.hornytimer
					end
					if tmp.textures then
						self.textures = tmp.textures
					end
					if tmp.mesh then
						self.mesh = tmp.mesh
					end
					if tmp.base_texture then
						self.base_texture = tmp.base_texture
					end
					if tmp.base_mesh then
						self.base_mesh = tmp.base_mesh
					end
				end
			end
			-- quick fix for dog so it doesn't revert back to wolf
			if self.type == "monster" and self.tamed == true then
				self.type = "npc"
			end
			if self.lifetimer <= 0 and not self.tamed and self.type ~= "npc" then
				self.object:remove()
			end
		end,

		get_staticdata = function(self)
			-- select random texture, set model
			if not self.base_texture then
				self.base_texture = def.textures[math.random(1,#def.textures)]
				self.base_mesh = def.mesh
			end
			-- set texture, model and size
			local textures = self.base_texture
			local mesh = self.base_mesh
			local vis_size = self.visual_size
			local colbox = self.collisionbox
			-- specific texture if gotten
			if self.gotten == true and def.gotten_texture then
				textures = def.gotten_texture
			end
			-- specific mesh if gotten
			if self.gotten == true and def.gotten_mesh then
				mesh = def.gotten_mesh
			end
			-- if object is child then set half size
			if self.child == true then
				vis_size = {x=self.visual_size.x/2,y=self.visual_size.y/2}
				if def.child_texture then
					textures = def.child_texture[1]
				end
				colbox = {self.collisionbox[1]/2, self.collisionbox[2]/2, self.collisionbox[3]/2,
						self.collisionbox[4]/2, self.collisionbox[5]/2, self.collisionbox[6]/2}
			end
			-- remember settings
			local tmp = {
				lifetimer = self.lifetimer,
				tamed = self.tamed,
				gotten = self.gotten,
				child = self.child,
				horny = self.horny,
				hornytimer = self.hornytimer,
				mesh = mesh,
				textures = textures,
				visual_size = vis_size,
				base_texture = self.base_texture,
				collisionbox = colbox,
			}
			self.object:set_properties(tmp)
			return minetest.serialize(tmp)
		end,

		on_punch = function(self, hitter, tflp, tool_capabilities, dir)

			process_weapon(hitter,tflp,tool_capabilities)
			check_for_death(self)

			--blood_particles
			local pos = self.object:getpos()
			pos.y = pos.y + (self.collisionbox[2] + self.collisionbox[5]) / 2
			if self.blood_amount > 0 and pos then
				effect(pos, self.blood_amount, self.blood_texture)
			end

			-- knock back effect, adapted from blockmen's pyramids mod
			-- https://github.com/BlockMen/pyramids
			local kb = self.knock_back
			local r = self.recovery_time

			if tflp < tool_capabilities.full_punch_interval then
				kb = kb * ( tflp / tool_capabilities.full_punch_interval )
				r = r * ( tflp / tool_capabilities.full_punch_interval )
			end

			local ykb=2
			local v = self.object:getvelocity()
			if v.y ~= 0 then
				ykb = 0
			end 

			self.object:setvelocity({x=dir.x*kb,y=ykb,z=dir.z*kb})
			self.pause_timer = r

			-- attack puncher and call other mobs for help
			if self.passive == false and not self.tamed then
				if self.state ~= "attack" then
					self.do_attack(self,hitter,1)
				end
				-- alert others to the attack
				local obj = nil
				for _, oir in pairs(minetest.get_objects_inside_radius(hitter:getpos(),5)) do
					obj = oir:get_luaentity()
					if obj then
						if obj.group_attack == true and obj.state ~= "attack" then
							obj.do_attack(obj,hitter,1)
						end
					end
				end
			end

		end,
		
	})
end

mobs.spawning_mobs = {}
function mobs:register_spawn(name, nodes, max_light, min_light, chance, active_object_count, max_height)
	mobs.spawning_mobs[name] = true	
	minetest.register_abm({
		nodenames = nodes,
		neighbors = {"air"},
		interval = 30,
		chance = chance,
		action = function(pos, node, _, active_object_count_wider)

			-- do not spawn if too many active in area
			if active_object_count_wider > active_object_count
			or not mobs.spawning_mobs[name] 
			or not pos then
				return
			end

			-- spawn above node
			pos.y = pos.y + 1

			-- mobs cannot spawn inside protected areas if enabled
			if mobs.protected == 1 and minetest.is_protected(pos, "") then
				return
			end

			-- check if light and height levels are ok to spawn
			local light = minetest.get_node_light(pos)
			if not light or light > max_light or light < min_light
			or pos.y > max_height then
				return
			end

			-- are we spawning inside a solid node?
			local nod = minetest.get_node_or_nil(pos)
			if not nod or not minetest.registered_nodes[nod.name]
			or minetest.registered_nodes[nod.name].walkable == true then return end
			pos.y = pos.y + 1
			nod = minetest.get_node_or_nil(pos)
			if not nod or not minetest.registered_nodes[nod.name]
			or minetest.registered_nodes[nod.name].walkable == true then return end

			if minetest.setting_getbool("display_mob_spawn") then
				minetest.chat_send_all("[mobs] Add "..name.." at "..minetest.pos_to_string(pos))
			end

			-- spawn mob half block higher
			pos.y = pos.y - 0.5
			minetest.add_entity(pos, name)

		end
	})
end

-- particle effects
function effect(pos, amount, texture)
	minetest.add_particlespawner({
		amount = amount,
		time = 0.25,
		minpos = pos,
		maxpos = pos,
		minvel = {x=-0, y=-2, z=-0},
		maxvel = {x=2,  y=2,  z=2},
		minacc = {x=-4, y=-4, z=-4},
		maxacc = {x=4, y=4, z=4},
		minexptime = 0.1,
		maxexptime = 1,
		minsize = 0.5,
		maxsize = 1,
		texture = texture,
	})
end

-- on mob death drop items
function check_for_death(self)
	if self.object:get_hp() > 0 then return end
	local pos = self.object:getpos()
	pos.y = pos.y + 0.5 -- drop items half a block higher
	self.object:remove()
	local obj = nil
	for _,drop in ipairs(self.drops) do
		if math.random(1, drop.chance) == 1 then
			obj = minetest.add_item(pos, ItemStack(drop.name.." "..math.random(drop.min, drop.max)))
			if obj then
				obj:setvelocity({x=math.random(-1,1), y=5, z=math.random(-1,1)})
			end
		end
	end
	if self.sounds.death ~= nil then
		minetest.sound_play(self.sounds.death,{object = self.object,})
	end
	if self.on_die then
		pos.y = pos.y - 0.5
		self.on_die(self, pos)
	end
end
		
function mobs:register_arrow(name, def)
	if not name or not def then return end -- errorcheck
	minetest.register_entity(name, {
		physical = false,
		visual = def.visual,
		visual_size = def.visual_size,
		textures = def.textures,
		velocity = def.velocity,
		hit_player = def.hit_player,
		hit_node = def.hit_node,
		hit_mob = def.hit_mob,
		drop = def.drop or false,
		collisionbox = {0,0,0,0,0,0}, -- remove box around arrows

		on_step = function(self, dtime)
			self.timer = (self.timer or 0) + 1
			if self.timer > 150 then self.object:remove() return end
			local engage = 10 - (self.velocity / 2) -- clear entity before arrow becomes active
			local pos = self.object:getpos()
			local node = minetest.get_node(self.object:getpos()).name
			-- hit node you can walk on
			if self.hit_node and node and minetest.registered_nodes[node] and minetest.registered_nodes[node].walkable then
				self.hit_node(self, pos, node)
				if self.drop == true then
					pos.y = pos.y + 1 ; self.lastpos = (self.lastpos or pos)
					minetest.add_item(self.lastpos, self.object:get_luaentity().name)
				end
				self.object:remove()
				return
			end

			if self.hit_player or self.hit_mob then
				for _,player in pairs(minetest.get_objects_inside_radius(pos, 1)) do
					-- hit player
					if self.hit_player and self.timer > engage and player:is_player() then
						self.hit_player(self, player)
						self.object:remove()
						return
					end
					-- hit mob
					if self.hit_mob and self.timer > engage and player:get_luaentity().name ~= self.object:get_luaentity().name
					and player:get_luaentity().name ~= "__builtin:item" then
						self.hit_mob(self, player)
						self.object:remove()
						return
					end
				end
				self.lastpos = pos
			end
		end
	})
end

function process_weapon(player, time_from_last_punch, tool_capabilities)
local weapon = player:get_wielded_item()
	if tool_capabilities ~= nil then
		local wear = ( tool_capabilities.full_punch_interval / 75 ) * 65535
		weapon:add_wear(wear)
		player:set_wielded_item(weapon)
	end
end

-- Spawn Egg
function mobs:register_egg(mob, desc, background, addegg)
local invimg = background
if addegg == 1 then
	invimg = invimg.."^mobs_chicken_egg.png"
end
minetest.register_craftitem(mob, {
	description = desc,
	inventory_image = invimg,
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.above
		if pointed_thing.above and not minetest.is_protected(pos, placer:get_player_name()) then
			pos.y = pos.y + 0.5
			minetest.add_entity(pos, mob)
			itemstack:take_item()
		end
		return itemstack
	end,
})
end
