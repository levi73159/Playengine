const std = @import("std");
const za = @import("zalgebra");

const Window = @import("Window.zig");
const Object = @import("Object.zig");
const assets = @import("assets_manager.zig");
const Color = @import("Color.zig");
const Camera = @import("Camera.zig");
const Scene = @import("Scene.zig");
const Texture = @import("Texture.zig");
const renderer = @import("renderer.zig");
const Engine = @import("Engine.zig");
const Input = @import("Input.zig");
const Rect = @import("bounds.zig").RectBounds;
const Circle = @import("bounds.zig").CircleBounds;
const time = @import("time.zig");
const random = @import("random.zig");

const Template = @import("rendererObjects.zig").RenderObjectTemplate;

const Self = @This();

const enemy_spawn_time = 3.0;
const bullet_max_count = 100;

player: *Object = undefined,
restartbtn_texture: *Texture = undefined,

restart_bounds: Rect = Rect.zero(),
exit_bounds: Rect = Rect.zero(),

// game state
timer: f32 = enemy_spawn_time,
game_over: bool = false,
bullet_count: u32 = 0,

// basic input tracking
mouse_hover: bool = false,
mouse_pressed: bool = false,
mouse_hold: bool = false,

pub fn getTemplates(allocator: std.mem.Allocator, window: *const Window) []const Template {
    const wb = window.getBounds();

    const templates = [_]Template{
        // game section
        Template{
            .name = "Background",
            .object_type = .textured_square,
            .texture = "BackgroundTexture",
            .color = Color.white,
            .zindex = -10,
            .transform = .{ .scale = za.Vec2.new(wb.width, wb.height) },
        },
        Template{
            .name = "Player",
            .object_type = .textured_square,
            .texture = "PlayerTexture",
            .color = Color.white,
            .zindex = 0,
            .transform = .{ .scale = za.Vec2.new(75, 75) },
        },
        // game over section
        Template{
            .name = "GameOverBackground",
            .object_type = .textured_square,
            .texture = "DeathBackgroundTexture",
            .color = Color.white,
            .zindex = -10,
            .transform = .{ .scale = za.Vec2.new(wb.width, wb.height) },
            .visible = false,
        },
        Template{
            .name = "GameOverText",
            .text_settings = .{
                .text = "Game Over",
                .font = "RobotoFont",
            },
            .object_type = .text,
            .color = Color.red,
            .zindex = 0,
            .transform = .{ .pos = za.Vec2.new(0, 200), .scale = za.Vec2.new(2.0, 2.0) }, // scale font by 2.0
            .visible = false,
        },
        Template{
            .name = "RestartButton",
            .object_type = .textured_square,
            .texture = "RestartButtonTexture",
            .color = Color.white,
            .zindex = 0,
            .visible = false,
            .transform = .{
                .pos = za.Vec2.new(0, 35),
            },
        },
        Template{
            .name = "ExitButton",
            .object_type = .textured_square,
            .texture = "ExitButtonTexture",
            .color = Color.white,
            .zindex = 0,
            .visible = false,
            .transform = .{
                .pos = za.Vec2.new(0, -150),
            },
        },
    };

    return allocator.dupe(Template, &templates) catch unreachable;
}

pub fn load(self: *Self, _: Scene, _: *const Window, _: *Camera) anyerror!void {
    try assets.preloadTextureCE("BackgroundTexture", "res/sprites/Background_game.png", 0);
    try assets.preloadTextureCE("PlayerTexture", "res/sprites/player.png", 1);
    try assets.preloadTextureCE("EnemyTexture", "res/sprites/enemy.png", 2);
    try assets.preloadTextureCE("BulletTexture", "res/sprites/bullet.png", 3);

    try assets.preloadTextureCE("DeathBackgroundTexture", "res/sprites/death_background.png", 0);
    try assets.preloadTextureCE("ExitButtonTexture", "res/sprites/exit_button.png", 1);
    self.restartbtn_texture = try assets.loadTexture("RestartButtonTexture", "res/sprites/restart.png", 2);

    // making sure the font is loaded
    _ = try assets.loadFont("RobotoFont", "res/fonts/Roboto.ttf", 48);
}

