const rl = @import("raylib");
const std = @import("std");
const tt = @import("tetrominoes.zig");

const GENERAL_PADDING = 100;
const BSIZE = 30;
const BSIZE_HALF = @divFloor(BSIZE, 2);
const NROWS = 20;
const NCOLS = 10;
var DEBUG = false;

var screenHeight: i32 = 0;
var screenWidth: i32 = 0;
var startX: i32 = 0;
var startY: i32 = 0;
var activePiece: ActivePiece = undefined;
var shadowPiece: ActivePiece = undefined;
var nextPiece: ActivePiece = undefined;
var hasNextPiece: bool = false;
var reservePiece: ?ActivePiece = null;
var reserveUsed = false;
var fallTimer: f32 = 0.0;
const fallDelay = 1.5;
var moveTimer: f32 = 0.0;
const moveDelay = 0.1;

var board = std.mem.zeroes([NROWS][NCOLS]u8);

const ActivePiece = struct { tType: u8, rotation: u8, x: i8, y: i8 };

fn drawDebugCoords() !void {
    var i: i32 = 0;
    var buf: [32]u8 = undefined;
    while (i < screenWidth) {
        rl.drawLine(i, 0, i, 10, .red);
        rl.drawText(try std.fmt.bufPrintZ(&buf, "{}", .{i}), i, 12, 4, .red);
        i += BSIZE;
    }
    i = 0;
    while (i < screenHeight) {
        rl.drawLine(0, i, 10, i, .red);
        rl.drawText(try std.fmt.bufPrintZ(&buf, "{}", .{i}), 12, i, 4, .red);
        i += BSIZE;
    }

    rl.drawText(try std.fmt.bufPrintZ(&buf, "{}x{}", .{ screenHeight, screenWidth }), screenWidth - 50, screenHeight - 50, 4, .red);
}

fn drawBoard() !void {
    const frameOutline = rl.Rectangle.init(@floatFromInt(startX), @floatFromInt(startY), BSIZE * NCOLS, BSIZE * NROWS);
    rl.drawRectangleLinesEx(frameOutline, 3.0, rl.Color.light_gray);

    for (0..NROWS) |_i| {
        for (0..NCOLS) |_j| {
            const i = @as(u32, @intCast(_i));
            const j = @as(u32, @intCast(_j));
            const square = rl.Rectangle.init(
                @floatFromInt(startX + BSIZE * @as(i32, @intCast(j))),
                @floatFromInt(startY + BSIZE * @as(i32, @intCast(i))),
                BSIZE,
                BSIZE,
            );
            rl.drawRectangleLinesEx(square, 1.0, rl.Color.light_gray);
            if (board[i][j] != 0) {
                rl.drawRectangleRec(square, tt.tetrominoes[board[i][j] - 1].color);
                rl.drawRectangleLinesEx(square, 1.0, rl.Color.gray);
            }
        }
    }
}

fn drawReservePiece() !void {
    const frameOutline = rl.Rectangle.init(@floatFromInt(startX - 350), @floatFromInt(startY), BSIZE * 3, BSIZE * 4);
    rl.drawRectangleLinesEx(frameOutline, 3.0, rl.Color.gray);
    rl.drawText("Reserve Piece", startX - 350, startY + BSIZE * 4, 18.0, rl.Color.gray);

    const rp = reservePiece orelse return;
    const shape = tt.tetrominoes[rp.tType].shape[rp.rotation];
    const color = tt.tetrominoes[rp.tType].color;

    for (0..4) |_row| {
        for (0..4) |_col| {
            if (shape[_row][_col] == 0) continue;
            const row = @as(i32, @intCast(_row));
            const col = @as(i32, @intCast(_col));

            const square = rl.Rectangle.init(@floatFromInt(startX - 325 + BSIZE_HALF * row), @floatFromInt(startY + 50 + BSIZE_HALF * col), @divFloor(BSIZE, 2), @divFloor(BSIZE, 2));
            rl.drawRectangleRec(square, color);
        }
    }
}

