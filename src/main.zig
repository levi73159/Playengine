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

// error TextureLoadFailed handle here
inline fn TextureLoadFailed() u8 {
    log.err("CANNOT LOAD TEXTURE", .{});
    return 2;
}

inline fn FontLoadFailed(err: anyerror) u8 {
    switch (err) {
        error.OutOfMemory => {
            std.log.err("Not enough memory to load font!!!!!!", .{});
            return 255; // fatal bad error is 255
        },
        error.FailedToLoadFont => {
            std.log.err("Failed to load font", .{});
            return 3;
        },
        error.FailedToInitFreeType => {
            std.log.err("Failed to init freetype", .{});
            return 1;
        },
        else => {
            std.log.err("Unknown error: {}", .{err});
            return 255;
        },
    }
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
    defer renderer.deinitResources();

    assets.init(allocator);
    defer assets.deinit();

    assets.preloadTexture("BulletTexture", "res/sprites/bullet.png", 2) catch return TextureLoadFailed();
    assets.preloadTexture("EnemyTexture", "res/sprites/enemy.png", 3) catch return TextureLoadFailed();
    assets.preloadTexture("BackgroundTexture", "res/sprites/Background_game.png", 1) catch return TextureLoadFailed();

    // ------------- SHADER INITIALIZATION -------------
    // initialize the two basic shaders (that we will always use)
    shader = Shader.getTexturedShader(allocator) catch |err| {
        log.err("Failed to load textured shader: {}", .{err});
        return 1;
    };
    defer shader.deinit();

    // ---- Font Initialization ----
    const basic_font = assets.loadFont(null, "res/fonts/Roboto.ttf", 48) catch |err| return FontLoadFailed(err);

    renderer.setFont(basic_font);
    renderer.setFontColor(Color.white);

    const camera = Camera{};
    _ = camera;

    mainmenu(&window) catch |err| {
        log.err("Error in mainmenu: {}", .{err});
        return 1;
    };
    Window.pollEvents();
    window.swapBuffers();

    renderer.destroyAll();

    return gameplay(&window) catch |err| {
        log.err("Error in gameplay: {}", .{err});
        return 1;
    };
}

var player: *Object = undefined;
var is_mouse_pressed: bool = false;
var timer: f32 = enemy_spawn_time; // so that the first enemy is spawned happen immediately
const enemy_spawn_time: f32 = 3.0; // 3 seconds
var bullet_count: u32 = 0;

