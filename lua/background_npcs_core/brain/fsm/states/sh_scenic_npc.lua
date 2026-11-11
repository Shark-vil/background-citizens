-- "calm" group: the reactions to a shot or a hit look for calm actors. Both realms know the group.
bgNPC.States.Register('scenic_npc', 'calm')

if SERVER then
	local DOOR_CAPABILITIES = CAP_AUTO_DOORS + CAP_OPEN_DOORS
	-- An actor of a scene (systems/scenic/): plays one looped sequence. A calm state (walk, talk, a random
	-- pick of the brain) does not pull it out of the scene, a reaction to danger does.
	bgNPC.States.Register('scenic_npc', 'calm', {
		start = function(actor, state, data)
			local npc = actor:GetNPC()
			if data.door and npc.CapabilitiesRemove then npc:CapabilitiesRemove(DOOR_CAPABILITIES) end
			actor:PlayStaticSequence(data.seq, true)
		end,
		update = function(actor, state, data)
			if data.door and (not IsValid(data.door) or bgNPC.Util.IsDoorOpen(data.door)) then
				actor:SetState('none', nil, true)
			end
		end,
		not_stop = function(actor, state, data, new_state)
			return new_state == 'none' or bgNPC.States.GetGroup(new_state) == 'calm'
		end,
		stop = function(actor, state, data)
			local npc = actor:GetNPC()
			local back = data.back
			if not back and data.exit_pos and IsValid(npc) then npc:SetPos(data.exit_pos) end
			if data.door and IsValid(npc) and npc.CapabilitiesAdd and GetConVar('bgn_npc_open_doors'):GetBool() then
				npc:CapabilitiesAdd(DOOR_CAPABILITIES)
			end
			if not back then return end

			-- off the chair or the seat, the way the sit_to_chair states do it
			if IsValid(npc) then
				npc:RemoveCallOnRemove('BGN_ScenicSeat')
				npc:SetParent(nil)
				npc:SetAngles(Angle(0, npc:GetAngles().y, 0))
				npc:SetPos(npc:GetPos() + npc:GetForward() * 15)
				npc:SetCollisionGroup(back.old_collision)
				npc:PhysWake()
			end

			if IsValid(back.chair) then
				back.chair.occupied = false
				back.chair.sitDelay = CurTime() + 15
			end
			if back.seat then
				back.seat:SetSitting(NULL)
				back.seat.sitDelay = CurTime() + 15
			end
		end,
	})
end