fn drawNextPiece() !void {
    const frameOutline = rl.Rectangle.init(@floatFromInt(startX + 350), @floatFromInt(startY), BSIZE * 3, BSIZE * 4);
    rl.drawRectangleLinesEx(frameOutline, 3.0, rl.Color.gray);
    rl.drawText("Next Piece", startX + 350, startY + BSIZE * 4, 18.0, rl.Color.gray);

    if (!hasNextPiece) return;

    const shape = tt.tetrominoes[nextPiece.tType].shape[nextPiece.rotation];
    const color = tt.tetrominoes[nextPiece.tType].color;

    for (0..4) |_row| {
        for (0..4) |_col| {
            if (shape[_row][_col] == 0) continue;
            const row = @as(i32, @intCast(_row));
            const col = @as(i32, @intCast(_col));

            const square = rl.Rectangle.init(@floatFromInt(startX + 375 + BSIZE_HALF * row), @floatFromInt(startY + 50 + BSIZE_HALF * col), @divFloor(BSIZE, 2), @divFloor(BSIZE, 2));
            rl.drawRectangleRec(square, color);
        }
    }
}

fn drawActivePiece() !void {
    const shape = tt.tetrominoes[activePiece.tType].shape[activePiece.rotation];
    const color = tt.tetrominoes[activePiece.tType].color;

    for (0..4) |row| {
        for (0..4) |col| {
            if (shape[row][col] == 0) continue;

            const boardX = activePiece.x + @as(i8, @intCast(col));
            const boardY = activePiece.y + @as(i8, @intCast(row));

            if (boardY < 0 or boardX < 0) continue;

            const square = rl.Rectangle.init(@floatFromInt(startX + BSIZE * @as(i32, boardX)), @floatFromInt(startY + BSIZE * @as(i32, boardY)), BSIZE, BSIZE);
            rl.drawRectangleRec(square, color);
            rl.drawRectangleLinesEx(square, 1.0, rl.Color.light_gray);
        }
    }
}

fn drawShadowPiece() !void {
    const shape = tt.tetrominoes[shadowPiece.tType].shape[shadowPiece.rotation];
    const color = rl.Color.contrast(rl.Color.light_gray, 0.0);

    for (0..4) |row| {
        for (0..4) |col| {
            if (shape[row][col] == 0) continue;

            const boardX = shadowPiece.x + @as(i8, @intCast(col));
            const boardY = shadowPiece.y + @as(i8, @intCast(row));

            if (boardY < 0 or boardX < 0) continue;

            const square = rl.Rectangle.init(@floatFromInt(startX + BSIZE * @as(i32, boardX)), @floatFromInt(startY + BSIZE * @as(i32, boardY)), BSIZE, BSIZE);
            rl.drawRectangleRec(square, color);
        }
    }
}

fn checkCollision() !bool {
    const shape = tt.tetrominoes[activePiece.tType].shape[activePiece.rotation];
    for (0..4) |i| {
        for (0..4) |j| {
            if (shape[i][j] == 0) continue;

            const boardRow = activePiece.y + @as(i8, @intCast(i));
            const boardCol = activePiece.x + @as(i8, @intCast(j));

            if (boardCol < 0 or boardCol >= NCOLS) return true;
            if (boardRow < 0) continue;
            if (boardRow >= NROWS) return true;
            if (board[@intCast(boardRow)][@intCast(boardCol)] != 0) return true;
        }
    }
    return false;
}

fn CheckIfLost() !bool {
    for (board[0]) |bl| {
        if (bl != 0) return true;
    }
    return false;
}

fn checkCollisionShadowPiece() !bool {
    const shape = tt.tetrominoes[shadowPiece.tType].shape[shadowPiece.rotation];
    for (0..4) |i| {
        for (0..4) |j| {
            if (shape[i][j] == 0) continue;

            const boardRow = shadowPiece.y + @as(i8, @intCast(i));
            const boardCol = shadowPiece.x + @as(i8, @intCast(j));

            if (boardCol < 0 or boardCol >= NCOLS) return true;
            if (boardRow < 0) continue;
            if (boardRow >= NROWS) return true;
            if (board[@intCast(boardRow)][@intCast(boardCol)] != 0) return true;
        }
    }
    return false;
}

