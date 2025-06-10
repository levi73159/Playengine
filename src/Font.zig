const std = @import("std");
const gl = @import("gl");

const log = std.log.scoped(.font);

const c = @cImport({
    @cInclude("ft2build.h");
    @cInclude("freetype/freetype.h");
});

const Self = @This();

const Character = struct {
    texture_id: u32,
    size: [2]u32,
    bearing: [2]i32,
    advance: i64, // c_long is kinda an int64_t
};
const CharacterMap = std.AutoHashMap(u8, Character);

path: []const u8,
map: CharacterMap,

const FontError = error{
    FailedToLoadFont,
    FailedToInitFreeType,
    OutOfMemory,
};

pub fn init(allocator: std.mem.Allocator, path: [:0]const u8, size: u32) FontError!Self {
    const ft: c.FT_Library = try FT_LibInit();
    defer _ = c.FT_Done_FreeType(ft);

    var face: c.FT_Face = undefined;
    if (c.FT_New_Face(ft, path.ptr, 0, @ptrCast(&face)) != 0) {
        return error.FailedToLoadFont;
    }
    defer _ = c.FT_Done_Face(face);

    _ = c.FT_Set_Pixel_Sizes(face, 0, size);

    const map = try initCharacterMap(allocator, face);

    return Self{
        .path = path,
        .map = map,
    };
}

pub fn initEmbedded(allocator: std.mem.Allocator, comptime path: []const u8, size: u32) FontError!Self {
    const ft: c.FT_Library = try FT_LibInit();
    defer _ = c.FT_Done_FreeType(ft);

    var face: c.FT_Face = undefined;
    const data: []const u8 = @embedFile(path);
    const data_ptr = data.ptr;
    const len = data.len;

    if (c.FT_New_Memory_Face(ft, data_ptr, @intCast(len), 0, @ptrCast(&face)) != 0) {
        return error.FailedToLoadFont;
    }
    defer _ = c.FT_Done_Face(face);

    _ = c.FT_Set_Pixel_Sizes(face, 0, size);

    const map = try initCharacterMap(allocator, face);

    return Self{
        .path = path,
        .map = map,
    };
}

fn FT_LibInit() FontError!c.FT_Library {
    var ft: c.FT_Library = undefined;
    if (c.FT_Init_FreeType(@ptrCast(&ft)) != 0) {
        return error.FailedToInitFreeType;
    }
    return ft;
}

fn initCharacterMap(allocator: std.mem.Allocator, face: c.FT_Face) !CharacterMap {
    var map = CharacterMap.init(allocator);
    errdefer map.deinit();

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);

    gl.ActiveTexture(gl.TEXTURE0); // bind to texture slot 0
    for (0..128) |i| {
        const char: u8 = @intCast(i);
        if (c.FT_Load_Char(face, char, c.FT_LOAD_RENDER) != 0) {
            log.err("Failed to load glyph", .{});
            continue;
        }

        const width = face.*.glyph.*.bitmap.width;
        const rows = face.*.glyph.*.bitmap.rows;

        if (char == ' ') {
            const character = Character{
                .texture_id = 0,
                .size = .{ width, rows },
                .bearing = .{ face.*.glyph.*.bitmap_left, face.*.glyph.*.bitmap_top },
                .advance = face.*.glyph.*.advance.x,
            };
            try map.put(char, character);
            continue;
        }

        var texture_id: u32 = 0;
        gl.GenTextures(1, @ptrCast(&texture_id));

        gl.BindTexture(gl.TEXTURE_2D, texture_id);
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RED,
            @intCast(width),
            @intCast(rows),
            0,
            gl.RED,
            gl.UNSIGNED_BYTE,
            face.*.glyph.*.bitmap.buffer,
        );

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        try map.put(char, Character{
            .texture_id = texture_id,
            .size = .{ width, rows },
            .bearing = .{ face.*.glyph.*.bitmap_left, face.*.glyph.*.bitmap_top },
            .advance = face.*.glyph.*.advance.x,
        });
    }

    return map;
}

pub fn deinit(self: *Self) void {
    var it = self.map.iterator();
    while (it.next()) |entry| {
        if (entry.key_ptr.* == ' ') continue; // because space doesn't have a texture (safe memory)
        gl.DeleteTextures(1, @ptrCast(&entry.value_ptr.texture_id));
    }

    self.map.deinit();
}

pub fn getCharacter(self: *const Self, char: u8) ?Character {
    return self.map.get(char);
}
