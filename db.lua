local ffi = require("ffi")

-- C definitions (only needed here, not in main.lua anymore)
ffi.cdef[[
    typedef struct sqlite3 sqlite3;

    int sqlite3_open(const char *filename, sqlite3 **ppDb);
    int sqlite3_close(sqlite3 *db);
    int sqlite3_exec(sqlite3 *db, const char *sql,
                     void *callback, void *arg, char **errmsg);
]]

local sqlite = ffi.load("sqlite3")

local ScoreDB = {}
ScoreDB.db = nil

-- =========================
-- INIT DATABASE
-- =========================
function ScoreDB.init(filename)
    local db_ptr = ffi.new("sqlite3*[1]")
    local result = sqlite.sqlite3_open(filename or "scores.db", db_ptr)

    if result ~= 0 then
        error("Failed to open database")
    end

    ScoreDB.db = db_ptr[0]

    -- create table if it doesn't exist
    local sql = [[
        CREATE TABLE IF NOT EXISTS scores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            score INTEGER
        );
    ]]

    sqlite.sqlite3_exec(ScoreDB.db, sql, nil, nil, nil)
end

-- =========================
-- SAVE SCORE
-- =========================
function ScoreDB.save(name, score)
    if not ScoreDB.db then return end

    -- simple (not SQL-injection safe, but fine for local game)
    local sql = string.format(
        "INSERT INTO scores (name, score) VALUES ('%s', %d);",
        name, score
    )

    sqlite.sqlite3_exec(ScoreDB.db, sql, nil, nil, nil)
end

-- =========================
-- CLOSE DB
-- =========================
function ScoreDB.close()
    if ScoreDB.db then
        sqlite.sqlite3_close(ScoreDB.db)
        ScoreDB.db = nil
    end
end

return ScoreDB