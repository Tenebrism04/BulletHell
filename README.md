# Bullet Hell

A very simple bullet-hell style prototype game built with LÖVE (Love2D) and Lua.

# Features

- Fast-paced bullet-hell gameplay
- Enemy waves and projectile patterns
- SQLite-backed data storage
- Custom game logic written in Lua

# Building
## Prerequisites

- LÖVE 11.x

## Running from source

Open the project with LÖVE:
```
love .
```
or drag the project folder onto `love.exe`

## Creating a `.love` File

Create a ZIP file containing the contents of the project directory and rename the archive extention from `.zip` to `.love`.

The archive should contain `main.lua` at its root.

## Creating a Windows Executable

Combine the LÖVE executable with the `.love` archive.
```
copy /b love.exe+BulletHell.love BulletHell.exe
```

# Credits

Music and sound effects are third-party assets and are not my original work. Ownership remains with their respective creators.

## Music

- ["Bad Apple - 8 Bit Tribute" By 8 Bit Universe](https://youtu.be/ncRL9Wk0jfA?si=uWSiJYry-pF71sI_)

## Sound Effects

Sound effects are taken from *Touhou 10: Mountain of Faith*, created by ZUN (Team Shanghai Alice).