fn lockPiece() !void {
    const shape = tt.tetrominoes[activePiece.tType].shape[activePiece.rotation];

    for (0..4) |i| {
        for (0..4) |j| {
            if (shape[i][j] == 0) continue;

            const boardRow = activePiece.y + @as(i8, @intCast(i));
            const boardCol = activePiece.x + @as(i8, @intCast(j));
            board[@intCast(boardRow)][@intCast(boardCol)] = activePiece.tType + 1;
        }
    }
}

fn getNewPiece() !void {
    var prng: std.Random.DefaultPrng = .init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    if (hasNextPiece) {
        activePiece = nextPiece;
    } else {
        activePiece = ActivePiece{ .rotation = rand.intRangeAtMost(u8, 0, 3), .tType = rand.intRangeAtMost(u8, 0, 6), .x = 0, .y = 0 };
    }
    nextPiece = ActivePiece{ .rotation = rand.intRangeAtMost(u8, 0, 3), .tType = rand.intRangeAtMost(u8, 0, 6), .x = 0, .y = 0 };
    hasNextPiece = true;
    reserveUsed = false;
}

fn MoveDown() !void {
    activePiece.y += 1;
    if (try checkCollision() == true) {
        activePiece.y -= 1;
        try lockPiece();
        try ClearRows();
        try getNewPiece();
    }
}

fn HardDrop() !void {
    while (true) {
        activePiece.y += 1;
        if (try checkCollision()) {
            activePiece.y -= 1;
            break;
        }
    }
    try lockPiece();
    try ClearRows();
    try getNewPiece();
}

fn MoveRight() !void {
    activePiece.x += 1;
    if (try checkCollision() == true) {
        activePiece.x -= 1;
    }
}

fn MoveLeft() !void {
    activePiece.x -= 1;
    if (try checkCollision() == true) {
        activePiece.x += 1;
    }
}

fn UpdateShadowPiece() !void {
    shadowPiece = activePiece;
    while (!try checkCollisionShadowPiece()) {
        shadowPiece.y += 1;
    }
    shadowPiece.y -= 1;
}

fn updateGravity(dt: f32) !void {
    fallTimer += dt;
    if (fallTimer >= fallDelay) {
        try MoveDown();
        fallTimer = 0;
    }
    try UpdateShadowPiece();
}

fn isRowFull(row: []u8) !bool {
    for (row) |el| {
        if (el == 0) return false;
    }
    return true;
}

fn ClearRows() !void {
    var row: usize = NROWS;
    while (row > 0) {
        row -= 1;
        if (try isRowFull(&board[row])) {
            var shift: usize = row;
            while (shift > 0) {
                shift -= 1;
                board[shift + 1] = board[shift];
            }
            board[0] = std.mem.zeroes([NCOLS]u8);
            row += 1;
        }
    }
}

fn RotatePieceCounterClockWise() !void {
    const shape = tt.tetrominoes[activePiece.tType].shape[(activePiece.rotation + 3) % 4];
    var correction: i8 = 0;

    for (0..4) |i| {
        for (0..4) |j| {
            if (shape[i][j] == 0) continue;

            const boardCol = activePiece.x + @as(i8, @intCast(j));

            if (boardCol >= NCOLS) {
                if (correction <= boardCol - NCOLS + 1)
                    correction = boardCol - NCOLS + 1;
            } else if (boardCol < 0) {
                if (correction >= boardCol) {
                    correction = boardCol;
                }
            }
        }
    }

    activePiece.x -= correction;
    activePiece.rotation = (activePiece.rotation + 3) % 4;
}