pub fn start(self: *Self, _: Scene, w: *const Window, _: *Camera) anyerror!void {
    renderer.setClearColor(Color.red);

    const restart_button = renderer.findGameObject("RestartButton") orelse return error.NotFound;
    const exit_button = renderer.findGameObject("ExitButton") orelse return error.NotFound;

    // assuming restart button and exit button are the same size
    restart_button.transform.scale = self.restartbtn_texture.size().scale(0.5);
    exit_button.transform.scale = self.restartbtn_texture.size().scale(0.5);

    self.restart_bounds = restart_button.getBounds();
    self.exit_bounds = exit_button.getBounds();

    const background = renderer.findGameObject("Background") orelse return error.NotFound;
    const death_background = renderer.findGameObject("GameOverBackground") orelse return error.NotFound;

    const wb = w.getDrawableBounds();

    background.transform.scale = wb.size();
    death_background.transform.scale = wb.size();

    self.player = renderer.findGameObject("Player") orelse return error.NotFound;
}

pub fn update(self: *Self, _: Scene, window: *const Window, _: *Camera, input: *Input) anyerror!void {
    const dt = time.delta();

    if (!self.game_over) {
        try self.gameState(window, input, dt);
    } else {
        try self.gameOverState(window, input);
    }
}

fn gameState(self: *Self, w: *const Window, input: *Input, dt: f32) !void {
    self.timer += dt;

    const player = self.player; // quick access

    const player_speed = 250.0;
    const enemy_speed = 150.0;

    var transform = player.transform;
    const move_vector = input.getVector(.w, .s, .a, .d).norm().scale(player_speed * dt);
    transform.pos = transform.pos.add(move_vector);

    const screen_bounds = w.getBounds();
    const player_bounds = Rect.fromTransform(transform);

    const outside_x = player_bounds.left() < screen_bounds.left() or player_bounds.right() > screen_bounds.right();
    const outside_y = player_bounds.bottom() < screen_bounds.bottom() or player_bounds.top() > screen_bounds.top();

    if (!outside_x) {
        player.transform.pos.xMut().* = transform.pos.x();
    }

    if (!outside_y) {
        player.transform.pos.yMut().* = transform.pos.y();
    }

    if (input.getMousePress(.left) and !self.mouse_pressed) {
        self.mouse_pressed = true;
        try self.spawnBullet(w, input);
    } else if (!input.getMousePress(.left)) {
        self.mouse_pressed = false;
    }

    var bullet_buffer: [bullet_max_count]renderer.RenderObject = undefined;
    const bullets_found = renderer.findObjectsLimited(&bullet_buffer, "bullet", self.bullet_count);
    const bullets = bullet_buffer[0..bullets_found];

    for (bullets) |render_object| {
        const bullet = render_object.object;
        const data = bullet.data.?.move_data;
        bullet.transform.pos = bullet.transform.pos.add(data.direction.scale(data.speed * dt));

        const b = Rect.fromTransform(bullet.transform);
        if (!b.overlaps(w.getBounds())) {
            renderer.destroyObject(render_object);
            self.bullet_count -= 1;
        }
    }

    // enemy code
    if (self.timer > enemy_spawn_time) {
        self.timer = 0.0;
        const enemy = try Object.createSquare("enemy", try assets.getShader("TexturedShader"));
        enemy.transform.scale = player.transform.scale;
        enemy.texture = try assets.loadTexture("EnemyTexture", "res/sprites/enemy.png", 2);

        const window_bounds = w.getBounds();
        while (true) {
            const pos_x: f32 = random.float(f32, window_bounds.left(), window_bounds.right());
            const pos_y: f32 = random.float(f32, window_bounds.bottom(), window_bounds.top());
            enemy.transform.pos = za.Vec2.new(pos_x, pos_y);

            const b = Circle.fromPoint(enemy.transform.pos, 0); // check if enemy is too close to player
            if (!b.overlaps(Circle.fromTransform(player.transform))) {
                break;
            }
        }
    }

    var enemy_buffer: [100]renderer.RenderObject = undefined;
    const enemies_found = renderer.findObjectsLimited(&enemy_buffer, "enemy", 100);
    const enemies = enemy_buffer[0..enemies_found];

    const player_cirlce_bounds = Circle.fromTransform(player.transform);

    // check if enemy collided with player if so, game over
    // check if bullet hit enemy if so, destroy both
    // else move enemy towards player
    enemy_loop: for (enemies) |enemy| {
        const enemy_transform = enemy.getTransform();
        const enemy_bounds = Circle.fromTransform(enemy_transform.*);

        if (enemy_bounds.overlaps(player_cirlce_bounds)) {
            self.die();
            return;
        }
        for (bullets) |bullet| {
            const bullet_bounds = Circle.fromPoint(bullet.getTransform().pos, bullet.getTransform().scale.x() / 2.0);
            if (bullet_bounds.overlaps(enemy_bounds)) {
                renderer.destroyObject(bullet);
                renderer.destroyObject(enemy);
                self.bullet_count -= 1;
                continue :enemy_loop; // continue to next enemy
            }
        }

        const mv = player.transform.pos.sub(enemy_transform.pos).norm(); // move vector
        enemy_transform.pos = enemy_transform.pos.add(mv.scale(enemy_speed * dt));
    }
}

