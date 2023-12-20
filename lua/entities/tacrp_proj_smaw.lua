AddCSLuaFile()

ENT.Base                     = "tacrp_proj_base"
ENT.PrintName                = "SMAW Rocket"
ENT.Spawnable                = false

ENT.Model                    = "models/weapons/tacint/rocket_deployed.mdl"

ENT.IsRocket = true // projectile has a booster and will not drop.

ENT.InstantFuse = false // projectile is armed immediately after firing.
ENT.RemoteFuse = false // allow this projectile to be triggered by remote detonator.
ENT.ImpactFuse = true // projectile explodes on impact.

ENT.ExplodeOnDamage = true
ENT.ExplodeUnderwater = true

ENT.Delay = 0
ENT.SafetyFuse = 0.2

ENT.AudioLoop = "TacRP/weapons/rpg7/rocket_flight-1.wav"

ENT.SmokeTrail = true

ENT.FlareColor = Color(200, 255, 255)

ENT.SteerSpeed = 30

function ENT:OnThink()
    if CLIENT then return end
    local wep = self.Inflictor
    if IsValid(wep) and wep:GetTactical() and !wep:GetReloading() and IsValid(wep:GetOwner()) and wep:GetOwner():IsPlayer() and wep:GetOwner():Alive() then
        local pos_tr = wep:GetMuzzleOrigin()
        local ang = wep:GetShootDir()

        local tr = util.TraceLine({
            start = pos_tr,
            endpos = pos_tr + (ang:Forward() * 30000),
            mask = MASK_VISIBLE,
            filter = self:GetOwner()
        })
        if tr.Hit then
            self.TargetAng = (tr.HitPos - self:GetPos()):Angle()
        end
    end
end

function ENT:PhysicsUpdate(phys)
    local v = phys:GetVelocity()
    if self.TargetAng then

        local p = self:GetAngles().p
        local y = self:GetAngles().y

        local diff = math.min(math.abs(math.AngleDifference(p, self.TargetAng.p)) + math.abs(math.AngleDifference(y, self.TargetAng.y)), self.SteerSpeed * 2)
        p = math.ApproachAngle(p, self.TargetAng.p, FrameTime() * self.SteerSpeed)
        y = math.ApproachAngle(y, self.TargetAng.y, FrameTime() * self.SteerSpeed)

        self:SetAngles(Angle(p, y, 0))
        phys:SetVelocityInstantaneous(self:GetForward() * math.min(v:Length() - diff * FrameTime() * 10 + 1500 * FrameTime(), 4000))
    else
        phys:SetVelocityInstantaneous(self:GetForward() * math.min(v:Length() + 1500 * FrameTime(), 4000))
    end
end

function ENT:Impact(data, collider)
    if self.SpawnTime + self.SafetyFuse > CurTime() and !self.NPCDamage then
        local attacker = self.Attacker or self:GetOwner()
        local ang = data.OurOldVelocity:Angle()
        local fx = EffectData()
        fx:SetOrigin(data.HitPos)
        fx:SetNormal(-ang:Forward())
        fx:SetAngles(-ang)
        util.Effect("ManhackSparks", fx)

        if IsValid(data.HitEntity) then
            local dmginfo = DamageInfo()
            dmginfo:SetAttacker(attacker)
            dmginfo:SetInflictor(self)
            dmginfo:SetDamageType(DMG_CRUSH + DMG_CLUB)
            dmginfo:SetDamage(250 * (self.NPCDamage and 0.5 or 1))
            dmginfo:SetDamageForce(data.OurOldVelocity * 25)
            dmginfo:SetDamagePosition(data.HitPos)
            data.HitEntity:TakeDamageInfo(dmginfo)
        end

        self:EmitSound("weapons/rpg/shotdown.wav", 80)

        for i = 1, 4 do
            local prop = ents.Create("prop_physics")
            prop:SetPos(self:GetPos())
            prop:SetAngles(self:GetAngles())
            prop:SetModel("models/weapons/tacint/rpg7_shrapnel_p" .. i .. ".mdl")
            prop:Spawn()
            prop:GetPhysicsObject():SetVelocityInstantaneous(data.OurNewVelocity * 0.5 + VectorRand() * 75)
            prop:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

            SafeRemoveEntityDelayed(prop, 3)
        end

        self:Remove()
        return true
    end
end

function ENT:Detonate()
    local attacker = self.Attacker or self:GetOwner()

    if self.NPCDamage then
        util.BlastDamage(self, attacker, self:GetPos(), 400, 120)
    else
        util.BlastDamage(self, attacker, self:GetPos(), 400, 300)
        self:FireBullets({
            Attacker = attacker,
            Damage = 600,
            Tracer = 0,
            Src = self:GetPos(),
            Dir = self:GetForward(),
            HullSize = 0,
            Distance = 32,
            IgnoreEntity = self,
            Callback = function(atk, btr, dmginfo)
                dmginfo:SetDamageType(DMG_AIRBOAT + DMG_BLAST) // airboat damage for helicopters and LVS vehicles
                dmginfo:SetDamageForce(self:GetForward() * 15000) // LVS uses this to calculate penetration!
            end,
        })
    end

    local fx = EffectData()
    fx:SetOrigin(self:GetPos())

    if self:WaterLevel() > 0 then
        util.Effect("WaterSurfaceExplosion", fx)
    else
        util.Effect("Explosion", fx)
    end

    self:EmitSound("TacRP/weapons/rpg7/explode.wav", 125, 90)

    self:Remove()
end