fn gameplay(window: *const Window) !u8 {
    const allocator = window.allocator;

    const texture = assets.loadTexture("PlayerTexture", "res/sprites/player.png", 0) catch |err| {
        log.err("Failed to load texture: {}", .{err});
        return 1;
    };
    defer assets.unloadTexture(texture);

    const background_texture = assets.loadTexture("BackgroundTexture", "res/sprites/Background_game.png", 1) catch |err| {
        log.err("Failed to load texture: {}", .{err});
        return 1;
    };
    defer assets.unloadTexture(background_texture);

    const restart_texture = assets.loadTexture("RestartTexture", "res/sprites/restart.png", 0) catch |err| {
        log.err("Failed to load texture: {}", .{err});
        return 1;
    };
    defer assets.unloadTexture(restart_texture);

    const exit_texture = assets.loadTexture("ExitTexture", "res/sprites/exit_button.png", 1) catch |err| {
        log.err("Failed to load texture: {}", .{err});
        return 1;
    };

    const death_background_texture = assets.loadTexture("DeathBackgroundTexture", "res/sprites/death_background.png", 2) catch |err| {
        log.err("Failed to load texture: {}", .{err});
        return 1;
    };

    var text_shader = Shader.init(allocator, @embedFile("shaders/text.vert"), @embedFile("shaders/text.frag")) catch |err| {
        log.err("Failed to load text shader: {}", .{err});
        return 1;
    };
    defer text_shader.deinit();

    player = try Object.createSquare("player", &shader);
    player.transform.scale = za.Vec2.new(75, 75);
    player.texture = texture;
    player.do_not_destroy = true;
    defer player.deinitAndDestroy();

    const window_bounds = window.getBounds();

    var background = try Object.createSquare("background", &shader);
    background.transform.scale = za.Vec2.new(window_bounds.width, window_bounds.height);
    background.texture = background_texture;
    background.zindex = -10; // put background behind everything
    background.do_not_destroy = true;
    defer background.deinitAndDestroy();

    const basic_font: *const Font = renderer.getFont().?;
    const end_text = try Text.createNoAdd("endText", "Game Over", &text_shader, basic_font);
    end_text.transform.pos = za.Vec2.new(0, 200);
    end_text.scale = 2.0;
    end_text.color = Color.red;
    end_text.do_not_destroy = true;
    defer end_text.destroy(allocator);

    const restart_btn = try Object.createSquareNoAdd("restart", &shader);
    restart_btn.transform.pos = za.Vec2.new(0, 35);
    restart_btn.transform.scale = restart_texture.size().scale(0.5);
    restart_btn.texture = restart_texture;
    restart_btn.do_not_destroy = true;
    defer restart_btn.deinitAndDestroy();

    const exit_btn = try Object.createSquareNoAdd("exit", &shader);
    exit_btn.transform.pos = za.Vec2.new(0, -150);
    exit_btn.transform.scale = exit_texture.size().scale(0.5);
    exit_btn.texture = exit_texture;
    exit_btn.do_not_destroy = true;
    defer exit_btn.deinitAndDestroy();

    const death_background = try Object.createSquareNoAdd("background", &shader);
    death_background.transform.scale = za.Vec2.new(window_bounds.width, window_bounds.height);
    death_background.texture = death_background_texture;
    death_background.zindex = -10; // put background behind everything
    death_background.do_not_destroy = true;
    defer death_background.deinitAndDestroy();

    const camera = Camera{};
    var game_over = false;

    var input = window.input();
    defer input.deinit();

    defer renderer.destroyAll(); // before we deinit the window destroy all objects in renderer queue to avoid segmentation fault

    var mouse_pressed: bool = false;
    var mouse_hold: bool = false;
    var mouse_hover: bool = false;
    while (!window.shouldClose()) {
        Window.pollEvents();
        time.startFrame();
        const dt = time.delta();

        renderer.clear(Color.black);
        if (!game_over) {
            update(window, &input, dt) catch |err| {
                if (err == error.GameOver) {
                    renderer.destroyAll();
                    try renderer.addObjectPtr(death_background);
                    try renderer.addTextPtr(end_text);
                    try renderer.addObjectPtr(restart_btn);
                    try renderer.addObjectPtr(exit_btn);
                    mouse_pressed = false;
                    mouse_hold = false;
                    mouse_hover = false;
                    game_over = true;
                } else {
                    return err;
                }
            };
        } else {
            if (input.getKeyPress(.space)) {
                renderer.destroyAll();
                try renderer.addObjectPtr(background);
                try renderer.addObjectPtr(player);
                timer = enemy_spawn_time;

                game_over = false;
                window.swapBuffers();
                continue;
            }

            const screen_mouse_pos = input.getMousePos();
            const mouse_pos = window.screenToWorld(screen_mouse_pos);

            if (input.getMousePress(.left) and !mouse_hold) {
                mouse_hold = true;
                mouse_pressed = true;
            } else if (!input.getMousePress(.left)) {
                mouse_hold = false;
            } else {
                mouse_pressed = false;
            }

            const is_hover = restart_btn.getBounds().contains(mouse_pos) or exit_btn.getBounds().contains(mouse_pos);
            if (is_hover and !mouse_hover) {
                mouse_hover = true;
                input.setCursorShape(.hand);
            } else if (!is_hover and mouse_hover) {
                mouse_hover = false;
                input.setCursorShape(.default);
            }

            if (restart_btn.getBounds().contains(mouse_pos) and mouse_pressed) {
                renderer.destroyAll();
                try renderer.addObjectPtr(background);
                try renderer.addObjectPtr(player);
                timer = enemy_spawn_time;

                input.setCursorShape(.default);

                game_over = false;
                window.swapBuffers();
                continue;
            } else if (exit_btn.getBounds().contains(mouse_pos) and mouse_pressed) {
                window.setShouldClose(true);
            }
        }

        try renderer.renderAll(camera);

        window.swapBuffers();
    }

    return 0;
}

