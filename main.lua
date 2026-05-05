local ScoreDB = require("db")

local player = {x = 400, y = 500, r = 6, speed = 260, hp = 3}

local bullets = {}

local spiralAngle = 0

local shootTimer = 0
local shootInterval = 0.5
local minShootInterval = 0.25

local fade = 1
local fadeSpeed = 2

local screenShake = 0

local state = "menu"

local playerName = ""
local score = 0

local menuItems = {"Start", "Controls", "Leaderboard", "Exit"}
local selected = 1

local menuY = 0
local targetMenuY = 0

function drawCentered(text, y, font)
    love.graphics.setFont(font)
    local w = font:getWidth(text)
    love.graphics.print(text, (800 - w) / 2, y)
end

function spawnRadial(x, y)
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

function resetGame()
    player.x = 400
    player.y = 500
    player.hp = 3
    bullets = {}
    shootTimer = 0
    shootInterval = 0.5
    score = 0
    screenShake = 0
end

function love.load()
    ScoreDB.init("scores.db")

    fontBig = love.graphics.newFont(32)
    fontMed = love.graphics.newFont(20)
    fontSmall = love.graphics.newFont(14)
end

function love.update(dt)

    if state ~= "menu" then
    fade = math.max(0, fade - fadeSpeed * dt)
    else
    targetMenuY = selected * 40
    menuY = menuY + (targetMenuY - menuY) * 10 * dt
    fade = math.min(1, fade + fadeSpeed * dt)
    end

    if state ~= "playing" then return end

    shootInterval = math.max(minShootInterval, shootInterval * (1 - 0.02 * dt))

    shootTimer = shootTimer + dt
    if shootTimer >= shootInterval then
        spawnRadial(400 + math.sin(love.timer.getTime()) * 100, 300)
        shootTimer = 0
    end

    score = score + dt * 10
    spiralAngle = spiralAngle + 2.5 * dt

    for i = #bullets, 1, -1 do
        local b = bullets[i]

        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt

        if b.y < -50 or b.y > 850 or b.x < -50 or b.x > 850 then
            table.remove(bullets, i)
        end
    end

    if love.keyboard.isDown("a") then player.x = player.x - player.speed * dt end
    if love.keyboard.isDown("d") then player.x = player.x + player.speed * dt end
    if love.keyboard.isDown("w") then player.y = player.y - player.speed * dt end
    if love.keyboard.isDown("s") then player.y = player.y + player.speed * dt end

    for i = #bullets, 1, -1 do
        local b = bullets[i]

        local dx = player.x - b.x
        local dy = player.y - b.y
        local d2 = dx * dx + dy * dy

        local r = player.r + 3

        if d2 < r * r then
            player.hp = player.hp - 1
            screenShake = 5
            table.remove(bullets, i)

            if player.hp <= 0 then
                state = "nameinput"
            end
        end
    end

    if screenShake > 0 then
        screenShake = math.max(0, screenShake - 10 * dt)
    end
end

function love.keypressed(key)

    if state == "menu" then
        if key == "up" then selected = selected - 1 end
        if key == "down" then selected = selected + 1 end

        if selected < 1 then selected = #menuItems end
        if selected > #menuItems then selected = 1 end

        if key == "return" then
            local choice = menuItems[selected]

            if choice == "Start" then
                resetGame()
                state = "playing"
            elseif choice == "Controls" then
                state = "controls"
            elseif choice == "Leaderboard" then
                state = "leaderboard"
            elseif choice == "Exit" then
                love.event.quit()
            end
        end
    end

    if state == "controls" and key == "escape" then
        state = "menu"
    end

    if state == "leaderboard" and key == "escape" then
        state = "menu"
    end

    if state == "nameinput" then
        if key == "backspace" then
            playerName = playerName:sub(1, -2)
        end

        if key == "return" then
            ScoreDB.save(playerName, math.floor(score))
            state = "leaderboard"
        end
    end

    if key == "r" and state ~= "playing" then
        love.event.quit("restart")
    end

    if key == "space" and state == "playing" then
        spawnRadial(400, 300)
    end
end

function love.textinput(t)
    if state == "nameinput" then
        if #playerName < 12 then
            playerName = playerName .. t
        end
    end
end

function love.draw()

    love.graphics.setColor(0.05, 0.05, 0.08)
    love.graphics.rectangle("fill", 0, 0, 800, 600)

    for i = 1, 40 do
        local x = (i * 97 + love.timer.getTime() * 30) % 800
        local y = (i * 53 + love.timer.getTime() * 20) % 600
        love.graphics.setColor(0.1, 0.1, 0.15, 0.3)
        love.graphics.circle("fill", x, y, 2)
    end

love.graphics.setColor(1, 1, 1)

    if state == "menu" then
        love.graphics.clear(0.05, 0.05, 0.08)
        
        if i == selected then
        love.graphics.setColor(1, 0.6, 0.2, 0.2)
        love.graphics.print(item, 295, y)
        love.graphics.print(item, 305, y)
        end

        -- Title
        love.graphics.setColor(1, 0.6, 0.2)
        drawCentered("BULLET HELL", 110 + math.sin(love.timer.getTime() * 2) * 3, fontBig)
        love.graphics.setColor(1, 1, 1)

        for i, item in ipairs(menuItems) do
    local y = 220 + i * 40

    local offset = 0
    if i == selected then
        offset = 10 * math.sin(love.timer.getTime() * 6)
        love.graphics.setColor(1, 0.7, 0.2)
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
    end

    love.graphics.print(
        item,
        300 + offset,
        y + (i - selected) * 2
    )
end

        return
    end

    if state == "controls" then
        love.graphics.clear(0.05, 0.05, 0.08)
        drawCentered("CONTROLS", 120, fontBig)
        drawCentered("WASD - Move", 220, fontMed)
        drawCentered("Avoid bullets", 260, fontMed)
        drawCentered("ESC to return", 340, fontSmall)
        return
    end

    if state == "leaderboard" then
    leaderboardData = ScoreDB.getTop(10)
    drawCentered("LEADERBOARD", 120, fontBig)

    for i, entry in ipairs(leaderboardData) do
        love.graphics.print(
            i .. ". " .. entry.name .. " - " .. entry.score,
            300,
            200 + i * 25
        )
    end

    drawCentered("Press R to return", 500, fontSmall)
    return
end

    if state == "nameinput" then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        love.graphics.setColor(1, 1, 1)

        drawCentered("GAME OVER", 180, fontBig)
        drawCentered("Enter Name", 240, fontMed)
        drawCentered(playerName .. "_", 280, fontMed)
        return
    end

    local shake = math.floor(screenShake)
    local ox = math.random(-shake, shake)
    local oy = math.random(-shake, shake)

    love.graphics.push()
    love.graphics.translate(ox, oy)

    for i = 1, #bullets do
        local b = bullets[i]
        love.graphics.circle("fill", b.x, b.y, 3)
    end

    love.graphics.circle("fill", player.x, player.y, player.r)

    love.graphics.pop()

    love.graphics.setFont(fontSmall)
    love.graphics.print("HP: " .. player.hp, 10, 10)
    love.graphics.print("Score: " .. math.floor(score), 10, 30)

    if fade > 0 then
    love.graphics.setColor(0, 0, 0, fade)
    love.graphics.rectangle("fill", 0, 0, 800, 600)
    love.graphics.setColor(1, 1, 1)
    end
end