fn gameOverState(self: *Self, w: *const Window, input: *Input) !void {
    if (input.getKeyPress(.space)) {
        self.restart();
    }

    const screen_mouse_pos = input.getMousePos();
    const mouse_pos = w.screenToWorld(screen_mouse_pos);

    if (input.getMousePress(.left) and !self.mouse_hold) {
        self.mouse_hold = true;
        self.mouse_pressed = true;
    } else if (!input.getMousePress(.left)) {
        self.mouse_hold = false;
    } else {
        self.mouse_pressed = false;
    }

    const is_hover = self.restart_bounds.contains(mouse_pos) or self.exit_bounds.contains(mouse_pos);
    if (is_hover and !self.mouse_hover) {
        self.mouse_hover = true;
        input.setCursorShape(.hand);
    } else if (!is_hover and self.mouse_hover) {
        self.mouse_hover = false;
        input.setCursorShape(.default);
    }

    if (self.restart_bounds.contains(mouse_pos) and self.mouse_pressed) {
        self.restart();
        input.setCursorShape(.default);
    } else if (self.exit_bounds.contains(mouse_pos) and self.mouse_pressed) {
        Engine.close();
    }
}

fn spawnBullet(self: *Self, w: *const Window, input: *Input) !void {
    if (self.bullet_count >= bullet_max_count) {
        return;
    }

    const screen_mouse_pos = input.getMousePos();
    const mouse_pos = w.screenToWorld(screen_mouse_pos);

    const bullet_texture = try assets.getTexture("BulletTexture");

    // rotate player to face mouse
    const look_vector = mouse_pos.sub(self.player.transform.pos).norm();
    const angle = std.math.atan2(look_vector.y(), look_vector.x()) + std.math.pi / 2.0;
    const degrees = std.math.radiansToDegrees(angle); // bottom is pointing to the mouse pos

    const bullet = try Object.createSquare("bullet", try assets.getShader("TexturedShader"));
    bullet.transform.pos = self.player.transform.pos;
    bullet.transform.rotation = degrees - 90.0; // make right point towards mouse
    const bullet_width: f32 = @floatFromInt(bullet_texture.width);
    const bullet_height: f32 = @floatFromInt(bullet_texture.height);
    bullet.transform.scale = za.Vec2.new(bullet_width / 20.0, bullet_height / 20.0);
    bullet.color = Color.white;
    bullet.texture = bullet_texture;

    self.bullet_count += 1;

    bullet.data = .{ .move_data = .{
        .speed = 1000.0,
        .direction = look_vector,
    } };
}

fn die(self: *Self) void {
    self.game_over = true;
    const objects = renderer.cloneActiveObjects() catch unreachable;
    defer objects.deinit();

    const eql = std.mem.eql;

    for (objects.items) |object| {
        if (eql(u8, object.getName(), "enemy") or eql(u8, object.getName(), "bullet")) {
            renderer.destroyObject(object);
        } else {
            switch (object) {
                .object => |obj| obj.visible = !obj.visible,
                .text => |txt| txt.visible = !txt.visible,
            }
        }
    }
}

fn restart(self: *Self) void {
    self.game_over = false;
    self.bullet_count = 0;
    self.timer = enemy_spawn_time;
    self.player.transform.pos = za.Vec2.new(0.0, 0.0);

    const objects = renderer.getActiveObjects();

    for (objects) |object| {
        switch (object) {
            .object => |obj| obj.visible = !obj.visible,
            .text => |txt| txt.visible = !txt.visible,
        }
    }
}
