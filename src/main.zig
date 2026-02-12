// raylib-zig (c) Nikolas Wipper 2023

const rl = @import("raylib");
const std = @import("std");
const GENERAL_PADDING = 100;


fn range(len: isize) []const void {
    return @as([*]void, undefined)[0..len];
}

fn drawDebugCoords(screenHeight: i32, screenWidth: i32 )!void{

    var i: i32 = 0;
    var buf: [32]u8 = undefined;

    while (i < screenWidth) {
        rl.drawLine(i, 0 , i , 10, .red);
        rl.drawText(try std.fmt.bufPrintZ(&buf, "{}", .{i}), i, 12, 4, .red);
        i+=30;

    }

    i = 0;
    while (i < screenHeight) {
        rl.drawLine(0, i , 10 , i, .red);
        rl.drawText(try std.fmt.bufPrintZ(&buf, "{}", .{i}), 12, i, 4, .red);
        i+=30;
    }
    

        rl.drawText(try std.fmt.bufPrintZ(&buf, "{}x{}", .{screenHeight, screenWidth}), screenWidth - 50, screenHeight - 50, 4, .red);

    }




pub fn main() anyerror!void {


    rl.initWindow(0, 0, "zetris");

    const screenHeight = rl.getScreenHeight() - GENERAL_PADDING;
    const screenWidth = rl.getScreenWidth() - GENERAL_PADDING;
    const startY = @divFloor(screenHeight, 7);
    const startX = @divFloor(screenWidth, 3);
    
    rl.setWindowSize(screenWidth, screenHeight);
        

    defer rl.closeWindow(); 
    rl.setTargetFPS(60); 

    rl.maximizeWindow();

    while (!rl.windowShouldClose()) {         


        rl.beginDrawing();
       defer rl.endDrawing();


        rl.clearBackground(.black);
        try drawDebugCoords(screenHeight, screenWidth);
        const frameOutline = rl.Rectangle.init(@floatFromInt(startX), @floatFromInt(startY), @floatFromInt(screenWidth - (startX * 2)) , @floatFromInt(screenHeight - (startY * 2)));
        rl.drawRectangleLinesEx(frameOutline, 3.0, rl.Color.gray); 

    }
}
