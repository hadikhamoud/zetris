const rl = @import("raylib");
const std = @import("std");
const tt = @import("tetrominoes.zig");

const GENERAL_PADDING = 100;
const BSIZE = 30;
const NROWS = 20;
const NCOLS = 10;
var DEBUG = false;

var screenHeight: i32 = 0;
var screenWidth: i32 = 0;
var startX: i32 = 0;
var startY: i32 = 0;
var activePiece: ActivePiece = undefined;
var fallTimer: f32 = 0.0;
const fallDelay = 0.3;

var board = std.mem.zeroes([NROWS][NCOLS]u8);

const ActivePiece = struct { tType: u8, rotation: u8, x: u8, y: u8 };

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
    rl.drawRectangleLinesEx(frameOutline, 3.0, rl.Color.gray);

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
            rl.drawRectangleLinesEx(square, 1.0, rl.Color.gray);
            if (board[i][j] != 0) {
                rl.drawRectangleRec(square, tt.tetrominoes[board[i][j] - 1].color);
            }
        }
    }
}

fn drawActivePiece() !void {
    const shape = tt.tetrominoes[activePiece.tType].shape[activePiece.rotation];
    const color = tt.tetrominoes[activePiece.tType].color;

    for (0..4) |row| {
        for (0..4) |col| {
            if (shape[row][col] == 0) continue;

            const boardX = activePiece.x + col;
            const boardY = activePiece.y + row;

            if (boardY < 0) continue;

            const square = rl.Rectangle.init(@floatFromInt(startX + BSIZE * @as(i32, @intCast(boardX))), @floatFromInt(startY + BSIZE * @as(i32, @intCast(boardY))), BSIZE, BSIZE);
            rl.drawRectangleRec(square, color);
        }
    }
}

fn checkCollision() !bool {
    const shape = tt.tetrominoes[activePiece.tType].shape[activePiece.rotation];
    for (0..4) |i| {
        for (0..4) |j| {
            if (shape[i][j] == 0) continue;

            const boardRow = activePiece.y + i;
            const boardCol = activePiece.x + j;

            if (boardCol < 0 or boardCol >= NCOLS) return true;
            if (boardRow >= NROWS) return true;
            if (board[boardRow][boardCol] != 0) return true;
        }
    }
    return false;
}

fn lockPiece() !void {
    const shape = tt.tetrominoes[activePiece.tType].shape[activePiece.rotation];

    for (0..4) |i| {
        for (0..4) |j| {
            if (shape[i][j] == 0) continue;

            const boardRow = activePiece.y + i;
            const boardCol = activePiece.x + j;
            board[boardRow][boardCol] = activePiece.tType + 1;
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
    activePiece = ActivePiece{ .rotation = rand.intRangeAtMost(u8, 0, 3), .tType = rand.intRangeAtMost(u8, 0, 6), .x = 0, .y = 0 };
}

fn MoveDown() !void {
    activePiece.y += 1;
    if (try checkCollision() == true) {
        activePiece.y -= 1;
        try lockPiece();
        try getNewPiece();
    }
}

fn updateGravity(dt: f32) !void {
    fallTimer += dt;
    if (fallTimer >= fallDelay) {
        try MoveDown();
        fallTimer = 0;
    }
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

    var prng: std.Random.DefaultPrng = .init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    rl.maximizeWindow();
    activePiece = ActivePiece{ .rotation = rand.intRangeAtMost(u8, 0, 3), .tType = rand.intRangeAtMost(u8, 0, 6), .x = 0, .y = 0 };

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        const dt = rl.getFrameTime();

        rl.clearBackground(.white);
        if (DEBUG) try drawDebugCoords();

        try updateGravity(dt);
        try drawBoard();
        try drawActivePiece();
    }
}