const bullet_max_count = 100; // 100 bullets and 100 enemies equal 200 objects not including player
fn update(window: *const Window, input: *Input, dt: f32) !void {
    timer += dt; // increment timer
    const player_speed = 250.0;
    const enemy_speed = 150.0;

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
        const enemy = try Object.createSquare("enemy", &shader);

        const window_bounds = window.getBounds();

        while (true) {
            const pos_x: f32 = randomFloat(window_bounds.left(), window_bounds.right());
            const pos_y: f32 = randomFloat(window_bounds.bottom(), window_bounds.top());
            enemy.transform.pos = za.Vec2.new(pos_x, pos_y); // later will be random

            const b = Circle.fromPoint(enemy.transform.pos, 100); // check if enemy is too close to player
            if (!b.overlaps(Circle.fromTransform(player.transform))) {
                break;
            }
        }

        enemy.transform.scale = za.Vec2.new(75, 75);
        enemy.texture = try assets.getTexture("EnemyTexture");
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

fn spawnBullet(window: *const Window, input: *Input) !void {
    if (bullet_count >= bullet_max_count)
        return;

    const screen_mouse_pos = input.getMousePos();
    const mouse_pos = window.screenToWorld(screen_mouse_pos);

    const bullet_texture = try assets.getTexture("BulletTexture");

    // rotate player to face mouse
    const look_vector = mouse_pos.sub(player.transform.pos).norm();
    const angle = std.math.atan2(look_vector.y(), look_vector.x()) + std.math.pi / 2.0;
    const degrees = std.math.radiansToDegrees(angle); // bottom is pointing to the mouse pos

    const bullet = try Object.createSquare("bullet", &shader);
    bullet.transform.pos = player.transform.pos;
    bullet.transform.rotation = degrees - 90.0; // make right point towards mouse
    const bullet_width: f32 = @floatFromInt(bullet_texture.width);
    const bullet_height: f32 = @floatFromInt(bullet_texture.height);
    bullet.transform.scale = za.Vec2.new(bullet_width / 20.0, bullet_height / 20.0);
    bullet.color = Color.white;
    bullet.texture = bullet_texture;

    bullet_count += 1;

    bullet.data = .{ .move_data = .{
        .speed = 1000.0,
        .direction = look_vector,
    } };
}

fn mainmenu(window: *const Window) !void {
    // should be 1920x1080 so scale that down to 1920/2 x 1080/2
    const background = try assets.loadTexture("MenuBackgroundTexture", "res/sprites/menu_background.png", 0);
    defer assets.unloadTexture(background);

    const start_button = try assets.loadTexture("StartButtonTexture", "res/sprites/start_button.png", 1);
    defer assets.unloadTexture(start_button);

    const exit_button = try assets.loadTexture("ExitButtonTexture", "res/sprites/exit_button.png", 2);
    defer assets.unloadTexture(exit_button);

    Window.pollEvents();
    window.swapBuffers();
    const wb = window.getBounds();

    const background_image = try Object.createSquare("background", &shader);
    background_image.texture = background;
    background_image.transform.scale = za.Vec2.new(wb.width, wb.height);

    const start_buttom = try Object.createSquare("start", &shader);
    start_buttom.texture = start_button;
    start_buttom.transform.scale = start_button.size().scale(0.5);
    start_buttom.transform.pos = za.Vec2.new(0, 0);

    const exit_buttom = try Object.createSquare("exit", &shader);
    exit_buttom.texture = exit_button;
    exit_buttom.transform.scale = exit_button.size().scale(0.5);
    exit_buttom.transform.pos = za.Vec2.new(0, -start_button.size().y() / 2.0 * 1.2);

    const start_bounds = start_buttom.getBounds();
    const exit_bounds = exit_buttom.getBounds();

    var input = window.input();
    defer input.deinit();

    var mouse_hover: bool = false;
    var mouse_hold: bool = false;
    var mouse_pressed: bool = false;

    while (!window.shouldClose()) {
        time.startFrame(); // but we still need to update the time
        Window.pollEvents();

        const screenspace_mousepos = input.getMousePos();
        const mouse_pos = window.screenToWorld(screenspace_mousepos);

        // hover logic for mouse cursor
        const is_hover = start_bounds.contains(mouse_pos) or exit_bounds.contains(mouse_pos);
        if (is_hover and !mouse_hover) {
            input.setCursorShape(.hand);
            mouse_hover = true;
        } else if (!is_hover and mouse_hover) {
            input.setCursorShape(.arrow);
            mouse_hover = false;
        }

        // mouse press logic
        if (input.getMousePress(.left) and !mouse_hold) {
            mouse_hold = true;
            mouse_pressed = true;
        } else if (!input.getMousePress(.left)) {
            mouse_hold = false;
            mouse_pressed = false;
        } else {
            mouse_pressed = false;
        }

        // button logic
        if (start_bounds.contains(mouse_pos) and mouse_pressed) {
            return; // start game
        } else if (exit_bounds.contains(mouse_pos) and mouse_pressed) {
            window.setShouldClose(true);
        }

        renderer.clear(Color.rgb(95, 185, 55));
        try renderer.renderAll(Camera{}); // camera is not used in main menu

        window.swapBuffers();
    }

    std.process.exit(0); // exit the game if close button is pressed is the window is closed
}
