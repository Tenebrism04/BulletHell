local ScoreDB = require("db")

-- SOunds
local sounds = {
    background   = love.audio.newSource("assets/audio/Bad_Apple_8Bit.wav", "stream"),
    select       = love.audio.newSource("assets/audio/select00.wav", "static"),
    ok           = love.audio.newSource("assets/audio/se_ok00.wav", "static"),
    cancel       = love.audio.newSource("assets/audio/se_cancel00.wav", "static"),
    bulletSpawn  = love.audio.newSource("assets/audio/tan01.wav", "static"),
    bomb         = love.audio.newSource("assets/audio/se_slash.wav", "static"),
    hit        = love.audio.newSource("assets/audio/damage00.wav", "static"),
    death        = love.audio.newSource("assets/audio/se_pldead00.wav", "static")
}

-- Player
local player = {
    x = 400, y = 500, r = 6, speed = 260,
    hp = 100, bombs = 3,
    bombActive = false, bombTimer = 0,
    invincible = false, invincibleTimer = 0
}

local BOMB_DURATION = 2.5
local MAX_BOMBS = 5

-- Bullets & patterns
local bullets = {}
local spiralAngle = 0
local shootTimer = 0
local shootInterval = 0.5
local minShootInterval = 0.18

local patterns = {"radial", "inverse", "cross", "aimed"}
local currentPattern = 1
local patternTimer = 0
local PATTERN_DURATION = 10
local patternLabel = ""
local patternLabelTimer = 0

-- Bomb pickups
local bombPickups = {}

-- Particles & rings
local particles = {}
local bombRings = {}

-- UI & effects
local fade = 1
local fadeSpeed = 2
local screenShake = 0
local hitFlash = 0
local slowMo = 1
local deathTimer = 0

-- Milestones
local lastMilestone = 0
local MILESTONE_INTERVAL = 500

-- Game state
local state = "menu"
local playerName = ""
local score = 0

-- Menu
local menuItems = {"Start", "Controls", "Leaderboard", "Exit"}
local selected = 1
local menuY = 0
local targetMenuY = 0

-- Fonts
local fontBig, fontMed, fontSmall, fontTiny

-- Utility
local function drawCentered(text, y, font)
    love.graphics.setFont(font)
    local w = font:getWidth(text)
    love.graphics.print(text, (800 - w) / 2, y)
end

-- Particles
local function spawnParticles(x, y, count, speed, size, r, g, b, life)
    for i = 1, count do
        local angle = love.math.random() * math.pi * 2
        local spd = love.math.random() * speed
        table.insert(particles, {
            x = x, y = y,
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd,
            life = life or 0.4,
            maxLife = life or 0.4,
            size = size or 2,
            r = r or 1, g = g or 1, b = b or 1
        })
    end
end

-- Pattern firing
local function firePattern(name)
    local ex = 400 + math.sin(love.timer.getTime()) * 100
    local ey = 300

    sounds.bulletSpawn:setVolume(0.1)
    local snd = sounds.bulletSpawn:clone()  -- new sound instance
    snd:play()

    if name == "radial" then
        local count, speed = 10, 160
        for i = 1, count do
            local angle = (i / count) * math.pi * 2 + spiralAngle
            table.insert(bullets, {
                x = ex, y = ey,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed,
                trail = {}, r = 1, g = 1, b = 1
            })
        end

    elseif name == "inverse" then
        local count, speed = 10, 160
        for i = 1, count do
            local angle = (i / count) * math.pi * 2 - spiralAngle * 2
            table.insert(bullets, {
                x = ex, y = ey,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed,
                trail = {}, r = 0.6, g = 0.8, b = 1
            })
        end
        -- fire both directions for (weave effect}
        for i = 1, count do
            local angle = (i / count) * math.pi * 2 + spiralAngle
            table.insert(bullets, {
                x = ex, y = ey,
                vx = math.cos(angle) * (speed * 0.7),
                vy = math.sin(angle) * (speed * 0.7),
                trail = {}, r = 0.4, g = 0.6, b = 1
            })
        end

    elseif name == "cross" then
        local clusters = 4
        local perCluster = 6
        local speed = 180
        for c = 0, clusters - 1 do
            local baseAngle = (c / clusters) * math.pi * 2 + spiralAngle
            for j = 1, perCluster do
                local spread = (j - perCluster/2) * 0.12
                local angle = baseAngle + spread
                table.insert(bullets, {
                    x = ex, y = ey,
                    vx = math.cos(angle) * speed,
                    vy = math.sin(angle) * speed,
                    trail = {}, r = 1, g = 0.6, b = 0.2
                })
            end
        end

    elseif name == "aimed" then
        -- aimed shot
        local dx = player.x - ex
        local dy = player.y - ey
        local len = math.sqrt(dx*dx + dy*dy)
        dx, dy = dx/len, dy/len
        local speed = 240
        local offsets = {-0.25, 0, 0.25}
        for _, off in ipairs(offsets) do
            local angle = math.atan2(dy, dx) + off
            table.insert(bullets, {
                x = ex, y = ey,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed,
                trail = {}, r = 1, g = 0.3, b = 0.4
            })
        end
        -- plus a radial ring at lower speed
        local count = 8
        for i = 1, count do
            local angle = (i / count) * math.pi * 2 + spiralAngle
            table.insert(bullets, {
                x = ex, y = ey,
                vx = math.cos(angle) * 130,
                vy = math.sin(angle) * 130,
                trail = {}, r = 1, g = 0.5, b = 0.5
            })
        end
    end
