const std = @import("std");
const Text = @import("Text.zig");
const Object = @import("Object.zig");
const Transform = @import("Transform.zig");
const Color = @import("Color.zig");
const Shader = @import("Shader.zig");
const assets = @import("assets_manager.zig");

pub const RenderObject = union(enum) {
    text: *Text,
    object: *Object,

    pub fn deinit(self: RenderObject) void {
        switch (self) {
            .text => {}, // text doesn't need deinit
            .object => |o| o.deinit(),
        }
    }

    pub fn forceDeinit(self: RenderObject) void {
        switch (self) {
            .text => {}, // text doesn't need deinit
            .object => |o| o.forceDeinit(),
        }
    }

    pub fn destroy(self: RenderObject, a: std.mem.Allocator) void {
        switch (self) {
            .text => |t| {
                if (t.do_not_destroy) return;
                a.destroy(t);
            },
            .object => |o| {
                if (o.do_not_destroy) return;
                a.destroy(o);
            },
        }
    }

    pub fn forceDestroy(self: RenderObject, a: std.mem.Allocator) void {
        switch (self) {
            .text => |t| {
                if (t.do_not_destroy) {
                    std.log.debug("Destroying text with do_not_destroy enabled: {s}", .{t.name});
                }
                a.destroy(t);
            },
            .object => |o| {
                if (o.do_not_destroy) {
                    std.log.debug("Destroying object with do_not_destroy enabled: {s}", .{o.name});
                }
                a.destroy(o);
            },
        }
    }

    pub fn getPointerAddress(self: RenderObject) usize {
        return switch (self) {
            .text => |t| @intFromPtr(t),
            .object => |o| @intFromPtr(o),
        };
    }

    pub fn getName(self: RenderObject) []const u8 {
        return switch (self) {
            .text => |t| t.name,
            .object => |o| o.name,
        };
    }

    pub fn getDoNotDestroy(self: RenderObject) bool {
        return switch (self) {
            .text => |t| t.do_not_destroy,
            .object => |o| o.do_not_destroy,
        };
    }

    pub fn getTransform(self: RenderObject) *Transform {
        return switch (self) {
            .text => |t| &t.transform,
            .object => |o| &o.transform,
        };
    }
};

pub const RenderObjectType = enum {
    textured_square,
    colored_square,
    text,

    pub fn isObject(self: RenderObjectType) bool {
        return switch (self) {
            .textured_square, .colored_square => true,
            else => false,
        };
    }
};

pub const RenderObjectTemplate = struct {
    const Self = @This();

    name: []const u8,
    object_type: RenderObjectType,
    transform: Transform = .{},
    color: Color = Color.white,
    zindex: i32 = 0,
    visible: bool = true,
    do_not_destroy: bool = false,

    // text settings
    text_settings: ?struct {
        text: []const u8,
        font: []const u8,
    } = null,

    // assets
    shader: ?[]const u8 = null, // if null we find the right shader to use depending on the object type
    texture: ?[]const u8 = null,

    /// note once this is called, it is added to active objects
    /// text will use transform.scale.x() for text.scale
    pub fn make(self: Self) !RenderObject {
        const shader_name = self.shader orelse self.getDefaultShaderName();
        std.log.debug("Getting shader: {s}", .{shader_name});
        const shader = try assets.getShader(shader_name);
        switch (self.object_type) {
            .textured_square, .colored_square => {
                const obj: *Object = if (self.object_type == .textured_square)
                    try Object.createSquare(self.name, shader)
                else
                    try Object.createBasicSquare(self.name, shader);

                if (self.texture) |t| {
                    const texture = try assets.getTexture(t);
                    obj.texture = texture;
                }
                obj.transform = self.transform;
                obj.color = self.color;
                obj.zindex = self.zindex;
                obj.visible = self.visible;
                obj.do_not_destroy = self.do_not_destroy;
                return RenderObject{ .object = obj };
            },
            .text => {
                if (self.text_settings == null) return error.MissingTextSettings;
                const font = try assets.getFont(self.text_settings.?.font);
                const text: *Text = try Text.create(self.name, self.text_settings.?.text, shader, font);
                text.transform = self.transform;
                text.scale = text.transform.scale.x();
                text.color = self.color;
                text.zindex = self.zindex;
                text.visible = self.visible;
                text.do_not_destroy = self.do_not_destroy;
                return RenderObject{ .text = text };
            },
        }
    }

    fn getDefaultShaderName(self: Self) []const u8 {
        return switch (self.object_type) {
            .textured_square => "TexturedShader",
            .colored_square => "ColoredShader",
            .text => "TextShader",
        };
    }
};