fn RotatePieceClockWise() !void {
    const shape = tt.tetrominoes[activePiece.tType].shape[(activePiece.rotation + 1) % 4];
    var correction: i8 = 0;

    for (0..4) |i| {
        for (0..4) |j| {
            if (shape[i][j] == 0) continue;

            const boardCol = activePiece.x + @as(i8, @intCast(j));

            if (boardCol >= NCOLS) {
                if (correction <= boardCol - NCOLS + 1)
                    correction = boardCol - NCOLS + 1;
            } else if (boardCol < 0) {
                if (correction >= boardCol) {
                    correction = boardCol;
                }
            }
        }
    }

    activePiece.x -= correction;
    activePiece.rotation = (activePiece.rotation + 1) % 4;
}

fn ReservePiece() !void {
    if (reserveUsed) return;
    const temp = reservePiece;
    if (temp) |t| {
        reservePiece = activePiece;
        activePiece = t;
    } else {
        reservePiece = activePiece;
        try getNewPiece();
    }

    reserveUsed = true;
}

fn handleInput(dt: f32) !void {
    var keyPressed = rl.getKeyPressed();
    while (keyPressed != .null) {
        switch (keyPressed) {
            rl.KeyboardKey.a, rl.KeyboardKey.left => {
                try MoveLeft();
                moveTimer = 0;
            },
            rl.KeyboardKey.d, rl.KeyboardKey.right => {
                try MoveRight();
                moveTimer = 0;
            },
            rl.KeyboardKey.s, rl.KeyboardKey.down => {
                try MoveDown();
                moveTimer = 0;
            },
            rl.KeyboardKey.c => {
                try RotatePieceClockWise();
                moveTimer = 0;
            },
            rl.KeyboardKey.z => {
                try RotatePieceCounterClockWise();
                moveTimer = 0;
            },
            rl.KeyboardKey.up => {
                try HardDrop();
                moveTimer = 0;
            },
            rl.KeyboardKey.space => {
                try ReservePiece();
                moveTimer = 0;
            },

            else => {},
        }
        keyPressed = rl.getKeyPressed();
    }

    moveTimer += dt;
    if (moveTimer >= moveDelay) {
        if (rl.isKeyDown(rl.KeyboardKey.a)) try MoveLeft();
        if (rl.isKeyDown(rl.KeyboardKey.d)) try MoveRight();
        if (rl.isKeyDown(rl.KeyboardKey.s)) try MoveDown();
        if (rl.isKeyDown(rl.KeyboardKey.left)) try MoveLeft();
        if (rl.isKeyDown(rl.KeyboardKey.right)) try MoveRight();
        if (rl.isKeyDown(rl.KeyboardKey.down)) try MoveDown();
        moveTimer = 0;
    }
    try UpdateShadowPiece();
}

pub fn main() anyerror!void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    DEBUG = blk: {
        const val = std.process.getEnvVarOwned(allocator, "DEBUG") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => break :blk false,
            else => return err,
        };
        defer allocator.free(val);

        if (std.mem.eql(u8, val, "1"))
            break :blk true
        else
            break :blk false;
    };

    rl.initWindow(0, 0, "zetris");
    screenHeight = rl.getScreenHeight() - GENERAL_PADDING;
    screenWidth = rl.getScreenWidth() - GENERAL_PADDING;
    const screenWidthF = @as(f32, @floatFromInt(screenWidth));

    startY = @divFloor(screenHeight, 6);
    startX = @as(i32, @intFromFloat(@floor(screenWidthF / 2.5)));

    rl.setWindowSize(screenWidth, screenHeight);

    defer rl.closeWindow();
    rl.setTargetFPS(60);

    rl.maximizeWindow();
    try getNewPiece();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        const dt = rl.getFrameTime();

        rl.clearBackground(.white);
        if (DEBUG) try drawDebugCoords();

        try updateGravity(dt);
        try handleInput(dt);

        if (try CheckIfLost()) {
            board = std.mem.zeroes([NROWS][NCOLS]u8);
        }
        try drawBoard();
        try drawNextPiece();
        try drawReservePiece();
        try drawActivePiece();
        try drawShadowPiece();
    }
}
