const std = @import("std");
const za = @import("zalgebra");

const bounds = @import("bounds.zig");
const Rect = bounds.RectBounds;
const Circle = bounds.CircleBounds;

const renderer = @import("renderer.zig");
const assets = @import("assets_manager.zig");

const Camera = @import("Camera.zig");

const Color = @import("Color.zig");
const Font = @import("Font.zig");
const Input = @import("Input.zig");
const Object = @import("Object.zig");
const Shader = @import("Shader.zig");
const Text = @import("Text.zig");
const Texture = @import("Texture.zig");
const Window = @import("Window.zig");
const time = @import("time.zig");
const Engine = @import("Engine.zig");
const Scene = @import("Scene.zig");

const Template = @import("rendererObjects.zig").RenderObjectTemplate;

const log = std.log.scoped(.core);

var shader: Shader = undefined;

var prng: std.Random.DefaultPrng = undefined;
var random: std.Random = undefined;

fn randomFloat(min: f32, max: f32) f32 {
    return random.float(f32) * (max - min) + min;
}

fn randomFloatMax(max: f32) f32 {
    return random.float(f32) * max; // 0 to max
}

const MainMenuScene = @import("mainmenue.zig");
const GameplayScene = @import("game.zig");

pub fn start(_: *const Engine) anyerror!void {
    const font = try assets.loadFont("RobotoFont", "res/fonts/Roboto.ttf", 48);
    renderer.setFont(font);

    try assets.preloadTexture("BackgroundTexture", "res/sprites/Background_game.png", 0);
    try assets.preloadTexture("PlayerTexture", "res/sprites/player.png", 1);
    try assets.preloadTexture("EnemyTexture", "res/sprites/enemy.png", 2);
    try assets.preloadTexture("BulletTexture", "res/sprites/bullet.png", 3);
    try assets.preloadTexture("DeathBackgroundTexture", "res/sprites/death_background.png", 0);
}

pub fn main() !u8 {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer _ = dbg.deinit();

    const allocator = dbg.allocator();

    prng = std.Random.DefaultPrng.init(std.crypto.random.int(u64));
    random = prng.random();

    const window = Window.init(allocator, .{ .title = "Playengine", .width = 1920 / 2, .height = 1080 / 2 }) catch |err| {
        log.err("Failed to create window: {}", .{err});
        return 1;
    };
    defer window.deinit();

    std.log.debug("Size: {}x{}", .{ window.info.width, window.info.height });

    renderer.setDefaultWindow(&window);

    var engine = Engine.init(&window);
    defer engine.deinit(allocator);
    engine.makeCurrent();

    engine.startSceneManager(&.{
        Scene.initFromType(MainMenuScene, allocator),
        Scene.initFromType(GameplayScene, allocator),
    });
    engine.on_start = &start;
    engine.run();

    return 0;
}
