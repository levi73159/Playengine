const std = @import("std");
const za = @import("zalgebra");

const bounds = @import("bounds.zig");
const Rect = bounds.RectBounds;
const Circle = bounds.CircleBounds;

const renderer = @import("renderer.zig");
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

const log = std.log.scoped(.core);

var shader: Shader = undefined;

var bullet_texture: Texture = undefined;
var enemy_texture: Texture = undefined;

var prng: std.Random.DefaultPrng = undefined;
var random: std.Random = undefined;

fn randomFloat(min: f32, max: f32) f32 {
    return random.float(f32) * (max - min) + min;
}

fn randomFloatMax(max: f32) f32 {
    return random.float(f32) * max; // 0 to max
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

    renderer.init(&window) catch {
        log.err("Failed to initialize renderer", .{});
        return 1;
    };
    defer renderer.deinit();

    renderer.deinitResources();

    var texture = Texture.loadFromFile(allocator, "res/sprites/player.png") catch |err| {
        log.err("Failed to load texture: {}", .{err});
        return 1;
    };
    defer texture.deinit();

    bullet_texture = Texture.loadFromFile(allocator, "res/sprites/bullet.png") catch |err| {
        log.err("Failed to load texture: {}", .{err});
        return 1;
    };
    defer bullet_texture.deinit();

    enemy_texture = Texture.loadFromFile(allocator, "res/sprites/enemy.png") catch |err| {
        log.err("Failed to load texture: {}", .{err});
        return 1;
    };
    defer enemy_texture.deinit();

    texture.bind(1); // bind to texture slot 1
    bullet_texture.bind(2); // bind to texture slot 2
    enemy_texture.bind(3); // bind to texture slot 3

    // ------------- SHADER INITIALIZATION -------------
    // initialize the two basic shaders (that we will always use)
    shader = Shader.getTexturedShader(allocator) catch |err| {
        log.err("Failed to load textured shader: {}", .{err});
        return 1;
    };
    defer shader.deinit();

    var color_shader = Shader.getColoredShader(allocator) catch |err| {
        log.err("Failed to load colored shader: {}", .{err});
        return 1;
    };
    defer color_shader.deinit();

    var text_shader = Shader.init(allocator, @embedFile("shaders/text.vert"), @embedFile("shaders/text.frag")) catch |err| {
        log.err("Failed to load text shader: {}", .{err});
        return 1;
    };
    defer text_shader.deinit();

    // ---- Font Initialization ----
    var basic_font = Font.init(allocator, "res/fonts/Roboto.ttf", 48) catch |err| switch (err) {
        error.OutOfMemory => {
            std.log.err("Not enough memory to load font!!!!!!", .{});
            return 255; // fatal bad error is 255
        },
        error.FailedToLoadFont => {
            std.log.err("Failed to load font", .{});
            return 1;
        },
        error.FailedToInitFreeType => {
            std.log.err("Failed to init freetype", .{});
            return 1;
        },
    };
    defer basic_font.deinit();

    renderer.setFont(&basic_font);
    renderer.setFontColor(Color.white);

    player = try Object.createSquare("player", &shader);
    player.transform.scale = za.Vec2.new(75, 75);
    player.texture = &texture;

    var text = try Text.create("Text", "Game by levi", &text_shader, &basic_font);
    text.transform.pos = window.getBounds().topLeft().add(za.Vec2.new(0, -10));
    text.transform.scale = za.Vec2.new(50, 100);
    text.color = Color.white;
    text.scale = 1.0;

    const camera = Camera{};

    while (!window.shouldClose()) {
        time.startFrame();
        const dt = time.delta();
        renderer.clear(Color.init(0.2, 0.3, 0.3, 1.0));

        update(&window, dt) catch |err| {
            log.err("Failed to update: {}", .{err});
            return 1;
        };

        renderer.renderAll(camera) catch |err| {
            log.err("Failed to render: {}", .{err});
            return 1;
        };

        window.swapBuffers();
        Window.pollEvents();
    }

    return 0;
}

var player: *Object = undefined;
var is_mouse_pressed: bool = false;
var timer: f32 = enemy_spawn_time; // so that the first enemy is spawned happen immediately
const enemy_spawn_time: f32 = 3.0; // 3 seconds
var bullet_count: u32 = 0;

