//! INPUT SYSTEM
const std = @import("std");
const glfw = @import("glfw");
const za = @import("zalgebra");

const Self = @This();

handle: *glfw.Window,
current_cursor: ?*glfw.CursorHandle = null,

pub const Key = enum(i32) {
    unknown = glfw.KeyUnknown,
    space = glfw.KeySpace,
    apostrophe = glfw.KeyApostrophe,
    comma = glfw.KeyComma,
    minus = glfw.KeyMinus,
    period = glfw.KeyPeriod,
    slash = glfw.KeySlash,
    zero = glfw.KeyNum0,
    one = glfw.KeyNum1,
    two = glfw.KeyNum2,
    three = glfw.KeyNum3,
    four = glfw.KeyNum4,
    five = glfw.KeyNum5,
    six = glfw.KeyNum6,
    seven = glfw.KeyNum7,
    eight = glfw.KeyNum8,
    nine = glfw.KeyNum9,
    semicolon = glfw.KeySemicolon,
    equal = glfw.KeyEqual,
    a = glfw.KeyA,
    b = glfw.KeyB,
    c = glfw.KeyC,
    d = glfw.KeyD,
    e = glfw.KeyE,
    f = glfw.KeyF,
    g = glfw.KeyG,
    h = glfw.KeyH,
    i = glfw.KeyI,
    j = glfw.KeyJ,
    k = glfw.KeyK,
    l = glfw.KeyL,
    m = glfw.KeyM,
    n = glfw.KeyN,
    o = glfw.KeyO,
    p = glfw.KeyP,
    q = glfw.KeyQ,
    r = glfw.KeyR,
    s = glfw.KeyS,
    t = glfw.KeyT,
    u = glfw.KeyU,
    v = glfw.KeyV,
    w = glfw.KeyW,
    x = glfw.KeyX,
    y = glfw.KeyY,
    z = glfw.KeyZ,
    left_bracket = glfw.KeyLeftBracket,
    backslash = glfw.KeyBackslash,
    right_bracket = glfw.KeyRightBracket,
    grave_accent = glfw.KeyGraveAccent,
    world_1 = glfw.KeyWorld1,
    world_2 = glfw.KeyWorld2,
    escape = glfw.KeyEscape,
    enter = glfw.KeyEnter,
    tab = glfw.KeyTab,
    backspace = glfw.KeyBackspace,
    insert = glfw.KeyInsert,
    delete = glfw.KeyDelete,
    right = glfw.KeyRight,
    left = glfw.KeyLeft,
    down = glfw.KeyDown,
    up = glfw.KeyUp,
    page_up = glfw.KeyPageUp,
    page_down = glfw.KeyPageDown,
    home = glfw.KeyHome,
    end = glfw.KeyEnd,
    caps_lock = glfw.KeyCapsLock,
    scroll_lock = glfw.KeyScrollLock,
    num_lock = glfw.KeyNumLock,
    print_screen = glfw.KeyPrintScreen,
    pause = glfw.KeyPause,
    f1 = glfw.KeyF1,
    f2 = glfw.KeyF2,
    f3 = glfw.KeyF3,
    f4 = glfw.KeyF4,
    f5 = glfw.KeyF5,
    f6 = glfw.KeyF6,
    f7 = glfw.KeyF7,
    f8 = glfw.KeyF8,
    f9 = glfw.KeyF9,
    f10 = glfw.KeyF10,
    f11 = glfw.KeyF11,
    f12 = glfw.KeyF12,
    f13 = glfw.KeyF13,
    f14 = glfw.KeyF14,
    f15 = glfw.KeyF15,
    f16 = glfw.KeyF16,
    f17 = glfw.KeyF17,
    f18 = glfw.KeyF18,
    f19 = glfw.KeyF19,
    f20 = glfw.KeyF20,
    f21 = glfw.KeyF21,
    f22 = glfw.KeyF22,
    f23 = glfw.KeyF23,
    f24 = glfw.KeyF24,
    f25 = glfw.KeyF25,
    kp_0 = glfw.KeyKp0,
    kp_1 = glfw.KeyKp1,
    kp_2 = glfw.KeyKp2,
    kp_3 = glfw.KeyKp3,
    kp_4 = glfw.KeyKp4,
    kp_5 = glfw.KeyKp5,
    kp_6 = glfw.KeyKp6,
    kp_7 = glfw.KeyKp7,
    kp_8 = glfw.KeyKp8,
    kp_9 = glfw.KeyKp9,
    kp_decimal = glfw.KeyKpDecimal,
    kp_divide = glfw.KeyKpDivide,
    kp_multiply = glfw.KeyKpMultiply,
    kp_subtract = glfw.KeyKpSubtract,
    kp_add = glfw.KeyKpAdd,
    kp_enter = glfw.KeyKpEnter,
    kp_equal = glfw.KeyKpEqual,
    left_shift = glfw.KeyLeftShift,
    left_control = glfw.KeyLeftControl,
    left_alt = glfw.KeyLeftAlt,
    left_super = glfw.KeyLeftSuper,
    right_shift = glfw.KeyRightShift,
    right_control = glfw.KeyRightControl,
    right_alt = glfw.KeyRightAlt,
    right_super = glfw.KeyRightSuper,
    menu = glfw.KeyMenu,
};

