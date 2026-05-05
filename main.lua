local ScoreDB = require("db")

local player = {x = 400, y = 500, r = 6, speed = 260, hp = 3, bomb = 3}

local bullets = {}

local spiralAngle = 0

local shootTimer = 0
local shootInterval = 0.5
local minShootInterval = 0.25
local difficultyTimer = 0

local screenShake = 0

local state = "playing"

local playerName = ""
local score = 0

function drawCentered(text, y, font)
    love.graphics.setFont(font)
    local w = font:getWidth(text)
    love.graphics.print(text, (800 - w) / 2, y)
end

function spawnRadial(x, y)
    -- number of bullets in a pattern
    local count = 18
    local speed = 200

    for i = 1, count do
        local angle = (i / count) * math.pi * 2
        angle = angle + spiralAngle
        table.insert(bullets, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed
        })
    end
end



function love.load()
    
    ScoreDB.init("scores.db")
    love.window.setTitle("Pattern Bullet Hell")

    -- UI
    fontBig = love.graphics.newFont(32)
    fontMed = love.graphics.newFont(20)
    fontSmall = love.graphics.newFont(14)

    table.insert(bullets, {
    x = 400,
    y = 300,
    vx = 0,
    vy = -200
})

end

function love.update(dt)

    
    if state ~= "playing" then return end

    shootInterval = math.max(minShootInterval, shootInterval * (1 - 0.02 * dt))
    
    shootTimer = shootTimer + dt
    if shootTimer >= shootInterval then
        spawnRadial(400 + math.sin(love.timer.getTime()) * 100, 300)
        shootTimer = 0
    end
    
    score = score + dt * 10
    spiralAngle = spiralAngle + 2.5 * dt
    -- reverse loop
    for i = #bullets, 1, -1 do
        local b = bullets[i]

        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt

        if b.y < -50 or b.y > 850 or b.x < -50 or b.x > 850 then
         table.remove(bullets, i)
        end
    end
    
    -- movement
    if love.keyboard.isDown("a") then
    player.x = player.x - player.speed * dt
    end

    if love.keyboard.isDown("s") then
    player.y = player.y + player.speed * dt
    end

    if love.keyboard.isDown("d") then
    player.x = player.x + player.speed * dt
    end

    if love.keyboard.isDown("w") then
    player.y = player.y - player.speed * dt
    end

    -- collision
    for i = #bullets, 1, -1 do
        local b = bullets[i]

        local dx = player.x - b.x
        local dy = player.y - b.y

        local distanceSq = dx * dx + dy * dy
        local radius = player.r + 3             -- circles are "touching"

        if distanceSq < radius * radius then
            -- should stop game here
            
            player.hp = player.hp - 1
            screenShake = 5
            table.remove(bullets, i)

            if player.hp <= 0 then
                player.hp = 0
                state = "nameinput"
                end

        end
    end

    if screenShake > 0 then
    screenShake = math.max(0, screenShake - 10 * dt)
    end

   
end

-- -- testing only
--  function love.keypressed(key)
--     if key == "space" then
--         spawnRadial(400, 300)
--     end
-- end

-- name input
function love.textinput(t)
    if state == "nameinput" then
        if #playerName < 12 then
            playerName = playerName .. t
        end
    end
end

-- backspace handling
function love.keypressed(key)
    if state == "nameinput" then
        if key == "backspace" then
            playerName = playerName:sub(1, -2)
        end

        if key == "return" then
            ScoreDB.save(playerName, math.floor(score)) -- replace 0 with your score later
            state = "leaderboard"
        end

        
    end
    if key == "r" and state ~= "playing" then
        love.event.quit("restart")
        end
end

function love.draw()

   if state == "nameinput" then

        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        love.graphics.setColor(1, 1, 1)

        drawCentered("GAME OVER", 180, fontBig)
        drawCentered("Enter Name", 240, fontMed)
        drawCentered(playerName .. "_", 280, fontMed)

        return
    end

if state == "leaderboard" then

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, 800, 600)
    love.graphics.setColor(1, 1, 1)

    drawCentered("SCORE SAVED!", 180, fontBig)
    drawCentered("Press R to restart", 240, fontMed)

    return
end

    local flooredShake = math.floor(screenShake)

    local offsetX = math.random(-flooredShake, flooredShake)
    local offsetY = math.random(-flooredShake, flooredShake)
    
    -- local offsetX = (math.random() * 2 - 1) * screenShake
    -- local offsetY = (math.random() * 2 - 1) * screenShake

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)


    for i = 1, #bullets do
        local b = bullets[i]
        love.graphics.circle("fill", b.x, b.y, 3)
    end
    love.graphics.circle("fill", player.x, player.y, player.r)

    -- original screen
    love.graphics.pop()

    -- HUD
    love.graphics.setFont(fontSmall)
    love.graphics.print("HP: " .. player.hp, 10, 10)
    love.graphics.print("Score: " .. math.floor(score or 0), 10, 30)

    love.graphics.setColor(1, 1, 1)
end