const bullet_max_count = 100; // 100 bullets and 100 enemies equal 200 objects not including player
fn update(window: *const Window, dt: f32) !void {
    timer += dt; // increment timer
    const player_speed = 250.0;
    const enemy_speed = 150.0;

    const input = window.input();

    var transform = player.transform;
    const move_vector = input.getVector(.w, .s, .a, .d).norm().scale(player_speed * dt);
    transform.pos = transform.pos.add(move_vector);

    const screen_bounds = window.getBounds();
    const player_bounds = Rect.fromTransform(transform);

    const outside_x = player_bounds.left() < screen_bounds.left() or player_bounds.right() > screen_bounds.right();
    const outside_y = player_bounds.bottom() < screen_bounds.bottom() or player_bounds.top() > screen_bounds.top();

    if (!outside_x) {
        player.transform.pos.xMut().* = transform.pos.x();
    }

    if (!outside_y) {
        player.transform.pos.yMut().* = transform.pos.y();
    }

    if (input.getMousePress(.left) and !is_mouse_pressed) {
        is_mouse_pressed = true;
        try spawnBullet(window, input);
    } else if (!input.getMousePress(.left)) {
        is_mouse_pressed = false;
    }

    // bullet code
    var bullet_buffer: [bullet_max_count]renderer.RenderObject = undefined;
    const bullets_found = renderer.findObjectsLimited(&bullet_buffer, "bullet", bullet_count);
    const bullets = bullet_buffer[0..bullets_found];

    for (bullets) |render_object| switch (render_object) {
        .object => |o| {
            const data = o.data.?.move_data;
            o.transform.pos = o.transform.pos.add(data.direction.scale(data.speed * dt));

            const b = Rect.fromTransform(o.transform);
            if (!b.overlaps(window.getBounds())) {
                renderer.destroyObject(render_object);
                bullet_count -= 1;
            }
        },
        else => {},
    };

    // enemy code
    if (timer > enemy_spawn_time) {
        timer = 0.0;
        const enemy = try renderer.createSquare("enemy", &shader);

        const window_bounds = window.getBounds();

        while (true) {
            const pos_x: f32 = randomFloat(window_bounds.left(), window_bounds.right());
            const pos_y: f32 = randomFloat(window_bounds.bottom(), window_bounds.top());
            enemy.transform.pos = za.Vec2.new(pos_x, pos_y); // later will be random

            const b = Circle.fromPoint(enemy.transform.pos, 50); // check if enemy is too close to player
            if (!b.overlaps(Circle.fromTransform(player.transform))) {
                break;
            }
        }

        enemy.transform.scale = za.Vec2.new(75, 75);
        enemy.texture = &enemy_texture;
        enemy.color = Color.white;
    }

    var enemy_buffer: [100]renderer.RenderObject = undefined;
    const enemies = renderer.findObjects(&enemy_buffer, "enemy");

    const player_cirlce_bounds = Circle.fromTransform(player.transform);

    // check if enemy collided with player if so, game over
    // check if bullet hit enemy if so, destroy both
    // else move enemy towards player
    enemy_loop: for (enemies) |enemy| {
        const enemy_transform = enemy.getTransform();
        const enemy_bounds = Circle.fromTransform(enemy_transform.*);

        if (enemy_bounds.overlaps(player_cirlce_bounds)) {
            log.info("Game Over", .{});
            return error.GameOver; // TODO: change this to a game over screen
        }
        for (bullets) |bullet| {
            const bullet_bounds = Circle.fromPoint(bullet.getTransform().pos, bullet.getTransform().scale.x() / 2.0);
            if (bullet_bounds.overlaps(enemy_bounds)) {
                renderer.destroyObject(bullet);
                renderer.destroyObject(enemy);
                bullet_count -= 1;
                continue :enemy_loop; // continue to next enemy
            }
        }

        const mv = player.transform.pos.sub(enemy_transform.pos).norm(); // move vector
        enemy_transform.pos = enemy_transform.pos.add(mv.scale(enemy_speed * dt));
    }
}

fn spawnBullet(window: *const Window, input: Input) !void {
    if (bullet_count >= bullet_max_count)
        return;

    const screen_mouse_pos = input.getMousePos();
    const mouse_pos = window.screenToWorld(screen_mouse_pos);

    // rotate player to face mouse
    const look_vector = mouse_pos.sub(player.transform.pos).norm();
    const angle = std.math.atan2(look_vector.y(), look_vector.x()) + std.math.pi / 2.0;
    const degrees = std.math.radiansToDegrees(angle); // bottom is pointing to the mouse pos

    const bullet = try renderer.createSquare("bullet", &shader);
    bullet.transform.pos = player.transform.pos;
    bullet.transform.rotation = degrees - 90.0; // make right point towards mouse
    const bullet_width: f32 = @floatFromInt(bullet_texture.width);
    const bullet_height: f32 = @floatFromInt(bullet_texture.height);
    bullet.transform.scale = za.Vec2.new(bullet_width / 20.0, bullet_height / 20.0);
    bullet.color = Color.white;
    bullet.texture = &bullet_texture;

    bullet_count += 1;

    bullet.data = .{ .move_data = .{
        .speed = 1000.0,
        .direction = look_vector,
    } };
}
