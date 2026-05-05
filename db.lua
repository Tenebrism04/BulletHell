local ffi = require("ffi")
local sqlite = ffi.load("sqlite3")

ffi.cdef[[
typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;

int sqlite3_open(const char *filename, sqlite3 **ppDb);
int sqlite3_close(sqlite3 *db);
int sqlite3_exec(sqlite3 *db, const char *sql, void *callback, void *arg, char **errmsg);

int sqlite3_prepare_v2(sqlite3 *db, const char *zSql, int nByte,
    sqlite3_stmt **ppStmt, const char **pzTail);

int sqlite3_step(sqlite3_stmt *pStmt);
int sqlite3_finalize(sqlite3_stmt *pStmt);

int sqlite3_column_int(sqlite3_stmt *pStmt, int iCol);
const unsigned char *sqlite3_column_text(sqlite3_stmt *pStmt, int iCol);
]]

local DB = {}
local db_ptr = ffi.new("sqlite3*[1]")

function DB.init(path)
    sqlite.sqlite3_open(path, db_ptr)
    local db = db_ptr[0]

    local sql = [[
        CREATE TABLE IF NOT EXISTS scores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            score INTEGER
        );
    ]]

    sqlite.sqlite3_exec(db, sql, nil, nil, nil)
end

function DB.save(name, score)
    local db = db_ptr[0]

    local sql = string.format(
        "INSERT INTO scores (name, score) VALUES ('%s', %d);",
        name,
        score
    )

    sqlite.sqlite3_exec(db, sql, nil, nil, nil)
end

function DB.getTop(limit)
    local db = db_ptr[0]

    local stmt_ptr = ffi.new("sqlite3_stmt*[1]")

    local sql = string.format(
        "SELECT name, score FROM scores ORDER BY score DESC LIMIT %d;",
        limit or 10
    )

    sqlite.sqlite3_prepare_v2(db, sql, -1, stmt_ptr, nil)

    local stmt = stmt_ptr[0]

    local results = {}

    while sqlite.sqlite3_step(stmt) == 100 do
        table.insert(results, {
            name = ffi.string(sqlite.sqlite3_column_text(stmt, 0)),
            score = sqlite.sqlite3_column_int(stmt, 1)
        })
    end

    sqlite.sqlite3_finalize(stmt)

    return results
end

return DB