end

local patternNames = {
    radial  = "RADIAL SPIRAL",
    inverse = "TWIN SPIRAL",
    cross   = "CROSS BURST",
    aimed   = "HUNTER MODE"
}

local function switchPattern()
    currentPattern = currentPattern % #patterns + 1
    patternLabel = patternNames[patterns[currentPattern]]
    patternLabelTimer = 2.0
end

-- Bomb
local function activateBomb()
    if player.bombs <= 0 or player.bombActive then return end
    player.bombs = player.bombs - 1
    player.bombActive = true
    player.bombTimer = BOMB_DURATION
    player.invincible = true
    player.invincibleTimer = BOMB_DURATION

    table.insert(bombRings, {r = 0, maxR = 700, life = 1.0, maxLife = 1.0})
    table.insert(bombRings, {r = 0, maxR = 700, life = 0.75, maxLife = 0.75})

    spawnParticles(player.x, player.y, 60, 320, 3, 0.4, 0.7, 1, 1.2)
    spawnParticles(player.x, player.y, 30, 180, 2, 1,   1,   1, 1.0)

    for _, b in ipairs(bullets) do
        spawnParticles(b.x, b.y, 3, 80, 1.5, 0.6, 0.8, 1, 0.4)
        score = score + 5
    end
    bullets = {}
    screenShake = 6
end

-- Spawn bomb pickup
local function spawnBombPickup()
    if player.bombs >= MAX_BOMBS then return end
    table.insert(bombPickups, {
        x = love.math.random(60, 740),
        y = love.math.random(80, 400),
        r = 10,
        pulse = 0
    })
end

-- Reset
local function resetGame()
    player.x, player.y = 400, 500
    player.hp = 100
    player.bombs = 3
    player.bombActive = false
    player.bombTimer = 0
    player.invincible = false
    player.invincibleTimer = 0
    bullets = {}
    particles = {}
    bombRings = {}
    bombPickups = {}
    shootTimer = 0
    shootInterval = 0.5
    spiralAngle = 0
    score = 0
    screenShake = 0
    fade = 0
    lastMilestone = 0
    currentPattern = 1
    patternTimer = 0
    patternLabel = ""
    patternLabelTimer = 0
end

function love.load()
    sounds.background:setLooping(true)
    sounds.background:setVolume(0.3)
    sounds.background:play()
    ScoreDB.init("scores.db")
    fontBig   = love.graphics.newFont(32)
    fontMed   = love.graphics.newFont(20)
    fontSmall = love.graphics.newFont(14)
    fontTiny  = love.graphics.newFont(11)
end

