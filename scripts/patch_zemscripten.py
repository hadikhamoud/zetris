from pathlib import Path


def replace_exact(content: str, old: str, new: str) -> str:
    if old not in content:
        raise RuntimeError("Expected block not found while patching zemscripten")
    return content.replace(old, new)


root = Path("/root/.cache/zig/p")
targets = list(root.glob("zemscripten-*/build.zig"))
if not targets:
    raise RuntimeError("No zemscripten build.zig found in Zig cache")

old_emcc = """pub fn emccPath(b: *std.Build) []const u8 {
    return std.fs.path.join(b.allocator, &.{
        b.dependency("emsdk", .{}).path("").getPath(b),
        "upstream",
        "emscripten",
        switch (builtin.target.os.tag) {
            .windows => "emcc.bat",
            else => "emcc",
        },
    }) catch unreachable;
}"""

new_emcc = """pub fn emccPath(b: *std.Build) []const u8 {
    _ = b;
    return switch (builtin.target.os.tag) {
        .windows => "C:/emsdk/upstream/emscripten/emcc.bat",
        else => "/emsdk/upstream/emscripten/emcc",
    };
}"""

old_emrun = """pub fn emrunPath(b: *std.Build) []const u8 {
    return std.fs.path.join(b.allocator, &.{
        b.dependency("emsdk", .{}).path("").getPath(b),
        "upstream",
        "emscripten",
        switch (builtin.target.os.tag) {
            .windows => "emrun.bat",
            else => "emrun",
        },
    }) catch unreachable;
}"""

new_emrun = """pub fn emrunPath(b: *std.Build) []const u8 {
    _ = b;
    return switch (builtin.target.os.tag) {
        .windows => "C:/emsdk/upstream/emscripten/emrun.bat",
        else => "/emsdk/upstream/emscripten/emrun",
    };
}"""

old_html = """pub fn htmlPath(b: *std.Build) []const u8 {
    return std.fs.path.join(b.allocator, &.{
        b.dependency("emsdk", .{}).path("").getPath(b),
        "upstream",
        "emscripten",
        "src",
        "shell.html",
    }) catch unreachable;
}"""

new_html = """pub fn htmlPath(b: *std.Build) []const u8 {
    _ = b;
    return "/emsdk/upstream/emscripten/src/shell.html";
}"""

old_activate = """pub fn activateEmsdkStep(b: *std.Build) *std.Build.Step {
    const emsdk_script_path = std.fs.path.join(b.allocator, &.{
        b.dependency("emsdk", .{}).path("").getPath(b),
        switch (builtin.target.os.tag) {
            .windows => "emsdk.bat",
            else => "emsdk",
        },
    }) catch unreachable;

    var emsdk_install = b.addSystemCommand(&.{ emsdk_script_path, "install", emsdk_version });

    switch (builtin.target.os.tag) {
        .linux, .macos => {
            emsdk_install.step.dependOn(&b.addSystemCommand(&.{ "chmod", "+x", emsdk_script_path }).step);
        },
        .windows => {
            emsdk_install.step.dependOn(&b.addSystemCommand(&.{ "takeown", "/f", emsdk_script_path }).step);
        },
        else => {},
    }

    var emsdk_activate = b.addSystemCommand(&.{ emsdk_script_path, "activate", emsdk_version });
    emsdk_activate.step.dependOn(&emsdk_install.step);

    const step = b.allocator.create(std.Build.Step) catch unreachable;
    step.* = std.Build.Step.init(.{
        .id = .custom,
        .name = "Activate EMSDK",
        .owner = b,
        .makeFn = &struct {
            fn make(_: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {}
        }.make,
    });

    switch (builtin.target.os.tag) {
        .linux, .macos => {
            const chmod_emcc = b.addSystemCommand(&.{ "chmod", "+x", emccPath(b) });
            chmod_emcc.step.dependOn(&emsdk_activate.step);
            step.dependOn(&chmod_emcc.step);

            const chmod_emrun = b.addSystemCommand(&.{ "chmod", "+x", emrunPath(b) });
            chmod_emrun.step.dependOn(&emsdk_activate.step);
            step.dependOn(&chmod_emrun.step);
        },
        .windows => {
            const takeown_emcc = b.addSystemCommand(&.{ "takeown", "/f", emccPath(b) });
            takeown_emcc.step.dependOn(&emsdk_activate.step);
            step.dependOn(&takeown_emcc.step);

            const takeown_emrun = b.addSystemCommand(&.{ "takeown", "/f", emrunPath(b) });
            takeown_emrun.step.dependOn(&emsdk_activate.step);
            step.dependOn(&takeown_emrun.step);
        },
        else => {},
    }

    return step;
}"""

new_activate = """pub fn activateEmsdkStep(b: *std.Build) *std.Build.Step {
    const step = b.allocator.create(std.Build.Step) catch unreachable;
    step.* = std.Build.Step.init(.{
        .id = .custom,
        .name = "Use preinstalled EMSDK",
        .owner = b,
        .makeFn = &struct {
            fn make(_: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {}
        }.make,
    });

    switch (builtin.target.os.tag) {
        .linux, .macos => {
            step.dependOn(&b.addSystemCommand(&.{ "chmod", "+x", emccPath(b) }).step);
            step.dependOn(&b.addSystemCommand(&.{ "chmod", "+x", emrunPath(b) }).step);
        },
        else => {},
    }

    return step;
}"""

for file_path in targets:
    text = file_path.read_text()
    text = replace_exact(text, old_emcc, new_emcc)
    text = replace_exact(text, old_emrun, new_emrun)
    text = replace_exact(text, old_html, new_html)
    text = replace_exact(text, old_activate, new_activate)
    file_path.write_text(text)
