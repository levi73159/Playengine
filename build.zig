const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "playengine",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true, // for freetype library
    });

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.6",
        .profile = .core,
    });

    const glfw_dep = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });

    const zigimg_dep = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const zalgebra_dep = b.dependency("zalgebra", .{
        .target = target,
        .optimize = optimize,
    });

    const freetype_dep = b.dependency("freetype", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("gl", gl_bindings);
    exe.root_module.addImport("glfw", glfw_dep.module("glfw"));
    exe.root_module.addImport("zigimg", zigimg_dep.module("zigimg"));
    exe.root_module.addImport("zalgebra", zalgebra_dep.module("zalgebra"));

    exe.linkLibrary(freetype_dep.artifact("freetype"));
    exe.addIncludePath(freetype_dep.path("include"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