function love.update(dt)
    if slowMo < 1 then
        slowMo = math.min(1, slowMo + dt * 1.5)
        dt = dt * slowMo
    end

    if state == "dying" then
        deathTimer = deathTimer + dt
        fade = math.min(1, fade + dt * 1.2)
        screenShake = screenShake * 0.9
        for i = #particles, 1, -1 do
            local p = particles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.life = p.life - dt
            if p.life <= 0 then table.remove(particles, i) end
        end
        if deathTimer > 1.2 then state = "nameinput" end
        return
    end

    if state ~= "menu" then
        fade = math.max(0, fade - fadeSpeed * dt)
    else
        targetMenuY = selected * 40
        menuY = menuY + (targetMenuY - menuY) * 10 * dt
        fade = math.min(1, fade + fadeSpeed * dt)
    end

    if state ~= "playing" then return end

    -- bomb state
    if player.bombActive then
        player.bombTimer = player.bombTimer - dt
        if player.bombTimer <= 0 then
            player.bombActive = false
        end
    end

    if player.invincible then
        player.invincibleTimer = player.invincibleTimer - dt
        if player.invincibleTimer <= 0 then
            player.invincible = false
        end
    end

    -- bomb rings
    for i = #bombRings, 1, -1 do
        local ring = bombRings[i]
        ring.r = ring.r + (ring.maxR / ring.maxLife) * dt * 1.5
        ring.life = ring.life - dt
        if ring.life <= 0 then table.remove(bombRings, i) end
    end

    -- pattern switching
    patternTimer = patternTimer + dt
    if patternTimer >= PATTERN_DURATION then
        patternTimer = 0
        switchPattern()
    end

    if patternLabelTimer > 0 then
        patternLabelTimer = patternLabelTimer - dt
    end

    -- shooting
    local interval = patterns[currentPattern] == "aimed" and
        math.max(0.55, shootInterval * 1.8) or
        math.max(minShootInterval, shootInterval)

    shootInterval = math.max(minShootInterval, shootInterval * (1 - 0.015 * dt))
    shootTimer = shootTimer + dt
    if shootTimer >= interval then
        firePattern(patterns[currentPattern])
        shootTimer = 0
    end

    spiralAngle = spiralAngle + 2.5 * dt

    score = score + dt * 10

    -- milestone check
    local milestone = math.floor(score / MILESTONE_INTERVAL)
    if milestone > lastMilestone then
        lastMilestone = milestone
        spawnBombPickup()
    end

    -- update bullets
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        table.insert(b.trail, 1, {x = b.x, y = b.y})
        if #b.trail > 8 then table.remove(b.trail) end
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        if b.y < -50 or b.y > 850 or b.x < -50 or b.x > 850 then
            table.remove(bullets, i)
        end
    end

    -- update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vx = p.vx * 0.92
        p.vy = p.vy * 0.92
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end

    -- update bomb pickups
    for i = #bombPickups, 1, -1 do
        local pk = bombPickups[i]
        pk.pulse = pk.pulse + dt * 3

        local dx = player.x - pk.x
        local dy = player.y - pk.y
        if math.sqrt(dx*dx + dy*dy) < player.r + pk.r then
            player.bombs = math.min(MAX_BOMBS, player.bombs + 1)
            spawnParticles(pk.x, pk.y, 12, 120, 2, 0.4, 0.8, 1, 0.5)
            table.remove(bombPickups, i)
        end
    end

    -- player movement
    if love.keyboard.isDown("a") then player.x = player.x - player.speed * dt end
    if love.keyboard.isDown("d") then player.x = player.x + player.speed * dt end
    if love.keyboard.isDown("w") then player.y = player.y - player.speed * dt end
    if love.keyboard.isDown("s") then player.y = player.y + player.speed * dt end
    if love.keyboard.isDown("lshift") then player.speed = 160 else player.speed = 260 end

    player.x = math.max(player.r, math.min(800 - player.r, player.x))
    player.y = math.max(player.r, math.min(600 - player.r, player.y))

    -- collision
    if not player.invincible then
        for i = #bullets, 1, -1 do
            local b = bullets[i]
            local dx = player.x - b.x
            local dy = player.y - b.y
            if dx*dx + dy*dy < (player.r + 3)^2 then
                love.audio.play(sounds.hit)
                player.hp = player.hp - 1
                screenShake = 8
                hitFlash = 1
                slowMo = 0.25
                player.invincible = true
                player.invincibleTimer = 1.8
                table.remove(bullets, i)

                if player.hp <= 0 then
                    love.audio.play(sounds.death)
                    spawnParticles(player.x, player.y, 40, 280, 4, 1, 0.4, 0.1, 0.9)
                    spawnParticles(player.x, player.y, 25, 150, 2, 1, 0.8, 0.2, 0.7)
                    spawnParticles(player.x, player.y, 15, 80,  3, 1, 1,   1,   0.5)
                    state = "dying"
                    deathTimer = 0
                else
                    spawnParticles(player.x, player.y, 14, 180, 2.5, 1, 0.5, 0.1, 0.35)
                    spawnParticles(player.x, player.y, 8,  90,  1.5, 1, 0.9, 0.5, 0.25)
                end
                break
            end
        end
    end

    if screenShake > 0 then
        screenShake = math.max(0, screenShake - 10 * dt)
    end
end

