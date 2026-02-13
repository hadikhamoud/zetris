const rl = @import("raylib");
const std = @import("std");
const GENERAL_PADDING = 100;
const BSIZE = 30;
const NROWS = 10;
const NCOLS = 20;
var DEBUG = false;

fn drawDebugCoords(screenHeight: i32, screenWidth: i32) !void {
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

fn drawBoard(startX: i32, startY: i32) !void {
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
        }
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
    const screenHeight = rl.getScreenHeight() - GENERAL_PADDING;
    const screenWidth = rl.getScreenWidth() - GENERAL_PADDING;
    const screenWidthF = @as(f32, @floatFromInt(screenWidth));

    const startY = @divFloor(screenHeight, 6);
    const startX = @as(i32, @intFromFloat(@floor(screenWidthF / 2.5)));

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
        }
    }

    rl.setWindowSize(screenWidth, screenHeight);

    defer rl.closeWindow();
    rl.setTargetFPS(120);

    rl.maximizeWindow();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);
        if (DEBUG) try drawDebugCoords(screenHeight, screenWidth);
        try drawBoard(startX, startY);
    }
}