pub const MouseButton = enum(i32) {
    left = glfw.MouseButtonLeft,
    right = glfw.MouseButtonRight,
    middle = glfw.MouseButtonMiddle,
    btn4 = glfw.MouseButton4,
    btn5 = glfw.MouseButton5,
    _,

    pub fn button(n: u32) MouseButton {
        return @enumFromInt(n);
    }
};

pub const Action = enum(u32) {
    release = glfw.Release,
    press = glfw.Press,
    repeat = glfw.Repeat,
};

pub const CursorShape = enum(i32) {
    default = glfw.DontCare, //
    arrow = glfw.Arrow,
    ibeam = glfw.IBeam,
    crosshair = glfw.Crosshair,
    hand = glfw.Hand,
    hresize = glfw.HResize,
    vresize = glfw.VResize,
};

pub fn init(handle: *glfw.Window) Self {
    return Self{
        .handle = handle,
    };
}

pub fn deinit(self: Self) void {
    glfw.setCursor(self.handle, null); // destroy current cursor
    glfw.destroyCursor(self.current_cursor);
}

pub fn getKey(self: Self, key: Key) Action {
    const action = glfw.getKey(self.handle, @intFromEnum(key));
    return @enumFromInt(action);
}

pub fn getKeyPress(self: Self, key: Key) bool {
    return glfw.getKey(self.handle, @intFromEnum(key)) == glfw.Press;
}

pub fn getKeyRelease(self: Self, key: Key) bool {
    return glfw.getKey(self.handle, @intFromEnum(key)) == glfw.Release;
}

pub fn getKeyRepeat(self: Self, key: Key) bool {
    return glfw.getKey(self.handle, @intFromEnum(key)) == glfw.Repeat;
}

pub fn getMouseButton(self: Self, button: MouseButton) Action {
    const action = glfw.getMouseButton(self.handle, @intFromEnum(button));
    return @enumFromInt(action);
}

pub fn getMousePress(self: Self, button: MouseButton) bool {
    return glfw.getMouseButton(self.handle, @intFromEnum(button)) == glfw.Press;
}

pub fn getMouseRelease(self: Self, button: MouseButton) bool {
    return glfw.getMouseButton(self.handle, @intFromEnum(button)) == glfw.Release;
}

pub fn getMouseRepeat(self: Self, button: MouseButton) bool {
    return glfw.getMouseButton(self.handle, @intFromEnum(button)) == glfw.Repeat;
}

pub fn getMousePos(self: Self) za.Vec2 {
    var x: f64 = undefined;
    var y: f64 = undefined;
    glfw.getCursorPos(self.handle, &x, &y);
    return za.Vec2.new(@floatCast(x), @floatCast(y));
}

pub fn setMousePos(self: Self, pos: za.Vec2) void {
    glfw.setCursorPos(self.handle, pos.x, pos.y);
}

pub fn setMouseVisible(self: Self, visible: bool) void {
    glfw.setInputMode(self.handle, glfw.Cursor, @intFromBool(visible));
}

pub fn setCursorShape(self: *Self, shape: CursorShape) void {
    glfw.destroyCursor(self.current_cursor);
    if (shape == .default) {
        self.current_cursor = null;
        glfw.setCursor(self.handle, null);
    } else {
        const cursor = glfw.createStandardCursor(@intFromEnum(shape));
        self.current_cursor = cursor;
        glfw.setCursor(self.handle, cursor);
    }
}

pub fn getAxis(self: Self, left: Key, right: Key) f32 {
    const left_action = glfw.getKey(self.handle, @intFromEnum(left));
    const right_action = glfw.getKey(self.handle, @intFromEnum(right));

    var axis: f32 = 0.0;
    if (left_action == glfw.Press) {
        axis -= 1.0;
    }
    if (right_action == glfw.Press) {
        axis += 1.0;
    }
    return axis;
}

pub fn getVector(self: Self, up: Key, down: Key, left: Key, right: Key) za.Vec2 {
    const up_action = glfw.getKey(self.handle, @intFromEnum(up));
    const down_action = glfw.getKey(self.handle, @intFromEnum(down));
    const left_action = glfw.getKey(self.handle, @intFromEnum(left));
    const right_action = glfw.getKey(self.handle, @intFromEnum(right));

    var x: f32 = 0;
    var y: f32 = 0;

    if (up_action == glfw.Press) {
        y += 1.0;
    }
    if (down_action == glfw.Press) {
        y -= 1.0;
    }
    if (left_action == glfw.Press) {
        x -= 1.0;
    }
    if (right_action == glfw.Press) {
        x += 1.0;
    }
    return za.Vec2.new(x, y);
}