function love.keypressed(key)
    if state == "menu" then
        if key == "up" then selected = selected - 1 love.audio.play(sounds.select) end
        if key == "down" then selected = selected + 1 love.audio.play(sounds.select) end
        if selected < 1 then selected = #menuItems end
        if selected > #menuItems then selected = 1 end
        if key == "return" then
            love.audio.play(sounds.ok)
            local choice = menuItems[selected]
            if choice == "Start" then resetGame(); state = "playing"
            elseif choice == "Controls" then state = "controls"
            elseif choice == "Leaderboard" then state = "leaderboard"
            elseif choice == "Exit" then love.event.quit()
            end
        end
    end

    if (state == "controls" or state == "leaderboard") and key == "escape" then
        love.audio.play(sounds.cancel)
        state = "menu"
    end

    if state == "nameinput" then
        if key == "backspace" then
            playerName = playerName:sub(1, -2)
        end
        if key == "return" and #playerName > 0 then
            love.audio.play(sounds.ok)
            ScoreDB.save(playerName, math.floor(score))
            state = "leaderboard"
        end
    end

    if key == "r" and state ~= "playing" then
        love.audio.play(sounds.cancel)
        love.event.quit("restart")
    end

    if key == "x" and state == "playing" then
        love.audio.play(sounds.bomb)
        activateBomb()
    end
end

function love.textinput(t)
    if state == "nameinput" and #playerName < 12 then
        playerName = playerName .. t
    end
end

