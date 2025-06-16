const std = @import("std");
const Texture = @import("Texture.zig");
const Font = @import("Font.zig");

pub const AssetData = union(enum) {
    texture: *Texture,
    font: *Font,
};

pub const Asset = struct {
    alias: ?[]const u8,
    data: AssetData,

    pub fn deinit(self: Asset) void {
        switch (self.data) {
            .texture => |texture| texture.deinit(),
            .font => |font| font.deinit(),
        }
    }

    pub fn destroyAndDeinit(self: Asset, alloc: std.mem.Allocator) void {
        switch (self.data) {
            .texture => |texture| {
                texture.deinit();
                alloc.destroy(texture);
            },
            .font => |font| {
                font.deinit();
                alloc.destroy(font);
            },
        }
    }
};
const Assets = std.StringHashMapUnmanaged(Asset);
const AssetsToData = std.StringHashMapUnmanaged(AssetData);

var assets = Assets.empty; // alias -> asset (data, alias)
var alias_map = AssetsToData.empty; // alias -> asset data (downside, can't really get path from alias but the upside is that it is faster then alias -> path -> asset)

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

pub fn deinit() void {
    var it = assets.iterator();
    while (it.next()) |entry| {
        std.log.debug("Destroying asset {?s} ({s})", .{ entry.value_ptr.alias, entry.key_ptr.* });
        entry.value_ptr.destroyAndDeinit(allocator);
    }
    assets.deinit(allocator);
    alias_map.deinit(allocator);
}

pub fn isTextureFile(path: []const u8) bool {
    const ext = std.fs.path.extension(path);
    return std.mem.eql(u8, ext, ".png") or
        std.mem.eql(u8, ext, ".jpg") or
        std.mem.eql(u8, ext, ".jpeg");
}

pub fn isFontFile(path: []const u8) bool {
    const ext = std.fs.path.extension(path);
    return std.mem.eql(u8, ext, ".ttf");
}

// TODO: change this where it will use path as key, and add alias if needed and as value
pub fn loadTexture(alias: ?[]const u8, path: []const u8, slot: ?u32) !*Texture {
    std.log.debug("Loading texture {?s} ({s})", .{ alias, path });
    if (assets.get(path)) |asset| {
        return asset.data.texture;
    }

    var texture = Texture.loadFromFile(allocator, path) catch |err| {
        std.log.err("Failed to load texture {s}", .{path});
        return err;
    };
    errdefer texture.deinit();

    if (slot) |s| {
        texture.bound_slot = s;
    }

    const gp_result = try assets.getOrPut(allocator, path);

    const data = try allocator.create(Texture);
    data.* = texture;
    gp_result.value_ptr.* = .{ .data = .{ .texture = data }, .alias = alias };

    // allows clobering of alias_map
    if (alias) |a| {
        try alias_map.put(allocator, a, .{ .texture = data });
    }

    return data;
}

pub fn preloadTexture(alias: ?[]const u8, path: []const u8, slot: ?u32) !void {
    std.log.debug("Preloading texture {?s} ({s})", .{ alias, path });
    var texture = Texture.loadFromFile(allocator, path) catch |err| {
        std.log.err("Failed to load texture {s}", .{path});
        return err;
    };
    errdefer texture.deinit();

    if (slot) |s| {
        texture.bound_slot = s;
    }

    const gp_result = try assets.getOrPut(allocator, path);

    if (gp_result.found_existing) {
        return error.AssetAlreadyLoaded; // can't preload an asset that is already loaded
    }

    const ptr = try allocator.create(Texture);
    ptr.* = texture;
    gp_result.value_ptr.* = .{ .data = .{ .texture = ptr }, .alias = alias };

    // allows clobering of alias_map
    if (alias) |a| {
        try alias_map.put(allocator, a, .{ .texture = ptr });
    }
}

pub fn loadFont(alias: ?[]const u8, path: []const u8, size: u32) !*Font {
    if (assets.get(path)) |asset| {
        return asset.data.font;
    }

    var font = Font.init(allocator, path, size) catch |err| {
        std.log.err("Failed to load font {s}", .{path});
        return err;
    };
    errdefer font.deinit();

    const gp_result = try assets.getOrPut(allocator, path);

    const data = try allocator.create(Font);
    data.* = font;
    gp_result.value_ptr.* = .{ .data = .{ .font = data }, .alias = alias };

    // allows clobering of alias_map
    if (alias) |a| {
        try alias_map.put(allocator, a, .{ .font = data });
    }
    return data;
}

pub fn preloadFont(alias: ?[]const u8, path: []const u8, size: u32) !void {
    var font = Font.init(allocator, path, size) catch |err| {
        std.log.err("Failed to load font {s}", .{path});
        return err;
    };
    errdefer font.deinit();

    const gp_result = try assets.getOrPut(allocator, path);
    if (gp_result.found_existing) {
        return error.AssetAlreadyLoaded; // can't preload an asset that is already loaded
    }

    const data = try allocator.create(Font);
    data.* = font;
    gp_result.value_ptr.* = .{ .data = .{ .font = data }, .alias = alias };

    // allows clobering of alias_map
    if (alias) |a| {
        try alias_map.put(allocator, a, .{ .font = data });
    }
}

/// get's any asset by alias that can be null
pub fn get(alias: []const u8) ?AssetData {
    return alias_map.get(alias);
}

const GetAssetError = error{ AssetNotFound, InvalidAssetType };

/// get's a texture by alias that can't be null and must be texture else `error.InvalidAssetType`
pub fn getTexture(alias: []const u8) GetAssetError!*Texture {
    std.log.debug("Getting texture {?s}", .{alias});
    const data = alias_map.get(alias) orelse return error.AssetNotFound;
    if (data != .texture) return error.InvalidAssetType;
    return data.texture;
}

pub fn getFont(alias: []const u8) GetAssetError!*Font {
    std.log.debug("Getting font {?s}", .{alias});
    const data = alias_map.get(alias) orelse return error.AssetNotFound;
    if (data != .font) return error.InvalidAssetType;
    return data.font;
}

pub fn unload(path: []const u8) void {
    const asset = assets.fetchRemove(path);
    if (asset) |*a| {
        a.value.destroyAndDeinit(allocator);
        if (a.value.alias) |alias| {
            std.debug.assert(alias_map.remove(alias)); // safety check to make sure there was an alias
        }
    }
}

pub fn unloadTexture(texture: *Texture) void {
    std.log.debug("Unloading texture {s}", .{texture.path});
    const asset = assets.fetchRemove(texture.path);
    if (asset) |*a| {
        std.debug.assert(a.value.data == .texture); // safety check
        a.value.destroyAndDeinit(allocator);
        if (a.value.alias) |alias| {
            std.debug.assert(alias_map.remove(alias)); // safety check to make sure there was an alias
        }
    }
}

pub fn unloadFont(font: *Font) void {
    std.log.debug("Unloading font {s}", .{font.path});
    const asset = assets.fetchRemove(font.path);
    if (asset) |*a| {
        std.debug.assert(a.value.data == .font); // safety check
        a.value.destroyAndDeinit(allocator);
        if (a.value.alias) |alias| {
            std.debug.assert(alias_map.remove(alias)); // safety check to make sure there was an alias
        }
    }
}