function love.draw()
    love.graphics.setColor(0.05, 0.05, 0.08)
    love.graphics.rectangle("fill", 0, 0, 800, 600)

    -- background dots
    for i = 1, 40 do
        local x = (i*97 + love.timer.getTime()*30) % 800
        local y = (i*53 + love.timer.getTime()*20) % 600
        love.graphics.setColor(0.1, 0.1, 0.15, 0.3)
        love.graphics.circle("fill", x, y, 2)
    end

    -- menu
    if state == "menu" then
        love.graphics.setColor(1, 1, 1)
        drawCentered("BULLET HELL", 110 + math.sin(love.timer.getTime()*2)*4, fontBig)
        for i, item in ipairs(menuItems) do
            local y = 220 + i*40 + math.sin(love.timer.getTime()*2 + i)*2
            if i == selected then
                love.graphics.setColor(1, 0.7, 0.2)
                love.graphics.print("> "..item, 300 + math.sin(love.timer.getTime()*8)*3, y)
            else
                love.graphics.setColor(0.7, 0.7, 0.7)
                love.graphics.print(item, 300, y)
            end
        end
        return
    end

    -- controls
    if state == "controls" then
        love.graphics.setColor(1, 1, 1)
        drawCentered("CONTROLS", 120, fontBig)
        drawCentered("WASD - Move", 210, fontMed)
        drawCentered("X - Bomb  (clears screen, invincible)", 250, fontMed)
        drawCentered("Collect glowing orbs for bonus bombs", 290, fontMed)
        drawCentered("Survive as long as possible", 330, fontMed)
        drawCentered("ESC to return", 400, fontSmall)
        return
    end

    -- leaderboard
    if state == "leaderboard" then
        local data = ScoreDB.getTop(10)
        love.graphics.setColor(1, 1, 1)
        drawCentered("LEADERBOARD", 100, fontBig)
        for i, entry in ipairs(data) do
            local y = 170 + i*32
            love.graphics.setColor(0.1, 0.1, 0.18, 0.85)
            love.graphics.rectangle("fill", 230, y-6, 360, 26, 6, 6)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(fontSmall)
            love.graphics.print(i..".", 240, y)
            love.graphics.print(entry.name, 270, y)
            love.graphics.print(entry.score, 500, y)
        end
        love.graphics.setColor(1, 1, 1, 0.4)
        drawCentered("Press ESCAPE to return", 530, fontTiny)
        return
    end

    -- name input
    if state == "nameinput" then
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        love.graphics.setColor(1, 1, 1)
        drawCentered("GAME OVER", 170, fontBig)
        drawCentered("Score: " .. math.floor(score), 220, fontMed)
        drawCentered("Enter your name:", 270, fontMed)
        love.graphics.setColor(0.4, 0.7, 1)
        drawCentered(playerName .. "_", 310, fontMed)
        love.graphics.setColor(1, 1, 1, 0.4)
        drawCentered("Press ENTER to save", 370, fontTiny)
        return
    end

    -- screen shake
    local shake = screenShake * screenShake
    local ox = shake > 0 and love.math.random(-math.ceil(shake), math.ceil(shake)) or 0
    local oy = shake > 0 and love.math.random(-math.ceil(shake), math.ceil(shake)) or 0
    love.graphics.push()
    love.graphics.translate(ox, oy)

    -- bomb rings
    for _, ring in ipairs(bombRings) do
        local a = (ring.life / ring.maxLife) * 0.5
        love.graphics.setColor(0.4, 0.7, 1, a)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", player.x, player.y, ring.r)
        love.graphics.setLineWidth(1)
    end

    -- bomb pickups
    for _, pk in ipairs(bombPickups) do
        local pulse = math.abs(math.sin(pk.pulse))
        love.graphics.setColor(0.3, 0.7, 1, 0.3 + pulse * 0.3)
        love.graphics.circle("fill", pk.x, pk.y, pk.r + pulse * 3)
        love.graphics.setColor(0.6, 0.9, 1, 0.9)
        love.graphics.circle("line", pk.x, pk.y, pk.r)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setFont(fontTiny)
        love.graphics.print("B", pk.x - 4, pk.y - 6)
    end

    -- bullet trails
    for _, b in ipairs(bullets) do
        for j, t in ipairs(b.trail) do
            local a = (1 - j / #b.trail) * 0.35
            local s = 3 * (1 - j / #b.trail)
            love.graphics.setColor(b.r * 0.7, b.g * 0.7, b.b, a)
            love.graphics.circle("fill", t.x, t.y, s)
        end
    end

    -- bullets
    for _, b in ipairs(bullets) do
        love.graphics.setColor(b.r, b.g, b.b)
        love.graphics.circle("fill", b.x, b.y, 3)
    end

    -- particles
    for _, p in ipairs(particles) do
        local a = p.life / p.maxLife
        love.graphics.setColor(p.r, p.g, p.b, a)
        love.graphics.circle("fill", p.x, p.y, p.size * a + 0.5)
    end

    -- player (flicker when invincible)
    local showPlayer = true
    if player.invincible and not player.bombActive then
        showPlayer = math.floor(love.timer.getTime() * 14) % 2 == 0
    end
    if showPlayer then
        if player.bombActive then
            love.graphics.setColor(0.4, 0.8, 1)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.circle("fill", player.x, player.y, player.r)

        -- hitbox dot
        love.graphics.setColor(1, 0.3, 0.3, 0.9)
        love.graphics.circle("fill", player.x, player.y, 2)
    end

    love.graphics.pop()

    -- HUD
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print("HP:    " .. player.hp, 10, 10)
    love.graphics.print("Score: " .. math.floor(score), 10, 30)

    -- bomb HUD
    for i = 1, MAX_BOMBS do
        if i <= player.bombs then
            love.graphics.setColor(0.4, 0.75, 1, 0.9)
        else
            love.graphics.setColor(0.3, 0.3, 0.4, 0.4)
        end
        love.graphics.circle("fill", 10 + (i-1) * 18, 62, 6)
    end
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.setFont(fontTiny)
    love.graphics.print("BOMBS [X]", 10, 72)

    -- pattern label flash
    if patternLabelTimer > 0 then
        local a = math.min(1, patternLabelTimer)
        love.graphics.setColor(1, 0.85, 0.3, a)
        love.graphics.setFont(fontMed)
        drawCentered(patternLabel, 30, fontMed)
    end

    -- next pattern timer bar
    local barW = 120
    local barProgress = 1 - (patternTimer / PATTERN_DURATION)
    love.graphics.setColor(0.2, 0.2, 0.3, 0.6)
    love.graphics.rectangle("fill", 800 - barW - 10, 10, barW, 6, 3)
    love.graphics.setColor(0.5, 0.7, 1, 0.8)
    love.graphics.rectangle("fill", 800 - barW - 10, 10, barW * barProgress, 6, 3)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setFont(fontTiny)
    love.graphics.print("next pattern", 800 - barW - 10, 20)

    -- bomb active overlay
    if player.bombActive then
        local a = (player.bombTimer / BOMB_DURATION) * 0.15
        love.graphics.setColor(0.3, 0.6, 1, a)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
    end

    -- fade overlay
    if fade > 0 then
        love.graphics.setColor(0, 0, 0, fade * 0.9)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        if state == "dying" then
            love.graphics.setColor(1, 0.5, 0.2, fade)
            drawCentered("YOU DIED", 260, fontBig)
        end
    end

    -- hit flash
    if hitFlash > 0 then
        love.graphics.setColor(1, 1, 1, hitFlash * 0.6)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        hitFlash = math.max(0, hitFlash - love.timer.getDelta() * 3)
    end
end