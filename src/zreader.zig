// zreader: e-ink reader for MTK hwtcon_v2 Kindles (PW6 class).
// Rendering via MuPDF (render.c); display, input, cache, UI and notes here.
const std = @import("std");
const linux = std.os.linux;
const alloc = std.heap.c_allocator;

const VERSION = "0.11.2";
const sans_font = @embedFile("fonts/NotoSans-Regular.otf");
// v0.10.0 second book font (OFL, Latin subset) and compact Latin hyphenation patterns (MIT).
const sans_bold = @embedFile("fonts/NotoSans-Bold-Latin.ttf");
const sans_italic = @embedFile("fonts/NotoSans-Italic-Latin.ttf");
const sans_bold_italic = @embedFile("fonts/NotoSans-BoldItalic-Latin.ttf");
const hyph_la = @embedFile("hyph/la");

// ---------------- C ----------------
const ZrDoc = opaque {};
const ZrUi = opaque {};
const ZrWord = extern struct { x0: f32, y0: f32, x1: f32, y1: f32, line: c_int, off: c_int, len: c_int };
const ZrToc = extern struct { page: c_int, level: c_int, off: c_int, len: c_int };
extern fn zrd_open(path: [*:0]const u8) c_int;
extern fn zrd_close() void;
extern fn zrl_open(path: [*:0]const u8) c_int;
extern fn zrl_close() void;
extern fn zrl_define(word: [*]const u8, len: c_int, lemma: [*]u8, lemma_cap: c_int, out: [*]u8, cap: c_int) c_int;
extern fn zr_book_language(path: [*:0]const u8, out: [*]u8, cap: c_int) c_int;
extern fn zrd_define(word: [*]const u8, len: c_int, lemma: [*]u8, lemma_cap: c_int, out: [*]u8, cap: c_int) c_int;
extern fn zr_open(path: [*:0]const u8, lw: f32, lh: f32, font: f32, margin: f32) ?*ZrDoc;
extern fn zr_open_style(path: [*:0]const u8, lw: f32, lh: f32, font: f32, margin: f32, spacing: f32) ?*ZrDoc;
extern fn zr_open_worker(path: [*:0]const u8, lw: f32, lh: f32, font: f32, margin: f32, spacing: f32, progress: *const fn (c_int) callconv(.c) c_int) ?*ZrDoc;
extern fn zr_open_initial(path: [*:0]const u8, lw: f32, lh: f32, font: f32, margin: f32, spacing: f32) ?*ZrDoc;
extern fn zr_open_upto(path: [*:0]const u8, lw: f32, lh: f32, font: f32, margin: f32, spacing: f32, chapter: c_int) ?*ZrDoc;
extern fn zr_pagination_pending(z: *ZrDoc) c_int;
extern fn zr_page_count_hint(z: *ZrDoc, pages: c_int) void;
extern fn zr_layout_cache(data: [*:0]const u8) void;
extern fn zr_no_core() void;
extern fn zr_battery() c_int;
extern fn zr_set_text_resources(la: [*]const u8, la_len: c_int, r: [*]const u8, rl: c_int, b: [*]const u8, bl: c_int, i: [*]const u8, il: c_int, bi: [*]const u8, bil: c_int) void;
extern fn zr_set_text_style(mode: c_int, font: c_int) void;
extern fn zr_touch_layout(z: ?*ZrDoc) void;
extern fn zr_contents_start(path: [*:0]const u8, out: [*:0]const u8, reflow: c_int, lw: f32, lh: f32, font: f32, margin: f32, spacing: f32) c_int;
extern fn zr_contents_poll(done: *c_int, total: *c_int, found: *c_int, ms: *c_int) c_int;
extern fn zr_contents_stop() void;
extern fn zr_set_ui_wake(fd: c_int) void;
extern fn zr_file_mtime(path: [*:0]const u8) i64;
extern fn zr_up_start(books: [*:0]const u8, port: c_int, max: u64, free_floor: u64, device: c_int) c_int;
extern fn zr_up_stop() void;
extern fn zr_up_revision() c_uint;
extern fn zr_up_saved() c_uint;
extern fn zr_up_status(out: [*]u8, cap: c_int) void;
extern fn zr_up_set_export(dir: [*:0]const u8) void;
extern fn zr_up_address(out: [*]u8, cap: c_int) c_int;
extern fn zr_pc_init(data: [*:0]const u8, cap: u64) c_int;
extern fn zr_pc_submit(name: [*:0]const u8, key: u64, fb: [*]const u8, w: c_int, h: c_int, stride: c_int) c_int;
extern fn zr_pc_flush() void;
extern fn zr_pc_stop() void;
extern fn zr_pc_load(name: [*:0]const u8, key: u64, out: [*]u8, w: c_int, h: c_int, stride: c_int) c_int;
extern fn zr_pc_drop(name: [*:0]const u8) void;
extern fn zr_file_size(path: [*:0]const u8) u64;
extern fn zr_storage(path: [*:0]const u8, free: *u64, total: *u64) c_int;
extern fn zr_thumbs_focus() void;
extern fn zr_thumbs_revalidate() void;
extern fn zr_thumb_peek(path: [*:0]const u8) c_int;
extern fn zr_cancel(z: *ZrDoc) void;
extern fn zr_reset_cancel(z: *ZrDoc) void;
extern fn zr_close(z: *ZrDoc) void;
extern fn zr_page_count(z: *ZrDoc) c_int;
extern fn zr_is_pdf(z: *ZrDoc) c_int;
extern fn zr_shrink_pdf(in: [*:0]const u8, out: [*:0]const u8, quality: c_int) c_int;
extern fn zr_shrink_cancel() void;
extern fn zr_shrink_progress(done: *c_int, total: *c_int) c_int;
extern fn zr_shrink_start(in: [*:0]const u8, out: [*:0]const u8) c_int;
extern fn zr_shrink_result() c_int;
extern fn zr_free_bytes(dir: [*:0]const u8) c_longlong;
extern fn zr_fsize(p: [*:0]const u8) c_longlong;
extern fn zr_move_file(src: [*:0]const u8, dst: [*:0]const u8, final: [*]u8, cap: c_int) c_int;
extern fn zr_dir_size(dir: [*:0]const u8) c_longlong;
extern fn zr_rm_tree(dir: [*:0]const u8) c_int;
extern fn zr_drm_check(path: [*:0]const u8) c_int;
extern fn zr_reflowable(z: *ZrDoc) c_int;
const Anchor = extern struct { chapter: c_int = -1, start: u32 = 0, end: u32 = 0, hash: u64 = 0 };
extern fn zr_set_spacing(z: *ZrDoc, spacing: f32) void;
extern fn zr_anchor_words(z: *ZrDoc, page: c_int, first: c_int, last: c_int, out: *Anchor) c_int;
extern fn zr_anchor_page(z: *ZrDoc, anchor: *const Anchor) c_int;
extern fn zr_anchor_quads(z: *ZrDoc, anchor: *const Anchor, page: c_int, quads: [*][4]f32, max: c_int) c_int;
extern fn zr_anchor_migrate(z: *ZrDoc, page: c_int, quote: [*]const u8, len: c_int, x: f32, y: f32, out: *Anchor) c_int;
extern fn zr_relayout(z: *ZrDoc, lw: f32, lh: f32, font: f32, margin: f32, page: c_int) c_int;
extern fn zr_page_bounds(z: *ZrDoc, page: c_int, r: *[4]f32) c_int;
extern fn zr_ink_bbox(z: *ZrDoc, page: c_int, r: *[4]f32, no_images: c_int) c_int;
extern fn zr_ink_bbox_flags(z: *ZrDoc, page: c_int, r: *[4]f32, no_images: c_int, flags: c_int) c_int;
extern fn zr_render(z: *ZrDoc, page: c_int, m: *const [6]f32, out: [*]u8, w: c_int, h: c_int, stride: c_int, no_images: c_int) c_int;
const ZrRenderStats = extern struct { image_coverage: f32 = 0, image_count: c_int = 0, cleaned: c_int = 0, drafted: c_int = 0 };
extern fn zr_draft_wanted(z: *ZrDoc, page: c_int, flags: c_int, w: c_int, h: c_int) c_int;
extern fn zr_render_with_stats(z: *ZrDoc, page: c_int, m: *const [6]f32, out: [*]u8, w: c_int, h: c_int, stride: c_int, no_images: c_int, image_dither: c_int, stats: *ZrRenderStats) c_int;

extern fn zr_words(z: *ZrDoc, page: c_int, out: [*]ZrWord, max: c_int, text: [*]u8, cap: c_int) c_int;
extern fn zr_outline(z: *ZrDoc, out: [*]ZrToc, max: c_int, text: [*]u8, cap: c_int) c_int;
extern fn zr_ui_new(sans: [*]const u8, len: c_int) ?*ZrUi;
extern fn zr_ui_measure(u: *ZrUi, font: c_int, size: f32, s: [*]const u8, len: c_int) f32;
extern fn zr_ui_text(u: *ZrUi, font: c_int, size: f32, buf: [*]u8, w: c_int, h: c_int, stride: c_int, x: f32, base: f32, s: [*]const u8, len: c_int, gray: c_int) void;

const PMutex = extern struct { b: [40]u8 align(8) = @splat(0) };
const PCond = extern struct { b: [64]u8 align(8) = @splat(0) };
extern fn pthread_mutex_lock(m: *PMutex) c_int;
extern fn pthread_mutex_unlock(m: *PMutex) c_int;
extern fn pthread_cond_wait(c: *PCond, m: *PMutex) c_int;
extern fn pthread_cond_broadcast(c: *PCond) c_int;
extern fn pthread_create(t: *c_ulong, attr: ?*anyopaque, f: *const fn (?*anyopaque) callconv(.c) ?*anyopaque, arg: ?*anyopaque) c_int;
const PAttr = extern struct { b: [64]u8 align(8) = @splat(0) };
extern fn pthread_attr_init(a: *PAttr) c_int;
extern fn pthread_attr_setstacksize(a: *PAttr, size: usize) c_int;
// MuPDF's HTML layout recurses deeply; musl's default thread stack (128 KiB) is too small.
fn spawn(t: *c_ulong, f: *const fn (?*anyopaque) callconv(.c) ?*anyopaque) c_int {
    var attr: PAttr = .{};
    _ = pthread_attr_init(&attr);
    _ = pthread_attr_setstacksize(&attr, 8 << 20);
    return pthread_create(t, &attr, f, null);
}
extern fn pthread_join(t: c_ulong, ret: ?*?*anyopaque) c_int;
extern fn signal(sig: c_int, handler: *const fn (c_int) callconv(.c) void) ?*anyopaque;
extern fn zr_now_seconds() i64;
const Tm = extern struct { sec: c_int, min: c_int, hour: c_int, mday: c_int, mon: c_int, year: c_int, wday: c_int, yday: c_int, isdst: c_int, gmtoff: c_long, zone: ?[*:0]const u8 };
extern fn zr_localtime64(t: *const i64, tm: *Tm) ?*Tm;

// v0.7 backends: all filesystem thumbnail work and firmware CLIs run off UI thread.
extern fn zr_thumbs_init(data: [*:0]const u8) void;
extern fn zr_thumb(path: [*:0]const u8, pixels: [*]u8) c_int;
extern fn zr_thumb_revision() u32;
extern fn zr_watch_events() c_int;
extern fn zr_make_thumb(path: [*:0]const u8, dest: [*:0]const u8) c_int;
extern fn zr_device_init(simulation: c_int) void;
extern fn zr_device_light(which: c_int, value: c_int) void;
extern fn zr_device_poll(light: *c_int, warm: *c_int) c_int;
extern fn zr_device_sleep(action: c_int) void;
extern fn zr_device_stop() void;

// ---------------- framebuffer / hwtcon (FBInk eink/mtk-kindle.h) ----------------
const FbBitfield = extern struct { offset: u32, length: u32, msb_right: u32 };
const FbVar = extern struct {
    xres: u32,
    yres: u32,
    xres_virtual: u32,
    yres_virtual: u32,
    xoffset: u32,
    yoffset: u32,
    bits_per_pixel: u32,
    grayscale: u32,
    red: FbBitfield,
    green: FbBitfield,
    blue: FbBitfield,
    transp: FbBitfield,
    nonstd: u32,
    activate: u32,
    height: u32,
    width: u32,
    accel_flags: u32,
    pixclock: u32,
    left_margin: u32,
    right_margin: u32,
    upper_margin: u32,
    lower_margin: u32,
    hsync_len: u32,
    vsync_len: u32,
    sync: u32,
    vmode: u32,
    rotate: u32,
    colorspace: u32,
    reserved: [4]u32,
};
const FbFix = extern struct {
    id: [16]u8,
    smem_start: c_ulong,
    smem_len: u32,
    type: u32,
    type_aux: u32,
    visual: u32,
    xpanstep: u16,
    ypanstep: u16,
    ywrapstep: u16,
    line_length: u32,
    mmio_start: c_ulong,
    mmio_len: u32,
    accel: u32,
    capabilities: u16,
    reserved: [2]u16,
};
const MxRect = extern struct { top: u32, left: u32, width: u32, height: u32 };
const AltBuffer = extern struct { phys_addr: u32, width: u32, height: u32, alt_update_region: MxRect };
const Swipe = extern struct { direction: u32, steps: u32 };
const UpdateDataMtk = extern struct {
    update_region: MxRect,
    waveform_mode: u32,
    update_mode: u32,
    update_marker: u32,
    temp: i32,
    flags: u32,
    dither_mode: i32,
    quant_bit: i32,
    alt_buffer_data: AltBuffer,
    swipe_data: Swipe,
    hist_bw_waveform_mode: u32,
    hist_gray_waveform_mode: u32,
    ts_pxp: u32,
    ts_epdc: u32,
};
const MarkerData = extern struct { update_marker: u32, collision_test: u32 };
comptime {
    std.debug.assert(@sizeOf(UpdateDataMtk) == 96);
}
fn ioc(dir: u32, typ: u8, nr: u32, size: u32) u32 {
    return (dir << 30) | (size << 16) | (@as(u32, typ) << 8) | nr;
}
const FBIOGET_VSCREENINFO: u32 = 0x4600;
const FBIOGET_FSCREENINFO: u32 = 0x4602;
const MXCFB_SEND_UPDATE_MTK = ioc(1, 'F', 0x2E, @sizeOf(UpdateDataMtk));
const MXCFB_WAIT_FOR_UPDATE_COMPLETE = ioc(3, 'F', 0x2F, @sizeOf(MarkerData));
const MXCFB_SET_UPDATE_FLAGS_MTK = ioc(1, 'F', 0x3B, 4);
const UPDATE_FLAGS_FAST_MODE: u32 = 0x80 << 24;
const UPDATE_MODE_PARTIAL: u32 = 0;
const UPDATE_MODE_FULL: u32 = 1;
const WF_DU: u32 = 1;
const WF_GC16: u32 = 2;
const WF_GL16: u32 = 3;
const WF_REAGL: u32 = 4;

// ---------------- evdev ----------------
const InputEvent = extern struct { sec: u32, usec: u32, type: u16, code: u16, value: i32 };
const AbsInfo = extern struct { value: i32, minimum: i32, maximum: i32, fuzz: i32, flat: i32, resolution: i32 };
const EV_SYN = 0;
const EV_KEY = 1;
const EV_ABS = 3;
const EV_SIM_SHOT = 0x7F;
const SYN_REPORT = 0;
const BTN_TOUCH = 0x14a;
const KEY_POWER = 116;
const ABS_MT_POSITION_X = 0x35;
const ABS_MT_POSITION_Y = 0x36;
const ABS_MT_TRACKING_ID = 0x39;
const ABS_MT_SLOT = 0x2f;
fn EVIOCGBIT(ev: u32, len: u32) u32 {
    return ioc(2, 'E', 0x20 + ev, len);
}
fn EVIOCGABS(abs: u32) u32 {
    return ioc(2, 'E', 0x40 + abs, @sizeOf(AbsInfo));
}
const EVIOCGRAB = ioc(1, 'E', 0x90, 4);
const EVIOCSCLOCKID = ioc(1, 'E', 0xa0, 4);

// ---------------- small utils ----------------
fn bad(rc: usize) bool {
    return linux.errno(rc) != .SUCCESS;
}
fn nowUs() u64 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1_000_000 + @as(u64, @intCast(ts.nsec)) / 1000;
}
fn sleepMs(ms: u64) void {
    const ts = linux.timespec{ .sec = @intCast(ms / 1000), .nsec = @intCast((ms % 1000) * 1_000_000) };
    _ = linux.nanosleep(&ts, null);
}
fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

var log_fd: i32 = 2;
fn logf(comptime fmt: []const u8, args: anytype) void {
    var b: [2048]u8 = undefined;
    const s = std.fmt.bufPrint(&b, fmt ++ "\n", args) catch return;
    _ = linux.write(log_fd, s.ptr, s.len);
}

fn readFile(path: [*:0]const u8) ?[]u8 {
    const rc = linux.open(path, .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    if (bad(rc)) return null;
    const fd: i32 = @intCast(rc);
    defer _ = linux.close(fd);
    var cap: usize = 16384;
    var buf = alloc.alloc(u8, cap) catch return null;
    var n: usize = 0;
    while (true) {
        if (n == cap) {
            cap *= 2;
            buf = alloc.realloc(buf, cap) catch return null;
        }
        const r = linux.read(fd, buf.ptr + n, cap - n);
        if (bad(r) or r == 0) break;
        n += r;
    }
    return buf[0..n];
}

fn writeFileAtomic(path: []const u8, data: []const u8) bool {
    var tmp: [1100]u8 = undefined;
    var fin: [1100]u8 = undefined;
    const t = std.fmt.bufPrintSentinel(&tmp, "{s}.tmp", .{path}, 0) catch return false;
    const f = std.fmt.bufPrintSentinel(&fin, "{s}", .{path}, 0) catch return false;
    const rc = linux.open(t, .{ .ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true, .NOFOLLOW = true, .CLOEXEC = true }, 0o644);
    if (bad(rc)) return false;
    const fd: i32 = @intCast(rc);
    var off: usize = 0;
    while (off < data.len) {
        const w = linux.write(fd, data.ptr + off, data.len - off);
        if (bad(w) or w == 0) break;
        off += w;
    }
    _ = linux.fsync(fd);
    _ = linux.close(fd);
    if (off != data.len) return false;
    return !bad(linux.rename(t, f));
}

fn appendFile(path: []const u8, data: []const u8) void {
    var p: [1100]u8 = undefined;
    const z = std.fmt.bufPrintSentinel(&p, "{s}", .{path}, 0) catch return;
    const rc = linux.open(z, .{ .ACCMODE = .WRONLY, .CREAT = true, .APPEND = true, .CLOEXEC = true }, 0o644);
    if (bad(rc)) return;
    const fd: i32 = @intCast(rc);
    _ = linux.write(fd, data.ptr, data.len);
    _ = linux.close(fd);
}

fn mkdirP(path: []const u8) void {
    var b: [1100]u8 = undefined;
    if (path.len >= b.len) return;
    var i: usize = 1;
    while (i <= path.len) : (i += 1) {
        if (i == path.len or path[i] == '/') {
            @memcpy(b[0..i], path[0..i]);
            b[i] = 0;
            _ = linux.mkdir(@ptrCast(&b), 0o755);
        }
    }
}

// Growable byte buffer for building files.
const Buf = struct {
    b: []u8,
    n: usize = 0,
    fn init(cap: usize) Buf {
        return .{ .b = alloc.alloc(u8, cap) catch &.{} };
    }
    fn deinit(self: *Buf) void {
        if (self.b.len > 0) alloc.free(self.b);
    }
    fn put(self: *Buf, s: []const u8) void {
        if (self.n + s.len > self.b.len) {
            const nc = @max(self.b.len * 2, self.n + s.len + 1024);
            self.b = alloc.realloc(self.b, nc) catch return;
        }
        @memcpy(self.b[self.n..][0..s.len], s);
        self.n += s.len;
    }
    fn print(self: *Buf, comptime fmt: []const u8, args: anytype) void {
        var t: [512]u8 = undefined;
        self.put(std.fmt.bufPrint(&t, fmt, args) catch return);
    }
    fn esc(self: *Buf, s: []const u8) void {
        for (s) |c| {
            switch (c) {
                '"' => self.put("\\\""),
                '\\' => self.put("\\\\"),
                '\n' => self.put("\\n"),
                '\r' => self.put("\\r"),
                '\t' => self.put("\\t"),
                else => if (c < 0x20) self.print("\\u{x:0>4}", .{c}) else self.put(&[_]u8{c}),
            }
        }
    }
    fn slice(self: *Buf) []const u8 {
        return self.b[0..self.n];
    }
};

// Minimal readers for the JSON files this program writes.
fn jsonKey(obj: []const u8, key: []const u8) ?usize {
    var pat: [64]u8 = undefined;
    const p = std.fmt.bufPrint(&pat, "\"{s}\":", .{key}) catch return null;
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, obj, from, p)) |i| {
        if (i == 0 or obj[i - 1] != '\\') return i + p.len;
        from = i + 1;
    }
    return null;
}
fn jsonNum(obj: []const u8, key: []const u8) ?f64 {
    var i = jsonKey(obj, key) orelse return null;
    while (i < obj.len and obj[i] == ' ') i += 1;
    var j = i;
    while (j < obj.len and (std.ascii.isDigit(obj[j]) or obj[j] == '-' or obj[j] == '.' or obj[j] == 'e' or obj[j] == '+')) j += 1;
    return std.fmt.parseFloat(f64, obj[i..j]) catch null;
}
// Decodes a JSON string value into out; returns the decoded slice.
fn jsonStr(obj: []const u8, key: []const u8, out: []u8) ?[]u8 {
    var i = jsonKey(obj, key) orelse return null;
    while (i < obj.len and std.ascii.isWhitespace(obj[i])) i += 1;
    if (i >= obj.len or obj[i] != '"') return null;
    i += 1;
    var n: usize = 0;
    while (i < obj.len and obj[i] != '"') : (i += 1) {
        var c = obj[i];
        if (c == '\\' and i + 1 < obj.len) {
            i += 1;
            if (obj[i] == 'u') {
                if (i + 4 >= obj.len) return null;
                var cp: u21 = std.fmt.parseInt(u21, obj[i + 1 .. i + 5], 16) catch return null;
                i += 4;
                if (cp >= 0xd800 and cp <= 0xdbff) {
                    if (i + 6 >= obj.len or obj[i + 1] != '\\' or obj[i + 2] != 'u') return null;
                    const low = std.fmt.parseInt(u21, obj[i + 3 .. i + 7], 16) catch return null;
                    if (low < 0xdc00 or low > 0xdfff) return null;
                    cp = 0x10000 + (cp - 0xd800) * 1024 + low - 0xdc00;
                    i += 6;
                }
                var encoded: [4]u8 = undefined;
                const len = std.unicode.utf8Encode(cp, &encoded) catch return null;
                if (n + len > out.len) return null;
                @memcpy(out[n..][0..len], encoded[0..len]);
                n += len;
                continue;
            }
            c = switch (obj[i]) {
                'n' => '\n',
                't' => '\t',
                'r' => '\r',
                'b' => 8,
                'f' => 12,
                '"', '\\', '/' => obj[i],
                else => return null,
            };
        }
        if (n >= out.len) return null;
        out[n] = c;
        n += 1;
    }
    if (i >= obj.len or !std.unicode.utf8ValidateSlice(out[0..n])) return null;
    return out[0..n];
}
// Iterates top-level {...} objects in a JSON array text.
const ObjIter = struct {
    s: []const u8,
    i: usize = 0,
    fn next(self: *ObjIter) ?[]const u8 {
        while (self.i < self.s.len and self.s[self.i] != '{') self.i += 1;
        if (self.i >= self.s.len) return null;
        const start = self.i;
        var depth: usize = 0;
        var in_str = false;
        while (self.i < self.s.len) : (self.i += 1) {
            const c = self.s[self.i];
            if (in_str) {
                if (c == '\\') self.i += 1 else if (c == '"') in_str = false;
            } else if (c == '"') in_str = true else if (c == '{') depth += 1 else if (c == '}') {
                depth -= 1;
                if (depth == 0) {
                    self.i += 1;
                    return self.s[start..self.i];
                }
            }
        }
        return null;
    }
};

// bit0: 16-level ordered dithering of images; bit1: v0.9.2 scanned-page cleanup
fn imageFlags() c_int {
    return @as(c_int, @intFromBool(opts.image_dither)) | (@as(c_int, @intFromBool(opts.clean_scans)) << 1);
}
fn fnv(s: []const u8) u64 {
    var h: u64 = 0xcbf29ce484222325;
    for (s) |c| {
        h ^= c;
        h *%= 0x100000001b3;
    }
    return h;
}

fn fmtDate(t: i64, out: []u8) []const u8 {
    var tm: Tm = undefined;
    if (zr_localtime64(&t, &tm) == null) return "";
    return std.fmt.bufPrint(out, "{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}", .{
        @as(u32, @intCast(tm.year + 1900)), @as(u32, @intCast(tm.mon + 1)), @as(u32, @intCast(tm.mday)), @as(u32, @intCast(tm.hour)), @as(u32, @intCast(tm.min)),
    }) catch "";
}

// ---------------- stats ----------------
const Stats = struct {
    v: [8192]u32 = undefined,
    n: usize = 0,
    fn add(self: *Stats, x: u64) void {
        if (self.n < self.v.len) {
            self.v[self.n] = @intCast(@min(x, std.math.maxInt(u32)));
            self.n += 1;
        }
    }
    fn p50(self: *Stats) u32 {
        if (self.n == 0) return 0;
        var tmp: [8192]u32 = undefined;
        @memcpy(tmp[0..self.n], self.v[0..self.n]);
        std.mem.sort(u32, tmp[0..self.n], {}, std.sort.asc(u32));
        return tmp[self.n / 2];
    }
    fn report(self: *Stats, name: []const u8) void {
        if (self.n == 0) {
            logf("{s:<22} n=0", .{name});
            return;
        }
        const s = self.v[0..self.n];
        std.mem.sort(u32, s, {}, std.sort.asc(u32));
        var sum: u64 = 0;
        for (s) |x| sum += x;
        logf("{s:<22} n={d:<4} min={d:>7} p50={d:>7} avg={d:>7} p90={d:>7} max={d:>7} us", .{
            name, self.n, s[0], s[self.n / 2], sum / self.n, s[(self.n * 9) / 10], s[self.n - 1],
        });
    }
};

// ---------------- configuration ----------------
const Opts = struct {
    book: ?[*:0]const u8 = null,
    wf: u32 = WF_REAGL,
    full_refresh: u8 = 0,
    refresh_cli: bool = false,
    image_dither: bool = true,
    audit_refresh: bool = false,
    no_images: bool = false,
    debug: bool = false,
    data: []const u8 = "/mnt/us/zreader",
    books: []const u8 = "/mnt/us/Books",
    dictionary: ?[*:0]const u8 = null,
    latin_dictionary: ?[*:0]const u8 = null,
    log: ?[*:0]const u8 = null,
    idle_min: u64 = 10,
    page_cache_mib: u64 = 20,
    clean_scans: bool = true,
    clean_cli: bool = false,
    upload_port: u16 = 8080,
    stats_idle_sec: u32 = 150,
    sim_battery: c_int = 76,
    text_mode: ?c_int = null,
    legacy_poll: bool = false,
    upload_min_free_mib: u64 = 6144,
    upload_max_mib: u64 = 500,
    sim: ?[*:0]const u8 = null,
    shots: []const u8 = "shots",
    fast: bool = true,
    governor: bool = true,
};
var opts: Opts = .{};

// ---------------- display ----------------
var W: u32 = 1272;
var H: u32 = 1696;
var STRIDE: u32 = 1272;
var fb: []u8 = &.{};
var fb_fd: i32 = -1;
var marker: u32 = 1;
var LW: f32 = 0;
var LH: f32 = 0;

const Rect = struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = 0,
    h: i32 = 0,
    fn full() Rect {
        return .{ .x = 0, .y = 0, .w = @intCast(W), .h = @intCast(H) };
    }
    fn empty(self: Rect) bool {
        return self.w <= 0 or self.h <= 0;
    }
    fn contains(self: Rect, px: i32, py: i32) bool {
        return px >= self.x and py >= self.y and px < self.x + self.w and py < self.y + self.h;
    }
    fn unite(a: Rect, b: Rect) Rect {
        if (a.empty()) return b;
        if (b.empty()) return a;
        const x0 = @min(a.x, b.x);
        const y0 = @min(a.y, b.y);
        const x1 = @max(a.x + a.w, b.x + b.w);
        const y1 = @max(a.y + a.h, b.y + b.h);
        return .{ .x = x0, .y = y0, .w = x1 - x0, .h = y1 - y0 };
    }
    fn clip(self: Rect) Rect {
        const x0 = std.math.clamp(self.x, 0, @as(i32, @intCast(W)));
        const y0 = std.math.clamp(self.y, 0, @as(i32, @intCast(H)));
        const x1 = std.math.clamp(self.x + self.w, 0, @as(i32, @intCast(W)));
        const y1 = std.math.clamp(self.y + self.h, 0, @as(i32, @intCast(H)));
        return .{ .x = x0, .y = y0, .w = x1 - x0, .h = y1 - y0 };
    }
    fn grow(self: Rect, d: i32) Rect {
        return .{ .x = self.x - d, .y = self.y - d, .w = self.w + 2 * d, .h = self.h + 2 * d };
    }
};

// GC16 must use FULL, including both histogram fallbacks. Never enable the
// per-update inversion flag: the inherited framebuffer grayscale state wins.
fn makeUpdate(r0: Rect, mode: u32, upd: u32) UpdateDataMtk {
    const r = r0.clip();
    var u = std.mem.zeroes(UpdateDataMtk);
    u.update_region = .{ .top = @intCast(r.y), .left = @intCast(r.x), .width = @intCast(r.w), .height = @intCast(r.h) };
    u.waveform_mode = mode;
    u.update_mode = if (mode == WF_GC16) UPDATE_MODE_FULL else upd;
    u.temp = 0x1000;
    u.hist_bw_waveform_mode = if (mode == WF_REAGL) WF_REAGL else if (mode == WF_GC16) WF_GC16 else WF_DU;
    u.hist_gray_waveform_mode = if (mode == WF_REAGL) WF_REAGL else WF_GC16;
    return u;
}
// ---- v0.9.4 launch profile: zreader-run.sh passes /proc/uptime readings
// (same clock as CLOCK_MONOTONIC while awake) so one log line shows where
// launch time goes, from the script start to the first screen update.
var lp_main: u64 = 0;
var lp_fb: u64 = 0;
var lp_fonts: u64 = 0;
var lp_setup: u64 = 0;
var lp_library: u64 = 0;
var lp_done = false;
fn envUptimeUs(name: [*:0]const u8) u64 {
    const v = std.c.getenv(name) orelse return 0;
    const f = std.fmt.parseFloat(f64, std.mem.span(v)) catch return 0;
    return if (f > 0) @intFromFloat(f * 1e6) else 0;
}
fn msBetween(a: u64, b: u64) f64 {
    return if (a == 0 or b < a) -1 else @as(f64, @floatFromInt(b - a)) / 1000.0;
}
fn logLaunchProfile() void {
    if (lp_done) return;
    lp_done = true;
    const now = nowUs();
    const t0 = envUptimeUs("ZR_LAUNCH_T0");
    const t1 = envUptimeUs("ZR_LAUNCH_EXEC");
    logf("launch profile: script_start..exec={d:.0}ms exec..main={d:.0}ms main..fb={d:.0}ms fb..fonts={d:.0}ms fonts..setup={d:.0}ms setup..library={d:.0}ms library..first_frame={d:.0}ms main..first_frame={d:.0}ms script_start..first_frame={d:.0}ms", .{
        msBetween(t0, t1), msBetween(t1, lp_main), msBetween(lp_main, lp_fb), msBetween(lp_fb, lp_fonts), msBetween(lp_fonts, lp_setup), msBetween(lp_setup, lp_library), msBetween(lp_library, now), msBetween(lp_main, now), msBetween(t0, now),
    });
}
fn sendUpdate(r0: Rect, mode: u32, upd: u32) u32 {
    if (!lp_done and lp_library != 0) logLaunchProfile();
    marker +%= 1;
    if (marker == 0) marker = 1;
    if (opts.sim != null or opts.debug) logf("refresh submit: wf={d} full={} {d}x{d}", .{ mode, mode == WF_GC16 or upd == UPDATE_MODE_FULL, r0.w, r0.h });
    if (fb_fd < 0) return marker;
    const r = r0.clip();
    if (r.empty()) return marker;
    var u = makeUpdate(r, mode, upd);
    u.update_marker = marker;
    if (bad(linux.ioctl(fb_fd, MXCFB_SEND_UPDATE_MTK, @intFromPtr(&u)))) logf("SEND_UPDATE_MTK failed for {d}x{d}+{d}+{d}", .{ r.w, r.h, r.x, r.y });
    return marker;
}

// Completion waiter: turns the blocking wait ioctl into a pipe wakeup.
const Waiter = struct {
    mtx: PMutex = .{},
    cond: PCond = .{},
    marker: u32 = 0,
    pending: bool = false,
    quit: bool = false,
    pipe_w: i32 = -1,
};
var waiter: Waiter = .{};
fn waiterThread(_: ?*anyopaque) callconv(.c) ?*anyopaque {
    _ = pthread_mutex_lock(&waiter.mtx);
    while (true) {
        while (!waiter.pending and !waiter.quit) _ = pthread_cond_wait(&waiter.cond, &waiter.mtx);
        if (waiter.quit) break;
        const m = waiter.marker;
        waiter.pending = false;
        _ = pthread_mutex_unlock(&waiter.mtx);
        if (fb_fd >= 0) {
            var md = MarkerData{ .update_marker = m, .collision_test = 0 };
            _ = linux.ioctl(fb_fd, MXCFB_WAIT_FOR_UPDATE_COMPLETE, @intFromPtr(&md));
        }
        _ = linux.write(waiter.pipe_w, "d", 1);
        _ = pthread_mutex_lock(&waiter.mtx);
    }
    _ = pthread_mutex_unlock(&waiter.mtx);
    return null;
}
fn waitAsync(m: u32) void {
    _ = pthread_mutex_lock(&waiter.mtx);
    waiter.marker = m;
    waiter.pending = true;
    _ = pthread_cond_broadcast(&waiter.cond);
    _ = pthread_mutex_unlock(&waiter.mtx);
}

// ---------------- drawing ----------------
var ui: *ZrUi = undefined;
const SANS: c_int = 0;
const SERIF: c_int = 1;
const SERIF_BOLD: c_int = 2;

fn fill(r0: Rect, g: u8) void {
    const r = r0.clip();
    if (r.empty()) return;
    var y: i32 = r.y;
    while (y < r.y + r.h) : (y += 1) {
        const off = @as(usize, @intCast(y)) * STRIDE + @as(usize, @intCast(r.x));
        @memset(fb[off .. off + @as(usize, @intCast(r.w))], g);
    }
}
fn frame(r: Rect, t: i32, g: u8) void {
    fill(.{ .x = r.x, .y = r.y, .w = r.w, .h = t }, g);
    fill(.{ .x = r.x, .y = r.y + r.h - t, .w = r.w, .h = t }, g);
    fill(.{ .x = r.x, .y = r.y, .w = t, .h = r.h }, g);
    fill(.{ .x = r.x + r.w - t, .y = r.y, .w = t, .h = r.h }, g);
}
// Multiplies pixels by k/255 (keeps black text black, tints paper).
fn tint(r0: Rect, k: u32) void {
    const r = r0.clip();
    if (r.empty()) return;
    var y: i32 = r.y;
    while (y < r.y + r.h) : (y += 1) {
        const off = @as(usize, @intCast(y)) * STRIDE + @as(usize, @intCast(r.x));
        for (fb[off .. off + @as(usize, @intCast(r.w))]) |*p| p.* = @intCast((@as(u32, p.*) * k) / 255);
    }
}
fn capLight(r0: Rect, k: u8) void {
    const r = r0.clip();
    if (r.empty()) return;
    var y: i32 = r.y;
    while (y < r.y + r.h) : (y += 1) {
        const off = @as(usize, @intCast(y)) * STRIDE + @as(usize, @intCast(r.x));
        for (fb[off .. off + @as(usize, @intCast(r.w))]) |*p| p.* = @min(p.*, k);
    }
}
// v0.10.6: the page on screen is a PDF page drawn mostly from images (scans).
fn shownImagePage() bool {
    if (!book.is_pdf or pool.shown < 0) return false;
    return pool.slots[@intCast(pool.shown)].metrics.image >= 0.5;
}
fn textW(font: c_int, size: f32, s: []const u8) f32 {
    if (s.len == 0) return 0;
    return zr_ui_measure(ui, font, size, s.ptr, @intCast(s.len));
}
fn text(font: c_int, size: f32, x: f32, base: f32, s: []const u8, gray: u8) void {
    if (s.len == 0) return;
    zr_ui_text(ui, font, size, fb.ptr, @intCast(W), @intCast(H), @intCast(STRIDE), x, base, s.ptr, @intCast(s.len), gray);
}
// Draws s, shortened with an ellipsis to fit max_w.
fn textFit(font: c_int, size: f32, x: f32, base: f32, s: []const u8, max_w: f32, gray: u8) void {
    if (textW(font, size, s) <= max_w) return text(font, size, x, base, s, gray);
    var b: [512]u8 = undefined;
    var n: usize = @min(s.len, 480);
    while (n > 0) {
        n -= 1;
        while (n > 0 and (s[n] & 0xC0) == 0x80) n -= 1;
        @memcpy(b[0..n], s[0..n]);
        @memcpy(b[n..][0..3], "\xe2\x80\xa6");
        if (textW(font, size, b[0 .. n + 3]) <= max_w) break;
    }
    text(font, size, x, base, b[0 .. n + 3], gray);
}
fn textCenter(font: c_int, size: f32, r: Rect, s: []const u8, gray: u8) void {
    const w = textW(font, size, s);
    const x = @as(f32, @floatFromInt(r.x)) + (@as(f32, @floatFromInt(r.w)) - w) / 2;
    const base = @as(f32, @floatFromInt(r.y)) + @as(f32, @floatFromInt(r.h)) / 2 + size * 0.36;
    text(font, size, x, base, s, gray);
}
fn smallButton(r: Rect, label: []const u8) void {
    fill(r, 0xFF);
    frame(r, 3, 0x00);
    const size: f32 = if (textW(SANS, 30, label) > @as(f32, @floatFromInt(r.w - 20))) 26 else 30;
    textCenter(SANS, size, r, label, 0x00);
}
fn button(r: Rect, label: []const u8, active: bool) void {
    fill(r, if (active) 0x00 else 0xFF);
    frame(r, 3, 0x00);
    textCenter(SANS, 34, r, label, if (active) 0xFF else 0x00);
}

// ---------------- measured-content refresh policy ----------------
const SAMPLE_STEP: usize = 8;
const PageMetrics = struct { ink: f32 = 0, dark: f32 = 0, tone: f32 = 0, image: f32 = 0, photo: f32 = 0 };
const Transition = struct { dark_to_light: f32 = 0, light_to_dark: f32 = 0 };
const CleanReason = enum { text, opening, context, cover, image, dark, transition, periodic };
const RefreshChoice = struct { mode: u32, reason: CleanReason };
var previous_samples: []u8 = &.{};
var previous_metrics: PageMetrics = .{};
var previous_page: i32 = -1;
var text_since_clean: u32 = 0;
fn pageMetrics(pixels: []const u8, w: usize, h: usize, stride: usize, image: f32) PageMetrics {
    var sum: u64 = 0;
    var hist: [256]usize = @splat(0);
    var n: usize = 0;
    var dark: usize = 0;
    var tone: usize = 0;
    var y: usize = 0;
    while (y < h) : (y += SAMPLE_STEP) {
        var x: usize = 0;
        while (x < w) : (x += SAMPLE_STEP) {
            const v = pixels[y * stride + x];
            sum += 255 - @as(u64, v);
            if (v < 248) hist[v] += 1;
            dark += @intFromBool(v < 80);
            tone += @intFromBool(v > 16 and v < 239);
            n += 1;
        }
    }
    // Infer the paper shade, excluding unpainted outside margins. A photographed
    // page of text is NOT a photograph: grey paper must not count as picture ink.
    var occupied: usize = 0;
    for (hist) |v| occupied += v;
    var paper: usize = 247;
    var cumulative: usize = 0;
    for (hist, 0..) |v, shade| {
        cumulative += v;
        if (cumulative >= occupied * 9 / 10 and occupied > 0) { paper = shade; break; }
    }
    // Broad filled tonal blocks, unlike fine text strokes and blank line gutters.
    var picture: usize = 0;
    var tiles: usize = 0;
    var ty: usize = 0;
    while (ty + 64 <= h) : (ty += 64) {
        var tx: usize = 0;
        while (tx + 64 <= w) : (tx += 64) {
            var below: usize = 0;
            var yy: usize = ty;
            while (yy < ty + 64) : (yy += 8) {
                var xx: usize = tx;
                while (xx < tx + 64) : (xx += 8) {
                    below += @intFromBool(@as(usize, pixels[yy * stride + xx]) + 40 < paper);
                }
            }
            picture += @intFromBool(below >= 32);
            tiles += 1;
        }
    }
    const photo = @as(f32, @floatFromInt(picture)) / @as(f32, @floatFromInt(@max(tiles, 1)));
    const total: f32 = @floatFromInt(@max(n, 1));
    return .{ .photo = photo, .ink = @as(f32, @floatFromInt(sum)) / (255 * total), .dark = @as(f32, @floatFromInt(dark)) / total, .tone = @as(f32, @floatFromInt(tone)) / total, .image = image };
}
fn transitionMetrics(old: []const u8, pixels: []const u8, w: usize, h: usize, stride: usize) Transition {
    var n: usize = 0;
    var dl: usize = 0;
    var ld: usize = 0;
    var y: usize = 0;
    while (y < h) : (y += SAMPLE_STEP) {
        var x: usize = 0;
        while (x < w) : (x += SAMPLE_STEP) {
            if (n >= old.len) return .{};
            const a = old[n];
            const b = pixels[y * stride + x];
            dl += @intFromBool(a < 80 and b > 192);
            ld += @intFromBool(a > 192 and b < 80);
            n += 1;
        }
    }
    const total: f32 = @floatFromInt(@max(n, 1));
    return .{ .dark_to_light = @as(f32, @floatFromInt(dl)) / total, .light_to_dark = @as(f32, @floatFromInt(ld)) / total };
}
fn saveSamples(out: []u8, pixels: []const u8, w: usize, h: usize, stride: usize) void {
    var n: usize = 0;
    var y: usize = 0;
    while (y < h) : (y += SAMPLE_STEP) {
        var x: usize = 0;
        while (x < w) : (x += SAMPLE_STEP) {
            out[n] = pixels[y * stride + x];
            n += 1;
        }
    }
}
fn imageHeavy(m: PageMetrics) bool {
    return m.image >= 0.25 and m.photo >= 0.18;
}
fn darkHeavy(m: PageMetrics) bool {
    return m.ink >= 0.25 or m.dark >= 0.30;
}
fn refreshChoice(old: PageMetrics, next: PageMetrics, delta: Transition, old_page: i32, page: i32, forced: bool, since: u32, every: u8, text_wf: u32) RefreshChoice {
    _ = delta;
    const reason: CleanReason = if (old_page < 0) .opening else if (forced) .context else if (old_page == 0 or page == 0) .cover else if (imageHeavy(old) or imageHeavy(next)) .image
        else if (every != 0 and since + 1 >= every) .periodic else .text;
    return .{ .mode = if (reason == .text) text_wf else WF_GC16, .reason = reason };
}
fn incomingChoice() RefreshChoice {
    const i = slotFor(pool.cur) orelse return .{ .mode = WF_GC16, .reason = .context };
    const slot = &pool.slots[i];
    const delta = transitionMetrics(previous_samples, slot.buf, W, H, STRIDE);
    const choice = refreshChoice(previous_metrics, slot.metrics, delta, previous_page, pool.cur, first_clean, text_since_clean, opts.full_refresh, opts.wf);
    saveSamples(previous_samples, slot.buf, W, H, STRIDE);
    previous_metrics = slot.metrics;
    previous_page = pool.cur;
    text_since_clean = if (choice.mode == WF_GC16) 0 else text_since_clean + 1;
    if (opts.debug or opts.sim != null or choice.mode == WF_GC16)
        logf("page refresh: p={d} reason={s} wf={d} ink={d:.3} dark={d:.3} image={d:.3} photo={d:.3} release={d:.3} fill={d:.3}", .{ pool.cur + 1, @tagName(choice.reason), choice.mode, slot.metrics.ink, slot.metrics.dark, slot.metrics.image, slot.metrics.photo, delta.dark_to_light, delta.light_to_dark });
    return choice;
}
fn closeOverlayRefresh(region: Rect) void {
    if (previous_page == 0 or imageHeavy(previous_metrics)) markFull(WF_GC16) else markDirty(region, WF_REAGL);
}
fn loadRefreshSetting() void {
    if (opts.refresh_cli) return;
    var b: [1200]u8 = undefined;
    const p = std.fmt.bufPrintSentinel(&b, "{s}/settings.json", .{opts.data}, 0) catch return;
    const data = readFile(p) orelse return;
    defer alloc.free(data);
    // v0.8 migrates every existing periodic setting OFF exactly once.
    // v0.9.3 resets it once more (policy 9): the menu button was easy to confuse
    // with "Clean up scanned pages" and periodic flashes break the default rule.
    if ((jsonNum(data, "refresh_policy") orelse 0) < 9) {
        opts.full_refresh = 0;
        _ = writeFileAtomic(p, "{\"full_refresh\":0,\"refresh_policy\":9}\n");
        return;
    }
    const n = jsonNum(data, "full_refresh") orelse return;
    if (n == 0 or n == 4 or n == 8 or n == 16) opts.full_refresh = @intFromFloat(n);
}
fn cycleRefreshSetting() void {
    opts.full_refresh = switch (opts.full_refresh) {
        0 => 4,
        4 => 8,
        8 => 16,
        else => 0,
    };
    var p: [1200]u8 = undefined;
    var b: [80]u8 = undefined;
    const path = std.fmt.bufPrint(&p, "{s}/settings.json", .{opts.data}) catch return;
    const data = std.fmt.bufPrint(&b, "{{\"full_refresh\":{d},\"refresh_policy\":9}}\n", .{opts.full_refresh}) catch return;
    if (!writeFileAtomic(path, data)) toast("Could not save refresh setting", .{});
    markDirty(bottomPanel(), WF_GL16);
}

// ---------------- page cache + render workers ----------------
const NSLOT = 14;
const SlotState = enum(u8) { empty, rendering, ready, failed };
const Slot = struct { draft: bool = false, step: i32 = 0, geometry: ViewGeometry = .{}, metrics: PageMetrics = .{}, page: i32 = -1, gen: u32 = 0, state: SlotState = .empty, buf: []u8 = &.{}, used: u64 = 0, m: [6]f32 = .{ 1, 0, 0, 1, 0, 0 } };
const Trim = struct { done: bool = false, r: [4]f32 = .{ 0, 0, 0, 0 } };
const Pool = struct {
    mtx: PMutex = .{},
    cond: PCond = .{},
    slots: [NSLOT]Slot = @splat(.{}),
    cur: i32 = 0,
    view: ViewMode = .page,
    base_width: bool = false,
    step: i32 = 0,
    pan_x: f32 = 0,
    pan_y: f32 = 0,
    dir: i32 = 1,
    gen: u32 = 1,
    quit: bool = false,
    suspended: bool = false,
    npages: i32 = 0,
    paginating: bool = false,
    trim: bool = false,
    split: bool = true,
    no_images: bool = false,
    trims: []Trim = &.{},
    font: f32 = 10.5,
    spacing: f32 = 1.4,
    margin: f32 = 18,
    shown: i32 = -1,
    busy: u32 = 0,
    tick: u64 = 0,
    pipe_w: i32 = -1,
    path: [*:0]const u8 = "",
    render_us: Stats = .{},
    errors: u32 = 0,
    docs: [2]?*ZrDoc = .{ null, null },
    // v0.10.5: page each worker is rendering (-1 idle) and whether it was preempted.
    job_p: [2]i32 = .{ -1, -1 },
    preempted: [2]bool = .{ false, false },
};
var pool: Pool = .{};

const ViewKey = struct { p: i32, step: i32 = 0 };
fn sameKey(a: ViewKey, b: ViewKey) bool {
    return a.p == b.p and a.step == b.step;
}
fn wantedList(out: *[10]ViewKey) usize {
    const c = pool.cur;
    const d = pool.dir;
    var seq: [10]ViewKey = undefined;
    var count: usize = 0;
    seq[count] = .{ .p = c, .step = pool.step };
    count += 1;
    if (pool.view == .width) {
        if (pool.step >= 0) {
            seq[count] = .{ .p = c, .step = pool.step + 1 };
            count += 1;
            seq[count] = .{ .p = c, .step = pool.step + 2 };
            count += 1;
            if (pool.step > 0) {
                seq[count] = .{ .p = c, .step = pool.step - 1 };
                count += 1;
            }
        }
    }
    if (splitActive() and c >= 0 and c < MAX_SPREAD_PAGES and spreads[@intCast(c)] > 0) {
        seq[count] = .{ .p = c, .step = if (pool.step == 0) 1 else 0 };
        count += 1;
    }
    const pages = [_]i32{ c + d, c + 2 * d, c + 3 * d, c + 4 * d, c - d, c - 2 * d };
    for (pages) |page| {
        if (count < seq.len) {
            seq[count] = .{ .p = page, .step = if ((pool.view == .width or splitActive()) and page < c) -1 else 0 };
            count += 1;
        }
    }
    var n: usize = 0;
    for (seq[0..count]) |key| if (key.p >= 0 and key.p < pool.npages) {
        out[n] = key;
        n += 1;
    };
    return n;
}
// v0.10.4: a first-page draft is shown only until the exact page is ready.
fn slotForKey(key: ViewKey) ?usize {
    var draft: ?usize = null;
    var rendering: ?usize = null;
    for (&pool.slots, 0..) |*slot, i| if (slot.page == key.p and slot.step == key.step and slot.gen == pool.gen and slot.state != .empty) {
        if (slot.draft) {
            draft = i;
        } else if (slot.state == .rendering) {
            rendering = i;
        } else return i;
    };
    return draft orelse rendering;
}
// True when an exact (non-draft) slot exists or is being rendered.
fn keyCovered(key: ViewKey) bool {
    for (&pool.slots) |*slot| if (slot.page == key.p and slot.step == key.step and slot.gen == pool.gen and slot.state != .empty and !slot.draft) return true;
    return false;
}
fn slotFor(p: i32) ?usize {
    return slotForKey(.{ .p = p, .step = if (p == pool.cur) pool.step else 0 });
}
const Job = struct { p: i32, step: i32, s: usize };
fn pickJob() ?Job {
    if (pool.suspended) return null;
    var want: [10]ViewKey = undefined;
    const n = wantedList(&want);
    for (want[0..n]) |key| {
        if (keyCovered(key)) continue;
        var best: ?usize = null;
        var score: u64 = std.math.maxInt(u64);
        for (&pool.slots, 0..) |*slot, i| {
            if (slot.state == .rendering or @as(i32, @intCast(i)) == pool.shown) continue;
            const stale = slot.state == .empty or slot.gen != pool.gen;
            var wanted = false;
            for (want[0..n]) |q| if (sameKey(q, .{ .p = slot.page, .step = slot.step })) {
                wanted = true;
            };
            if (!stale and wanted) continue;
            const candidate: u64 = if (stale) 0 else slot.used + 1;
            if (candidate < score) {
                score = candidate;
                best = i;
            }
        }
        if (best) |i| return .{ .p = key.p, .step = key.step, .s = i };
        return null;
    }
    return null;
}

// CPU governor boost while rendering (restored when idle and on exit).
const GOV_PATH = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor";
var gov_orig: [32]u8 = undefined;
var gov_orig_len: usize = 0;
var gov_ok = false;
var gov_boosted = false;
fn govInit() void {
    if (!opts.governor or opts.sim != null) return;
    const cur = readFile(GOV_PATH) orelse return;
    defer alloc.free(cur);
    const avail = readFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors") orelse return;
    defer alloc.free(avail);
    const t = std.mem.trim(u8, cur, " \n");
    if (t.len == 0 or t.len > gov_orig.len or std.mem.indexOf(u8, avail, "performance") == null) return;
    @memcpy(gov_orig[0..t.len], t);
    gov_orig_len = t.len;
    gov_ok = !eql(t, "performance");
    logf("cpu governor: {s} (boost {s})", .{ t, if (gov_ok) "enabled" else "not needed" });
}
fn govWrite(s: []const u8) void {
    const rc = linux.open(GOV_PATH, .{ .ACCMODE = .WRONLY, .CLOEXEC = true }, 0);
    if (bad(rc)) return;
    const fd: i32 = @intCast(rc);
    _ = linux.write(fd, s.ptr, s.len);
    _ = linux.close(fd);
}
fn govBoost(on: bool) void {
    if (!gov_ok or on == gov_boosted) return;
    gov_boosted = on;
    govWrite(if (on) "performance" else gov_orig[0..gov_orig_len]);
}

fn fitMatrix(r: [4]f32) [6]f32 {
    const rw = @max(r[2] - r[0], 1);
    const rh = @max(r[3] - r[1], 1);
    const fw: f32 = @floatFromInt(W);
    const fh: f32 = @floatFromInt(H);
    const s = @min(fw / rw, fh / rh);
    const ox = (fw - rw * s) / 2;
    const oy = (fh - rh * s) / 2;
    return .{ s, 0, 0, s, ox - r[0] * s, oy - r[1] * s };
}

const ViewMode = enum(u8) { page, width, zoom15, zoom2 };
const VIEW_NAMES = [_][]const u8{ "Fit page", "Fit width", "Zoom 1.5x", "Zoom 2x" };
const VIEW_OVERLAP: f32 = 96;
const ViewGeometry = struct { m: [6]f32 = .{ 1, 0, 0, 1, 0, 0 }, r: [4]f32 = .{ 0, 0, 1, 1 }, steps: i32 = 1, actual_step: i32 = 0, max_x: f32 = 0, max_y: f32 = 0 };
fn viewUsesTrim(pdf: bool, trim: bool, mode: ViewMode, base_width: bool) bool {
    return pdf and (trim or mode == .width or (base_width and (mode == .zoom15 or mode == .zoom2)));
}
// ---- v0.11.1: two-page scans (landscape page that is one big image) are shown as two halves ----
const MAX_SPREAD_PAGES = 20000;
var spreads: [MAX_SPREAD_PAGES]f32 = @splat(0); // 0 unknown, <0 not a spread, else split x (page units)
fn resetSpreads() void {
    @memset(&spreads, 0);
}
fn detectSpread(doc: *ZrDoc, p: i32, slot_i: usize) f32 {
    var b: [4]f32 = undefined;
    if (zr_page_bounds(doc, p, &b) != 0) return -1;
    const w = b[2] - b[0];
    const h = b[3] - b[1];
    if (h <= 1 or w / h < 1.15) return -1;
    const TW: usize = 400;
    const th: usize = @min(560, @as(usize, @intFromFloat(@max(1, @round(h * 400 / w)))));
    const sc: f32 = 400 / w;
    const m = [6]f32{ sc, 0, 0, sc, -b[0] * sc, -b[1] * sc };
    _ = slot_i;
    const buf = alloc.alloc(u8, 400 * 560) catch return -1;
    defer alloc.free(buf);
    var rs: ZrRenderStats = .{};
    if (zr_render_with_stats(doc, p, &m, buf.ptr, @intCast(TW), @intCast(th), @intCast(TW), 0, 0, &rs) != 0) return -1;
    if (rs.image_coverage < 0.85) return -1;
    return b[0] + gutterColumn(buf[0 .. TW * th], TW, th) * w / @as(f32, @floatFromInt(TW));
}
// Column (in thumbnail pixels) to split at: the middle of the widest band without text
// between 35% and 65% of the width. Text columns have many light/dark edges; blank paper and
// the spine shadow (dark but smooth) have few. Exact centre if no such band is found.
fn gutterColumn(px: []const u8, tw: usize, th: usize) f32 {
    const y0 = th / 12;
    const y1 = th - th / 12;
    const c0 = tw * 35 / 100;
    const c1 = tw * 65 / 100;
    var edges: [512]u32 = @splat(0);
    var maxe: u32 = 0;
    for (c0..c1) |c| {
        var e: u32 = 0;
        var y = y0 + 1;
        while (y < y1) : (y += 1) {
            const a0: i32 = px[(y - 1) * tw + c];
            const a1: i32 = px[y * tw + c];
            if (@abs(a1 - a0) > 48) e += 1;
        }
        edges[c] = e;
        maxe = @max(maxe, e);
    }
    if (maxe < 8) return @as(f32, @floatFromInt(tw)) / 2;
    const quiet = @max(maxe / 8, 2);
    var best_len: usize = 0;
    var best_mid: f32 = @as(f32, @floatFromInt(tw)) / 2;
    var c = c0;
    while (c < c1) {
        if (edges[c] > quiet) {
            c += 1;
            continue;
        }
        const st = c;
        while (c < c1 and edges[c] <= quiet) c += 1;
        if (c - st > best_len) {
            best_len = c - st;
            best_mid = @as(f32, @floatFromInt(st + c)) / 2;
        }
    }
    if (best_len < 2) return @as(f32, @floatFromInt(tw)) / 2;
    return best_mid;
}
fn spreadSplit(doc: *ZrDoc, p: i32, slot_i: usize) f32 {
    if (!book.is_pdf or !pool.split or p < 0 or p >= MAX_SPREAD_PAGES) return -1;
    const i: usize = @intCast(p);
    if (spreads[i] == 0) spreads[i] = detectSpread(doc, p, slot_i);
    return spreads[i];
}
fn viewGeometryP(doc: *ZrDoc, p: i32, slot_i: usize, r: [4]f32, mode: ViewMode, base_width: bool, step: i32, px: f32, py: f32) ViewGeometry {
    if (mode != .page or !book.is_pdf or !pool.split) return viewGeometry(r, mode, base_width, step, px, py);
    const xs = spreadSplit(doc, p, slot_i);
    if (xs <= r[0] + 1 or xs >= r[2] - 1) return viewGeometry(r, mode, base_width, step, px, py);
    const actual: i32 = if (step < 0) 1 else @min(step, 1);
    const half: [4]f32 = if (actual == 0) .{ r[0], r[1], xs, r[3] } else .{ xs, r[1], r[2], r[3] };
    return .{ .m = fitMatrix(half), .r = half, .steps = 2, .actual_step = actual };
}
// The fitted half is narrower than the screen; paint the side strips white so the facing
// page (beyond the split) never shows.
fn clipHalf(buf: []u8, g: ViewGeometry) void {
    if (g.steps != 2 or !splitActive()) return;
    const fx0 = g.m[0] * g.r[0] + g.m[4];
    const fx1 = g.m[0] * g.r[2] + g.m[4];
    const x0: usize = @intFromFloat(std.math.clamp(@ceil(fx0), 0, @as(f32, @floatFromInt(W))));
    const x1: usize = @intFromFloat(std.math.clamp(@floor(fx1), 0, @as(f32, @floatFromInt(W))));
    for (0..H) |y| {
        const row = buf[y * STRIDE ..][0..W];
        if (x0 > 0) @memset(row[0..x0], 0xFF);
        if (x1 < W) @memset(row[x1..W], 0xFF);
    }
}
fn halfLabel() []const u8 {
    const g = visibleGeometry() orelse return "";
    if (!splitActive() or g.steps != 2) return "";
    return if (g.actual_step == 0) " L" else " R";
}
fn splitActive() bool {
    return book.is_pdf and pool.split and pool.view == .page;
}
fn viewGeometry(r: [4]f32, mode: ViewMode, base_width: bool, step: i32, px: f32, py: f32) ViewGeometry {
    const fw: f32 = @floatFromInt(W);
    const fh: f32 = @floatFromInt(H);
    const rw = @max(r[2] - r[0], 1);
    const rh = @max(r[3] - r[1], 1);
    if (mode == .page) return .{ .m = fitMatrix(r), .r = r };
    if (mode == .width) {
        const scale = fw / rw;
        const count: i32 = 1 + @as(i32, @intFromFloat(@ceil(@max(rh * scale - fh, 0) / (fh - VIEW_OVERLAP))));
        const actual = if (step < 0) count - 1 else std.math.clamp(step, 0, count - 1);
        return .{ .m = .{ scale, 0, 0, scale, -r[0] * scale, -r[1] * scale - @as(f32, @floatFromInt(actual)) * (fh - VIEW_OVERLAP) }, .r = r, .steps = count, .actual_step = actual };
    }
    const base = if (base_width) fw / rw else @min(fw / rw, fh / rh);
    const scale = base * @as(f32, if (mode == .zoom15) 1.5 else 2);
    const mx = @max(rw * scale - fw, 0);
    const my = @max(rh * scale - fh, 0);
    return .{ .m = .{ scale, 0, 0, scale, @max((fw - rw * scale) / 2, 0) - r[0] * scale - std.math.clamp(px, 0, 1) * mx, @max((fh - rh * scale) / 2, 0) - r[1] * scale - std.math.clamp(py, 0, 1) * my }, .r = r, .max_x = mx, .max_y = my };
}
fn visibleGeometry() ?ViewGeometry {
    if (pool.shown < 0) return null;
    const slot = &pool.slots[@intCast(pool.shown)];
    if (slot.page != pool.cur or slot.gen != pool.gen) return null;
    return slot.geometry;
}
fn invalidateView() void {
    pool.gen +%= 1;
    pool.shown = -1;
    book.words_page = -1;
    book.state_dirty = true;
    need_page = true;
    sel_active = false;
    popup_open = false;
    editing_note = null;
    _ = pthread_cond_broadcast(&pool.cond);
}
// v0.11.2 (pool.mtx held, after invalidateView): zoom in and pan show at once as a draft
// scaled from the page already on screen; the exact render replaces it with a
// non-flashing update (as for first-page drafts).
fn instantDraft(old_i: i32, og: ViewGeometry) void {
    if (old_i < 0 or draft_slot != null or pool.no_images or !book.is_pdf) return;
    const src = &pool.slots[@intCast(old_i)];
    if (src.state != .ready or src.draft) return;
    const ng = viewGeometry(og.r, pool.view, pool.base_width, pool.step, pool.pan_x, pool.pan_y);
    if (ng.m[0] < og.m[0] * 0.99) return; // zooming out: nothing useful to scale
    var di: ?usize = null;
    for (&pool.slots, 0..) |*slot, i| {
        if (@as(i32, @intCast(i)) == old_i or slot.state == .rendering) continue;
        di = i;
        if (slot.state == .empty or slot.gen != pool.gen) break;
    }
    const d = &pool.slots[di orelse return];
    const t0 = nowUs();
    defer logf("zoom/pan draft shown from the current page in {d} us", .{nowUs() - t0});
    const a = og.m[0] / ng.m[0];
    const bx = og.m[4] - a * ng.m[4];
    const ay = og.m[3] / ng.m[3];
    const by = og.m[5] - ay * ng.m[5];
    const fw: f32 = @floatFromInt(W);
    const fh: f32 = @floatFromInt(H);
    for (0..H) |y| {
        const oy = ay * @as(f32, @floatFromInt(y)) + by;
        const row = d.buf[y * STRIDE ..][0..W];
        if (oy < 0 or oy >= fh) {
            @memset(row, 0xFF);
            continue;
        }
        const srow = src.buf[@as(usize, @intFromFloat(oy)) * STRIDE ..][0..W];
        for (row, 0..) |*px, x| {
            const ox = a * @as(f32, @floatFromInt(x)) + bx;
            px.* = if (ox < 0 or ox >= fw) 0xFF else srow[@intFromFloat(ox)];
        }
    }
    d.page = pool.cur;
    d.step = pool.step;
    d.gen = pool.gen;
    d.geometry = ng;
    d.m = ng.m;
    d.metrics = src.metrics;
    d.state = .ready;
    d.draft = true;
    draft_slot = di;
}
fn setView(mode: ViewMode, anchor: ?[2]i32) void {
    if (!book.is_pdf) return;
    const geometry = visibleGeometry();
    const old_shown = pool.shown;
    const point = if (anchor) |p| toPage(p[0], p[1]) else [2]f32{ 0, 0 };
    _ = pthread_mutex_lock(&pool.mtx);
    if (pool.view == .page or pool.view == .width) pool.base_width = pool.view == .width;
    if (mode == .page or mode == .width) pool.base_width = mode == .width;
    pool.view = mode;
    pool.step = 0;
    pool.pan_x = 0;
    pool.pan_y = 0;
    if (anchor != null and geometry != null and mode == .width) {
        const g = viewGeometry(geometry.?.r, .width, true, 0, 0, 0);
        const desired = ((point[1] - g.r[1]) * g.m[3] - @as(f32, @floatFromInt(anchor.?[1]))) / (@as(f32, @floatFromInt(H)) - VIEW_OVERLAP);
        pool.step = std.math.clamp(@as(i32, @intFromFloat(@round(desired))), 0, g.steps - 1);
    }
    if (anchor != null and geometry != null and (mode == .zoom15 or mode == .zoom2)) {
        const g = viewGeometry(geometry.?.r, mode, pool.base_width, 0, 0, 0);
        const p = anchor.?;
        if (g.max_x > 0) pool.pan_x = std.math.clamp(((point[0] - g.r[0]) * g.m[0] - @as(f32, @floatFromInt(p[0]))) / g.max_x, 0, 1);
        if (g.max_y > 0) pool.pan_y = std.math.clamp(((point[1] - g.r[1]) * g.m[3] - @as(f32, @floatFromInt(p[1]))) / g.max_y, 0, 1);
    }
    invalidateView();
    if (geometry) |og| if (mode == .zoom15 or mode == .zoom2) instantDraft(old_shown, og);
    _ = pthread_mutex_unlock(&pool.mtx);
    logf("PDF view: {s}", .{VIEW_NAMES[@backingInt(mode)]});
}
fn zoomCycle(x: i32, y: i32) void {
    const next: ViewMode = switch (pool.view) {
        .page, .width => .zoom15,
        .zoom15 => .zoom2,
        .zoom2 => if (pool.base_width) .width else .page,
    };
    menu_open = false;
    setView(next, .{ x, y });
}
fn turnView(direction: i32, t: u64) void {
    if (book.is_pdf and (pool.view == .width or splitActive())) {
        const g = visibleGeometry() orelse return;
        const step = g.actual_step + direction;
        if (step >= 0 and step < g.steps) {
            _ = pthread_mutex_lock(&pool.mtx);
            pool.step = step;
            pool.dir = direction;
            _ = pthread_cond_broadcast(&pool.cond);
            _ = pthread_mutex_unlock(&pool.mtx);
            need_page = true;
            book.state_dirty = true;
            sel_active = false;
            popup_open = false;
            t_tap = t;
            tap_pending_measure = t != 0;
            stats_last_activity = nowUs();
            logf("PDF slice: page={d} step={d}/{d}", .{ pool.cur + 1, step + 1, g.steps });
            return;
        }
    }
    goPage(pool.cur + direction, t);
    if (book.is_pdf and (pool.view == .width or splitActive()) and direction < 0) {
        _ = pthread_mutex_lock(&pool.mtx);
        pool.step = -1;
        _ = pthread_cond_broadcast(&pool.cond);
        _ = pthread_mutex_unlock(&pool.mtx);
    }
}

fn paginationProgress(pages: c_int) callconv(.c) c_int {
    _ = pthread_mutex_lock(&pool.mtx);
    defer _ = pthread_mutex_unlock(&pool.mtx);
    if (pool.quit) return 0;
    if (pages > pool.npages) {
        pool.npages = pages;
        _ = linux.write(pool.pipe_w, "r", 1);
    }
    return 1;
}
fn workerThread(_: ?*anyopaque) callconv(.c) ?*anyopaque {
    _ = pthread_mutex_lock(&pool.mtx);
    var my_font = pool.font;
    var my_margin = pool.margin;
    var my_spacing = pool.spacing;
    _ = pthread_mutex_unlock(&pool.mtx);
    const doc = zr_open_worker(pool.path, LW, LH, my_font, my_margin, my_spacing, paginationProgress) orelse {
        if (!pool.quit) logf("worker: cannot open document", .{});
        return null;
    };
    zr_set_spacing(doc, my_spacing);
    if (zr_reflowable(doc) != 0) _ = zr_relayout(doc, LW, LH, my_font, my_margin, 0);
    _ = pthread_mutex_lock(&pool.mtx);
    var doc_index: usize = 0;
    while (doc_index < pool.docs.len and pool.docs[doc_index] != null) : (doc_index += 1) {}
    if (doc_index < pool.docs.len) pool.docs[doc_index] = doc;
    if (zr_reflowable(doc) != 0) {
        pool.npages = zr_page_count(doc);
        pool.paginating = false;
        logf("pagination: completed asynchronously pages={d}", .{pool.npages});
        _ = linux.write(pool.pipe_w, "r", 1);
    }
    while (!pool.quit) {
        if (pool.font != my_font or pool.margin != my_margin or pool.spacing != my_spacing) {
            my_font = pool.font;
            my_margin = pool.margin;
            my_spacing = pool.spacing;
            _ = pthread_mutex_unlock(&pool.mtx);
            zr_set_spacing(doc, my_spacing);
            _ = zr_relayout(doc, LW, LH, my_font, my_margin, 0);
            _ = pthread_mutex_lock(&pool.mtx);
            continue;
        }
        const my_gen = pool.gen;
        const job = pickJob() orelse {
            if (pool.busy == 0) govBoost(false);
            _ = pthread_cond_wait(&pool.cond, &pool.mtx);
            continue;
        };
        const slot = &pool.slots[job.s];
        slot.page = job.p;
        slot.step = job.step;
        slot.gen = my_gen;
        slot.state = .rendering;
        slot.draft = false;
        pool.busy += 1;
        govBoost(true);
        const mode = pool.view;
        const base_width = pool.base_width;
        const pan_x = pool.pan_x;
        const pan_y = pool.pan_y;
        const use_trim = viewUsesTrim(book.is_pdf, pool.trim, mode, base_width);
        var have_trim = false;
        var r: [4]f32 = undefined;
        if (use_trim and job.p < pool.trims.len and pool.trims[@intCast(job.p)].done) {
            r = pool.trims[@intCast(job.p)].r;
            have_trim = true;
        }
        const ni: c_int = @intFromBool(pool.no_images);
        zr_reset_cancel(doc);
        const wi = @min(doc_index, pool.job_p.len - 1);
        pool.job_p[wi] = job.p;
        pool.preempted[wi] = false;
        // v0.10.5: the page the user is waiting for, if heavy, is drawn as a draft first.
        const waiting = job.p == pool.cur and job.step == pool.step and mode == .page and book.is_pdf and draft_slot == null and !pool.no_images and !pool.slots[job.s].draft;
        const my_gen_draft = pool.gen;
        _ = pthread_mutex_unlock(&pool.mtx);

        if (waiting and workerDraft(doc, job, my_gen_draft)) {
            _ = pthread_mutex_lock(&pool.mtx);
            pool.busy -= 1;
            pool.job_p[wi] = -1;
            _ = pthread_cond_broadcast(&pool.cond);
            _ = linux.write(pool.pipe_w, "r", 1);
            continue;
        }

        const t0 = nowUs();
        var rc: c_int = 0;
        if (!have_trim) {
            rc = if (use_trim) zr_ink_bbox_flags(doc, job.p, &r, ni, imageFlags()) else zr_page_bounds(doc, job.p, &r);
        }
        const geometry = viewGeometryP(doc, job.p, wi, r, mode, base_width, job.step, pan_x, pan_y);
        const m = geometry.m;
        var render_stats: ZrRenderStats = .{};
        if (rc == 0) rc = zr_render_with_stats(doc, job.p, &m, slot.buf.ptr, @intCast(W), @intCast(H), @intCast(STRIDE), ni, imageFlags(), &render_stats);
        if (rc == 0) clipHalf(slot.buf, geometry);
        const metrics = pageMetrics(slot.buf, W, H, STRIDE, render_stats.image_coverage);
        const dt = nowUs() - t0;

        _ = pthread_mutex_lock(&pool.mtx);
        pool.job_p[wi] = -1;
        if (pool.preempted[wi]) {
            // Aborted for the page the user is waiting for: nothing is kept.
            pool.preempted[wi] = false;
            slot.state = .empty;
            slot.page = -1;
            pool.busy -= 1;
            logf("prerender of page {d} preempted for page {d}", .{ job.p + 1, pool.cur + 1 });
            _ = pthread_cond_broadcast(&pool.cond);
            _ = linux.write(pool.pipe_w, "r", 1);
            continue;
        }
        if (use_trim and !have_trim and rc == 0 and job.p < pool.trims.len) pool.trims[@intCast(job.p)] = .{ .done = true, .r = r };
        slot.m = m;
        slot.geometry = geometry;
        slot.metrics = metrics;
        slot.state = if (rc == 0) .ready else .failed;
        if (rc != 0) {
            pool.errors += 1;
            logf("render error on page {d}", .{job.p + 1});
        }
        pool.busy -= 1;
        pool.render_us.add(dt);
        noteSlowPage(dt);
        if (dt > 150_000) logf("slow render: p={d} step={d} view={s} ms={d}", .{ job.p + 1, job.step, @tagName(mode), dt / 1000 });
        _ = pthread_cond_broadcast(&pool.cond);
        _ = linux.write(pool.pipe_w, "r", 1);
    }
    if (doc_index < pool.docs.len) pool.docs[doc_index] = null;
    _ = pthread_mutex_unlock(&pool.mtx);
    zr_close(doc);
    return null;
}

// ---------------- book, notes, state ----------------
const Note = struct { anchor: Anchor = .{}, unresolved: bool = false, page: i32, style: u8, ts: i64, text: []u8, nq: usize, q: [24][4]f32, comment: []u8 = &.{} };
const STYLE_NAMES = [_][]const u8{ "underline", "highlight", "note" };
const STYLE_LABELS = [_][]const u8{ "Underline", "Highlight", "Note" };

const MAXW = 12000;
const Book = struct {
    open: bool = false,
    path: [1024]u8 = undefined,
    path_len: usize = 0,
    name: [256]u8 = undefined,
    name_len: usize = 0,
    doc: *ZrDoc = undefined,
    is_pdf: bool = false,
    reflow: bool = false,
    threads: [2]c_ulong = .{ 0, 0 },
    nthreads: usize = 0,
    words: []ZrWord = &.{},
    wtext: []u8 = &.{},
    nwords: usize = 0,
    words_page: i32 = -1,
    words_gen: u32 = 0,
    toc: []ZrToc = &.{},
    toc_text: []u8 = &.{},
    ntoc: usize = 0,
    toc_loaded: bool = false,
    toc_detected: bool = false,
    toc_real: bool = false,
    notes: [1024]Note = undefined,
    nnotes: usize = 0,
    opened_ts: i64 = 0,
    state_dirty: bool = false,
    position: Anchor = .{},
    fsize: u64 = 0,
    fmtime: i64 = 0,
    fn pathS(self: *Book) []const u8 {
        return self.path[0..self.path_len];
    }
    fn nameS(self: *Book) []const u8 {
        return self.name[0..self.name_len];
    }
};
var book: Book = .{};

fn statePath(path: []const u8, out: []u8) []const u8 {
    return std.fmt.bufPrint(out, "{s}/state/{x:0>16}.json", .{ opts.data, fnv(path) }) catch "";
}
fn notesBase(out: []u8) []const u8 {
    var clean: [256]u8 = undefined;
    const n = book.nameS();
    for (n, 0..) |c, i| clean[i] = if (c == '/' or c == '\\' or c == ':' or c == '"' or c < 0x20) '_' else c;
    return std.fmt.bufPrint(out, "{s}/notes/{s}", .{ opts.data, clean[0..n.len] }) catch "";
}

const State = struct { anchor: Anchor = .{}, typography: bool = true, spacing: f32 = 1.4, view: ViewMode = .page, base_width: bool = false, step: i32 = 0, pan_x: f32 = 0, pan_y: f32 = 0, page: i32 = 0, font: f32 = 10.5, margin: f32 = 18, trim: bool = true, split: bool = true, opened: i64 = 0, pages: i32 = 0 };
fn readAnchor(data: []const u8) Anchor {
    var a: Anchor = .{};
    if ((jsonNum(data, "anchor_version") orelse 0) != 1) return a;
    const chapter = jsonNum(data, "anchor_chapter") orelse return a;
    const start = jsonNum(data, "anchor_start") orelse return a;
    const end = jsonNum(data, "anchor_end") orelse return a;
    if (chapter < 0 or chapter > 100000 or start < 0 or end <= start or end > 2097152) return a;
    var hb: [24]u8 = undefined;
    const hash = jsonStr(data, "anchor_hash", &hb) orelse return a;
    const h = std.fmt.parseInt(u64, hash, 16) catch return a;
    if (h == 0) return a;
    a = .{ .chapter = @intFromFloat(chapter), .start = @intFromFloat(start), .end = @intFromFloat(end), .hash = h };
    return a;
}
fn writeAnchor(b: *Buf, a: Anchor) void {
    if (a.chapter < 0 or a.hash == 0) return;
    b.print("\"anchor_version\":1,\"anchor_chapter\":{d},\"anchor_start\":{d},\"anchor_end\":{d},\"anchor_hash\":\"{x:0>16}\",", .{ a.chapter, a.start, a.end, a.hash });
}
fn pageAnchor(page: i32) Anchor {
    var a: Anchor = .{};
    if (book.reflow) _ = zr_anchor_words(book.doc, page, 0, 0, &a);
    return a;
}
fn readingAnchor() Anchor {
    if (book.position.chapter >= 0 and zr_anchor_page(book.doc, &book.position) == pool.cur) return book.position;
    return pageAnchor(pool.cur);
}
fn repairOpened(v: f64) i64 {
    if (!std.math.isFinite(v) or v < -4294967296 or v > 253402300799) return 0;
    const n: i64 = @intFromFloat(v);
    // Recover the corrupt high word returned by the old time32 binding.
    return if (n < 0) n + 4294967296 else n;
}
fn loadState(path: []const u8) State {
    var st: State = .{};
    var pb: [1200]u8 = undefined;
    var zb: [1200]u8 = undefined;
    const p = statePath(path, &pb);
    const z = std.fmt.bufPrintSentinel(&zb, "{s}", .{p}, 0) catch return st;
    const data = readFile(z) orelse return st;
    defer alloc.free(data);
    st.anchor = readAnchor(data);
    st.typography = (jsonNum(data, "typography_version") orelse 0) == 1;
    if (jsonNum(data, "spacing")) |v| st.spacing = std.math.clamp(@as(f32, @floatCast(v)), 1.15, 1.7);
    if (jsonNum(data, "view")) |v| if (v >= 0 and v <= 3) {
        st.view = @fromBackingInt(@intCast(@as(u8, @intFromFloat(v))));
    };
    if (jsonNum(data, "view_step")) |v| if (v >= 0 and v < 100000) {
        st.step = @intFromFloat(v);
    };
    if (jsonNum(data, "pan_x")) |v| st.pan_x = std.math.clamp(@as(f32, @floatCast(v)), 0, 1);
    if (jsonNum(data, "pan_y")) |v| st.pan_y = std.math.clamp(@as(f32, @floatCast(v)), 0, 1);
    if (jsonNum(data, "base_width")) |v| st.base_width = v != 0;
    if (jsonNum(data, "page")) |v| st.page = @intFromFloat(v);
    if (jsonNum(data, "font")) |v| {
        st.font = std.math.clamp(@as(f32, @floatCast(v)), 6, 30);
    } else if (!st.typography) st.font = 9;
    if (jsonNum(data, "margin")) |v| st.margin = std.math.clamp(@as(f32, @floatCast(v)), 0, 60);
    if (jsonNum(data, "trim")) |v| st.trim = v != 0;
    if (jsonNum(data, "split")) |v| st.split = v != 0;
    if (jsonNum(data, "opened")) |v| st.opened = repairOpened(v);
    if (jsonNum(data, "pages")) |v| st.pages = @intFromFloat(v);
    return st;
}
fn saveState() void {
    if (!book.open) return;
    if (book.reflow) zr_page_count_hint(book.doc, pool.npages);
    var b = Buf.init(2048);
    defer b.deinit();
    b.put("{\"path\":\"");
    b.esc(book.pathS());
    const step = if (visibleGeometry()) |g| g.actual_step else @max(pool.step, 0);
    b.print("\",\"view\":{d},\"view_step\":{d},\"pan_x\":{d:.9},\"pan_y\":{d:.9},\"base_width\":{d},", .{ @backingInt(pool.view), step, pool.pan_x, pool.pan_y, @intFromBool(pool.base_width) });
    if (book.reflow) {
        book.position = readingAnchor();
        writeAnchor(&b, book.position);
    }
    b.print("\"typography_version\":1,\"spacing\":{d:.2},", .{pool.spacing});
    b.print("\"page\":{d},\"pages\":{d},\"opened\":{d},\"font\":{d:.2},\"margin\":{d:.1},\"trim\":{d},\"split\":{d}}}\n", .{
        pool.cur, pool.npages, book.opened_ts, pool.font, pool.margin, @intFromBool(pool.trim), @intFromBool(pool.split),
    });
    var pb: [1200]u8 = undefined;
    _ = writeFileAtomic(statePath(book.pathS(), &pb), b.slice());
    var lb: [1200]u8 = undefined;
    if (std.fmt.bufPrint(&lb, "{s}/last_book", .{opts.data})) |lp| {
        _ = writeFileAtomic(lp, book.pathS());
    } else |_| {}
    book.state_dirty = false;
}

fn freeNotes() void {
    for (book.notes[0..book.nnotes]) |*n| {
        alloc.free(n.text);
        alloc.free(n.comment);
    }
    book.nnotes = 0;
}
fn loadNotes() void {
    freeNotes();
    var pb: [1200]u8 = undefined;
    var zb: [1200]u8 = undefined;
    const base = notesBase(&pb);
    const z = std.fmt.bufPrintSentinel(&zb, "{s}.json", .{base}, 0) catch return;
    const data = readFile(z) orelse return;
    defer alloc.free(data);
    var it = ObjIter{ .s = data };
    var tbuf: [8192]u8 = undefined;
    while (it.next()) |obj| {
        if (book.nnotes >= book.notes.len) break;
        var n: Note = undefined;
        n.anchor = readAnchor(obj);
        n.unresolved = (jsonNum(obj, "anchor_unresolved") orelse 0) != 0;
        n.page = @as(i32, @intFromFloat(jsonNum(obj, "page") orelse continue)) - 1;
        n.ts = @intFromFloat(jsonNum(obj, "ts") orelse 0);
        var sb: [32]u8 = undefined;
        const style = jsonStr(obj, "style", &sb) orelse "note";
        n.style = 2;
        for (STYLE_NAMES, 0..) |sn, i| {
            if (eql(sn, style)) n.style = @intCast(i);
        }
        const t = jsonStr(obj, "text", &tbuf) orelse "";
        n.text = alloc.dupe(u8, t) catch continue;
        n.comment = &.{};
        if (jsonStr(obj, "comment", &tbuf)) |c| n.comment = alloc.dupe(u8, c) catch &.{};
        n.nq = 0;
        if (jsonKey(obj, "quads")) |qi| {
            var i = qi;
            var vals: [4]f32 = undefined;
            var k: usize = 0;
            while (i < obj.len and obj[i] != '}') : (i += 1) {
                const c = obj[i];
                if (std.ascii.isDigit(c) or c == '-') {
                    var j = i;
                    while (j < obj.len and (std.ascii.isDigit(obj[j]) or obj[j] == '-' or obj[j] == '.' or obj[j] == 'e')) j += 1;
                    vals[k] = std.fmt.parseFloat(f32, obj[i..j]) catch 0;
                    k += 1;
                    if (k == 4) {
                        if (n.nq < n.q.len) {
                            n.q[n.nq] = vals;
                            n.nq += 1;
                        }
                        k = 0;
                    }
                    i = j - 1;
                } else if (c == ']' and i + 1 < obj.len and obj[i + 1] == ']') break;
            }
        }
        // Older versions could store two overlapping rectangles for one
        // visual line. Canonicalize them before either drawing or rewriting.
        var qn: usize = 0;
        for (n.q[0..n.nq]) |q| {
            var merged = false;
            for (n.q[0..qn]) |*old| {
                if (sameTextLine(old.*, q)) {
                    old.* = .{ @min(old[0], q[0]), @min(old[1], q[1]), @max(old[2], q[2]), @max(old[3], q[3]) };
                    merged = true;
                    break;
                }
            }
            if (!merged) {
                n.q[qn] = q;
                qn += 1;
            }
        }
        n.nq = qn;
        book.notes[book.nnotes] = n;
        book.nnotes += 1;
    }
}
// Migrate against the old layout BEFORE applying new typography. Ambiguous
// repeated quotes are disambiguated by the original first quad, not a global
// first-match search. Unresolvable text is retained but never drawn randomly.
fn migrateNotes() bool {
    if (!book.reflow) return false;
    var changed = false;
    for (book.notes[0..book.nnotes]) |*n| {
        if (n.anchor.chapter >= 0 or n.unresolved) continue;
        const q = if (n.nq > 0) n.q[0] else [4]f32{ 0, 0, 0, 0 };
        if (zr_anchor_migrate(book.doc, n.page, n.text.ptr, @intCast(n.text.len), (q[0] + q[2]) / 2, (q[1] + q[3]) / 2, &n.anchor) == 0) {
            n.unresolved = true;
            logf("EPUB note retained without anchor: p. {d}", .{n.page + 1});
        }
        changed = true;
    }
    return changed;
}
fn resolveNotePages() void {
    if (!book.reflow) return;
    for (book.notes[0..book.nnotes]) |*n| {
        const page = zr_anchor_page(book.doc, &n.anchor);
        if (page < 0) {
            n.unresolved = true;
            continue;
        }
        n.unresolved = false;
        n.page = page;
        n.nq = @intCast(@max(zr_anchor_quads(book.doc, &n.anchor, page, &n.q, @intCast(n.q.len)), 0));
    }
}
fn noteQuads(n: *const Note, page: i32, out: [][4]f32) usize {
    if (book.reflow and n.unresolved) return 0;
    if (book.reflow) return @intCast(@max(zr_anchor_quads(book.doc, &n.anchor, page, out.ptr, @intCast(out.len)), 0));
    if (n.page != page) return 0;
    const count = @min(n.nq, out.len);
    @memcpy(out[0..count], n.q[0..count]);
    return count;
}
// Pages are stored 1-based in the files, as people read them.
fn saveNotesJson() void {
    var b = Buf.init(8192);
    defer b.deinit();
    b.put("[\n");
    for (book.notes[0..book.nnotes], 0..) |*n, i| {
        b.put("{");
        if (n.unresolved) b.put("\"anchor_unresolved\":1,");
        writeAnchor(&b, n.anchor);
        b.print("\"page\":{d},\"style\":\"{s}\",\"ts\":{d},\"quads\":[", .{ n.page + 1, STYLE_NAMES[n.style], n.ts });
        for (n.q[0..n.nq], 0..) |q, k| {
            b.print("{s}[{d:.2},{d:.2},{d:.2},{d:.2}]", .{ if (k > 0) "," else "", q[0], q[1], q[2], q[3] });
        }
        b.put("],");
        if (n.comment.len > 0) {
            b.put("\"comment\":\"");
            b.esc(n.comment);
            b.put("\",");
        }
        b.put("\"text\":\"");
        b.esc(n.text);
        b.put(if (i + 1 < book.nnotes) "\"},\n" else "\"}\n");
    }
    b.put("]\n");
    var pb: [1200]u8 = undefined;
    var fb2: [1200]u8 = undefined;
    const base = notesBase(&pb);
    const p = std.fmt.bufPrint(&fb2, "{s}.json", .{base}) catch return;
    if (!writeFileAtomic(p, b.slice())) logf("could not write {s}", .{p});
}
fn saveNotesTxt() void {
    var b = Buf.init(1024);
    defer b.deinit();
    for (book.notes[0..book.nnotes]) |*n| {
        var db: [64]u8 = undefined;
        b.print("p. {d}  \xc2\xb7  {s}  \xc2\xb7  {s}\n", .{ n.page + 1, STYLE_LABELS[n.style], fmtDate(n.ts, &db) });
        b.put("\xe2\x80\x9c");
        b.put(n.text);
        b.put("\xe2\x80\x9d\n");
        if (n.comment.len > 0) {
            b.put("Note: ");
            b.put(n.comment);
            b.put("\n");
        }
        b.put("\n");
    }
    var pb: [1200]u8 = undefined;
    var fb2: [1200]u8 = undefined;
    const base = notesBase(&pb);
    const p = std.fmt.bufPrint(&fb2, "{s}.txt", .{base}) catch return;
    if (!writeFileAtomic(p, b.slice())) logf("could not write {s}", .{p});
}
fn saveNotes() void {
    saveNotesJson();
    saveNotesTxt();
    exportCurrentNotes();
}
fn deleteNote(k: usize) void {
    if (k >= book.nnotes) return;
    alloc.free(book.notes[k].text);
    alloc.free(book.notes[k].comment);
    var j = k;
    while (j + 1 < book.nnotes) : (j += 1) book.notes[j] = book.notes[j + 1];
    book.nnotes -= 1;
    saveNotes();
}

fn spawnWorkers() void {
    pool.quit = false;
    book.nthreads = 0;
    for (book.threads[0..(if (book.reflow) @as(usize, 1) else book.threads.len)]) |*t| {
        if (spawn(t, workerThread) == 0) book.nthreads += 1;
    }
}
fn stopWorkers() void {
    _ = pthread_mutex_lock(&pool.mtx);
    pool.quit = true;
    for (pool.docs) |doc| if (doc) |d| zr_cancel(d);
    _ = pthread_cond_broadcast(&pool.cond);
    _ = pthread_mutex_unlock(&pool.mtx);
    for (book.threads[0..book.nthreads]) |t| _ = pthread_join(t, null);
    book.nthreads = 0;
}

// ---- v0.9 instant reopen: saved page image per book ----
// The image is the composed reading page (page raster + annotation overlays), never
// menus, toasts, selection or the battery. The key covers the book file (size+mtime),
// screen, image options and every layout field saveState() records, so any change
// (file, font, margin, spacing, trim, view, page) makes the saved image unusable.
const PC_EVERY: u32 = 8;
var pc_preview: []u8 = &.{};
var pc_preview_active = false;
var pc_turns: u32 = 0;
var pc_open_us: u64 = 0;
var pc_first_frame_pending = false;
fn pcName(path: []const u8, out: *[32]u8) [*:0]const u8 {
    const n = std.fmt.bufPrintSentinel(out, "{x:0>16}.pg", .{fnv(path)}, 0) catch return "x";
    return n.ptr;
}
fn pcKey(page: i32, view: u8, step: i32, pan_x: f32, pan_y: f32, base_width: bool, trim: bool, font: f32, margin: f32, spacing: f32, a: Anchor) u64 {
    var b: [512]u8 = undefined;
    const k = std.fmt.bufPrint(&b, "zrpg1|{s}|{d}|{d}|{d}x{d}|d{d}|c{d}|i{d}|p{d}|v{d}|s{d}|x{d:.9}|y{d:.9}|b{d}|t{d}|f{d:.2}|m{d:.1}|l{d:.2}|a{d}:{d}:{d}:{x}|sp{d}", .{
        book.pathS(), book.fsize, book.fmtime, W, H, @intFromBool(opts.image_dither), @intFromBool(opts.clean_scans), @intFromBool(opts.no_images), page, view, step, pan_x, pan_y, @intFromBool(base_width), @intFromBool(trim), font, margin, spacing, a.chapter, a.start, a.end, a.hash, @intFromBool(pool.split),
    }) catch return 0;
    if (book.reflow and (text_mode != 0 or book_font != 0)) {
        var b2: [600]u8 = undefined;
        const k2 = std.fmt.bufPrint(&b2, "{s}|ts{d}{d}", .{ k, text_mode, book_font }) catch return 0;
        return fnv(k2);
    }
    return fnv(k);
}
fn pcCurrentKey() u64 {
    const step = if (visibleGeometry()) |g| g.actual_step else @max(pool.step, 0);
    const a = if (book.reflow) readingAnchor() else Anchor{};
    return pcKey(pool.cur, @backingInt(pool.view), step, pool.pan_x, pool.pan_y, pool.base_width, pool.trim, pool.font, pool.margin, pool.spacing, a);
}
// fb currently holds raster+overlays for pool.cur (called from drawReader before menus).
fn pcSubmitFb(final: bool) void {
    if (!book.open or opts.page_cache_mib == 0) return;
    if (draft_slot != null) return; // never save a draft as the page's image
    if (final) zr_pc_flush();
    var nb: [32]u8 = undefined;
    const key = pcCurrentKey();
    if (key == 0) return;
    if (zr_pc_submit(pcName(book.pathS(), &nb), key, fb.ptr, @intCast(W), @intCast(H), @intCast(STRIDE)) == 0) {
        pc_turns = 0;
        if (opts.debug or opts.sim != null) logf("page cache: saved p={d}{s}", .{ pool.cur + 1, if (final) " (final)" else "" });
    }
    if (final) zr_pc_flush();
}
// Composes the clean reading page into fb (fb is fully redrawn afterwards) and saves it.
fn pcCaptureNow() void {
    if (!book.open or opts.page_cache_mib == 0 or sleep_phase != .awake) return;
    _ = pthread_mutex_lock(&pool.mtx);
    const i = slotFor(pool.cur) orelse {
        _ = pthread_mutex_unlock(&pool.mtx);
        return;
    };
    const s = &pool.slots[i];
    if (s.state != .ready) {
        _ = pthread_mutex_unlock(&pool.mtx);
        return;
    }
    @memcpy(fb[0 .. STRIDE * H], s.buf[0 .. STRIDE * H]);
    shown_m = s.m;
    _ = pthread_mutex_unlock(&pool.mtx);
    const sel = sel_active;
    const hit = search_hit;
    sel_active = false;
    search_hit = null;
    drawOverlays();
    sel_active = sel;
    search_hit = hit;
    pcSubmitFb(true);
}
// Shows the saved page at once if its key matches the state about to be opened.
fn pcShowPreview(st: State) void {
    if (opts.page_cache_mib == 0 or pc_preview.len == 0) return;
    var nb: [32]u8 = undefined;
    const name = pcName(book.pathS(), &nb);
    const key = pcKey(st.page, @backingInt(st.view), st.step, st.pan_x, st.pan_y, st.base_width, st.trim, st.font, st.margin, st.spacing, st.anchor);
    const t0 = nowUs();
    const rc = zr_pc_load(name, key, pc_preview.ptr, @intCast(W), @intCast(H), @intCast(STRIDE));
    if (rc != 0) {
        if (rc == -5 or rc == -4 or rc == -6) {
            zr_pc_drop(name);
            logf("page cache: stale saved page dropped (rc={d})", .{rc});
        } else if (opts.debug or opts.sim != null) logf("page cache: miss (rc={d})", .{rc});
        return;
    }
    @memcpy(fb[0 .. STRIDE * H], pc_preview[0 .. STRIDE * H]);
    // Same opening policy as a normal open: the first frame of a book is the single clean.
    const m = sendUpdate(Rect.full(), WF_GC16, UPDATE_MODE_FULL);
    t_submit = nowUs();
    if (!in_flight) {
        in_flight = true;
        waitAsync(m);
    }
    saveSamples(previous_samples, pc_preview, W, H, STRIDE);
    previous_metrics = .{};
    previous_page = st.page;
    text_since_clean = 0;
    pc_preview_active = true;
    pc_first_frame_pending = false;
    logf("page refresh: p={d} reason=opening wf={d} source=saved-page", .{ st.page + 1, WF_GC16 });
    logf("page cache: preview shown p={d} load_us={d}", .{ st.page + 1, t_submit - t0 });
    logf("open profile: first_frame_us={d} (saved page)", .{t_submit - pc_open_us});
}
// 4-bit comparison: the panel shows 16 gray levels, so equal high nibbles look identical.
fn pcSameAsPreview() bool {
    var y: usize = 0;
    while (y < H) : (y += 1) {
        const a = fb[y * STRIDE ..][0..W];
        const b = pc_preview[y * STRIDE ..][0..W];
        for (a, b) |p, q| if ((p >> 4) != (q >> 4)) return false;
    }
    return true;
}

fn closeBook() void {
    if (!book.open) return;
    zr_contents_stop();
    ct_running = false;
    ct_status = 0;
    statsCloseBook();
    pcCaptureNow();
    stopWorkers();
    saveState();
    zr_close(book.doc);
    dictionary_open = false;
    search_running = false;
    search_hit = null;
    freeNotes();
    nbookmarks = 0;
    if (pool.trims.len > 0) alloc.free(pool.trims);
    pool.trims = &.{};
    book.open = false;
    book.toc_loaded = false;
    book.words_page = -1;
}

// v0.10.4: the first page after opening a PDF may be a picture page (e.g. a
// scanned colour cover) whose full-resolution JPEG 2000 layers take seconds
// to decode on the device. It is then drawn first as a draft: untrimmed page
// bounds, half resolution, large images decoded reduced; a worker renders the
// exact page next and it replaces the draft with a non-flashing update.
var draft_slot: ?usize = null;
var draft_buf: []u8 = &.{};
fn renderDraftRaster(doc: *ZrDoc) bool {
    if (!book.is_pdf or pc_preview_active or opts.no_images or pool.view != .page or pool.step != 0) return false;
    if (zr_draft_wanted(doc, pool.cur, imageFlags(), @intCast(W), @intCast(H)) == 0) return false;
    const hw = W / 2;
    const hh = H / 2;
    if (draft_buf.len < hw * hh) draft_buf = alloc.alloc(u8, hw * hh) catch return false;
    var r: [4]f32 = .{ 0, 0, 612, 792 };
    if (zr_page_bounds(doc, pool.cur, &r) != 0) return false;
    const slot = &pool.slots[0];
    const geometry = viewGeometryP(doc, pool.cur, 3, r, pool.view, pool.base_width, pool.step, pool.pan_x, pool.pan_y);
    var hm = geometry.m;
    for (&hm) |*v| v.* *= 0.5;
    var rs: ZrRenderStats = .{};
    if (zr_render_with_stats(doc, pool.cur, &hm, draft_buf.ptr, @intCast(hw), @intCast(hh), @intCast(hw), 0, imageFlags() | 4, &rs) != 0 or rs.drafted == 0) return false;
    upscale2(draft_buf, hw, hh, slot.buf, W, H, STRIDE);
    clipHalf(slot.buf, geometry);
    slot.geometry = geometry;
    slot.m = geometry.m;
    slot.page = pool.cur;
    slot.step = pool.step;
    slot.gen = pool.gen;
    slot.state = .ready;
    slot.draft = true;
    slot.metrics = pageMetrics(slot.buf, W, H, STRIDE, rs.image_coverage);
    draft_slot = 0;
    logf("open profile: first page drawn as a draft p={d}", .{pool.cur + 1});
    return true;
}
// Bilinear 2x enlargement (pixel centres aligned).
fn upscale2(src: []const u8, sw: usize, sh: usize, dst: []u8, dw: usize, dh: usize, stride: usize) void {
    var y: usize = 0;
    while (y < dh) : (y += 1) {
        // source row (y + 0.5) / 2 - 0.5 = (2y - 1) / 4, in quarter-pixel units
        const sy4: isize = @as(isize, @intCast(2 * y)) - 1;
        const y0: isize = @divFloor(sy4, 4);
        const wy: u32 = @intCast(@mod(sy4, 4)); // 0..3 quarters
        const ya: usize = @intCast(std.math.clamp(y0, 0, @as(isize, @intCast(sh - 1))));
        const yb: usize = @intCast(std.math.clamp(y0 + 1, 0, @as(isize, @intCast(sh - 1))));
        var x: usize = 0;
        while (x < dw) : (x += 1) {
            const sx4: isize = @as(isize, @intCast(2 * x)) - 1;
            const x0: isize = @divFloor(sx4, 4);
            const wx: u32 = @intCast(@mod(sx4, 4));
            const xa: usize = @intCast(std.math.clamp(x0, 0, @as(isize, @intCast(sw - 1))));
            const xb: usize = @intCast(std.math.clamp(x0 + 1, 0, @as(isize, @intCast(sw - 1))));
            const p00: u32 = src[ya * sw + xa];
            const p01: u32 = src[ya * sw + xb];
            const p10: u32 = src[yb * sw + xa];
            const p11: u32 = src[yb * sw + xb];
            const top = p00 * (4 - wx) + p01 * wx;
            const bot = p10 * (4 - wx) + p11 * wx;
            dst[y * stride + x] = @intCast((top * (4 - wy) + bot * wy + 8) / 16);
        }
    }
}
// Main thread: once the exact page is ready, it replaces the draft on screen
// with a REAGL (non-flashing) update; the draft slot is released.
fn refineDraft() void {
    _ = pthread_mutex_lock(&pool.mtx);
    const di = draft_slot orelse {
        _ = pthread_mutex_unlock(&pool.mtx);
        return;
    };
    const d = &pool.slots[di];
    var show = false;
    var final: ?usize = null;
    if (d.state == .empty or !d.draft or d.gen != pool.gen) {
        d.draft = false;
        draft_slot = null;
    } else {
        const key = ViewKey{ .p = d.page, .step = d.step };
        for (&pool.slots, 0..) |*slot, i| if (i != di and slot.page == key.p and slot.step == key.step and slot.gen == pool.gen and (slot.state == .ready or slot.state == .failed) and !slot.draft) {
            final = i;
        };
        if (final != null) {
            show = pool.shown == @as(i32, @intCast(di)) and d.page == pool.cur;
            d.state = .empty;
            d.draft = false;
            d.page = -1;
            if (pool.shown == @as(i32, @intCast(di))) pool.shown = -1;
            draft_slot = null;
        }
    }
    if (show) if (final) |fi| {
        previous_metrics = pool.slots[fi].metrics;
        saveSamples(previous_samples, pool.slots[fi].buf, W, H, STRIDE);
    };
    _ = pthread_mutex_unlock(&pool.mtx);
    if (show and screen == .reader and !need_page) {
        markFull(WF_REAGL);
        logf("open profile: draft replaced by the exact page (REAGL, no flash) after {d}us", .{nowUs() - pc_open_us});
    }
}
// v0.10.5: worker-side draft of the page the user is waiting for (same draft as
// the first page: untrimmed bounds, half resolution, big JPEG 2000 reduced).
fn workerDraft(doc: *ZrDoc, job: Job, gen: u32) bool {
    if (zr_draft_wanted(doc, job.p, imageFlags(), @intCast(W), @intCast(H)) == 0) return false;
    const hw = W / 2;
    const hh = H / 2;
    const half = alloc.alloc(u8, hw * hh) catch return false;
    defer alloc.free(half);
    var r: [4]f32 = .{ 0, 0, 612, 792 };
    if (zr_page_bounds(doc, job.p, &r) != 0) return false;
    const geometry = viewGeometryP(doc, job.p, 2, r, .page, false, job.step, 0, 0);
    var hm = geometry.m;
    for (&hm) |*v| v.* *= 0.5;
    var rs: ZrRenderStats = .{};
    if (zr_render_with_stats(doc, job.p, &hm, half.ptr, @intCast(hw), @intCast(hh), @intCast(hw), 0, imageFlags() | 4, &rs) != 0 or rs.drafted == 0) return false;
    const slot = &pool.slots[job.s];
    upscale2(half, hw, hh, slot.buf, W, H, STRIDE);
    clipHalf(slot.buf, geometry);
    const metrics = pageMetrics(slot.buf, W, H, STRIDE, rs.image_coverage);
    _ = pthread_mutex_lock(&pool.mtx);
    defer _ = pthread_mutex_unlock(&pool.mtx);
    if (pool.gen != gen or pool.base_width or draft_slot != null) {
        slot.state = .empty;
        slot.page = -1;
        return true; // slot released; the exact job is picked again
    }
    slot.geometry = geometry;
    slot.m = geometry.m;
    slot.metrics = metrics;
    slot.state = .ready;
    slot.draft = true;
    draft_slot = job.s;
    logf("page {d} drawn as a draft while the exact page renders", .{job.p + 1});
    return true;
}
// v0.10.5 (pool.mtx held): when the current page has no exact slot and every worker
// is busy prerendering other pages, abort one of those renders (MuPDF cookie).
fn preemptForCurrent() void {
    const key = ViewKey{ .p = pool.cur, .step = pool.step };
    if (keyCovered(key)) return;
    for (pool.job_p) |p| if (p < 0) return; // a worker is free
    for (pool.job_p, 0..) |p, i| {
        if (p != pool.cur and !pool.preempted[i]) if (pool.docs[i]) |d| {
            pool.preempted[i] = true;
            zr_cancel(d);
            return;
        };
    }
}
fn renderFirstRaster(doc: *ZrDoc) void {
    pool.slots[0].draft = false;
    if (renderDraftRaster(doc)) return;
    var r: [4]f32 = .{ 0, 0, 612, 792 };
    const ni: c_int = @intFromBool(opts.no_images);
    const rc = if (pool.trim) zr_ink_bbox_flags(doc, pool.cur, &r, ni, imageFlags()) else zr_page_bounds(doc, pool.cur, &r);
    const slot = &pool.slots[0];
    slot.geometry = viewGeometryP(doc, pool.cur, 3, r, pool.view, pool.base_width, pool.step, pool.pan_x, pool.pan_y);
    slot.m = slot.geometry.m;
    var rs: ZrRenderStats = .{};
    const rendered = rc == 0 and zr_render_with_stats(doc, pool.cur, &slot.m, slot.buf.ptr, @intCast(W), @intCast(H), @intCast(STRIDE), ni, imageFlags(), &rs) == 0;
    if (rendered) clipHalf(slot.buf, slot.geometry);
    slot.page = pool.cur; slot.step = pool.step; slot.gen = pool.gen;
    slot.state = if (rendered) .ready else .failed;
    slot.metrics = pageMetrics(slot.buf, W, H, STRIDE, rs.image_coverage);
    if (pool.trim and rendered) pool.trims[@intCast(pool.cur)] = .{ .done = true, .r = r };
}

// v0.9.4 slow-pages check: one log line per opened book once its first 8
// page renders average more than SLOW_PAGE_US, so slow books show up in the log.
const SLOW_PAGE_US: u64 = 700_000;
var slow_sum: u64 = 0;
var slow_max: u64 = 0;
var slow_n: u32 = 0;
var slow_logged = false;
fn noteSlowPage(dt: u64) void { // called with pool.mtx held
    slow_sum += dt;
    slow_n += 1;
    slow_max = @max(slow_max, dt);
    if (!slow_logged and slow_n >= 8) {
        slow_logged = true;
        const avg = slow_sum / slow_n;
        if (avg > SLOW_PAGE_US or opts.sim != null)
            logf("slow pages: {s} avg={d}ms max={d}ms over {d} renders, clean_scans={} book='{s}'", .{ if (avg > SLOW_PAGE_US) "SLOW" else "ok", avg / 1000, slow_max / 1000, slow_n, opts.clean_scans, book.pathS() });
    }
}
var open_drm = false;
fn openBook(path: []const u8) bool {
    open_drm = false;
    {
        var dz: [1200]u8 = undefined;
        if (std.fmt.bufPrintSentinel(&dz, "{s}", .{path}, 0)) |zp| {
            if (zr_drm_check(zp) != 0) {
                logf("drm: {s} is DRM-protected; not opened", .{path});
                open_drm = true;
                return false;
            }
        } else |_| {}
    }
    const request_start = nowUs();
    closeBook();
    _ = pthread_mutex_lock(&pool.mtx);
    slow_sum = 0;
    slow_max = 0;
    slow_n = 0;
    slow_logged = false;
    _ = pthread_mutex_unlock(&pool.mtx);
    logf("open profile: close_previous_us={d}", .{nowUs() - request_start});
    first_clean = true;
    previous_page = -1;
    previous_metrics = .{};
    text_since_clean = 0;
    if (path.len >= book.path.len) return false;
    @memcpy(book.path[0..path.len], path);
    book.path[path.len] = 0;
    book.path_len = path.len;
    const base = if (std.mem.lastIndexOfScalar(u8, path, '/')) |i| path[i + 1 ..] else path;
    const stem = if (std.mem.lastIndexOfScalar(u8, base, '.')) |i| base[0..i] else base;
    const nl = @min(stem.len, book.name.len);
    @memcpy(book.name[0..nl], stem[0..nl]);
    book.name_len = nl;

    const st = loadState(path);
    const zpath: [*:0]const u8 = @ptrCast(&book.path);
    book.fsize = zr_file_size(zpath);
    book.fmtime = zr_file_mtime(zpath);
    pc_open_us = request_start;
    pc_preview_active = false;
    pc_first_frame_pending = true;
    pc_turns = 0;
    pcShowPreview(st);
    const open_start = nowUs();
    const doc = (if (st.typography and st.page == 0 and st.anchor.chapter < 0) zr_open_initial(zpath, LW, LH, st.font, st.margin, st.spacing) else if (st.typography and st.anchor.chapter >= 0) zr_open_upto(zpath, LW, LH, st.font, st.margin, st.spacing, st.anchor.chapter) else if (st.typography) zr_open_style(zpath, LW, LH, st.font, st.margin, st.spacing) else zr_open(zpath, LW, LH, st.font, st.margin)) orelse {
        logf("cannot open {s}", .{path});
        return false;
    };
    logf("open profile: load+pagination_us={d}", .{nowUs() - open_start});
    book.doc = doc;
    book.is_pdf = zr_is_pdf(doc) != 0;
    book.reflow = zr_reflowable(doc) != 0;

    const np = zr_page_count(doc);
    if (np <= 0) {
        zr_close(doc);
        return false;
    }
    _ = pthread_mutex_lock(&pool.mtx);
    pool.gen +%= 1;
    for (&pool.slots) |*s| {
        s.state = .empty;
        s.page = -1;
        s.draft = false;
    }
    draft_slot = null;
    pool.npages = np;
    pool.paginating = zr_pagination_pending(doc) != 0;
    pool.cur = std.math.clamp(st.page, 0, np - 1);
    pool.dir = 1;
    pool.spacing = st.spacing;
    pool.font = st.font;
    pool.margin = st.margin;
    pool.trim = book.is_pdf and st.trim;
    pool.split = st.split;
    resetSpreads();
    pool.view = if (book.is_pdf) st.view else .page;
    pool.base_width = st.base_width;
    pool.step = if (book.is_pdf) st.step else 0;
    pool.pan_x = st.pan_x;
    pool.pan_y = st.pan_y;
    pool.no_images = opts.no_images;
    pool.shown = -1;
    pool.path = zpath;
    pool.trims = if (book.is_pdf) (alloc.alloc(Trim, @intCast(np)) catch &.{}) else &.{};
    for (pool.trims) |*t| t.* = .{};
    _ = pthread_mutex_unlock(&pool.mtx);
    if (book.words.len == 0) {
        book.words = alloc.alloc(ZrWord, MAXW) catch &.{};
        book.wtext = alloc.alloc(u8, 256 * 1024) catch &.{};
        book.toc = alloc.alloc(ZrToc, 4000) catch &.{};
        book.toc_text = alloc.alloc(u8, 256 * 1024) catch &.{};
    }
    book.open = true;
    book.opened_ts = zr_now_seconds();
    book.position = .{};
    search_query[0] = 0;
    search_len = 0;
    search_count = 0;
    search_running = false;
    search_hit = null;
    loadNotes();
    loadBookmarks();
    statsOpenBook();
    if (book.reflow) {
        const migrated = if (book.nnotes > 0) migrateNotes() else false;
        const position = if (st.anchor.chapter >= 0) st.anchor else if (!st.typography or book.nnotes > 0) pageAnchor(pool.cur) else Anchor{};
        book.position = position;
        if (!st.typography) {
            zr_set_spacing(doc, st.spacing);
            _ = zr_relayout(doc, LW, LH, st.font, st.margin, pool.cur);
            pool.npages = zr_page_count(doc);
        }
        const anchored_page = if (position.chapter >= 0) zr_anchor_page(doc, &position) else -1;
        if (anchored_page >= 0) pool.cur = anchored_page else pool.cur = std.math.clamp(pool.cur, 0, pool.npages - 1);
        if (book.nnotes > 0) resolveNotePages();
        if (migrated or !st.typography) saveNotes();
    }
    // Reuse the already-open document for the first raster. Do NOT wait for two
    // more independently opened/paginated worker documents before showing it.
    const raster_start = nowUs();
    renderFirstRaster(doc);
    logf("open profile: first_raster_us={d} first_page_ready_us={d}", .{nowUs() - raster_start, nowUs() - open_start});
    spawnWorkers();
    book.state_dirty = true;
    logf("opened {s}: pages={d} pdf={} reflow={} start={d} notes={d}", .{ path, np, book.is_pdf, book.reflow, pool.cur + 1, book.nnotes });
    return true;
}

fn relayout(font: f32, margin: f32) void {
    relayoutStyle(font, margin, pool.spacing);
}
fn relayoutStyle(font: f32, margin: f32, spacing: f32) void {
    if (!book.reflow) return;
    const position = readingAnchor();
    book.position = position;
    _ = migrateNotes();
    zr_set_spacing(book.doc, spacing);
    var np_page = zr_relayout(book.doc, LW, LH, font, margin, pool.cur);
    const anchored_page = zr_anchor_page(book.doc, &position);
    if (anchored_page >= 0) np_page = anchored_page;
    resolveNotePages();
    saveNotes();
    resolveBookmarkPages();
    saveBookmarks();
    _ = pthread_mutex_lock(&pool.mtx);
    pool.font = font;
    pool.margin = margin;
    pool.spacing = spacing;
    pool.gen +%= 1;
    pool.npages = zr_page_count(book.doc);
    pool.cur = np_page;
    pool.shown = -1;
    _ = pthread_cond_broadcast(&pool.cond);
    _ = pthread_mutex_unlock(&pool.mtx);
    book.words_page = -1;
    book.toc_loaded = false;
    book.state_dirty = true;
}

fn loadWords() void {
    if (book.words_page == pool.cur and book.words_gen == pool.gen) return;
    const n = zr_words(book.doc, pool.cur, book.words.ptr, @intCast(book.words.len), book.wtext.ptr, @intCast(book.wtext.len));
    book.nwords = @intCast(@max(n, 0));
    book.words_page = pool.cur;
    book.words_gen = pool.gen;
}
fn loadToc() void {
    if (book.toc_loaded) return;
    const n = zr_outline(book.doc, book.toc.ptr, @intCast(book.toc.len), book.toc_text.ptr, @intCast(book.toc_text.len));
    book.ntoc = @intCast(@max(n, 0));
    book.toc_loaded = true;
    book.toc_real = book.ntoc > 0;
    // v0.10.2: MOBI/AZW3/FB2/TXT outlines come from headings in the HTML and are
    // often a single "Table of Contents" entry; fewer than 3 entries -> detect.
    if (book.reflow and book.ntoc < 3 and (bookKind(book.pathS()) orelse 0) >= 2) {
        book.ntoc = 0;
        book.toc_real = false;
    }
    book.toc_detected = false;
    if (!book.toc_real) loadDetectedToc();
}

// ---- v0.10.1 Contents fallback for books without an outline ----
// Detected on a low-priority thread the first time Contents is opened, cached
// in DATA/state/contents/<key>.tsv (key: book identity + layout). Books with a
// real outline never use it.
var ct_running = false;
var ct_last_pct: i32 = -1;
var ct_status: u8 = 0; // 0 not started, 1 running, 2 done (cache written), 3 failed
fn contentsCachePath(out: []u8) ?[:0]const u8 {
    var kb: [1400]u8 = undefined;
    const k = std.fmt.bufPrint(&kb, "ct1|{s}|{d}|{d}|{d}|{d:.2}|{d:.1}|{d:.2}|{d}|{d}", .{ book.pathS(), book.fsize, book.fmtime, @intFromBool(book.reflow), if (book.reflow) pool.font else 0, if (book.reflow) pool.margin else 0, if (book.reflow) pool.spacing else 0, if (book.reflow) text_mode else 0, if (book.reflow) book_font else 0 }) catch return null;
    return std.fmt.bufPrintSentinel(out, "{s}/state/contents/{x:0>16}.tsv", .{ opts.data, fnv(k) }, 0) catch null;
}
fn loadDetectedToc() void {
    var pb: [1300]u8 = undefined;
    if (!ct_running) ct_status = 0;
    const p = contentsCachePath(&pb) orelse return;
    const data = readFile(p) orelse return;
    defer alloc.free(data);
    ct_status = 2;
    var it = std.mem.splitScalar(u8, data, '\n');
    const head = it.next() orelse return;
    if (!std.mem.startsWith(u8, head, "zrcontents\t1")) return;
    var n: usize = 0;
    var tl: usize = 0;
    while (it.next()) |line| {
        if (n >= book.toc.len) break;
        var f = std.mem.splitScalar(u8, line, '\t');
        const page = std.fmt.parseInt(i32, f.next() orelse continue, 10) catch continue;
        const level = std.fmt.parseInt(i32, f.next() orelse continue, 10) catch continue;
        const label = f.rest();
        if (label.len == 0 or page < 0 or page >= pool.npages or tl + label.len > book.toc_text.len) continue;
        @memcpy(book.toc_text[tl..][0..label.len], label);
        book.toc[n] = .{ .page = page, .level = level, .off = @intCast(tl), .len = @intCast(label.len) };
        tl += label.len;
        n += 1;
    }
    book.ntoc = n;
    book.toc_detected = n > 0;
    logf("contents: detected {d} entr{s} (cached)", .{ n, if (n == 1) "y" else "ies" });
}
fn ensureDetectedToc() void {
    loadToc();
    if (book.toc_real or ct_running or ct_status == 2) return;
    var pb: [1300]u8 = undefined;
    const p = contentsCachePath(&pb) orelse return;
    var db: [1200]u8 = undefined;
    if (std.fmt.bufPrint(&db, "{s}/state/contents", .{opts.data})) |d| mkdirP(d) else |_| {}
    var zb: [1200]u8 = undefined;
    const zp = std.fmt.bufPrintSentinel(&zb, "{s}", .{book.pathS()}, 0) catch return;
    if (zr_contents_start(zp, p, @intFromBool(book.reflow), LW, LH, pool.font, pool.margin, pool.spacing) != 0) return;
    ct_running = true;
    ct_status = 1;
    ct_last_pct = -1;
    logf("contents: no outline; detecting chapter headings in the background", .{});
}
fn contentsTick() void {
    if (!ct_running) return;
    var done: c_int = 0;
    var total: c_int = 0;
    var found: c_int = 0;
    var ms: c_int = 0;
    const st = zr_contents_poll(&done, &total, &found, &ms);
    if (st == 1) {
        const pct: i32 = if (total > 0) @divTrunc(done * 100, total) else 0;
        if (screen == .toc and @divTrunc(pct, 10) != @divTrunc(ct_last_pct, 10)) markDirty(contentsStatusRect(), WF_REAGL);
        ct_last_pct = pct;
        return;
    }
    ct_running = false;
    ct_status = if (st == 2) 2 else 3;
    logf("contents: detection {s}: {d} entr{s} from {d} pages in {d} ms", .{ if (st == 2) "done" else "failed", found, if (found == 1) "y" else "ies", total, ms });
    if (st == 2) {
        book.toc_loaded = false;
        loadToc();
    }
    if (screen == .toc) markFull(WF_REAGL);
}
fn contentsStatusRect() Rect {
    return .{ .x = 0, .y = 340, .w = @intCast(W), .h = 150 };
}
fn openGoto(t: EditTarget) void {
    edit_target = t;
    note_len = 0;
    note_shift = false;
    showScreen(.noteedit);
}
fn closeGoto(save: bool) void {
    const t = edit_target;
    edit_target = .note;
    const s = std.mem.trim(u8, note_buf[0..note_len], " %.");
    const v = std.fmt.parseInt(i32, s, 10) catch -1;
    if (!save) return showScreen(.toc);
    if (t == .goto_page) {
        if (v < 1 or v > pool.npages) {
            showScreen(.toc);
            return toast("Enter a page from 1 to {d}", .{pool.npages});
        }
        showScreen(.reader);
        return goPage(v - 1, nowUs());
    }
    if (v < 0 or v > 100) {
        showScreen(.toc);
        return toast("Enter a percentage from 0 to 100", .{});
    }
    showScreen(.reader);
    const target: i32 = @intCast(@divTrunc(@as(i64, @max(pool.npages - 1, 0)) * v, 100));
    return goPage(target, nowUs());
}

// ---------------- v0.7 library, device controls and opt-in sleep ----------------
const SORT_NAMES = [_][]const u8{ "Recent", "Title", "Progress", "Size: largest first", "Size: smallest first" };
var lib_sort: usize = 0;
var lib_visible: [4000]usize = undefined;
var nvisible: usize = 0;
var folders: [4000][]const u8 = undefined;
var nfolders: usize = 0;
var folder_filter: usize = 0;
var folder_picker = false;
var thumb_revision: u32 = 0;
var power_sleeps = false;
var device_return: Screen = .reader;
var light_values: [2]i32 = .{ -1, -1 };
var light_edited: [2]bool = .{ false, false };
var light_drag: ?usize = null;
const SleepPhase = enum { awake, drawing, waiting, asleep, waking };
var sleep_phase: SleepPhase = .awake;
var sleep_since: u64 = 0;
var sleep_external = false;
var sleep_confirmed = false;
var sim_powerd_events: c_int = 0;
fn ui07Path(out: []u8) [:0]u8 {
    return std.fmt.bufPrintSentinel(out, "{s}/ui07.json", .{opts.data}, 0) catch unreachable;
}
fn saveUi07() void {
    var path: [1200]u8 = undefined;
    var buf: [120]u8 = undefined;
    const data = std.fmt.bufPrint(&buf, "{{\"sort\":{d},\"power_sleeps\":{d},\"clean_scans\":{d},\"text_mode\":{d},\"book_font\":{d}}}\n", .{ lib_sort, @intFromBool(power_sleeps), @intFromBool(opts.clean_scans), text_mode, book_font }) catch return;
    if (!writeFileAtomic(ui07Path(&path), data)) toast("Could not save library/sleep settings", .{});
}
fn init07() void {
    var path: [1200]u8 = undefined;
    if (readFile(ui07Path(&path))) |data| {
        defer alloc.free(data);
        if (jsonNum(data, "sort")) |v| {
            if (v >= 0 and v < SORT_NAMES.len) lib_sort = @intFromFloat(v);
        }
        power_sleeps = (jsonNum(data, "power_sleeps") orelse 0) == 1;
        if (!opts.clean_cli) opts.clean_scans = (jsonNum(data, "clean_scans") orelse 1) != 0;
        if (jsonNum(data, "text_mode")) |v| text_mode = @intFromFloat(std.math.clamp(v, 0, 2));
        if (jsonNum(data, "book_font")) |v| book_font = @intFromFloat(std.math.clamp(v, 0, 2));
    }
    if (opts.text_mode) |m| text_mode = m;
    // Host tests written before 0.10.0 lay out EPUBs independently with the 0.9.x
    // style; the runner sets this so they keep checking that layout (sim only).
    if (opts.sim != null and opts.text_mode == null) {
        if (std.c.getenv("ZREADER_SIM_TEXT_MODE")) |s| text_mode = std.math.clamp(std.fmt.parseInt(c_int, std.mem.span(s), 10) catch text_mode, 0, 2);
    }
    zr_set_text_resources(hyph_la.ptr, hyph_la.len, sans_font.ptr, sans_font.len, sans_bold.ptr, sans_bold.len, sans_italic.ptr, sans_italic.len, sans_bold_italic.ptr, sans_bold_italic.len);
    zr_set_text_style(text_mode, book_font);
    const root = std.fmt.bufPrintSentinel(&path, "{s}", .{opts.data}, 0) catch return;
    zr_layout_cache(root);
    zr_thumbs_init(root);
    zr_device_init(@intFromBool(opts.sim != null));
    if (opts.sim != null) {
        light_values = .{ 14, 18 };
        logf("device controls: simulated 14/18; no hardware commands", .{});
    }
    // Enabling is deferred until findInputs; no startup light value is ever written.
}
fn libraryControl(i: i32) Rect {
    return .{ .x = 70 + i * 380, .y = 220, .w = 360, .h = 85 };
}
fn libraryCount() usize {
    return if (folder_picker) nfolders + 3 + ncoll else nvisible;
}
fn filterLibrary() void {
    nvisible = 0;
    if (folder_filter > nfolders) folder_filter = 0;
    for (lib[0..nlib], 0..) |e, i| {
        if (folder_filter != 0 and !eql(e.folder, folders[folder_filter - 1])) continue;
        if (coll_filter == 0 and !e.fav) continue;
        if (coll_filter > 0 and (e.cmask >> @intCast(coll_filter - 1)) & 1 == 0) continue;
        lib_visible[nvisible] = i;
        nvisible += 1;
    }
    var ob: [400]u8 = undefined;
    var on: usize = 0;
    for (lib_visible[0..@min(nvisible, 5)]) |li| {
        const t = lib[li].title;
        const s = std.fmt.bufPrint(ob[on..], "{s}{s}", .{ if (on > 0) " | " else "", t[0..@min(t.len, 60)] }) catch break;
        on += s.len;
    }
    logf("library view: sort={s} shown={d}: {s}", .{ SORT_NAMES[lib_sort], nvisible, ob[0..on] });
}
fn folderLess(_: void, a: []const u8, b: []const u8) bool {
    return std.ascii.lessThanIgnoreCase(a, b);
}
fn sortLibrary() void {
    std.mem.sort(Entry, lib[0..nlib], {}, libLess);
    nfolders = 0;
    for (lib[0..nlib]) |e| {
        var found = false;
        for (folders[0..nfolders]) |f| if (eql(e.folder, f)) {
            found = true;
            break;
        };
        if (!found) {
            folders[nfolders] = e.folder;
            nfolders += 1;
        }
    }
    std.mem.sort([]const u8, folders[0..nfolders], {}, folderLess);
    filterLibrary();
}
fn drawThumb(path: []const u8, r: Rect) bool {
    var z: [1200]u8 = undefined;
    const p = std.fmt.bufPrintSentinel(&z, "{s}", .{path}, 0) catch return false;
    var pixels: [96 * 128]u8 = undefined;
    if (zr_thumb(p, &pixels) == 0) {
        frame(r, 2, 0xBB);
        return false;
    }
    var y: i32 = 0;
    while (y < r.h) : (y += 1) {
        var x: i32 = 0;
        while (x < r.w) : (x += 1) {
            const xx = r.x + x;
            const yy = r.y + y;
            if (xx >= 0 and yy >= 0 and xx < W and yy < H) fb[@as(usize, @intCast(yy)) * STRIDE + @as(usize, @intCast(xx))] = pixels[@as(usize, @intCast(@divTrunc(y * 128, r.h))) * 96 + @as(usize, @intCast(@divTrunc(x * 96, r.w)))];
        }
    }
    return true;
}
fn lightSlider(i: usize) Rect {
    return .{ .x = 300, .y = 440 + @as(i32, @intCast(i)) * 300, .w = @as(i32, @intCast(W)) - 600, .h = 100 };
}
fn lightButton(i: usize, plus: bool) Rect {
    return .{ .x = if (plus) @as(i32, @intCast(W)) - 230 else 70, .y = lightSlider(i).y, .w = 160, .h = 100 };
}
fn sleepButton() Rect {
    return .{ .x = 70, .y = 1120, .w = @as(i32, @intCast(W)) - 140, .h = 110 };
}
fn lightAt(x: i32) i32 {
    const r = lightSlider(0);
    return std.math.clamp(@divTrunc((x - r.x) * 24 + @divTrunc(r.w, 2), r.w), 0, 24);
}
fn openDevice() void {
    device_return = screen;
    showScreen(.device);
}
fn changeLight(i: usize, value: i32) void {
    const v = std.math.clamp(value, 0, 24);
    if (v == light_values[i]) return;
    light_values[i] = v;
    light_edited[i] = true;
    if (opts.sim == null) zr_device_light(@intCast(i), v);
    logf("light change: {d}={d}{s}", .{ i, v, if (opts.sim != null) " simulated" else " queued" });
    markFull(WF_REAGL);
}
fn statsButton() Rect {
    return .{ .x = 560, .y = 40, .w = 420, .h = 90 };
}
fn drawDevice() void {
    header("Settings", true);
    button(statsButton(), "Reading stats", false);
    for (0..2) |i| {
        var b: [100]u8 = undefined;
        const label = if (light_values[i] < 0) std.fmt.bufPrint(&b, "{s}: unavailable", .{if (i == 0) "Frontlight" else "Warmth"}) catch "" else std.fmt.bufPrint(&b, "{s}: {d} / 24", .{ if (i == 0) "Frontlight" else "Warmth", light_values[i] }) catch "";
        text(SANS, 40, 70, @floatFromInt(lightSlider(i).y - 45), label, 0);
        button(lightButton(i, false), "-", false);
        button(lightButton(i, true), "+", false);
        const r = lightSlider(i);
        const x = r.x + @divTrunc(r.w * @max(light_values[i], 0), 24);
        fill(.{ .x = r.x, .y = r.y + 44, .w = r.w, .h = 12 }, 0xCC);
        fill(.{ .x = r.x, .y = r.y + 44, .w = x - r.x, .h = 12 }, 0x33);
        fill(.{ .x = x - 14, .y = r.y + 18, .w = 28, .h = 64 }, 0);
    }
    text(SANS, 28, 70, 960, "powerd controls the curves. No dark-mode changes.", 0x55);
    text(SANS, 28, 70, 1010, "Values are written only when you change them.", 0x55);
    button(sleepButton(), if (power_sleeps) "Power button sleeps: ON" else "Power button sleeps: OFF", power_sleeps);
    text(SANS, 28, 70, 1300, "Opt-in / experimental: test wake with SSH available.", 0x55);
    text(SANS, 28, 70, 1350, "OFF keeps the original power-button exit behavior.", 0x55);
    button(uploadButton(), "Upload books over Wi-Fi", false);
    button(cleanButton(), if (opts.clean_scans) "Clean up scanned pages: ON" else "Clean up scanned pages: OFF", opts.clean_scans);
    drawToast();
}
// ---- v0.9.1 Wi-Fi book upload (server lives only while this screen is open) ----
fn uploadButton() Rect {
    return .{ .x = 70, .y = 1430, .w = @as(i32, @intCast(W)) - 140, .h = 110 };
}
fn cleanButton() Rect {
    return .{ .x = 70, .y = 1565, .w = @as(i32, @intCast(W)) - 140, .h = 110 };
}
fn uploadStatusRect() Rect {
    return .{ .x = 0, .y = 1000, .w = @intCast(W), .h = 260 };
}
var up_rev: c_uint = 0;
var up_ok = false;
var up_addr: [64]u8 = undefined;
var up_addr_len: usize = 0;
fn startUpload() void {
    var bz: [1100]u8 = undefined;
    const books = std.fmt.bufPrintSentinel(&bz, "{s}", .{opts.books}, 0) catch return;
    up_addr_len = 0;
    if (zr_up_address(&up_addr, up_addr.len) == 0) up_addr_len = std.mem.indexOfScalar(u8, &up_addr, 0) orelse 0;
    const ex = exportAllNotes();
    var ez: [1200]u8 = undefined;
    if (std.fmt.bufPrintSentinel(&ez, "{s}/export", .{opts.data}, 0)) |ed| {
        mkdirP(ed);
        zr_up_set_export(ed);
    } else |_| {}
    logf("upload export: {d} book(s) refreshed, {d} error(s)", .{ ex.books, ex.errors });
    const rc = zr_up_start(books, opts.upload_port, opts.upload_max_mib << 20, opts.upload_min_free_mib << 20, @intFromBool(opts.sim == null));
    up_ok = rc == 0;
    up_rev = zr_up_revision();
    logf("upload server: {s} port {d} (rc={d})", .{ if (up_ok) "started" else "failed", opts.upload_port, rc });
}
fn stopUpload() void {
    zr_up_stop();
    const n = zr_up_saved();
    logf("upload server: stopped; {d} book(s) received", .{n});
    if (n > 0) scanLibrary();
}
fn drawUpload() void {
    header("Upload books", true);
    text(SANS, 34, 70, 320, "On a phone or computer on the same Wi-Fi,", 0);
    text(SANS, 34, 70, 375, "open this address in a web browser:", 0);
    var b: [128]u8 = undefined;
    const addr = if (!up_ok) "Could not start (port busy?)" else if (up_addr_len == 0) "Not connected to Wi-Fi" else std.fmt.bufPrint(&b, "http://{s}:{d}", .{ up_addr[0..up_addr_len], opts.upload_port }) catch "";
    textCenter(SANS, 56, .{ .x = 0, .y = 470, .w = @intCast(W), .h = 120 }, addr, 0);
    var l: [128]u8 = undefined;
    text(SANS, 28, 70, 700, std.fmt.bufPrint(&l, "PDF, EPUB, MOBI, AZW3, TXT, CBZ or FB2, up to {d} MB per file.", .{opts.upload_max_mib}) catch "", 0x55);
    text(SANS, 28, 70, 750, std.fmt.bufPrint(&l, "Uploads are refused if less than {d} GB would stay free.", .{opts.upload_min_free_mib / 1024}) catch "", 0x55);
    text(SANS, 28, 70, 800, "The upload page stops as soon as you leave this screen.", 0x55);
    text(SANS, 28, 70, 850, "The same page offers your highlights and notes to download.", 0x55);
    var st: [256]u8 = undefined;
    zr_up_status(&st, st.len);
    const sl = std.mem.indexOfScalar(u8, &st, 0) orelse 0;
    text(SANS, 34, 70, 1080, if (up_ok) st[0..sl] else "Upload page is off", 0);
    var c: [64]u8 = undefined;
    text(SANS, 30, 70, 1150, std.fmt.bufPrint(&c, "Books received: {d}", .{zr_up_saved()}) catch "", 0x55);
    drawToast();
}
fn uploadTap(x: i32, y: i32) void {
    if (topButton(true).contains(x, y)) return showScreen(.library);
}
fn uploadTick() void {
    if (screen != .upload or !up_ok) return;
    const r = zr_up_revision();
    if (r != up_rev) {
        up_rev = r;
        markDirty(uploadStatusRect(), WF_REAGL);
    }
}

fn configureSleep(on: bool) bool {
    if (opts.sim == null) {
        if (on and in.power_fd < 0) {
            toast("Power input unavailable; sleep remains OFF", .{});
            return false;
        }
        var grab: c_int = if (on) 1 else 0;
        if (in.power_fd >= 0 and bad(linux.ioctl(in.power_fd, EVIOCGRAB, @intFromPtr(&grab)))) {
            toast("Cannot claim power input; sleep remains OFF", .{});
            return false;
        }
        zr_device_sleep(@intFromBool(on));
    }
    return true;
}
fn deviceTap(x: i32, y: i32) void {
    if (topButton(true).contains(x, y)) return showScreen(device_return);
    if (statsButton().contains(x, y)) return openStats();
    if (uploadButton().contains(x, y)) return showScreen(.upload);
    if (cleanButton().contains(x, y)) {
        opts.clean_scans = !opts.clean_scans;
        saveUi07();
        if (book.open) {
            _ = pthread_mutex_lock(&pool.mtx);
            pool.gen +%= 1;
            pool.shown = -1;
            _ = pthread_cond_broadcast(&pool.cond);
            _ = pthread_mutex_unlock(&pool.mtx);
        }
        logf("clean up scanned pages: {s}", .{if (opts.clean_scans) "on" else "off"});
        return markFull(WF_REAGL);
    }
    for (0..2) |i| {
        if (light_values[i] >= 0 and lightButton(i, false).contains(x, y)) return changeLight(i, light_values[i] - 1);
        if (light_values[i] >= 0 and lightButton(i, true).contains(x, y)) return changeLight(i, light_values[i] + 1);
    }
    if (sleepButton().contains(x, y) and configureSleep(!power_sleeps)) {
        power_sleeps = !power_sleeps;
        saveUi07();
        markFull(WF_REAGL);
    }
}
fn pausePrefetch(on: bool) void {
    _ = pthread_mutex_lock(&pool.mtx);
    pool.suspended = on;
    _ = pthread_cond_broadcast(&pool.cond);
    _ = pthread_mutex_unlock(&pool.mtx);
}
fn beginSleep(external: bool) void {
    if (!power_sleeps or sleep_phase != .awake) return;
    if (screen == .upload) showScreen(.library);
    pcCaptureNow();
    saveState();
    statsSave();
    search_running = false;
    gs.down = false;
    gs.long_fired = false;
    light_drag = null;
    center_pending = false;
    popup_open = false;
    sel_active = false;
    menu_open = false;
    dictionary_open = false;
    sleep_phase = .drawing;
    sleep_since = nowUs();
    sleep_external = external;
    sleep_confirmed = external;
    need_page = false;
    pausePrefetch(true);
    markFull(WF_GC16);
    logf("sleep: drawing cover; external={}", .{external});
}
fn requestSleep() void {
    if (sleep_phase == .asleep) {
        sleep_phase = .waking;
        sleep_since = nowUs();
        if (opts.sim == null) zr_device_sleep(4) else wakeReader();
        return;
    }
    if (sleep_phase != .awake) return; // Don't double-toggle a pending transition.
    beginSleep(false);
}
fn drawSleeping() void {
    @memset(fb[0 .. STRIDE * H], 255);
    var cover = false;
    if (book.open) {
        const r = Rect{ .x = @divTrunc(@as(i32, @intCast(W)) - 576, 2), .y = 260, .w = 576, .h = 768 };
        cover = drawThumb(book.pathS(), r);
        if (!cover) fill(r, 255);
    }
    textCenter(SERIF_BOLD, 64, .{ .x = 0, .y = if (cover) 1120 else 650, .w = @intCast(W), .h = 120 }, "Sleeping", 0);
    textCenter(SANS, 30, .{ .x = 0, .y = if (cover) 1260 else 800, .w = @intCast(W), .h = 100 }, "Press power to wake", 0x55);
}
fn wakeReader() void {
    if (sleep_phase == .awake) return;
    sleep_phase = .awake;
    sleep_confirmed = false;
    pausePrefetch(false);
    if (opts.sim == null) zr_device_sleep(3);
    first_clean = true;
    need_page = screen == .reader;
    markFull(WF_GC16);
    in.down = false;
    in.was_down = false;
    gs.down = false;
    logf("sleep: wake; restore GC16", .{});
}
fn tick07() void {
    contentsTick();
    if (screen == .library and sleep_phase == .awake and battery_class_drawn != 255 and batteryLevelClass(batteryValue()) != battery_class_drawn) markDirty(lowBatteryRect().grow(20), WF_REAGL);
    const rev = zr_thumb_revision();
    if (rev != thumb_revision) {
        thumb_revision = rev;
        if (screen == .library and sleep_phase == .awake) libCoversArrived();
    }
    var a: c_int = -1;
    var b: c_int = -1;
    const events = if (opts.sim == null) zr_device_poll(&a, &b) else sim_powerd_events;
    sim_powerd_events = 0;
    if (events & 16 != 0) {
        light_edited = .{ false, false };
        toast("Device command failed; showing last confirmed light values", .{});
    }
    for ([_]i32{ a, b }, 0..) |v, i| {
        if (v >= 0 and v == light_values[i]) light_edited[i] = false;
        if (v >= 0 and !light_edited[i] and light_values[i] != v) {
            light_values[i] = v;
            if (screen == .device) markFull(WF_REAGL);
        }
    }
    if (events != 0) logf("powerd events: 0x{x}", .{events});
    if (power_sleeps and events & 1 != 0) {
        beginSleep(true);
        sleep_confirmed = true;
    }
    if (events & (1 | 4 | 128) != 0 and sleep_phase != .awake) sleep_confirmed = true;
    if (events & 2 != 0) wakeReader();
    // Only use active-state fallback after screensaver/suspend was confirmed.
    if (events & 64 != 0 and (sleep_phase == .asleep or sleep_phase == .waking) and sleep_confirmed) wakeReader();
    if (events & (16 | 32) != 0 and power_sleeps) {
        wakeReader();
        _ = configureSleep(false);
        power_sleeps = false;
        saveUi07();
        toast("Powerd error: sleep disabled; use restore-ui if needed", .{});
    }
    if (sleep_phase == .drawing and !in_flight and dirty.empty()) {
        sleep_phase = .waiting;
        sleep_since = nowUs();
        if (!sleep_external and opts.sim == null) zr_device_sleep(2);
        logf("sleep: cover completed; powerd requested", .{});
        if (opts.sim != null or sleep_external) sleep_phase = .asleep;
    }
    if (sleep_phase == .waiting and sleep_confirmed) {
        sleep_phase = .asleep;
        logf("sleep: screensaver confirmed", .{});
    }
    if ((sleep_phase == .drawing or sleep_phase == .waiting or sleep_phase == .waking) and nowUs() - sleep_since > 8_000_000) {
        wakeReader();
        _ = configureSleep(false);
        power_sleeps = false;
        saveUi07();
        toast("Sleep timed out; disabled. Restore-ui available over SSH.", .{});
    }
}

// ---------------- library ----------------
// v0.10.2: book file types in the library (index = Entry.kind).
const BOOK_EXTS = [_][]const u8{ ".pdf", ".epub", ".mobi", ".azw3", ".azw", ".txt", ".cbz", ".fb2" };
const BOOK_LABELS = [_][]const u8{ "PDF", "EPUB", "MOBI", "AZW3", "AZW", "TXT", "CBZ", "FB2" };
fn bookKind(name: []const u8) ?u8 {
    for (BOOK_EXTS, 0..) |e, i| if (std.ascii.endsWithIgnoreCase(name, e)) return @intCast(i);
    return null;
}
fn entryLabel(e: Entry) []const u8 {
    if (e.kind == 0) return if (e.epub) "EPUB" else "PDF";
    return BOOK_LABELS[e.kind];
}
const Entry = struct { path: []u8, title: []const u8, folder: []const u8, opened: i64, progress: i32, bytes: u64 = 0, epub: bool = false, kind: u8 = 0, fav: bool = false, cmask: u64 = 0 };
var books_bytes: u64 = 0;
var storage_free: u64 = 0;
var storage_total: u64 = 0;
var lib: [4000]Entry = undefined;
var nlib: usize = 0;

fn scanDir(path: []const u8, depth: u32) void {
    if (depth > 8) return;
    var zb: [1100]u8 = undefined;
    const z = std.fmt.bufPrintSentinel(&zb, "{s}", .{path}, 0) catch return;
    const rc = linux.open(z, .{ .ACCMODE = .RDONLY, .DIRECTORY = true, .CLOEXEC = true }, 0);
    if (bad(rc)) return;
    const fd: i32 = @intCast(rc);
    defer _ = linux.close(fd);
    var buf: [8192]u8 align(8) = undefined;
    while (true) {
        const n = linux.getdents64(fd, &buf, buf.len);
        if (bad(n) or n == 0) break;
        var off: usize = 0;
        while (off < n) {
            const reclen = std.mem.readInt(u16, buf[off + 16 ..][0..2], .little);
            const dtype = buf[off + 18];
            const name = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(&buf[off + 19])), 0);
            off += reclen;
            if (name.len == 0 or name[0] == '.') continue;
            var pb: [1100]u8 = undefined;
            const full = std.fmt.bufPrint(&pb, "{s}/{s}", .{ path, name }) catch continue;
            if (dtype == 4) {
                scanDir(full, depth + 1);
                continue;
            }
            const kind = bookKind(name) orelse continue;
            if (dtype == 10 or nlib >= lib.len) continue;
            const p = alloc.dupe(u8, full) catch continue;
            const base = p[p.len - name.len ..];
            const dot = std.mem.lastIndexOfScalar(u8, base, '.') orelse base.len;
            const folder_full = p[0 .. p.len - name.len - 1];
            const folder = if (std.mem.startsWith(u8, folder_full, opts.books) and folder_full.len > opts.books.len) folder_full[opts.books.len + 1 ..] else if (std.mem.startsWith(u8, folder_full, "/mnt/us/documents")) folder_full[8..] else "Books";
            var fzb: [1200]u8 = undefined;
            const fz = std.fmt.bufPrintSentinel(&fzb, "{s}", .{p}, 0) catch continue;
            const bytes = zr_file_size(fz);
            books_bytes += bytes;
            const st = loadState(p);
            lib[nlib] = .{ .bytes = bytes, .epub = kind == 1, .kind = if (kind <= 1) 0 else kind, .path = p, .title = base[0..dot], .folder = folder, .opened = st.opened, .progress = if (st.pages > 0) @intCast(std.math.clamp(@divTrunc((@as(i64, st.page) + 1) * 100, st.pages), 0, 100)) else -1 };
            nlib += 1;
        }
    }
}
fn libLess(_: void, a: Entry, b: Entry) bool {
    if (lib_sort == 0 and a.opened != b.opened) return a.opened > b.opened;
    if (lib_sort == 2 and a.progress != b.progress) return a.progress > b.progress;
    if (lib_sort == 3 and a.bytes != b.bytes) return a.bytes > b.bytes;
    if (lib_sort == 4 and a.bytes != b.bytes) return a.bytes < b.bytes;
    return std.ascii.lessThanIgnoreCase(a.title, b.title);
}
fn scanLibrary() void {
    for (lib[0..nlib]) |e| alloc.free(e.path);
    nlib = 0;
    last_cover_page = std.math.maxInt(usize);
    zr_thumbs_revalidate();
    books_bytes = 0;
    _ = zr_storage("/mnt/us", &storage_free, &storage_total);
    scanDir(opts.books, 0);
    if (eql(opts.books, "/mnt/us/Books")) scanDir("/mnt/us/documents", 0);
    applyCollections();
    sortLibrary();
    logf("library: {d} books under {s}", .{ nlib, opts.books });
}

// ---------------- UI state ----------------
const Screen = enum { library, reader, toc, notes, search, device, upload, bookmarks, noteedit, stats };
var screen: Screen = .library;
var menu_open = false;
var popup_open = false;
var editing_note: ?usize = null;
const Handle = enum { none, start, end };
var dragging_handle: Handle = .none;
var handle_dx: i32 = 0;
var handle_dy: i32 = 0;
var visible_page: i32 = -1;
var shown_gen: u32 = 0;
var list_page: usize = 0;
var sel_active = false;
var sel_a: usize = 0;
var sel_b: usize = 0;
var slider_active = false;
var slider_page: i32 = 0;
var toast_buf: [128]u8 = undefined;
var toast_len: usize = 0;
var toast_until: u64 = 0;
var quit_requested = false;

var need_page = false;
var first_clean = true;
var dirty: Rect = .{};
var dirty_mode: u32 = WF_DU;
var in_flight = false;
var t_submit: u64 = 0;
var t_tap: u64 = 0;
var tap_pending_measure = false;

var st_tap_submit: Stats = .{};
var st_tap_complete: Stats = .{};
var st_update: Stats = .{};
var turns: u32 = 0;
var coalesced: u32 = 0;

fn wfRank(m: u32) u32 {
    return switch (m) {
        WF_GC16 => 4,
        WF_REAGL => 3,
        WF_GL16 => 2,
        else => 1,
    };
}
fn markDirty(r: Rect, mode: u32) void {
    dirty = Rect.unite(dirty, r.clip());
    if (wfRank(mode) > wfRank(dirty_mode)) dirty_mode = mode;
}
fn markFull(mode: u32) void {
    markDirty(Rect.full(), mode);
}
fn toastRect() Rect {
    return .{ .x = @divTrunc(@as(i32, @intCast(W)) - 760, 2), .y = @as(i32, @intCast(H)) - 260, .w = 760, .h = 110 };
}
fn toast(comptime fmt: []const u8, args: anytype) void {
    const s = std.fmt.bufPrint(&toast_buf, fmt, args) catch return;
    toast_len = s.len;
    toast_until = nowUs() + 1_600_000;
    markDirty(toastRect(), WF_GL16);
}

fn topBar() Rect {
    return .{ .x = 0, .y = 0, .w = @intCast(W), .h = 170 };
}
fn bottomPanel() Rect {
    const h: i32 = 760;
    return .{ .x = 0, .y = @as(i32, @intCast(H)) - h, .w = @intCast(W), .h = h };
}
fn spacingButton() Rect {
    return .{ .x = 406, .y = @as(i32, @intCast(H)) - 182, .w = 460, .h = 75 };
}
// v0.10.0 EPUB text controls either side of line spacing.
fn bookFontButton() Rect {
    return .{ .x = 70, .y = @as(i32, @intCast(H)) - 182, .w = 320, .h = 75 };
}
fn textModeButton() Rect {
    return .{ .x = 882, .y = @as(i32, @intCast(H)) - 182, .w = @as(i32, @intCast(W)) - 70 - 882, .h = 75 };
}
var text_mode: c_int = 2; // 0 publisher/0.9.x, 1 justify, 2 justify + hyphenation
var book_font: c_int = 0; // 0 book's own, 1 Charis SIL (serif), 2 Noto Sans
const TEXT_MODE_NAMES = [_][]const u8{ "Align: original", "Align: justify", "Justify + hyphens" };
const BOOK_FONT_NAMES = [_][]const u8{ "Font: book", "Font: Charis", "Font: Noto Sans" };
fn setTextStyle(mode: c_int, font: c_int) void {
    text_mode = mode;
    book_font = font;
    zr_set_text_style(mode, font);
    saveUi07();
    logf("text style: mode={d} ({s}) font={d} ({s})", .{ mode, TEXT_MODE_NAMES[@intCast(mode)], font, BOOK_FONT_NAMES[@intCast(font)] });
    if (!book.reflow or !book.open) return;
    zr_touch_layout(book.doc);
    relayoutStyle(pool.font, pool.margin, pool.spacing);
    need_page = true;
}
fn refreshButton() Rect {
    return .{ .x = 70, .y = @as(i32, @intCast(H)) - 95, .w = @as(i32, @intCast(W)) - 140, .h = 75 };
}
fn sliderRect() Rect {
    const p = bottomPanel();
    return .{ .x = 70, .y = p.y + 110, .w = @as(i32, @intCast(W)) - 140, .h = 70 };
}
fn panelButton(row: i32, col: i32) Rect {
    const p = bottomPanel();
    const gap: i32 = 24;
    const bw = @divTrunc(@as(i32, @intCast(W)) - 140 - 3 * gap, 4);
    return .{ .x = 70 + col * (bw + gap), .y = p.y + 210 + row * 130, .w = bw, .h = 100 };
}
fn topButton(right: bool) Rect {
    return if (right) .{ .x = @as(i32, @intCast(W)) - 250, .y = 40, .w = 210, .h = 90 } else .{ .x = 40, .y = 40, .w = 250, .h = 90 };
}

var shown_m: [6]f32 = .{ 1, 0, 0, 1, 0, 0 };
fn toScreen(q: [4]f32) Rect {
    const m = shown_m;
    const x0 = q[0] * m[0] + m[4];
    const y0 = q[1] * m[3] + m[5];
    const x1 = q[2] * m[0] + m[4];
    const y1 = q[3] * m[3] + m[5];
    return .{ .x = @intFromFloat(@floor(x0)), .y = @intFromFloat(@floor(y0)), .w = @intFromFloat(@ceil(x1 - x0)), .h = @intFromFloat(@ceil(y1 - y0)) };
}
fn toPage(x: i32, y: i32) [2]f32 {
    const m = shown_m;
    return .{ (@as(f32, @floatFromInt(x)) - m[4]) / m[0], (@as(f32, @floatFromInt(y)) - m[5]) / m[3] };
}
fn wordRect(i: usize) [4]f32 {
    const w = book.words[i];
    return .{ w.x0, w.y0, w.x1, w.y1 };
}
// Hit testing always uses the matrix belonging to the *visible* cached page.
// Never snap a press on whitespace to an unrelated word elsewhere on the page.
fn textReady() bool {
    return !need_page and visible_page == pool.cur and shown_gen == pool.gen;
}
fn wordAt(x: i32, y: i32, nearest: bool) ?usize {
    if (!textReady() or x < 0 or y < 0 or x >= W or y >= H) return null;
    const p = toPage(x, y);
    var best: ?usize = null;
    var bd: f32 = std.math.floatMax(f32);
    const slop: f32 = if (nearest) 26 / shown_m[0] else 0;
    for (0..book.nwords) |i| {
        const w = book.words[i];
        const dx = @max(@max(w.x0 - p[0], p[0] - w.x1), 0);
        const dy = @max(@max(w.y0 - p[1], p[1] - w.y1), 0);
        if (dx > slop or dy > slop) continue;
        const d = dx * dx + dy * dy * 16;
        if (d < bd or (d == bd and best != null and
            (w.x1 - w.x0) * (w.y1 - w.y0) <
                (book.words[best.?].x1 - book.words[best.?].x0) * (book.words[best.?].y1 - book.words[best.?].y0)))
        {
            bd = d;
            best = i;
        }
    }
    return best;
}
fn sameTextLine(a: [4]f32, b: [4]f32) bool {
    const overlap = @min(a[3], b[3]) - @max(a[1], b[1]);
    return overlap > 0.65 * @max(a[3] - a[1], b[3] - b[1]);
}
fn handleRect(which: Handle) Rect {
    if (!sel_active or book.nwords == 0) return .{};
    const r = toScreen(wordRect(if (which == .start) @min(sel_a, sel_b) else @max(sel_a, sel_b)));
    const x = if (which == .start) r.x else r.x + r.w;
    return .{ .x = x - 15, .y = r.y + r.h + 8, .w = 30, .h = 38 };
}
fn annotationAt(x: i32, y: i32) ?usize {
    if (!textReady()) return null;
    // Newest overlay wins, just like the visual stacking order.
    var i = book.nnotes;
    while (i > 0) {
        i -= 1;
        const n = &book.notes[i];
        if (n.style == 2) continue;
        var qs: [64][4]f32 = undefined;
        const nq = noteQuads(n, visible_page, &qs);
        for (qs[0..nq]) |q| if (toScreen(q).grow(12).contains(x, y)) return i;
    }
    return null;
}
// Merges selected words into one rect per line (page coords).
fn selectionQuads(a0: usize, b0: usize, out: [][4]f32) usize {
    const a = @min(a0, b0);
    const b = @max(a0, b0);
    var n: usize = 0;
    var i = a;
    while (i <= b and i < book.nwords) : (i += 1) {
        const r = wordRect(i);
        if (n > 0 and i > a and sameTextLine(out[n - 1], r)) {
            const q = &out[n - 1];
            q[0] = @min(q[0], r[0]);
            q[1] = @min(q[1], r[1]);
            q[2] = @max(q[2], r[2]);
            q[3] = @max(q[3], r[3]);
        } else if (n < out.len) {
            out[n] = r;
            n += 1;
        }
    }
    return n;
}
fn selectionScreenRect() Rect {
    var qs: [64][4]f32 = undefined;
    const n = selectionQuads(sel_a, sel_b, &qs);
    var r: Rect = .{};
    for (qs[0..n]) |q| r = Rect.unite(r, toScreen(q));
    if (sel_active) {
        r = Rect.unite(r, handleRect(.start).grow(30));
        r = Rect.unite(r, handleRect(.end).grow(30));
    }
    return r.grow(16);
}
fn selectionText(out: []u8) []const u8 {
    const a = @min(sel_a, sel_b);
    const b = @max(sel_a, sel_b);
    var n: usize = 0;
    var i = a;
    while (i <= b and i < book.nwords) : (i += 1) {
        const w = book.words[i];
        const s = book.wtext[@intCast(w.off)..][0..@intCast(w.len)];
        if (i > a and n < out.len) {
            out[n] = ' ';
            n += 1;
        }
        const k = @min(s.len, out.len - n);
        @memcpy(out[n..][0..k], s[0..k]);
        n += k;
    }
    return out[0..n];
}
fn popupRect() Rect {
    var sr = selectionScreenRect();
    if (editing_note) |k| {
        sr = .{};
        var qs: [64][4]f32 = undefined;
        const nq = noteQuads(&book.notes[k], pool.cur, &qs);
        for (qs[0..nq]) |q| sr = Rect.unite(sr, toScreen(q));
    }
    const w: i32 = 1220;
    const h: i32 = 124;
    const x = @divTrunc(@as(i32, @intCast(W)) - w, 2);
    var y = sr.y + sr.h + 20;
    if (y + h > @as(i32, @intCast(H)) - 20) y = sr.y - h - 20;
    if (y < 20) y = 20;
    return .{ .x = x, .y = y, .w = w, .h = h };
}
// v0.9.6 popup. Action indices are stable (0 underline/remove, 1 highlight/
// style, 2 copy to notes, 3 cancel, 4 look up, 5 note); this is the column order.
fn popupOrder() []const i32 {
    if (editing_note != null) return &[_]i32{ 5, 0, 1, 2, 3 };
    if (sel_active and sel_a == sel_b) return &[_]i32{ 1, 0, 5, 4, 2, 3 };
    return &[_]i32{ 1, 0, 5, 2, 3 };
}
fn popupCount() i32 {
    return @intCast(popupOrder().len);
}
fn popupButton(i: i32) Rect {
    const p = popupRect();
    const order = popupOrder();
    const count: i32 = @intCast(order.len);
    const bw = @divTrunc(p.w - 24, count);
    var col: i32 = count - 1;
    for (order, 0..) |o, c| if (o == i) {
        col = @intCast(c);
    };
    if (std.mem.indexOfScalar(i32, order, i) == null) return .{ .x = -1000, .y = -1000, .w = 0, .h = 0 };
    return .{ .x = p.x + 12 + col * bw + 6, .y = p.y + 12, .w = bw - 12, .h = p.h - 24 };
}
fn popupLabel(i: i32) []const u8 {
    if (editing_note) |k| return switch (i) {
        0 => "Remove",
        1 => if (book.notes[k].style == 0) "Highlight" else "Underline",
        2 => "Copy to notes",
        5 => if (book.notes[k].comment.len > 0) "Edit note" else "Add note",
        else => "Cancel",
    };
    return switch (i) {
        0 => "Underline",
        1 => "Highlight",
        2 => "Copy to notes",
        4 => "Look up",
        5 => "Note",
        else => "Cancel",
    };
}

// Offline dictionary modal. Parsed only after a single-word Define action.
var dictionary_open = false;
var dictionary_tried = false;
var dictionary_ready = false;
var definition: [32768]u8 = undefined;
var definition_len: usize = 0;
var definition_title: [128]u8 = undefined;
var definition_title_len: usize = 0;
const DefLine = struct { off: usize, len: usize };
var definition_lines: [512]DefLine = undefined;
var definition_nlines: usize = 0;
var definition_page: usize = 0;
fn definitionRect() Rect {
    return .{ .x = 40, .y = 180, .w = @as(i32, @intCast(W)) - 80, .h = @as(i32, @intCast(H)) - 220 };
}
// v0.10.3: optional Latin dictionary (Whitaker's Words) with an EN / LA toggle in the popup.
var latin_tried = false;
var latin_ready = false;
var definition_latin = false;
var definition_word: [256]u8 = undefined;
var definition_word_len: usize = 0;
var book_lang_path: [1200]u8 = undefined;
var book_lang_path_len: usize = 0;
var book_lang: [8]u8 = undefined;
var book_lang_len: usize = 0;
fn definitionLang(latin: bool) Rect {
    return .{ .x = @as(i32, @intCast(W)) - (if (latin) @as(i32, 400) else 520), .y = 200, .w = 110, .h = 80 };
}
fn bookIsLatin() bool {
    const p = book.pathS();
    if (p.len == 0) return false;
    if (!(book_lang_path_len == p.len and std.mem.eql(u8, book_lang_path[0..p.len], p))) {
        book_lang_len = 0;
        var z: [1200]u8 = undefined;
        if (std.fmt.bufPrintSentinel(&z, "{s}", .{p}, 0)) |zp| {
            const n = zr_book_language(zp, &book_lang, @intCast(book_lang.len));
            if (n > 0) book_lang_len = @intCast(n);
        } else |_| {}
        if (p.len <= book_lang_path.len) {
            @memcpy(book_lang_path[0..p.len], p);
            book_lang_path_len = p.len;
        }
        logf("dictionary: book language '{s}'", .{book_lang[0..book_lang_len]});
    }
    const l = book_lang[0..book_lang_len];
    return std.mem.eql(u8, l, "la") or std.mem.eql(u8, l, "lat");
}
fn lookupWord(word: []const u8, latin: bool) c_int {
    if (latin) {
        if (!latin_ready) return -1;
        return zrl_define(word.ptr, @intCast(word.len), &definition_title, @intCast(definition_title.len), &definition, @intCast(definition.len));
    }
    return if (dictionary_ready) zrd_define(word.ptr, @intCast(word.len), &definition_title, @intCast(definition_title.len), &definition, @intCast(definition.len)) else -1;
}
fn showDefinition(word: []const u8, latin: bool, length: c_int) void {
    definition_latin = latin;
    definition_title_len = if (length > 0) std.mem.indexOfScalar(u8, &definition_title, 0) orelse 127 else 0;
    if (length <= 0) {
        const n = @min(word.len, definition_title.len);
        @memcpy(definition_title[0..n], word[0..n]);
        definition_title_len = n;
        const message = if (latin)
            (if (length < 0) "Latin dictionary unavailable. Install dictionary/latin.zdict and restart zreader. No network is used." else "No entry found in the offline Latin dictionary. Tap EN for English, or try another form of the word.")
        else if (length < 0) "Dictionary unavailable. Install dictionary/wordnet.zdict and restart zreader. No network is used." else "No definition found in the offline English dictionary. Try a different word; names and specialist terms may not be included.";
        @memcpy(definition[0..message.len], message);
        definition_len = message.len;
    } else definition_len = @intCast(length);
    definition_page = 0;
    wrapDefinition();
}
fn definitionClose() Rect {
    return .{ .x = @as(i32, @intCast(W)) - 280, .y = 200, .w = 200, .h = 80 };
}
fn definitionNav(next: bool) Rect {
    const r = definitionRect();
    return .{ .x = if (next) r.x + r.w - 250 else r.x + 30, .y = r.y + r.h - 110, .w = 220, .h = 80 };
}
fn definitionPerPage() usize {
    return @intCast(@max(@divTrunc(definitionRect().h - 280, 44), 1));
}
fn wrapDefinition() void {
    definition_nlines = 0;
    var paragraphs = std.mem.splitScalar(u8, definition[0..definition_len], '\n');
    while (paragraphs.next()) |p| {
        const base = @intFromPtr(p.ptr) - @intFromPtr(&definition);
        if (p.len == 0 and definition_nlines < definition_lines.len) {
            definition_lines[definition_nlines] = .{ .off = base, .len = 0 };
            definition_nlines += 1;
        }
        var start: usize = 0;
        while (start < p.len and definition_nlines < definition_lines.len) {
            var end = start;
            var last_space = start;
            while (end < p.len) {
                const step = std.unicode.utf8ByteSequenceLength(p[end]) catch 1;
                const next = @min(end + step, p.len);
                if (textW(SANS, 32, p[start..next]) > @as(f32, @floatFromInt(definitionRect().w - 80)) and end > start) break;
                if (p[end] == ' ') last_space = end;
                end = next;
            }
            if (end < p.len and last_space > start) end = last_space;
            definition_lines[definition_nlines] = .{ .off = base + start, .len = end - start };
            definition_nlines += 1;
            start = end;
            while (start < p.len and p[start] == ' ') start += 1;
        }
    }
}
fn defineSelection() void {
    if (!sel_active or sel_a != sel_b) return;
    if (!dictionary_tried) {
        var path: [1400]u8 = undefined;
        const p = if (opts.dictionary) |explicit| std.mem.span(explicit) else std.fmt.bufPrint(&path, "{s}/dictionary/wordnet.zdict", .{opts.data}) catch "";
        var z: [1400]u8 = undefined;
        if (std.fmt.bufPrintSentinel(&z, "{s}", .{p}, 0)) |zp| dictionary_ready = zrd_open(zp) != 0 else |_| {}
        dictionary_tried = true;
    }
    if (!latin_tried) {
        var path: [1400]u8 = undefined;
        const p = if (opts.latin_dictionary) |explicit| std.mem.span(explicit) else std.fmt.bufPrint(&path, "{s}/dictionary/latin.zdict", .{opts.data}) catch "";
        var z: [1400]u8 = undefined;
        if (std.fmt.bufPrintSentinel(&z, "{s}", .{p}, 0)) |zp| latin_ready = zrl_open(zp) != 0 else |_| {}
        latin_tried = true;
    }
    var selected: [8192]u8 = undefined;
    const word = selectionText(&selected);
    definition_word_len = @min(word.len, definition_word.len);
    @memcpy(definition_word[0..definition_word_len], word[0..definition_word_len]);
    // Latin first in a Latin book; otherwise English, then Latin when English has no entry.
    var latin = latin_ready and bookIsLatin();
    var length = lookupWord(word, latin);
    if (length <= 0 and latin_ready) {
        const other = lookupWord(word, !latin);
        if (other > 0) {
            latin = !latin;
            length = other;
        } else length = lookupWord(word, latin);
    }
    showDefinition(word, latin, length);
    dictionary_open = true;
    popup_open = false;
    sel_active = false;
    center_pending = false;
    editing_note = null;
    logf("dictionary: {s}, result={d}, lines={d}{s}", .{ definition_title[0..definition_title_len], length, definition_nlines, if (latin) " (latin)" else "" });
    closeOverlayRefresh(Rect.full());
}
fn drawDefinition() void {
    const r = definitionRect();
    fill(r.grow(8), 0xFF);
    frame(r, 4, 0);
    textFit(SERIF_BOLD, 44, @floatFromInt(r.x + 35), @floatFromInt(r.y + 80), definition_title[0..definition_title_len], @floatFromInt(r.w - (if (latin_ready) @as(i32, 560) else 320)), 0);
    button(definitionClose(), "Close", false);
    if (latin_ready) {
        button(definitionLang(false), "EN", !definition_latin);
        button(definitionLang(true), "LA", definition_latin);
    }
    const per = definitionPerPage();
    var i: usize = 0;
    while (i < per) : (i += 1) {
        const k = definition_page * per + i;
        if (k >= definition_nlines) break;
        const line = definition_lines[k];
        text(SANS, 32, @floatFromInt(r.x + 40), @floatFromInt(r.y + 160 + @as(i32, @intCast(i)) * 44), definition[line.off..][0..line.len], 0);
    }
    text(SANS, 24, @floatFromInt(r.x + 35), @floatFromInt(r.y + r.h - 140), if (definition_latin) "Whitaker's Words / Latin / offline" else "WordNet 3.0 / English / offline", 0x55);
    if (definition_page > 0) button(definitionNav(false), "Previous", false);
    if ((definition_page + 1) * per < definition_nlines) button(definitionNav(true), "Next", false);
    var b: [48]u8 = undefined;
    const page = std.fmt.bufPrint(&b, "{d} / {d}", .{ definition_page + 1, @max(@divTrunc(definition_nlines + per - 1, per), 1) }) catch "";
    textCenter(SANS, 28, .{ .x = r.x + 280, .y = r.y + r.h - 110, .w = r.w - 560, .h = 80 }, page, 0x55);
}
fn definitionTap(x: i32, y: i32) void {
    if (definitionClose().contains(x, y)) {
        dictionary_open = false;
        return closeOverlayRefresh(Rect.full());
    }
    if (latin_ready) {
        const to_latin = definitionLang(true).contains(x, y);
        if ((to_latin or definitionLang(false).contains(x, y)) and to_latin != definition_latin) {
            const word = definition_word[0..definition_word_len];
            showDefinition(word, to_latin, lookupWord(word, to_latin));
            logf("dictionary: switched to {s}: {s}, lines={d}", .{ if (to_latin) "latin" else "english", definition_title[0..definition_title_len], definition_nlines });
            return markDirty(definitionRect().grow(8), WF_REAGL);
        }
    }
    if (definitionNav(false).contains(x, y) and definition_page > 0) {
        definition_page -= 1;
    } else if (definitionNav(true).contains(x, y) and (definition_page + 1) * definitionPerPage() < definition_nlines) {
        definition_page += 1;
    } else return;
    markDirty(definitionRect().grow(8), WF_REAGL);
}

// ---------------- composing ----------------
fn drawOverlays() void {
    drawSearchHit();
    if (bookmarkIndex(pool.cur) != null) drawRibbon();
    for (book.notes[0..book.nnotes]) |*n| {
        if (n.style == 2) continue;
        var qs: [64][4]f32 = undefined;
        const nq = noteQuads(n, pool.cur, &qs);
        for (qs[0..nq]) |q| {
            const r = toScreen(q);
            if (n.style == 1) {
                // v0.10.6: on scanned/image pages the multiplied tint (applied once per
                // overlapping OCR quad) built up into a dark box over the print; there
                // the paper is capped at light grey instead, which never builds up.
                if (shownImagePage()) capLight(r.grow(4), 0xC8) else tint(r.grow(4), 0xC8);
            } else {
                fill(.{ .x = r.x, .y = r.y + r.h + 3, .w = r.w, .h = 5 }, 0x00);
            }
        }
    }
    if (sel_active) {
        var qs: [64][4]f32 = undefined;
        const n = selectionQuads(sel_a, sel_b, &qs);
        for (qs[0..n]) |q| {
            const r = toScreen(q).grow(4);
            tint(r, 0x9C);
            // Pure black border remains visible during DU's binary refresh.
            frame(r, 2, 0);
        }
        for ([_]Handle{ .start, .end }) |which| {
            const r = handleRect(which);
            fill(.{ .x = r.x + 12, .y = r.y - 8, .w = 6, .h = 18 }, 0);
            fill(r, 0);
            frame(r, 3, 0xFF);
        }
    }
}

fn drawMenu() void {
    const tb = topBar();
    fill(tb, 0xFF);
    fill(.{ .x = 0, .y = tb.h - 3, .w = tb.w, .h = 3 }, 0x00);
    button(topButton(false), "\xe2\x80\xb9 Library", false);
    button(topButton(true), "Quit", false);
    textFit(SERIF_BOLD, 40, 330, 100, book.nameS(), @as(f32, @floatFromInt(W)) - 640, 0x00);
    if (opts.debug) {
        var b: [200]u8 = undefined;
        const s = std.fmt.bufPrint(&b, "tap\xe2\x86\x92submit p50 {d} ms \xc2\xb7 render p50 {d} ms \xc2\xb7 coalesced {d}", .{ st_tap_submit.p50() / 1000, pool.render_us.p50() / 1000, coalesced }) catch "";
        text(SANS, 24, 330, 150, s, 0x55);
    }

    const p = bottomPanel();
    fill(p, 0xFF);
    fill(.{ .x = 0, .y = p.y, .w = p.w, .h = 3 }, 0x00);
    const shown_page = if (slider_active) slider_page else pool.cur;
    var b1: [64]u8 = undefined;
    const pg = if (pool.paginating) std.fmt.bufPrint(&b1, "Page {d} / counting pages...", .{shown_page + 1}) catch "" else std.fmt.bufPrint(&b1, "Page {d}{s} of {d}", .{ shown_page + 1, halfLabel(), pool.npages }) catch "";
    text(SANS, 36, 70, @floatFromInt(p.y + 80), pg, 0x00);
    var b2: [16]u8 = undefined;
    const pct = std.fmt.bufPrint(&b2, "{d}%", .{@divTrunc((shown_page + 1) * 100, @max(pool.npages, 1))}) catch "";
    text(SANS, 36, @as(f32, @floatFromInt(W)) - 70 - textW(SANS, 36, pct), @floatFromInt(p.y + 80), pct, 0x00);
    const sr = sliderRect();
    const track = Rect{ .x = sr.x, .y = sr.y + 28, .w = sr.w, .h = 14 };
    frame(track, 3, 0x00);
    const frac = @as(f32, @floatFromInt(shown_page)) / @as(f32, @floatFromInt(@max(pool.npages - 1, 1)));
    const kx = sr.x + @as(i32, @intFromFloat(frac * @as(f32, @floatFromInt(sr.w))));
    fill(.{ .x = track.x, .y = track.y, .w = kx - track.x, .h = track.h }, 0x00);
    fill(.{ .x = kx - 18, .y = sr.y + 8, .w = 36, .h = 54 }, 0x00);
    fill(.{ .x = kx - 12, .y = sr.y + 14, .w = 24, .h = 42 }, 0xFF);

    button(panelButton(0, 0), "Contents", false);
    button(panelButton(0, 1), "Notes", false);
    button(panelButton(0, 2), "Refresh", false);
    if (book.is_pdf) button(panelButton(0, 3), if (pool.trim) "Trim: on" else "Trim: off", pool.trim) else button(panelButton(0, 3), "Go to start", false);
    if (book.is_pdf) {
        button(panelButton(1, 0), VIEW_NAMES[@backingInt(pool.view)], false);
        // 0.9.4: "Up"/"Down" removed (page taps and swipes do the same); row 1
        // columns 2-3 are free for future buttons.
        button(panelButton(1, 1), "Reset pan", false);
        button(panelButton(1, 2), if (bookmarkIndex(pool.cur) != null) "Unbookmark" else "Bookmark", bookmarkIndex(pool.cur) != null);
        button(panelButton(1, 3), if (pool.split) "Split: on" else "Split: off", pool.split);
    }
    button(panelButton(2, 0), "Search", false);
    button(panelButton(2, 1), "Export all", false);
    button(panelButton(2, 2), "Settings", false);
    button(panelButton(2, 3), "Bookmarks", false);
    drawRefreshButton();
    if (book.reflow) {
        button(panelButton(1, 0), "Text -", false);
        button(panelButton(1, 1), "Text +", false);
        button(panelButton(1, 2), "Margin -", false);
        button(panelButton(1, 3), "Margin +", false);
        var sb: [128]u8 = undefined;
        const label = std.fmt.bufPrint(&sb, "{d:.0}px / spacing {d:.2}x", .{ pool.font / 0.75, pool.spacing }) catch "Line spacing";
        button(spacingButton(), label, false);
        smallButton(bookFontButton(), BOOK_FONT_NAMES[@intCast(book_font)]);
        smallButton(textModeButton(), TEXT_MODE_NAMES[@intCast(text_mode)]);
    }
}

fn drawRefreshButton() void {
    var b: [80]u8 = undefined;
    const label = if (opts.full_refresh == 0) "Full refresh: off" else std.fmt.bufPrint(&b, "Full refresh: every {d} pages", .{opts.full_refresh}) catch "Full refresh";
    button(refreshButton(), label, false);
}
fn drawPopup() void {
    const p = popupRect();
    fill(p.grow(6), 0xFF);
    frame(p, 4, 0x00);
    for (popupOrder()) |i| {
        const r = popupButton(i);
        const l = popupLabel(i);
        fill(r, 0xFF);
        frame(r, 3, 0);
        const size: f32 = if (textW(SANS, 28, l) > @as(f32, @floatFromInt(r.w - 14))) 24 else 28;
        textCenter(SANS, size, r, l, 0);
    }
}

fn drawToast() void {
    if (toast_len == 0) return;
    const r = toastRect();
    fill(r, 0x00);
    textCenter(SANS, if (toast_len > 44) 29 else 34, r, toast_buf[0..toast_len], 0xFF); // v0.10.2: long messages fit the box
}

fn formatBytes(value: u64, buf: []u8) []const u8 {
    if (value >= 1024 * 1024 * 1024) return std.fmt.bufPrint(buf, "{d:.1} GiB", .{@as(f64, @floatFromInt(value)) / (1024 * 1024 * 1024)}) catch "";
    if (value >= 1024 * 1024) return std.fmt.bufPrint(buf, "{d:.1} MiB", .{@as(f64, @floatFromInt(value)) / (1024 * 1024)}) catch "";
    if (value >= 1024) return std.fmt.bufPrint(buf, "{d:.0} KiB", .{@as(f64, @floatFromInt(value)) / 1024}) catch "";
    return std.fmt.bufPrint(buf, "{d} B", .{value}) catch "";
}
fn drawBattery() void {
    // Cached read-only powerd value. No independent dirty mark or screen update.
    const value = batteryValue();
    const x: i32 = @as(i32, @intCast(W)) - 205;
    const y: i32 = 4;
    fill(.{ .x = x - 8, .y = y - 4, .w = 205, .h = 38 }, 255);
    const icon = Rect{ .x = x, .y = y + 3, .w = 54, .h = 27 };
    frame(icon, 2, 0x33);
    fill(.{ .x = x + 54, .y = y + 10, .w = 5, .h = 12 }, 0x33);
    if (value >= 0) fill(.{ .x = x + 5, .y = y + 8, .w = @divTrunc(44 * value, 100), .h = 17 }, 0x33);
    var b: [16]u8 = undefined;
    const label = if (value >= 0) std.fmt.bufPrint(&b, "{d}%", .{value}) catch "" else "--%";
    text(SANS, 27, @floatFromInt(x + 71), @floatFromInt(y + 28), label, 0x33);
}
fn batteryValue() c_int {
    return if (opts.sim != null) opts.sim_battery else zr_battery();
}
// v0.9.9: library-only low-battery notice under the battery (never over book text).
fn batteryLevelClass(v: c_int) u8 {
    return if (v < 0) 0 else if (v <= 5) 2 else if (v <= 15) 1 else 0;
}
var battery_class_drawn: u8 = 255;
fn lowBatteryRect() Rect {
    return .{ .x = 420, .y = 150, .w = @as(i32, @intCast(W)) - 490, .h = 44 };
}
fn drawLowBattery() void {
    const v = batteryValue();
    const c = batteryLevelClass(v);
    battery_class_drawn = c;
    if (c == 0) return;
    var b: [80]u8 = undefined;
    const s = std.fmt.bufPrint(&b, "{s} ({d}%) · charge soon", .{ if (c == 2) "Battery very low" else "Battery low", v }) catch "";
    const r = lowBatteryRect();
    const w = textW(SANS, 28, s);
    const x = @as(f32, @floatFromInt(r.x + r.w)) - w;
    if (c == 2) {
        fill(.{ .x = @as(i32, @intFromFloat(x)) - 14, .y = r.y, .w = @as(i32, @intFromFloat(w)) + 28, .h = r.h }, 0x00);
        text(SANS, 28, x, @floatFromInt(r.y + 32), s, 0xFF);
    } else text(SANS, 28, x, @floatFromInt(r.y + 32), s, 0x00);
}
fn drawReader() bool {
    _ = pthread_mutex_lock(&pool.mtx);
    if (book.reflow) zr_page_count_hint(book.doc, pool.npages);
    if (pool.paginating and slotFor(pool.cur) == null) renderFirstRaster(book.doc);
    if (book.is_pdf) preemptForCurrent();
    var ok = false;
    if (slotFor(pool.cur)) |i| {
        const s = &pool.slots[i];
        if (s.state == .ready or s.state == .failed) {
            pool.tick += 1;
            s.used = pool.tick;
            pool.shown = @intCast(i);
            shown_m = s.m;
            visible_page = s.page;
            shown_gen = s.gen;
            if (s.state == .ready) {
                @memcpy(fb[0 .. STRIDE * H], s.buf[0 .. STRIDE * H]);
            } else {
                @memset(fb[0 .. STRIDE * H], 0xFF);
            }
            ok = true;
            if (s.state == .failed) {
                _ = pthread_mutex_unlock(&pool.mtx);
                textCenter(SERIF, 40, Rect.full(), "This page could not be rendered.", 0x00);
                _ = pthread_mutex_lock(&pool.mtx);
            }
        }
    }
    _ = pthread_mutex_unlock(&pool.mtx);
    if (!ok) return false;
    drawOverlays();
    // v0.9: throttled crash-safe snapshot of the clean page (before menus/toasts).
    if (pc_turns >= PC_EVERY and !sel_active and search_hit == null and visible_page == pool.cur) pcSubmitFb(false);
    if (menu_open) drawMenu();
    if (popup_open) drawPopup();
    if (dictionary_open) drawDefinition();
    drawToast();
    // v0.9: no battery while a book is open (it covered text); library only.
    return true;
}

fn header(title: []const u8, close: bool) void {
    @memset(fb[0 .. STRIDE * H], 0xFF);
    text(SERIF_BOLD, 64, 70, 150, title, 0x00);
    if (close) button(topButton(true), "Close", false);
    fill(.{ .x = 70, .y = 200, .w = @as(i32, @intCast(W)) - 140, .h = 4 }, 0x00);
}
const ROW_H: i32 = 150;
const LIST_TOP: i32 = 220;
fn rowsPerPage() usize {
    if (screen == .library or tocFallback()) return @intCast(@divTrunc(@as(i32, @intCast(H)) - LIST_TOP - 320, ROW_H));
    return @intCast(@divTrunc(@as(i32, @intCast(H)) - LIST_TOP - 210, ROW_H));
}
fn rowRect(i: usize) Rect {
    return .{ .x = 70, .y = LIST_TOP + @as(i32, if (screen == .library or tocFallback()) 110 else 0) + @as(i32, @intCast(i)) * ROW_H, .w = @as(i32, @intCast(W)) - 140, .h = ROW_H };
}
// v0.10.1: Contents of a book without an outline has the jump buttons above the list.
fn tocFallback() bool {
    return screen == .toc and book.open and !book.toc_real;
}
fn pagerPrev() Rect {
    return .{ .x = 70, .y = @as(i32, @intCast(H)) - 140, .w = 300, .h = 100 };
}
fn pagerNext() Rect {
    return .{ .x = @as(i32, @intCast(W)) - 370, .y = @as(i32, @intCast(H)) - 140, .w = 300, .h = 100 };
}
fn pager(total: usize) void {
    const per = rowsPerPage();
    const pages = @max((total + per - 1) / per, 1);
    if (list_page >= pages) list_page = pages - 1;
    var b: [32]u8 = undefined;
    const s = std.fmt.bufPrint(&b, "{d} / {d}", .{ list_page + 1, pages }) catch "";
    textCenter(SANS, 34, .{ .x = 0, .y = @as(i32, @intCast(H)) - 140, .w = @intCast(W), .h = 100 }, s, 0x33);
    if (list_page > 0) button(pagerPrev(), "\xe2\x80\xb9 Previous", false);
    if (list_page + 1 < pages) button(pagerNext(), "Next \xe2\x80\xba", false);
}
fn rowSep(r: Rect) void {
    fill(.{ .x = r.x, .y = r.y + r.h - 2, .w = r.w, .h = 2 }, 0xC0);
}

// ---- v0.8.1 library update batching ----
// A library page change produces one composed update. Cached covers are read
// (off the UI thread) during a short hold before the first draw; covers that
// must be generated are merged into at most two non-flashing GL16 updates
// limited to the thumbnail column. Battery and storage are composed into the
// same raster and never cause their own update.
const LIB_HOLD_US: u64 = 300_000;
const LIB_BATCH1_US: u64 = 1_500_000;
var lib_hold = false;
var lib_hold_until: u64 = 0;
var lib_hold_mode: u32 = WF_REAGL;
var lib_drawn_at: u64 = 0;
var lib_batches: u32 = 0;
var lib_shown: [16]bool = @splat(false);
var lib_pending: [16]bool = @splat(false);
fn thumbRect(i: usize) Rect {
    const r = rowRect(i);
    return .{ .x = r.x, .y = r.y + 8, .w = 96, .h = 128 };
}
fn libPath(k: usize, z: *[1200]u8) ?[*:0]const u8 {
    const p = std.fmt.bufPrintSentinel(z, "{s}", .{lib[lib_visible[k]].path}, 0) catch return null;
    return p.ptr;
}
fn libFocus() void {
    const filt = folder_filter + 1000 * @as(usize, @intCast(coll_filter + 1));
    if (last_cover_page != list_page or last_cover_sort != lib_sort or last_cover_folder != filt) {
        zr_thumbs_focus(); last_cover_page = list_page; last_cover_sort = lib_sort; last_cover_folder = filt;
    }
}
// Visible rows first (oldest request = served first), then next and previous
// pages so a later page change is a single cached update.
fn libRequestThumbs() void {
    if (folder_picker) return;
    const per = rowsPerPage();
    const total = libraryCount();
    var scratch: [96 * 128]u8 = undefined;
    var z: [1200]u8 = undefined;
    const pages = [_]i64{ @intCast(list_page), @as(i64, @intCast(list_page)) + 1, @as(i64, @intCast(list_page)) - 1 };
    for (pages) |pg| {
        if (pg < 0) continue;
        for (0..per) |i| {
            const k = @as(usize, @intCast(pg)) * per + i;
            if (k >= total) break;
            if (libPath(k, &z)) |p| _ = zr_thumb(p, &scratch);
        }
    }
}
fn libVisibleState(reading: *usize, generating: *usize) void {
    reading.* = 0;
    generating.* = 0;
    if (folder_picker) return;
    const per = rowsPerPage();
    var z: [1200]u8 = undefined;
    for (0..per) |i| {
        const k = list_page * per + i;
        if (k >= libraryCount()) break;
        const p = libPath(k, &z) orelse continue;
        switch (zr_thumb_peek(p)) {
            1, 0 => reading.* += 1,
            2 => generating.* += 1,
            else => {},
        }
    }
}
fn libPageChange(mode: u32) void {
    if (screen == .library) logf("library page: {d}", .{list_page + 1});
    libFocus();
    libRequestThumbs();
    lib_hold = true;
    lib_hold_mode = mode;
    lib_hold_until = nowUs() + LIB_HOLD_US;
    lib_batches = 0;
    lib_shown = @splat(false);
    lib_pending = @splat(false);
    libTick();
}
// Called every loop iteration and on cover revisions.
fn libTick() void {
    if (screen != .library or sleep_phase != .awake) return;
    if (lib_hold) {
        var reading: usize = 0;
        var generating: usize = 0;
        libVisibleState(&reading, &generating);
        if (reading > 0 and nowUs() < lib_hold_until) return;
        lib_hold = false;
        lib_drawn_at = nowUs();
        const per = @min(rowsPerPage(), lib_shown.len);
        var z: [1200]u8 = undefined;
        for (0..per) |i| {
            const k = list_page * per + i;
            lib_shown[i] = true;
            lib_pending[i] = false;
            if (folder_picker or k >= libraryCount()) continue;
            const p = libPath(k, &z) orelse continue;
            const st = zr_thumb_peek(p);
            lib_shown[i] = st == 3 or st == 4;
            lib_pending[i] = !lib_shown[i];
        }
        logf("library compose: one update; covers pending={d}", .{reading + generating});
        markFull(lib_hold_mode);
        return;
    }
    libFlushCovers(false);
}
fn libCoversArrived() void {
    if (lib_hold) return libTick();
    libFlushCovers(true);
}
fn libFlushCovers(_: bool) void {
    if (lib_batches >= 2) return;
    const per = @min(rowsPerPage(), lib_shown.len);
    var z: [1200]u8 = undefined;
    var ready = Rect{};
    var still: usize = 0;
    var ready_rows: [16]bool = @splat(false);
    for (0..per) |i| {
        if (!lib_pending[i]) continue;
        const k = list_page * per + i;
        if (folder_picker or k >= libraryCount()) {
            lib_pending[i] = false;
            continue;
        }
        const p = libPath(k, &z) orelse continue;
        switch (zr_thumb_peek(p)) {
            3 => {
                ready_rows[i] = true;
                ready = Rect.unite(ready, thumbRect(i).grow(2));
            },
            4 => lib_pending[i] = false,
            0 => {
                // Request was evicted/cancelled: ask again, keep waiting.
                var scratch: [96 * 128]u8 = undefined;
                _ = zr_thumb(p, &scratch);
                still += 1;
            },
            else => still += 1,
        }
    }
    if (ready.empty()) return;
    // Batch 1 waits for every pending cover or 1.5 s; batch 2 (the last) waits
    // for every remaining cover. Never one update per cover, never a flash.
    const last = lib_batches == 1;
    if (still > 0 and (last or nowUs() < lib_drawn_at + LIB_BATCH1_US)) return;
    for (0..per) |i| if (ready_rows[i]) {
        lib_pending[i] = false;
        lib_shown[i] = true;
    };
    lib_batches += 1;
    logf("library covers: batch {d} GL16 partial {d}x{d}", .{ lib_batches, ready.w, ready.h });
    markDirty(ready, WF_GL16);
}
fn formatBookCount(buf: []u8, shown: usize, all: usize, filtered: bool) []const u8 {
    if (filtered and shown != all) return std.fmt.bufPrint(buf, "{d} of {d} {s}", .{ shown, all, if (all == 1) "book" else "books" }) catch "";
    return std.fmt.bufPrint(buf, "{d} {s}", .{ all, if (all == 1) "book" else "books" }) catch "";
}
fn libraryFooter(line: []u8) []const u8 {
    var a: [32]u8 = undefined; var b: [32]u8 = undefined; var c: [32]u8 = undefined; var n: [48]u8 = undefined;
    const count = formatBookCount(&n, nvisible, nlib, folder_filter != 0 or coll_filter >= 0);
    return if (storage_total > 0)
        std.fmt.bufPrint(line, "{s}  \xc2\xb7  Books {s}  \xc2\xb7  {s} free / {s}", .{ count, formatBytes(books_bytes, &c), formatBytes(storage_free, &a), formatBytes(storage_total, &b) }) catch ""
    else
        std.fmt.bufPrint(line, "{s}  \xc2\xb7  Books {s}  \xc2\xb7  Device storage unavailable", .{ count, formatBytes(books_bytes, &c) }) catch "";
}
var last_cover_page: usize = std.math.maxInt(usize);
var last_cover_sort: usize = 255;
var last_cover_folder: usize = std.math.maxInt(usize);
fn drawLibrary() void {
    header(if (folder_picker) "Show" else "Library", book.open);
    drawBattery();
    drawLowBattery();
    libFocus();
    button(libraryControl(0), SORT_NAMES[lib_sort], false);
    var label: [1100]u8 = undefined;
    const flabel = if (coll_filter == 0) "Favourites" else if (coll_filter > 0) (std.fmt.bufPrint(&label, "{s}", .{collName(@intCast(coll_filter - 1))}) catch "Collection") else std.fmt.bufPrint(&label, "Folder: {s}", .{if (folder_filter == 0) "All" else folders[folder_filter - 1]}) catch "Folders";
    button(libraryControl(1), flabel, folder_picker);
    button(libraryControl(2), "Settings", false);
    const total = libraryCount();
    const per = rowsPerPage();
    if (total == 0) text(SANS, 34, 70, 410, "No books here (PDF, EPUB, MOBI, AZW3, TXT, CBZ, FB2).", 0x55);
    for (0..per) |i| {
        const k = list_page * per + i;
        if (k >= total) break;
        const r = rowRect(i);
        if (folder_picker) {
            var nb: [200]u8 = undefined;
            const name = pickerLabel(k, &nb);
            const sel = pickerSelected(k);
            if (sel and k > nfolders) fill(.{ .x = r.x - 40, .y = r.y + 50, .w = 12, .h = 50 }, 0x00);
            if (k == favRow()) fillStar(r.x + 40, r.y + 72, 22, 0x00);
            textFit(SERIF, 42, @floatFromInt(r.x + (if (k == favRow()) @as(i32, 80) else 20)), @floatFromInt(r.y + 85), name, @floatFromInt(r.w - 100), if (k == newRow()) 0x55 else 0);
        } else {
            const e = lib[lib_visible[k]];
            if (!drawThumb(e.path, .{ .x = r.x, .y = r.y + 8, .w = 96, .h = 128 })) {
                frame(.{ .x = r.x, .y = r.y + 8, .w = 96, .h = 128 }, 2, 0xAA);
                textCenter(SANS, 20, .{ .x = r.x, .y = r.y + 8, .w = 96, .h = 128 }, entryLabel(e), 0x55);
            }
            if (e.fav) fillStar(r.x + 142, r.y + 42, 17, 0x00);
            const tx: i32 = if (e.fav) 170 else 125;
            textFit(SERIF, 38, @floatFromInt(r.x + tx), @floatFromInt(r.y + 55), e.title, @floatFromInt(r.w - tx), 0);
            var subbuf: [1200]u8 = undefined;
            var sizebuf: [32]u8 = undefined;
            const sub = std.fmt.bufPrint(&subbuf, "{s}  \xc2\xb7  {s}  \xc2\xb7  {s}", .{ entryLabel(e), formatBytes(e.bytes, &sizebuf), e.folder }) catch "";
            textFit(SANS, 25, @floatFromInt(r.x + 125), @floatFromInt(r.y + 92), sub, @floatFromInt(r.w - 240), 0x55);
            const track = Rect{ .x = r.x + 125, .y = r.y + 115, .w = r.w - 250, .h = 12 };
            fill(track, 0xDD);
            fill(.{ .x = track.x, .y = track.y, .w = @divTrunc(track.w * @max(e.progress, 0), 100), .h = track.h }, 0x33);
            var pb: [24]u8 = undefined;
            text(SANS, 24, @floatFromInt(r.x + r.w - 100), @floatFromInt(r.y + 128), std.fmt.bufPrint(&pb, "{d}%", .{@max(e.progress, 0)}) catch "", 0x55);
        }
        rowSep(r);
    }
    var line: [200]u8 = undefined;
    text(SANS, 26, 70, @floatFromInt(@as(i32, @intCast(H)) - 180), libraryFooter(&line), 0x33);
    pager(total);
    drawLibMenu();
    drawToast();
}

fn drawToc() void {
    loadToc();
    header("Contents", true);
    drawBookStatsLine(430, 95);
    const fallback = !book.toc_real;
    if (fallback) {
        button(libraryControl(0), "Go to page...", false);
        button(libraryControl(1), "Go to %...", false);
        if (book.toc_detected) textCenter(SANS, 30, libraryControl(2), "(detected)", 0x55);
        if (!book.toc_detected) {
            const msg = if (ct_status == 1) "Looking for chapter headings..." else if (ct_status == 3) "Could not read this book's text." else "No chapter headings found in the text.";
            text(SANS, 34, 70, 400, msg, 0x33);
            var pb: [80]u8 = undefined;
            if (ct_status == 1) text(SANS, 30, 70, 460, std.fmt.bufPrint(&pb, "{d}% \xc2\xb7 you can keep reading meanwhile", .{@max(ct_last_pct, 0)}) catch "", 0x55) else text(SANS, 30, 70, 460, "Use Go to page or Go to % to jump.", 0x55);
        }
    }
    const per = rowsPerPage();
    var i: usize = 0;
    while (i < per) : (i += 1) {
        const k = list_page * per + i;
        if (k >= book.ntoc) break;
        const e = book.toc[k];
        const r = rowRect(i);
        const indent: f32 = @floatFromInt(@min(e.level, 4) * 50);
        const t = book.toc_text[@intCast(e.off)..][0..@intCast(e.len)];
        var b: [16]u8 = undefined;
        const pg = std.fmt.bufPrint(&b, "{d}", .{e.page + 1}) catch "";
        const pw = textW(SANS, 32, pg);
        const cur_mark = e.page <= pool.cur and (k + 1 >= book.ntoc or book.toc[k + 1].page > pool.cur);
        textFit(if (e.level == 0) SERIF_BOLD else SERIF, 38, @as(f32, @floatFromInt(r.x)) + indent, @floatFromInt(r.y + 90), t, @as(f32, @floatFromInt(r.w)) - indent - pw - 40, 0x00);
        text(SANS, 32, @as(f32, @floatFromInt(r.x + r.w)) - pw, @floatFromInt(r.y + 90), pg, 0x33);
        if (cur_mark) fill(.{ .x = r.x - 40, .y = r.y + 50, .w = 12, .h = 50 }, 0x00);
        rowSep(r);
    }
    pager(book.ntoc);
}

fn drawNotes() void {
    header("Highlights & notes", true);
    if (book.nnotes == 0) text(SANS, 34, 70, 300, "No notes yet. Long-press text to start one.", 0x33);
    const per = rowsPerPage();
    var i: usize = 0;
    while (i < per) : (i += 1) {
        const k = list_page * per + i;
        if (k >= book.nnotes) break;
        const n = &book.notes[k];
        const r = rowRect(i);
        var b: [200]u8 = undefined;
        var db: [64]u8 = undefined;
        const meta = std.fmt.bufPrint(&b, "p. {d}  \xc2\xb7  {s}  \xc2\xb7  {s}{s}", .{ n.page + 1, STYLE_LABELS[n.style], fmtDate(n.ts, &db), if (book.reflow and n.unresolved) " (location unresolved)" else "" }) catch "";
        text(SANS, 28, @floatFromInt(r.x), @floatFromInt(r.y + 50), meta, 0x55);
        var q: [600]u8 = undefined;
        const qt = std.fmt.bufPrint(&q, "\xe2\x80\x9c{s}\xe2\x80\x9d", .{n.text[0..@min(n.text.len, 500)]}) catch n.text;
        if (n.comment.len > 0) {
            textFit(SERIF, 34, @floatFromInt(r.x), @floatFromInt(r.y + 96), qt, @floatFromInt(r.w), 0x00);
            var cb: [600]u8 = undefined;
            const ct = std.fmt.bufPrint(&cb, "Note: {s}", .{n.comment[0..@min(n.comment.len, 500)]}) catch n.comment;
            textFit(SANS, 28, @floatFromInt(r.x), @floatFromInt(r.y + 136), ct, @floatFromInt(r.w), 0x33);
        } else textFit(SERIF, 38, @floatFromInt(r.x), @floatFromInt(r.y + 112), qt, @floatFromInt(r.w), 0x00);
        rowSep(r);
    }
    pager(book.nnotes);
    drawToast();
}

// ---- v0.9.5 bookmarks ----
// Per book in DATA/state/<hash>.bookmarks (one line each: page, time, EPUB
// anchor, snippet; tab-separated). Local only. The ribbon is an overlay drawn
// with the page (drawOverlays), never part of the rendered page raster.
const Bookmark = struct { page: i32, ts: i64, anchor: Anchor = .{}, snip: [96]u8 = undefined, snip_len: usize = 0 };
var bookmarks: [256]Bookmark = undefined;
var nbookmarks: usize = 0;
fn bookmarksPath(out: []u8) []const u8 {
    return std.fmt.bufPrint(out, "{s}/state/{x:0>16}.bookmarks", .{ opts.data, fnv(book.pathS()) }) catch "";
}
fn bookmarkIndex(page: i32) ?usize {
    for (bookmarks[0..nbookmarks], 0..) |*b, i| if (b.page == page) return i;
    return null;
}
fn sortBookmarks() void {
    std.mem.sort(Bookmark, bookmarks[0..nbookmarks], {}, struct {
        fn lt(_: void, a: Bookmark, b: Bookmark) bool {
            return a.page < b.page;
        }
    }.lt);
}
fn resolveBookmarkPages() void {
    if (!book.reflow) return;
    for (bookmarks[0..nbookmarks]) |*b| {
        if (b.anchor.chapter < 0) continue;
        const p = zr_anchor_page(book.doc, &b.anchor);
        if (p >= 0) b.page = p;
    }
    sortBookmarks();
}
fn loadBookmarks() void {
    nbookmarks = 0;
    var pb: [1200]u8 = undefined;
    var zb: [1200]u8 = undefined;
    const z = std.fmt.bufPrintSentinel(&zb, "{s}", .{bookmarksPath(&pb)}, 0) catch return;
    const data = readFile(z) orelse return;
    defer alloc.free(data);
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        if (nbookmarks >= bookmarks.len) break;
        var f = std.mem.splitScalar(u8, line, '\t');
        const page = std.fmt.parseInt(i32, f.next() orelse continue, 10) catch continue;
        if (page < 0) continue;
        var b: Bookmark = .{ .page = page, .ts = std.fmt.parseInt(i64, f.next() orelse "0", 10) catch 0 };
        const ch = std.fmt.parseInt(c_int, f.next() orelse "-1", 10) catch -1;
        const st = std.fmt.parseInt(u32, f.next() orelse "0", 10) catch 0;
        const en = std.fmt.parseInt(u32, f.next() orelse "0", 10) catch 0;
        const hs = std.fmt.parseInt(u64, f.next() orelse "0", 16) catch 0;
        if (ch >= 0 and en > st and hs != 0) b.anchor = .{ .chapter = ch, .start = st, .end = en, .hash = hs };
        const s = f.rest();
        b.snip_len = @min(s.len, b.snip.len);
        @memcpy(b.snip[0..b.snip_len], s[0..b.snip_len]);
        if (bookmarkIndex(b.page) != null) continue;
        bookmarks[nbookmarks] = b;
        nbookmarks += 1;
    }
    resolveBookmarkPages();
    sortBookmarks();
}
fn saveBookmarks() void {
    var b = Buf.init(4096);
    defer b.deinit();
    for (bookmarks[0..nbookmarks]) |*m| {
        b.print("{d}\t{d}\t{d}\t{d}\t{d}\t{x}\t", .{ m.page, m.ts, m.anchor.chapter, m.anchor.start, m.anchor.end, m.anchor.hash });
        b.put(m.snip[0..m.snip_len]);
        b.put("\n");
    }
    var pb: [1200]u8 = undefined;
    _ = writeFileAtomic(bookmarksPath(&pb), b.slice());
}
fn pageSnippet(out: []u8) usize {
    loadWords();
    var n: usize = 0;
    for (book.words[0..book.nwords]) |w| {
        if (w.off < 0 or w.len <= 0) continue;
        const o: usize = @intCast(w.off);
        const l: usize = @intCast(w.len);
        if (o + l > book.wtext.len) break;
        if (n > 0) {
            if (n + 1 >= out.len) break;
            out[n] = ' ';
            n += 1;
        }
        var k: usize = 0;
        while (k < l and n < out.len) : (k += 1) {
            const c = book.wtext[o + k];
            out[n] = if (c == '\t' or c == '\n' or c == '\r') ' ' else c;
            n += 1;
        }
        if (n >= 60) break;
    }
    // never cut a UTF-8 sequence in half
    var s = n;
    while (s > 0 and (out[s - 1] & 0xC0) == 0x80) s -= 1;
    if (s > 0 and out[s - 1] >= 0xC0) {
        const lead = out[s - 1];
        const need: usize = if (lead >= 0xF0) 4 else if (lead >= 0xE0) 3 else 2;
        if (n - (s - 1) < need) n = s - 1;
    }
    return n;
}
fn toggleBookmark() void {
    if (!book.open) return;
    if (bookmarkIndex(pool.cur)) |i| {
        var j = i;
        while (j + 1 < nbookmarks) : (j += 1) bookmarks[j] = bookmarks[j + 1];
        nbookmarks -= 1;
        logf("bookmark removed: p={d}", .{pool.cur + 1});
    } else {
        if (nbookmarks >= bookmarks.len) return toast("Bookmark list is full", .{});
        var b: Bookmark = .{ .page = pool.cur, .ts = zr_now_seconds() };
        if (book.reflow) b.anchor = readingAnchor();
        b.snip_len = pageSnippet(&b.snip);
        bookmarks[nbookmarks] = b;
        nbookmarks += 1;
        sortBookmarks();
        logf("bookmark added: p={d}", .{pool.cur + 1});
    }
    saveBookmarks();
}
fn deleteBookmark(k: usize) void {
    if (k >= nbookmarks) return;
    var j = k;
    while (j + 1 < nbookmarks) : (j += 1) bookmarks[j] = bookmarks[j + 1];
    nbookmarks -= 1;
    saveBookmarks();
}
fn ribbonRect() Rect {
    return .{ .x = @as(i32, @intCast(W)) - 96, .y = 0, .w = 44, .h = 92 };
}
fn drawRibbon() void {
    const r = ribbonRect();
    fill(.{ .x = r.x - 3, .y = 0, .w = r.w + 6, .h = r.h - 18 }, 0xFF);
    fill(.{ .x = r.x, .y = 0, .w = r.w, .h = r.h - 22 }, 0x00);
    // swallow-tail: two black legs with a white notch between them
    var k: i32 = 0;
    while (k < 22) : (k += 1) {
        const half = @divTrunc(r.w, 2);
        const leg = half - k;
        if (leg <= 0) break;
        fill(.{ .x = r.x, .y = r.y + r.h - 22 + k, .w = leg, .h = 1 }, 0x00);
        fill(.{ .x = r.x + r.w - leg, .y = r.y + r.h - 22 + k, .w = leg, .h = 1 }, 0x00);
    }
}
fn bookmarkToggleButton() Rect {
    return .{ .x = 336, .y = @as(i32, @intCast(H)) - 262, .w = @as(i32, @intCast(W)) - 672, .h = 100 };
}
fn drawBookmarks() void {
    header("Bookmarks", true);
    if (nbookmarks == 0) text(SANS, 34, 70, 300, "No bookmarks yet.", 0x33);
    if (nbookmarks > 0) text(SANS, 26, 430, 112, "Tap to open \xc2\xb7 long-press to delete", 0x77);
    const per = rowsPerPage();
    var i: usize = 0;
    while (i < per) : (i += 1) {
        const k = list_page * per + i;
        if (k >= nbookmarks) break;
        const m = &bookmarks[k];
        const r = rowRect(i);
        var b: [120]u8 = undefined;
        var db: [64]u8 = undefined;
        const meta = std.fmt.bufPrint(&b, "Page {d}  \xc2\xb7  {s}", .{ m.page + 1, fmtDate(m.ts, &db) }) catch "";
        text(SANS, 30, @floatFromInt(r.x), @floatFromInt(r.y + 50), meta, 0x33);
        if (m.snip_len > 0) textFit(SERIF, 36, @floatFromInt(r.x), @floatFromInt(r.y + 110), m.snip[0..m.snip_len], @floatFromInt(r.w), 0x00);
        rowSep(r);
    }
    pager(nbookmarks);
    var lb: [64]u8 = undefined;
    const label = std.fmt.bufPrint(&lb, "{s} page {d}", .{ if (bookmarkIndex(pool.cur) != null) "Remove bookmark," else "Bookmark", pool.cur + 1 }) catch "Bookmark";
    button(bookmarkToggleButton(), label, false);
    drawToast();
}
fn bookmarksTap(x: i32, y: i32, t_ev: u64) void {
    if (topButton(true).contains(x, y)) return showScreen(.reader);
    if (bookmarkToggleButton().contains(x, y)) {
        toggleBookmark();
        return markFull(WF_REAGL);
    }
    if (listNav(x, y)) return;
    const per = rowsPerPage();
    for (0..per) |i| {
        if (!rowRect(i).contains(x, y)) continue;
        const k = list_page * per + i;
        if (k >= nbookmarks) return;
        showScreen(.reader);
        return goPage(bookmarks[k].page, t_ev);
    }
}
fn bookmarksLongPress(x: i32, y: i32) void {
    const per = rowsPerPage();
    for (0..per) |i| {
        if (!rowRect(i).contains(x, y)) continue;
        const k = list_page * per + i;
        if (k >= nbookmarks) return;
        deleteBookmark(k);
        toast("Bookmark deleted", .{});
        return markFull(WF_REAGL);
    }
}

// ---- v0.9.6 note editor (compact on-screen keyboard) ----
var note_edit_idx: usize = 0;
var note_buf: [480]u8 = undefined;
var note_len: usize = 0;
var note_shift = false;
const EditTarget = enum { note, coll_new, coll_rename, goto_page, goto_pct };
var edit_target: EditTarget = .note;
var edit_coll: usize = 0;
var edit_add_entry: ?usize = null;
const NOTE_PUNCT = ".,?!;:()\"/";
fn noteKey(row: usize, col: usize) Rect {
    const bw = @divTrunc(@as(i32, @intCast(W)) - 140, 10);
    return .{ .x = 70 + @as(i32, @intCast(col)) * bw, .y = 600 + @as(i32, @intCast(row)) * 118, .w = bw - 10, .h = 104 };
}
fn noteField() Rect {
    return .{ .x = 70, .y = 250, .w = @as(i32, @intCast(W)) - 140, .h = 320 };
}
fn noteControl(which: usize) Rect {
    const y0: i32 = 600 + 5 * 118;
    return switch (which) {
        0 => .{ .x = 70, .y = y0, .w = 145, .h = 104 }, // Shift
        6 => .{ .x = 225, .y = y0, .w = 145, .h = 104 }, // accents
        1 => .{ .x = 390, .y = y0, .w = 492, .h = 104 }, // Space
        2 => .{ .x = 902, .y = y0, .w = 300, .h = 104 }, // Backspace
        3 => .{ .x = 70, .y = y0 + 130, .w = 300, .h = 104 }, // Clear
        4 => .{ .x = 390, .y = y0 + 130, .w = 492, .h = 104 }, // Cancel
        else => .{ .x = 902, .y = y0 + 130, .w = 300, .h = 104 }, // Save
    };
}
fn noteKeyChar(row: usize, col: usize) ?u8 {
    if (row < KEY_ROWS.len) return if (col < KEY_ROWS[row].len) KEY_ROWS[row][col] else null;
    if (row == KEY_ROWS.len and col < NOTE_PUNCT.len) return NOTE_PUNCT[col];
    return null;
}
fn noteAutoShift() bool {
    const s = std.mem.trimEnd(u8, note_buf[0..note_len], " ");
    return s.len == 0 or s[s.len - 1] == '.' or s[s.len - 1] == '?' or s[s.len - 1] == '!';
}
fn openNoteEditor(k: usize) void {
    if (k >= book.nnotes) return;
    note_edit_idx = k;
    const c = book.notes[k].comment;
    note_len = @min(c.len, note_buf.len);
    @memcpy(note_buf[0..note_len], c[0..note_len]);
    note_shift = noteAutoShift();
    edit_target = .note;
    showScreen(.noteedit);
}
fn closeNoteEditor(save: bool) void {
    if (edit_target == .goto_page or edit_target == .goto_pct) return closeGoto(save);
    if (edit_target != .note) return closeNameEditor(save);
    if (save and note_edit_idx < book.nnotes) {
        const n = &book.notes[note_edit_idx];
        const t = std.mem.trim(u8, note_buf[0..note_len], " ");
        const d = alloc.dupe(u8, t) catch return toast("Could not save note", .{});
        alloc.free(n.comment);
        n.comment = d;
        saveNotes();
        logf("note text saved: page {d} ({d} bytes)", .{ n.page + 1, d.len });
        showScreen(.reader);
        return toast("Note saved \xc2\xb7 p. {d}", .{n.page + 1});
    }
    showScreen(.reader);
}
fn drawWrapped(font: c_int, size: f32, r: Rect, s: []const u8, max_lines: usize, gray: u8) void {
    // Shows the last max_lines wrapped lines so the end being typed stays visible.
    var starts: [64]usize = undefined;
    var ends: [64]usize = undefined;
    var n: usize = 0;
    var start: usize = 0;
    const maxw: f32 = @floatFromInt(r.w - 40);
    while (start <= s.len and n < starts.len) {
        var end = start;
        var last_space = start;
        while (end < s.len) {
            const step = std.unicode.utf8ByteSequenceLength(s[end]) catch 1;
            const next = @min(end + step, s.len);
            if (textW(font, size, s[start..next]) > maxw and end > start) break;
            if (s[end] == ' ') last_space = end;
            end = next;
        }
        if (end < s.len and last_space > start) end = last_space;
        starts[n] = start;
        ends[n] = end;
        n += 1;
        if (end >= s.len) break;
        start = end;
        while (start < s.len and s[start] == ' ') start += 1;
    }
    const first = if (n > max_lines) n - max_lines else 0;
    var line: usize = 0;
    for (first..n) |i| {
        text(font, size, @floatFromInt(r.x + 20), @as(f32, @floatFromInt(r.y + 20)) + size * 1.25 * @as(f32, @floatFromInt(line + 1)), s[starts[i]..ends[i]], gray);
        line += 1;
    }
}
fn drawNoteEditor() void {
    var hb: [64]u8 = undefined;
    header(switch (edit_target) {
        .note => "Note",
        .coll_new => "New collection",
        .coll_rename => "Rename collection",
        .goto_page => std.fmt.bufPrint(&hb, "Go to page (1-{d})", .{pool.npages}) catch "Go to page",
        .goto_pct => "Go to percent (0-100)",
    }, true);
    if (edit_target == .note and note_edit_idx < book.nnotes) {
        const n = &book.notes[note_edit_idx];
        var q: [600]u8 = undefined;
        const qt = std.fmt.bufPrint(&q, "p. {d}  \xe2\x80\x9c{s}\xe2\x80\x9d", .{ n.page + 1, n.text[0..@min(n.text.len, 500)] }) catch n.text;
        textFit(SERIF, 32, 70, 220, qt, @as(f32, @floatFromInt(W)) - 140, 0x55);
    }
    const f = noteField();
    frame(f, 3, 0);
    var tb: [484]u8 = undefined;
    @memcpy(tb[0..note_len], note_buf[0..note_len]);
    tb[note_len] = '|';
    drawWrapped(SANS, 38, f, tb[0 .. note_len + 1], 5, 0);
    for (0..KEY_ROWS.len + 1) |r| for (0..10) |c| {
        if (kb_accents and r < 4) {
            const k = accentKey(r, c, note_shift);
            if (k.len > 0) button(noteKey(r, c), k, false);
            continue;
        }
        const ch = noteKeyChar(r, c) orelse continue;
        const shown = if (note_shift) std.ascii.toUpper(ch) else ch;
        button(noteKey(r, c), &.{shown}, false);
    };
    button(noteControl(0), "Shift", note_shift);
    button(noteControl(6), if (kb_accents) "abc" else ACCENT_LABEL, kb_accents);
    button(noteControl(1), "Space", false);
    button(noteControl(2), "Backspace", false);
    button(noteControl(3), "Clear", false);
    button(noteControl(4), "Cancel", false);
    button(noteControl(5), "Save", true);
    drawToast();
}
fn noteEditorTap(x: i32, y: i32) void {
    if (topButton(true).contains(x, y) or noteControl(4).contains(x, y)) return closeNoteEditor(false);
    if (noteControl(5).contains(x, y)) return closeNoteEditor(true);
    if (noteControl(0).contains(x, y)) {
        note_shift = !note_shift;
        return markFull(WF_REAGL);
    }
    if (noteControl(6).contains(x, y)) {
        kb_accents = !kb_accents;
        return markFull(WF_REAGL);
    }
    if (kb_accents) for (0..4) |r| for (0..10) |c| {
        if (!noteKey(r, c).contains(x, y)) continue;
        const k = accentKey(r, c, note_shift);
        if (k.len == 0) return;
        if (note_len + k.len >= note_buf.len - 1) return toast("Note is full", .{});
        @memcpy(note_buf[note_len..][0..k.len], k);
        note_len += k.len;
        note_shift = false;
        return markFull(WF_REAGL);
    };
    if (noteControl(3).contains(x, y)) {
        note_len = 0;
        note_shift = true;
        return markFull(WF_REAGL);
    }
    if (noteControl(2).contains(x, y)) {
        if (note_len > 0) {
            note_len -= 1;
            while (note_len > 0 and (note_buf[note_len] & 0xC0) == 0x80) note_len -= 1;
        }
        note_shift = noteAutoShift();
        return markFull(WF_REAGL);
    }
    var ch: ?u8 = null;
    if (noteControl(1).contains(x, y)) ch = ' ';
    for (0..KEY_ROWS.len + 1) |r| for (0..10) |c| {
        if (noteKey(r, c).contains(x, y)) ch = noteKeyChar(r, c);
    };
    const c = ch orelse return;
    if (note_len >= note_buf.len - 1) return toast("Note is full", .{});
    note_buf[note_len] = if (note_shift) std.ascii.toUpper(c) else c;
    note_len += 1;
    note_shift = c == ' ' and noteAutoShift();
    markFull(WF_REAGL);
}

// ---- v0.9.7 reading stats (device only) ----
// DATA/state/stats.tsv: "b <id> secs pages sessions first last pct finished"
// per book (id = same hash as the state file) and "d <day> secs" per local
// day. Active time only counts while a page is on screen in the reader, the
// menu is closed, the device is awake and the last page turn is recent.
// Saved at most once a minute (and on close/sleep/exit), never per page.
const BookStat = struct { id: u64, secs: u32 = 0, pages: u32 = 0, sessions: u32 = 0, first: i64 = 0, last: i64 = 0, pct: u8 = 0, finished: i64 = 0 };
const DayStat = struct { day: i32, secs: u32 };
var bstats: [4000]BookStat = undefined;
var nbstats: usize = 0;
var dstats: [400]DayStat = undefined;
var ndstats: usize = 0;
var stats_loaded = false;
var stats_dirty = false;
var stats_last_save: u64 = 0;
var stats_last_activity: u64 = 0;
var stats_prev_tick: u64 = 0;
var stats_frac_us: u64 = 0;
var stats_cur: ?usize = null;
var stats_confirm_until: u64 = 0;
var stats_return: Screen = .device;
fn statsPath(out: []u8) []const u8 {
    return std.fmt.bufPrint(out, "{s}/state/stats.tsv", .{opts.data}) catch "";
}
fn localDay(t: i64) i32 {
    var tm: Tm = undefined;
    if (zr_localtime64(&t, &tm) == null) return @intCast(@divFloor(t, 86400));
    // days from civil (Howard Hinnant)
    var y: i64 = tm.year + 1900;
    const m: i64 = tm.mon + 1;
    const d: i64 = tm.mday;
    if (m <= 2) y -= 1;
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const mp = @mod(m + 9, 12);
    const doy = @divFloor(153 * mp + 2, 5) + d - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return @intCast(era * 146097 + doe - 719468);
}
fn statsLoad() void {
    if (stats_loaded) return;
    stats_loaded = true;
    nbstats = 0;
    ndstats = 0;
    var pb: [1200]u8 = undefined;
    var zb: [1200]u8 = undefined;
    const z = std.fmt.bufPrintSentinel(&zb, "{s}", .{statsPath(&pb)}, 0) catch return;
    const data = readFile(z) orelse return;
    defer alloc.free(data);
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        var f = std.mem.splitScalar(u8, line, '\t');
        const kind = f.next() orelse continue;
        if (eql(kind, "b") and nbstats < bstats.len) {
            var s: BookStat = .{ .id = std.fmt.parseInt(u64, f.next() orelse continue, 16) catch continue };
            s.secs = std.fmt.parseInt(u32, f.next() orelse "0", 10) catch 0;
            s.pages = std.fmt.parseInt(u32, f.next() orelse "0", 10) catch 0;
            s.sessions = std.fmt.parseInt(u32, f.next() orelse "0", 10) catch 0;
            s.first = std.fmt.parseInt(i64, f.next() orelse "0", 10) catch 0;
            s.last = std.fmt.parseInt(i64, f.next() orelse "0", 10) catch 0;
            s.pct = std.fmt.parseInt(u8, f.next() orelse "0", 10) catch 0;
            s.finished = std.fmt.parseInt(i64, f.next() orelse "0", 10) catch 0;
            bstats[nbstats] = s;
            nbstats += 1;
        } else if (eql(kind, "d") and ndstats < dstats.len) {
            const day = std.fmt.parseInt(i32, f.next() orelse continue, 10) catch continue;
            const secs = std.fmt.parseInt(u32, f.next() orelse "0", 10) catch 0;
            dstats[ndstats] = .{ .day = day, .secs = secs };
            ndstats += 1;
        }
    }
    std.mem.sort(DayStat, dstats[0..ndstats], {}, struct {
        fn lt(_: void, x: DayStat, y: DayStat) bool {
            return x.day < y.day;
        }
    }.lt);
}
fn statsSave() void {
    if (!stats_loaded or !stats_dirty) return;
    var b = Buf.init(4096);
    defer b.deinit();
    b.put("zrstats\t1\n");
    for (bstats[0..nbstats]) |s| b.print("b\t{x:0>16}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\n", .{ s.id, s.secs, s.pages, s.sessions, s.first, s.last, s.pct, s.finished });
    for (dstats[0..ndstats]) |d| b.print("d\t{d}\t{d}\n", .{ d.day, d.secs });
    var pb: [1200]u8 = undefined;
    if (writeFileAtomic(statsPath(&pb), b.slice())) {
        stats_dirty = false;
        stats_last_save = nowUs();
    }
}
fn statsFor(id: u64, create: bool) ?usize {
    for (bstats[0..nbstats], 0..) |s, i| if (s.id == id) return i;
    if (!create or nbstats >= bstats.len) return null;
    bstats[nbstats] = .{ .id = id };
    nbstats += 1;
    return nbstats - 1;
}
fn statsAddDay(secs: u32) void {
    const today = localDay(zr_now_seconds());
    if (ndstats > 0 and dstats[ndstats - 1].day == today) {
        dstats[ndstats - 1].secs +|= secs;
        return;
    }
    if (ndstats == dstats.len) {
        std.mem.copyForwards(DayStat, dstats[0 .. ndstats - 1], dstats[1..ndstats]);
        ndstats -= 1;
    }
    dstats[ndstats] = .{ .day = today, .secs = secs };
    ndstats += 1;
}
fn statsOpenBook() void {
    statsLoad();
    stats_cur = statsFor(fnv(book.pathS()), true);
    const now = zr_now_seconds();
    if (stats_cur) |i| {
        const s = &bstats[i];
        s.sessions += 1;
        if (s.first == 0) s.first = now;
        s.last = now;
        statsUpdatePct(s, pool.cur);
    }
    stats_last_activity = nowUs();
    stats_prev_tick = nowUs();
    stats_frac_us = 0;
    stats_dirty = true;
}
fn statsUpdatePct(s: *BookStat, cur: i32) void {
    if (pool.npages <= 0) return;
    s.pct = @intCast(std.math.clamp(@divTrunc((cur + 1) * 100, pool.npages), 0, 100));
    if (cur >= pool.npages - 1 and pool.npages > 1 and s.finished == 0 and (!book.reflow or !pool.paginating)) s.finished = zr_now_seconds();
}
fn statsPageTurn(old: i32, new: i32) void {
    stats_last_activity = nowUs();
    const i = stats_cur orelse return;
    if (new == old) return;
    const s = &bstats[i];
    if (new > old) s.pages += 1;
    statsUpdatePct(s, new);
    s.last = zr_now_seconds();
    stats_dirty = true;
}
fn statsActive(now: u64) bool {
    return book.open and stats_cur != null and screen == .reader and !menu_open and sleep_phase == .awake and
        now -| stats_last_activity < @as(u64, opts.stats_idle_sec) * 1_000_000;
}
var stats_state_active = false;
fn statsTick(last_input: u64) void {
    _ = last_input;
    const now = nowUs();
    const prev = stats_prev_tick;
    stats_prev_tick = now;
    // v0.9.9: the loop may sleep for long stretches, so count the part of
    // [prev, now] before the activity window closed, using the state at prev.
    const was_active = stats_state_active;
    stats_state_active = book.open and stats_cur != null and screen == .reader and !menu_open and sleep_phase == .awake;
    const end = @min(now, stats_last_activity + @as(u64, opts.stats_idle_sec) * 1_000_000);
    if (was_active and stats_cur != null and end > prev) {
        stats_frac_us += end - prev;
        if (stats_frac_us >= 1_000_000) {
            const secs: u32 = @intCast(stats_frac_us / 1_000_000);
            stats_frac_us -= @as(u64, secs) * 1_000_000;
            bstats[stats_cur.?].secs +|= secs;
            statsAddDay(secs);
            stats_dirty = true;
        }
    }
    if (stats_dirty and now -| stats_last_save > 60_000_000 and !need_page and !in_flight) statsSave();
}
fn statsCloseBook() void {
    if (stats_cur) |i| bstats[i].last = zr_now_seconds();
    stats_cur = null;
    stats_dirty = true;
    statsSave();
}
fn fmtDur(secs: u64, out: []u8) []const u8 {
    if (secs < 60) return std.fmt.bufPrint(out, "{d}s", .{secs}) catch "";
    const m = secs / 60;
    if (m < 60) return std.fmt.bufPrint(out, "{d}m", .{m}) catch "";
    return std.fmt.bufPrint(out, "{d}h {d:0>2}m", .{ m / 60, m % 60 }) catch "";
}
const Overall = struct { today: u64 = 0, week: u64 = 0, all: u64 = 0, finished: usize = 0, streak: u32 = 0 };
fn statsOverall() Overall {
    statsLoad();
    var o: Overall = .{};
    const today = localDay(zr_now_seconds());
    for (dstats[0..ndstats]) |d| {
        o.all += d.secs;
        if (d.day == today) o.today += d.secs;
        if (d.day > today - 7 and d.day <= today) o.week += d.secs;
    }
    for (bstats[0..nbstats]) |s| {
        if (s.finished != 0) o.finished += 1;
    }
    var day = today;
    if (daySecs(day) < 60) day -= 1;
    while (daySecs(day) >= 60) : (day -= 1) o.streak += 1;
    return o;
}
fn daySecs(day: i32) u32 {
    var i = ndstats;
    while (i > 0) {
        i -= 1;
        if (dstats[i].day == day) return dstats[i].secs;
        if (dstats[i].day < day) break;
    }
    return 0;
}
fn bookStatsLine(s: *const BookStat, l1: []u8, l2: []u8) [2][]const u8 {
    var d: [32]u8 = undefined;
    const a = std.fmt.bufPrint(l1, "{s} read \xc2\xb7 {d} pages \xc2\xb7 {d} session{s}", .{ fmtDur(s.secs, &d), s.pages, s.sessions, if (s.sessions == 1) "" else "s" }) catch "";
    var e: [32]u8 = undefined;
    var f: [64]u8 = undefined;
    const pct: u32 = if (pool.npages > 0) @intCast(std.math.clamp(@divTrunc((pool.cur + 1) * 100, pool.npages), 0, 100)) else s.pct;
    const b = if (s.finished != 0)
        std.fmt.bufPrint(l2, "{d}% \xc2\xb7 finished \xc2\xb7 since {s}", .{ pct, fmtDate(s.first, &f)[0..@min(10, fmtDate(s.first, &f).len)] }) catch ""
    else if (book.reflow and s.pages >= 3 and s.secs >= 60 and pool.npages > pool.cur + 1)
        std.fmt.bufPrint(l2, "{d}% \xc2\xb7 about {s} left at your pace", .{ pct, fmtDur(@as(u64, s.secs) * @as(u64, @intCast(pool.npages - 1 - pool.cur)) / s.pages, &e) }) catch ""
    else
        std.fmt.bufPrint(l2, "{d}% \xc2\xb7 since {s}", .{ pct, fmtDate(s.first, &f)[0..@min(10, fmtDate(s.first, &f).len)] }) catch "";
    return .{ a, b };
}
fn drawBookStatsLine(x: i32, y: i32) void {
    const i = stats_cur orelse return;
    var l1: [160]u8 = undefined;
    var l2: [160]u8 = undefined;
    const ls = bookStatsLine(&bstats[i], &l1, &l2);
    const maxw: f32 = @floatFromInt(@as(i32, @intCast(W)) - 270 - x);
    textFit(SANS, 26, @floatFromInt(x), @floatFromInt(y), ls[0], maxw, 0x33);
    textFit(SANS, 26, @floatFromInt(x), @floatFromInt(y + 42), ls[1], maxw, 0x55);
}
fn openStats() void {
    statsLoad();
    statsSave();
    stats_return = screen;
    stats_confirm_until = 0;
    const o = statsOverall();
    logf("stats: today={d}s week={d}s all={d}s finished={d} streak={d} books={d}", .{ o.today, o.week, o.all, o.finished, o.streak, nbstats });
    showScreen(.stats);
}
fn resetStatsButton() Rect {
    return .{ .x = 70, .y = @as(i32, @intCast(H)) - 170, .w = @as(i32, @intCast(W)) - 140, .h = 110 };
}
fn drawStats() void {
    header("Reading stats", true);
    const o = statsOverall();
    var a: [32]u8 = undefined;
    var b: [32]u8 = undefined;
    var c: [32]u8 = undefined;
    var l: [200]u8 = undefined;
    text(SANS, 36, 70, 290, std.fmt.bufPrint(&l, "Today {s}  \xc2\xb7  Last 7 days {s}  \xc2\xb7  All time {s}", .{ fmtDur(o.today, &a), fmtDur(o.week, &b), fmtDur(o.all, &c) }) catch "", 0);
    text(SANS, 36, 70, 350, std.fmt.bufPrint(&l, "Books finished {d}  \xc2\xb7  Streak {d} day{s}", .{ o.finished, o.streak, if (o.streak == 1) "" else "s" }) catch "", 0);
    // 7-day bar chart
    const today = localDay(zr_now_seconds());
    var maxs: u32 = 60;
    for (0..7) |k| maxs = @max(maxs, daySecs(today - 6 + @as(i32, @intCast(k))));
    const top: i32 = 440;
    const ch: i32 = 300;
    const bw: i32 = 120;
    const gap: i32 = @divTrunc(@as(i32, @intCast(W)) - 140 - 7 * bw, 6);
    const names = [_][]const u8{ "Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed" };
    for (0..7) |k| {
        const day = today - 6 + @as(i32, @intCast(k));
        const s = daySecs(day);
        const h: i32 = @intCast(@divTrunc(@as(i64, s) * ch, maxs));
        const x = 70 + @as(i32, @intCast(k)) * (bw + gap);
        fill(.{ .x = x, .y = top + ch - h, .w = bw, .h = h }, if (k == 6) 0x00 else 0x77);
        fill(.{ .x = x, .y = top + ch, .w = bw, .h = 3 }, 0x00);
        var m: [16]u8 = undefined;
        if (s >= 60) textCenter(SANS, 24, .{ .x = x, .y = top + ch - h - 40, .w = bw, .h = 36 }, std.fmt.bufPrint(&m, "{d}m", .{s / 60}) catch "", 0x33);
        textCenter(SANS, 26, .{ .x = x, .y = top + ch + 8, .w = bw, .h = 40 }, if (k == 6) "Today" else names[@intCast(@mod(day, 7))], 0x33);
    }
    text(SERIF_BOLD, 38, 70, 880, "Recent books", 0);
    // up to 5 most recently opened books
    var order: [4000]usize = undefined;
    for (0..nbstats) |i| order[i] = i;
    std.mem.sort(usize, order[0..nbstats], {}, struct {
        fn lt(_: void, x: usize, y: usize) bool {
            return bstats[x].last > bstats[y].last;
        }
    }.lt);
    var row: i32 = 0;
    for (order[0..nbstats]) |i| {
        if (row >= 5) break;
        const s = &bstats[i];
        var title: []const u8 = "";
        for (lib[0..nlib]) |e| if (fnv(e.path) == s.id) {
            title = e.title;
            break;
        };
        if (title.len == 0) continue;
        const y = 950 + row * 100;
        textFit(SERIF, 34, 70, @floatFromInt(y), title, @as(f32, @floatFromInt(W)) - 140, 0);
        var d: [32]u8 = undefined;
        text(SANS, 26, 70, @floatFromInt(y + 40), std.fmt.bufPrint(&l, "{s}  \xc2\xb7  {d} pages  \xc2\xb7  {d} sessions  \xc2\xb7  {d}%{s}", .{ fmtDur(s.secs, &d), s.pages, s.sessions, s.pct, if (s.finished != 0) "  \xc2\xb7  finished" else "" }) catch "", 0x55);
        row += 1;
    }
    if (row == 0) text(SANS, 30, 70, 950, "No reading recorded yet.", 0x55);
    text(SANS, 24, 70, @floatFromInt(@as(i32, @intCast(H)) - 190), "Counts active reading only. Stored on this Kindle; never sent anywhere.", 0x77);
    const confirming = nowUs() < stats_confirm_until;
    button(resetStatsButton(), if (confirming) "Tap again to erase all reading stats" else "Reset stats", confirming);
    drawToast();
}
fn statsTap(x: i32, y: i32) void {
    if (topButton(true).contains(x, y)) return showScreen(stats_return);
    if (resetStatsButton().contains(x, y)) {
        if (nowUs() < stats_confirm_until) {
            nbstats = 0;
            ndstats = 0;
            if (book.open) {
                stats_cur = statsFor(fnv(book.pathS()), true);
                if (stats_cur) |i| {
                    bstats[i].first = zr_now_seconds();
                    bstats[i].last = bstats[i].first;
                }
            }
            stats_dirty = true;
            statsSave();
            stats_confirm_until = 0;
            logf("reading stats reset", .{});
            toast("Reading stats erased", .{});
        } else {
            stats_confirm_until = nowUs() + 5_000_000;
        }
        return markFull(WF_REAGL);
    }
}

// ---- v0.9.8 collections and favourites ----
// DATA/state/collections.tsv: "c <name>" lines (order = display order) and
// "m <collection #, or * for favourites> <bytes> <book path>" member lines.
// Members are matched by path; a book whose path disappeared is re-attached to
// a single unclaimed book with the same size and the same title ignoring an
// upload " (N)" suffix. Deleting a collection only removes these lines.
const MAXCOLL = 60;
var coll_names: [MAXCOLL][64]u8 = undefined;
var coll_lens: [MAXCOLL]usize = undefined;
var ncoll: usize = 0;
const Member = struct { coll: i32, bytes: u64, path: []u8 };
var members: [8000]Member = undefined;
var nmembers: usize = 0;
var coll_loaded = false;
var coll_filter: i32 = -1; // -1 none, 0 favourites, k = collection k-1
const LibMenu = enum { none, book, add, remove, coll, confirm_delete, shrink_run, shrink_done, shrink_small, orig_confirm };
var lib_menu: LibMenu = .none;
var lib_menu_entry: usize = 0;
var lib_menu_coll: usize = 0;
fn collName(i: usize) []const u8 {
    return coll_names[i][0..coll_lens[i]];
}
fn collPath(out: []u8) []const u8 {
    return std.fmt.bufPrint(out, "{s}/state/collections.tsv", .{opts.data}) catch "";
}
fn loadCollections() void {
    if (coll_loaded) return;
    coll_loaded = true;
    var pb: [1200]u8 = undefined;
    var zb: [1200]u8 = undefined;
    const z = std.fmt.bufPrintSentinel(&zb, "{s}", .{collPath(&pb)}, 0) catch return;
    const data = readFile(z) orelse return;
    defer alloc.free(data);
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        var f = std.mem.splitScalar(u8, line, '\t');
        const kind = f.next() orelse continue;
        if (eql(kind, "c") and ncoll < MAXCOLL) {
            const n = f.rest();
            if (n.len == 0) continue;
            coll_lens[ncoll] = @min(n.len, 63);
            @memcpy(coll_names[ncoll][0..coll_lens[ncoll]], n[0..coll_lens[ncoll]]);
            ncoll += 1;
        } else if (eql(kind, "m") and nmembers < members.len) {
            const cs = f.next() orelse continue;
            const c: i32 = if (eql(cs, "*")) -1 else std.fmt.parseInt(i32, cs, 10) catch continue;
            const bytes = std.fmt.parseInt(u64, f.next() orelse continue, 10) catch 0;
            const p = f.rest();
            if (p.len == 0 or c >= @as(i32, @intCast(ncoll))) continue;
            members[nmembers] = .{ .coll = c, .bytes = bytes, .path = alloc.dupe(u8, p) catch continue };
            nmembers += 1;
        }
    }
}
fn saveCollections() void {
    var b = Buf.init(4096);
    defer b.deinit();
    b.put("zrcoll\t1\n");
    for (0..ncoll) |i| {
        b.put("c\t");
        b.put(collName(i));
        b.put("\n");
    }
    for (members[0..nmembers]) |m| {
        if (m.coll < 0) b.put("m\t*\t") else b.print("m\t{d}\t", .{m.coll});
        b.print("{d}\t", .{m.bytes});
        b.put(m.path);
        b.put("\n");
    }
    var pb: [1200]u8 = undefined;
    if (!writeFileAtomic(collPath(&pb), b.slice())) toast("Could not save collections", .{});
}
fn baseTitle(t: []const u8) []const u8 {
    // "Name (2)" -> "Name"
    if (t.len > 4 and t[t.len - 1] == ')') {
        if (std.mem.lastIndexOf(u8, t, " (")) |i| {
            const num = t[i + 2 .. t.len - 1];
            if (num.len > 0 and num.len < 4 and for (num) |c| {
                if (!std.ascii.isDigit(c)) break false;
            } else true) return t[0..i];
        }
    }
    return t;
}
fn pathTitle(p: []const u8) []const u8 {
    const base = if (std.mem.lastIndexOfScalar(u8, p, '/')) |i| p[i + 1 ..] else p;
    const dot = std.mem.lastIndexOfScalar(u8, base, '.') orelse base.len;
    return base[0..dot];
}
fn entryIndexByPath(p: []const u8) ?usize {
    for (lib[0..nlib], 0..) |e, i| if (eql(e.path, p)) return i;
    return null;
}
fn applyCollections() void {
    loadCollections();
    for (lib[0..nlib]) |*e| {
        e.fav = false;
        e.cmask = 0;
    }
    var changed = false;
    for (members[0..nmembers]) |*m| {
        var idx = entryIndexByPath(m.path);
        if (idx == null) {
            // re-attach a moved/renamed copy: same size, same base title, path not already a member of this set
            var found: ?usize = null;
            var count: usize = 0;
            for (lib[0..nlib], 0..) |e, i| {
                if (e.bytes != m.bytes or m.bytes == 0) continue;
                if (!std.ascii.eqlIgnoreCase(baseTitle(e.title), baseTitle(pathTitle(m.path)))) continue;
                var taken = false;
                for (members[0..nmembers]) |o| if (o.coll == m.coll and eql(o.path, e.path)) {
                    taken = true;
                };
                if (taken) continue;
                found = i;
                count += 1;
            }
            if (count > 1) {
                // several identical copies: prefer the single one no list knows about yet
                count = 0;
                for (lib[0..nlib], 0..) |e, i| {
                    if (e.bytes != m.bytes or !std.ascii.eqlIgnoreCase(baseTitle(e.title), baseTitle(pathTitle(m.path)))) continue;
                    var known = false;
                    for (members[0..nmembers]) |o| if (eql(o.path, e.path)) {
                        known = true;
                    };
                    if (known) continue;
                    found = i;
                    count += 1;
                }
            }
            if (count == 1) {
                const np = alloc.dupe(u8, lib[found.?].path) catch continue;
                logf("collections: re-attached a moved book", .{});
                alloc.free(m.path);
                m.path = np;
                idx = found;
                changed = true;
            }
        }
        const i = idx orelse continue;
        if (m.coll < 0) lib[i].fav = true else lib[i].cmask |= @as(u64, 1) << @intCast(m.coll);
    }
    if (changed) saveCollections();
}
fn memberIndex(coll: i32, p: []const u8) ?usize {
    for (members[0..nmembers], 0..) |m, i| if (m.coll == coll and eql(m.path, p)) return i;
    return null;
}
fn removeMemberAt(i: usize) void {
    alloc.free(members[i].path);
    var j = i;
    while (j + 1 < nmembers) : (j += 1) members[j] = members[j + 1];
    nmembers -= 1;
}
fn setMember(coll: i32, e: *const Entry, on: bool) void {
    if (memberIndex(coll, e.path)) |i| {
        if (!on) removeMemberAt(i);
    } else if (on and nmembers < members.len) {
        members[nmembers] = .{ .coll = coll, .bytes = e.bytes, .path = alloc.dupe(u8, e.path) catch return };
        nmembers += 1;
    }
}
fn refreshLibraryAfterCollections() void {
    saveCollections();
    applyCollections();
    filterLibrary();
    const per = rowsPerPage();
    if (list_page * per >= @max(libraryCount(), 1)) list_page = 0;
    markFull(WF_REAGL);
}
fn deleteCollection(c: usize) void {
    var i: usize = 0;
    while (i < nmembers) {
        if (members[i].coll == @as(i32, @intCast(c))) {
            removeMemberAt(i);
            continue;
        }
        if (members[i].coll > @as(i32, @intCast(c))) members[i].coll -= 1;
        i += 1;
    }
    var j = c;
    while (j + 1 < ncoll) : (j += 1) {
        coll_names[j] = coll_names[j + 1];
        coll_lens[j] = coll_lens[j + 1];
    }
    ncoll -= 1;
    if (coll_filter == @as(i32, @intCast(c)) + 1) coll_filter = -1 else if (coll_filter > @as(i32, @intCast(c)) + 1) coll_filter -= 1;
    logf("collection deleted (books untouched)", .{});
}
// picker rows (folder rows keep their 0.9.7 positions): 0 All books,
// 1..nfolders folders, then Favourites, each collection, "+ New collection".
fn favRow() usize {
    return nfolders + 1;
}
fn newRow() usize {
    return nfolders + 2 + ncoll;
}
fn pickerColl(k: usize) ?usize {
    return if (k >= favRow() + 1 and k < newRow()) k - favRow() - 1 else null;
}
fn pickerLabel(k: usize, out: []u8) []const u8 {
    if (k == 0) return "All books";
    if (k <= nfolders) return folders[k - 1];
    if (k == favRow()) return "Favourites";
    if (pickerColl(k)) |c| return std.fmt.bufPrint(out, "Collection: {s}", .{collName(c)}) catch "";
    return "+ New collection";
}
fn pickerSelected(k: usize) bool {
    if (k == 0) return coll_filter < 0 and folder_filter == 0;
    if (k <= nfolders) return coll_filter < 0 and folder_filter == k;
    if (k == favRow()) return coll_filter == 0;
    if (pickerColl(k)) |c| return coll_filter == @as(i32, @intCast(c)) + 1;
    return false;
}
fn pickerChoose(k: usize) void {
    folder_filter = 0;
    coll_filter = -1;
    if (k >= 1 and k <= nfolders) folder_filter = k else if (k == favRow()) coll_filter = 0 else if (pickerColl(k)) |c| {
        coll_filter = @intCast(c + 1);
    }
}
fn fillStar(cx: i32, cy: i32, r: i32, g: u8) void {
    var pts: [10][2]f32 = undefined;
    for (0..10) |i| {
        const ang = -std.math.pi / 2.0 + @as(f32, @floatFromInt(i)) * std.math.pi / 5.0;
        const rr: f32 = if (i % 2 == 0) @floatFromInt(r) else @as(f32, @floatFromInt(r)) * 0.42;
        pts[i] = .{ @as(f32, @floatFromInt(cx)) + rr * @cos(ang), @as(f32, @floatFromInt(cy)) + rr * @sin(ang) };
    }
    var y = cy - r;
    while (y <= cy + r) : (y += 1) {
        var x = cx - r;
        while (x <= cx + r) : (x += 1) {
            const px = @as(f32, @floatFromInt(x)) + 0.5;
            const py = @as(f32, @floatFromInt(y)) + 0.5;
            var inside = false;
            var j: usize = 9;
            for (0..10) |i| {
                const a = pts[i];
                const b = pts[j];
                if ((a[1] > py) != (b[1] > py) and px < (b[0] - a[0]) * (py - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
                j = i;
            }
            if (inside and x >= 0 and y >= 0 and x < W and y < H) fb[@as(usize, @intCast(y)) * STRIDE + @as(usize, @intCast(x))] = g;
        }
    }
}
// ---- v0.11.0 "Shrink for Kindle" ----
var shrink_msg: [160]u8 = undefined;
var shrink_msg_len: usize = 0;
var shrink_tmp: [1100:0]u8 = undefined;
var shrink_before: i64 = 0;
var shrink_last: i32 = -1;
var shrink_tick_us: u64 = 0;
fn mb(b: i64) f64 {
    return @as(f64, @floatFromInt(b)) / 1_000_000.0;
}
fn setShrinkMsg(comptime f: []const u8, a: anytype) void {
    shrink_msg_len = if (std.fmt.bufPrint(&shrink_msg, f, a)) |m| m.len else |_| 0;
}
fn originalsBytes() i64 {
    var ob: [600]u8 = undefined;
    const d = std.fmt.bufPrintSentinel(&ob, "{s}/originals", .{opts.data}, 0) catch return 0;
    return zr_dir_size(d);
}
fn shrinkTmpPath(path: []const u8) ?[:0]const u8 {
    return std.fmt.bufPrintSentinel(&shrink_tmp, "{s}.shrink-tmp", .{path}, 0) catch null;
}
fn startShrink(e: *Entry) void {
    var pb: [1100]u8 = undefined;
    const p = std.fmt.bufPrintSentinel(&pb, "{s}", .{e.path}, 0) catch return;
    const tmp = shrinkTmpPath(e.path) orelse return;
    shrink_before = zr_fsize(p);
    const dir = std.fs.path.dirname(e.path) orelse ".";
    var db: [1100]u8 = undefined;
    const dz = std.fmt.bufPrintSentinel(&db, "{s}", .{dir}, 0) catch return;
    const free = zr_free_bytes(dz);
    if (free >= 0 and free < shrink_before + 20_000_000) {
        lib_menu = .shrink_small;
        setShrinkMsg("Not enough free space ({d:.0} MB free, {d:.0} MB needed)", .{ mb(free), mb(shrink_before + 20_000_000) });
        return markFull(WF_REAGL);
    }
    if (zr_shrink_start(p, tmp) != 0) return toast("Could not start", .{});
    lib_menu = .shrink_run;
    shrink_last = -1;
    setShrinkMsg("Shrinking ({d:.1} MB): starting...", .{mb(shrink_before)});
    markFull(WF_REAGL);
}
fn shrinkTick() void {
    if (lib_menu != .shrink_run) return;
    var done: c_int = 0;
    var total: c_int = 0;
    const ph = zr_shrink_progress(&done, &total);
    if (ph == 3) {
        const rc = zr_shrink_result();
        if (rc != 0) {
            _ = linux.unlink(&shrink_tmp);
            lib_menu = .shrink_small;
            if (rc == 1) setShrinkMsg("Cancelled; the book is unchanged", .{}) else setShrinkMsg("Could not shrink this PDF; the book is unchanged", .{});
            return markFull(WF_REAGL);
        }
        const after = zr_fsize(&shrink_tmp);
        if (after < 0 or after * 10 > shrink_before * 9) {
            _ = linux.unlink(&shrink_tmp);
            lib_menu = .shrink_small;
            setShrinkMsg("Only {d:.1} -> {d:.1} MB (under 10% smaller); original kept", .{ mb(shrink_before), mb(@max(after, 0)) });
            return markFull(WF_REAGL);
        }
        lib_menu = .shrink_done;
        setShrinkMsg("{d:.1} MB -> {d:.1} MB ({d}% smaller)", .{ mb(shrink_before), mb(after), 100 - @divTrunc(after * 100, @max(shrink_before, 1)) });
        return markFull(WF_REAGL);
    }
    const now = nowUs();
    const key: i32 = if (ph == 2) -2 else done;
    if (key == shrink_last or now -| shrink_tick_us < 1_000_000) return;
    shrink_last = key;
    shrink_tick_us = now;
    const pages = @divTrunc(total, 2);
    if (ph == 2) setShrinkMsg("Saving smaller copy...", .{}) else if (done < pages) setShrinkMsg("Checking page {d}/{d}", .{ done + 1, pages }) else setShrinkMsg("Shrinking page {d}/{d}", .{ @min(done - pages + 1, pages), pages });
    markDirty(libMenuRect(1), WF_REAGL);
}
fn discardShrunk() void {
    _ = linux.unlink(&shrink_tmp);
}
fn useShrunk(e: *Entry) void {
    var pb: [1100]u8 = undefined;
    const p = std.fmt.bufPrintSentinel(&pb, "{s}", .{e.path}, 0) catch return;
    const rel = if (std.mem.startsWith(u8, e.path, opts.books) and e.path.len > opts.books.len) e.path[opts.books.len + 1 ..] else std.fs.path.basename(e.path);
    var ob: [1100]u8 = undefined;
    const dst = std.fmt.bufPrintSentinel(&ob, "{s}/originals/{s}", .{ opts.data, rel }, 0) catch return;
    var final: [1100]u8 = undefined;
    if (zr_move_file(p, dst, &final, final.len) != 0) {
        discardShrunk();
        return toast("Could not move the original; book unchanged", .{});
    }
    if (linux.errno(linux.rename(&shrink_tmp, p)) != .SUCCESS) {
        // put the original back
        var back: [1100]u8 = undefined;
        _ = zr_move_file(@ptrCast(&final), p, &back, back.len);
        discardShrunk();
        return toast("Could not replace the book; book unchanged", .{});
    }
    const after = zr_fsize(p);
    if (after > 0) e.bytes = @intCast(after);
    toast("Smaller copy in use; original in originals/", .{});
    markFull(WF_REAGL);
}
fn libMenuRect(rows: usize) Rect {
    const h: i32 = 140 + @as(i32, @intCast(rows)) * 120;
    return .{ .x = 170, .y = @divTrunc(@as(i32, @intCast(H)) - h, 2), .w = @as(i32, @intCast(W)) - 340, .h = h };
}
fn libMenuButton(rows: usize, i: usize) Rect {
    const m = libMenuRect(rows);
    return .{ .x = m.x + 40, .y = m.y + 110 + @as(i32, @intCast(i)) * 120, .w = m.w - 80, .h = 100 };
}
fn libMenuItems(out: *[MAXCOLL + 4][96]u8, lens: *[MAXCOLL + 4]usize, act: *[MAXCOLL + 4]i32) usize {
    var n: usize = 0;
    const put = struct {
        fn f(o: *[MAXCOLL + 4][96]u8, l: *[MAXCOLL + 4]usize, a: *[MAXCOLL + 4]i32, k: *usize, s: []const u8, code: i32) void {
            const len = @min(s.len, 95);
            @memcpy(o[k.*][0..len], s[0..len]);
            l[k.*] = len;
            a[k.*] = code;
            k.* += 1;
        }
    }.f;
    const e = &lib[lib_menu_entry];
    switch (lib_menu) {
        .book => {
            put(out, lens, act, &n, if (e.fav) "Remove from Favourites" else "Favourite", 1);
            put(out, lens, act, &n, "Add to collection", 2);
            if (e.cmask != 0) put(out, lens, act, &n, "Remove from collection", 3);
            if (e.kind == 0 and !e.epub and std.ascii.endsWithIgnoreCase(e.path, ".pdf")) put(out, lens, act, &n, "Shrink for Kindle", 8);
            const osz = originalsBytes();
            if (osz > 0) {
                var ob: [64]u8 = undefined;
                put(out, lens, act, &n, std.fmt.bufPrint(&ob, "Delete originals ({d:.1} MB)", .{mb(osz)}) catch "Delete originals", 12);
            }
            put(out, lens, act, &n, "Cancel", 0);
        },
        .add, .remove => {
            for (0..ncoll) |c| {
                const member = (e.cmask >> @intCast(c)) & 1 != 0;
                if ((lib_menu == .add) == member) continue;
                if (n >= 9) break;
                put(out, lens, act, &n, collName(c), 100 + @as(i32, @intCast(c)));
            }
            if (lib_menu == .add) put(out, lens, act, &n, "+ New collection", 4);
            put(out, lens, act, &n, "Cancel", 0);
        },
        .coll => {
            put(out, lens, act, &n, "Rename", 5);
            put(out, lens, act, &n, "Delete collection", 6);
            put(out, lens, act, &n, "Cancel", 0);
        },
        .confirm_delete => {
            put(out, lens, act, &n, "Delete (books are kept)", 7);
            put(out, lens, act, &n, "Cancel", 0);
        },
        .shrink_run => put(out, lens, act, &n, "Cancel", 9),
        .shrink_done => {
            put(out, lens, act, &n, "Use smaller copy", 10);
            put(out, lens, act, &n, "Discard", 11);
        },
        .shrink_small => put(out, lens, act, &n, "OK", 0),
        .orig_confirm => {
            put(out, lens, act, &n, "Delete originals permanently", 13);
            put(out, lens, act, &n, "Cancel", 0);
        },
        .none => {},
    }
    return n;
}
fn drawLibMenu() void {
    if (lib_menu == .none) return;
    var items: [MAXCOLL + 4][96]u8 = undefined;
    var lens: [MAXCOLL + 4]usize = undefined;
    var act: [MAXCOLL + 4]i32 = undefined;
    const n = libMenuItems(&items, &lens, &act);
    const m = libMenuRect(n);
    fill(m.grow(6), 0xFF);
    frame(m, 4, 0x00);
    var tb: [200]u8 = undefined;
    const title = switch (lib_menu) {
        .coll, .confirm_delete => std.fmt.bufPrint(&tb, "Collection: {s}", .{collName(lib_menu_coll)}) catch "",
        .add => "Add to collection",
        .remove => "Remove from collection",
        .shrink_run, .shrink_done, .shrink_small, .orig_confirm => shrink_msg[0..shrink_msg_len],
        else => lib[lib_menu_entry].title,
    };
    textFit(SERIF_BOLD, 38, @floatFromInt(m.x + 40), @floatFromInt(m.y + 70), title, @floatFromInt(m.w - 80), 0);
    for (0..n) |i| button(libMenuButton(n, i), items[i][0..lens[i]], false);
}
fn libMenuTap(x: i32, y: i32) void {
    var items: [MAXCOLL + 4][96]u8 = undefined;
    var lens: [MAXCOLL + 4]usize = undefined;
    var act: [MAXCOLL + 4]i32 = undefined;
    const n = libMenuItems(&items, &lens, &act);
    var code: i32 = 0;
    var hit = false;
    for (0..n) |i| if (libMenuButton(n, i).contains(x, y)) {
        code = act[i];
        hit = true;
    };
    if (!hit and libMenuRect(n).contains(x, y)) return;
    // Shrink dialogs only close through their buttons (a stray tap must not drop a run).
    if (!hit and (lib_menu == .shrink_run or lib_menu == .shrink_done)) return;
    const e = &lib[lib_menu_entry];
    lib_menu = .none;
    switch (code) {
        1 => {
            setMember(-1, e, !e.fav);
            toast("{s}", .{if (e.fav) "Removed from Favourites" else "Added to Favourites"});
        },
        2 => {
            lib_menu = .add;
            return markFull(WF_REAGL);
        },
        3 => {
            lib_menu = .remove;
            return markFull(WF_REAGL);
        },
        4 => return openNameEditor(.coll_new, 0, lib_menu_entry),
        5 => return openNameEditor(.coll_rename, lib_menu_coll, null),
        6 => {
            lib_menu = .confirm_delete;
            return markFull(WF_REAGL);
        },
        7 => {
            deleteCollection(lib_menu_coll);
            toast("Collection deleted; books kept", .{});
        },
        8 => return startShrink(e),
        9 => {
            zr_shrink_cancel();
            lib_menu = .shrink_run;
            setShrinkMsg("Cancelling...", .{});
            return markFull(WF_REAGL);
        },
        10 => return useShrunk(e),
        11 => {
            discardShrunk();
            toast("Smaller copy discarded", .{});
            return markFull(WF_REAGL);
        },
        12 => {
            lib_menu = .orig_confirm;
            setShrinkMsg("Delete {d:.1} MB of originals? This cannot be undone.", .{mb(originalsBytes())});
            return markFull(WF_REAGL);
        },
        13 => {
            var ob: [600]u8 = undefined;
            const d = std.fmt.bufPrintSentinel(&ob, "{s}/originals", .{opts.data}, 0) catch return;
            _ = zr_rm_tree(d);
            toast("Originals deleted", .{});
            return markFull(WF_REAGL);
        },
        else => {
            if (code >= 100) {
                const c: usize = @intCast(code - 100);
                const was_add = (e.cmask >> @intCast(c)) & 1 == 0;
                setMember(@intCast(c), e, was_add);
                toast("{s} {s}", .{ if (was_add) "Added to" else "Removed from", collName(c) });
            } else return markFull(WF_REAGL);
        },
    }
    refreshLibraryAfterCollections();
}
fn libLongPress(x: i32, y: i32) void {
    if (lib_menu != .none) return;
    loadCollections();
    const per = rowsPerPage();
    for (0..per) |i| {
        if (!rowRect(i).contains(x, y)) continue;
        const k = list_page * per + i;
        if (k >= libraryCount()) return;
        if (folder_picker) {
            lib_menu_coll = pickerColl(k) orelse return;
            lib_menu = .coll;
        } else {
            lib_menu_entry = lib_visible[k];
            lib_menu = .book;
        }
        return markFull(WF_REAGL);
    }
}
fn openNameEditor(t: EditTarget, coll: usize, add_entry: ?usize) void {
    edit_target = t;
    edit_coll = coll;
    edit_add_entry = add_entry;
    note_len = 0;
    if (t == .coll_rename) {
        note_len = coll_lens[coll];
        @memcpy(note_buf[0..note_len], collName(coll));
    }
    note_shift = note_len == 0;
    folder_picker = false;
    showScreen(.noteedit);
}
fn closeNameEditor(save: bool) void {
    const t = edit_target;
    edit_target = .note;
    const name = std.mem.trim(u8, note_buf[0..@min(note_len, 63)], " ");
    var ok_name = save and name.len > 0;
    if (ok_name) {
        for (0..ncoll) |c| if (std.ascii.eqlIgnoreCase(collName(c), name) and !(t == .coll_rename and c == edit_coll)) {
            ok_name = false;
        };
        if (!ok_name) {
            showScreen(.library);
            refreshLibraryAfterCollections();
            return toast("A collection with that name exists", .{});
        }
    }
    showScreen(.library);
    if (!ok_name) return refreshLibraryAfterCollections();
    var clean: [64]u8 = undefined;
    for (name, 0..) |c, i| clean[i] = if (c == '\t' or c < 0x20) ' ' else c;
    if (t == .coll_new) {
        if (ncoll >= MAXCOLL) return toast("Too many collections", .{});
        coll_lens[ncoll] = name.len;
        @memcpy(coll_names[ncoll][0..name.len], clean[0..name.len]);
        ncoll += 1;
        if (edit_add_entry) |ei| if (ei < nlib) setMember(@intCast(ncoll - 1), &lib[ei], true);
        toast("Collection created", .{});
        logf("collection created", .{});
    } else {
        coll_lens[edit_coll] = name.len;
        @memcpy(coll_names[edit_coll][0..name.len], clean[0..name.len]);
        toast("Collection renamed", .{});
    }
    refreshLibraryAfterCollections();
}

// v0.9.9: the main loop sleeps until the next real deadline instead of
// waking ten times a second. Workers, covers and powerd events wake it
// through the existing render pipe; input wakes it through its own fds.
fn idleTimeoutMs(last_input: u64, last_save: u64) i32 {
    if (opts.legacy_poll) return 100;
    if (sleep_phase != .awake and sleep_phase != .asleep) return 100;
    if (in_flight or need_page or !dirty.empty() or pending_shot != null or slider_active or light_drag != null or gs.down) return 100;
    if (screen == .library and lib_hold) return 15;
    const now = nowUs();
    var until: u64 = 60_000_000;
    if (toast_len > 0) until = @min(until, toast_until -| now);
    if (search_hit != null and search_hit_until > 0) until = @min(until, search_hit_until -| now);
    if (opts.idle_min > 0) until = @min(until, (last_input + opts.idle_min * 60 * 1_000_000) -| now);
    if (book.state_dirty) until = @min(until, (@max(last_save + 2_000_000, last_input + 1_500_000) -| now) + 10_000);
    if (stats_dirty) until = @min(until, (stats_last_save + 60_000_000) -| now);
    if (stats_state_active) until = @min(until, (stats_last_activity + @as(u64, opts.stats_idle_sec) * 1_000_000) -| now);
    return @intCast(std.math.clamp(until / 1000 + 1, 1, 60_000));
}

fn redraw() bool {
    if (sleep_phase != .awake) {
        drawSleeping();
        return true;
    }
    switch (screen) {
        .library => drawLibrary(),
        .toc => drawToc(),
        .notes => drawNotes(),
        .search => drawSearch(),
        .device => drawDevice(),
        .upload => drawUpload(),
        .bookmarks => drawBookmarks(),
        .noteedit => drawNoteEditor(),
        .stats => drawStats(),
        .reader => return drawReader(),
    }
    return true;
}

// Submits pending work if the panel is idle; otherwise it stays queued (and coalesces).
fn pump() void {
    if (in_flight) return;
    if (sleep_phase == .awake and screen == .reader and need_page) {
        if (!redraw()) return;
        if (pc_preview_active) {
            pc_preview_active = false;
            first_clean = false;
            if (previous_page == pool.cur and pcSameAsPreview()) {
                // The saved image already on screen is what the real page looks like.
                if (slotFor(pool.cur)) |i| {
                    previous_metrics = pool.slots[i].metrics;
                    saveSamples(previous_samples, pool.slots[i].buf, W, H, STRIDE);
                }
                need_page = false;
                dirty = .{};
                dirty_mode = WF_DU;
                logf("page cache: real page matches saved image; no update", .{});
                return;
            }
            logf("page cache: real page differs from saved image; normal update", .{});
        }
        if (pc_first_frame_pending) {
            pc_first_frame_pending = false;
            logf("open profile: first_frame_us={d} (rendered)", .{nowUs() - pc_open_us});
        }
        const choice = incomingChoice();
        const mode = choice.mode;
        const upd: u32 = if (mode == WF_GL16) UPDATE_MODE_PARTIAL else UPDATE_MODE_FULL;
        first_clean = false;
        need_page = false;
        dirty = .{};
        dirty_mode = WF_DU;
        const m = sendUpdate(Rect.full(), mode, upd);
        t_submit = nowUs();
        if (tap_pending_measure) st_tap_submit.add(t_submit -| t_tap);
        in_flight = true;
        waitAsync(m);
        return;
    }
    if (!dirty.empty()) {
        if (!redraw()) return;
        const mode = dirty_mode;
        const upd: u32 = if (mode == WF_GL16 or mode == WF_DU) UPDATE_MODE_PARTIAL else UPDATE_MODE_FULL;
        const r = if (mode == WF_GC16) Rect.full() else dirty;
        if (mode == WF_GC16) text_since_clean = 0;
        dirty = .{};
        dirty_mode = WF_DU;
        const m = sendUpdate(r, mode, upd);
        t_submit = nowUs();
        tap_pending_measure = false;
        in_flight = true;
        waitAsync(m);
    }
}

fn onComplete() void {
    in_flight = false;
    const now = nowUs();
    st_update.add(now - t_submit);
    if (tap_pending_measure) {
        st_tap_complete.add(now -| t_tap);
        tap_pending_measure = false;
    }
}

// ---------------- actions ----------------
fn goPage(p: i32, t_ev: u64) void {
    if (!book.open) return;
    const np = std.math.clamp(p, 0, pool.npages - 1);
    if (np == pool.cur and !need_page) return;
    statsPageTurn(pool.cur, np);
    _ = pthread_mutex_lock(&pool.mtx);
    if (np != pool.cur) pool.dir = if (np > pool.cur) 1 else -1;
    pool.cur = np;
    pool.step = 0;
    search_hit = null;
    search_hit_until = 0;
    book.position = .{};
    _ = pthread_cond_broadcast(&pool.cond);
    _ = pthread_mutex_unlock(&pool.mtx);
    if (need_page) coalesced += 1;
    need_page = true;
    if (!tap_pending_measure or t_ev == 0) t_tap = t_ev;
    tap_pending_measure = t_ev != 0;
    turns += 1;
    pc_turns += 1;
    book.state_dirty = true;
    sel_active = false;
    popup_open = false;
    editing_note = null;
    dragging_handle = .none;
}

fn showScreen(s: Screen) void {
    if (screen == .upload and s != .upload) stopUpload();
    if (s == .upload and screen != .upload) startUpload();
    dictionary_open = false;
    if (s != .search) search_running = false;
    search_hit = null;
    screen = s;
    list_page = 0;
    menu_open = false;
    center_pending = false;
    popup_open = false;
    editing_note = null;
    dragging_handle = .none;
    sel_active = false;
    if (s == .reader) {
        first_clean = true;
        need_page = true;
        tap_pending_measure = false;
    } else if (s == .library) libPageChange(WF_REAGL) else markFull(WF_REAGL);
}

fn openFromLibrary(i: usize) void {
    if (i >= nlib) return;
    if (openBook(lib[i].path)) {
        first_clean = true;
        showScreen(.reader);
    } else if (open_drm) toast("This book is DRM-protected and can't be opened", .{}) else toast("Could not open this book", .{});
}

fn listNav(x: i32, y: i32) bool {
    if (pagerPrev().contains(x, y) and list_page > 0) {
        list_page -= 1;
        if (screen == .library) libPageChange(WF_REAGL) else markFull(WF_REAGL);
        return true;
    }
    if (pagerNext().contains(x, y)) {
        list_page += 1;
        if (screen == .library) libPageChange(WF_REAGL) else markFull(WF_REAGL);
        return true;
    }
    return false;
}

// v0.8.2 exit gesture: three taps in a row inside the top-left corner (W/6 x H/8)
// of a list screen (library, folders, Contents, Notes, search, device). That area
// holds no button on those screens. In the book view every corner is a page-turn
// zone, so the gesture is off there (use menu -> Quit). Any other tap, handled or
// not, resets the count, so fast paging / page turning can never quit.
var corner_taps: [3]u64 = .{ 0, 0, 0 };
fn exitCorner(x: i32, y: i32) bool {
    if (screen == .reader) return false;
    return x < @divTrunc(@as(i32, @intCast(W)), 6) and y < @divTrunc(@as(i32, @intCast(H)), 8);
}
fn onTap(x: i32, y: i32, t_ev: u64) void {
    if (sleep_phase != .awake) return;
    if (!exitCorner(x, y)) {
        corner_taps = .{ 0, 0, 0 };
    } else {
        corner_taps[0] = corner_taps[1];
        corner_taps[1] = corner_taps[2];
        corner_taps[2] = t_ev;
        if (corner_taps[0] != 0 and corner_taps[2] - corner_taps[0] < 1_500_000) {
            logf("exit gesture (top-left triple tap); exiting", .{});
            quit_requested = true;
            return;
        }
        return;
    }
    const per = rowsPerPage();
    switch (screen) {
        .library => {
            if (lib_menu != .none) return libMenuTap(x, y);
            if (libraryControl(0).contains(x, y)) {
                lib_sort = (lib_sort + 1) % SORT_NAMES.len;
                saveUi07();
                sortLibrary();
                list_page = 0;
                libPageChange(WF_REAGL);
                return;
            }
            if (libraryControl(1).contains(x, y)) {
                folder_picker = !folder_picker;
                list_page = 0;
                libPageChange(WF_REAGL);
                return;
            }
            if (libraryControl(2).contains(x, y)) return openDevice();
            if (book.open and topButton(true).contains(x, y)) return showScreen(.reader);
            if (listNav(x, y)) return;
            for (0..per) |i| if (rowRect(i).contains(x, y)) {
                const k = list_page * per + i;
                if (k >= libraryCount()) return;
                if (folder_picker) {
                    if (k == newRow()) return openNameEditor(.coll_new, 0, null);
                    pickerChoose(k);
                    folder_picker = false;
                    filterLibrary();
                    list_page = 0;
                    libPageChange(WF_REAGL);
                    return;
                }
                return openFromLibrary(lib_visible[k]);
            };
        },
        .toc, .notes => {
            if (topButton(true).contains(x, y)) return showScreen(.reader);
            if (screen == .toc and !book.toc_real) {
                if (libraryControl(0).contains(x, y)) return openGoto(.goto_page);
                if (libraryControl(1).contains(x, y)) return openGoto(.goto_pct);
            }
            if (listNav(x, y)) return;
            for (0..per) |i| {
                if (!rowRect(i).contains(x, y)) continue;
                const k = list_page * per + i;
                if (screen == .toc and book.toc_detected and k < book.ntoc) {
                    showScreen(.reader);
                    return goPage(book.toc[k].page, t_ev);
                }
                if (screen == .toc and k < book.ntoc) {
                    showScreen(.reader);
                    return goPage(book.toc[k].page, t_ev);
                }
                if (screen == .notes and k < book.nnotes) {
                    if (book.reflow and book.notes[k].unresolved) return toast("Passage retained, but its location could not be resolved", .{});
                    showScreen(.reader);
                    return goPage(book.notes[k].page, t_ev);
                }
            }
        },
        .reader => onReaderTap(x, y, t_ev),
        .search => searchTap(x, y, t_ev),
        .device => deviceTap(x, y),
        .upload => uploadTap(x, y),
        .bookmarks => bookmarksTap(x, y, t_ev),
        .noteedit => noteEditorTap(x, y),
        .stats => statsTap(x, y),
    }
}

fn onReaderTap(x: i32, y: i32, t_ev: u64) void {
    if (dictionary_open) return definitionTap(x, y);
    if (popup_open) {
        for (popupOrder()) |i| {
            if (popupButton(i).contains(x, y)) return popupAction(i);
        }
        // v0.9.6: with a fresh selection, tapping another word makes it the end word.
        if (editing_note == null and sel_active) {
            loadWords();
            if (wordAt(x, y, false)) |w| {
                const old = Rect.unite(selectionScreenRect(), popupRect().grow(10));
                const anchor_word = sel_a;
                sel_a = @min(anchor_word, w);
                sel_b = @max(anchor_word, w);
                return markDirty(Rect.unite(old, Rect.unite(selectionScreenRect(), popupRect().grow(10))), WF_REAGL);
            }
        }
        return popupAction(3);
    }
    if (menu_open) {
        if (panelButton(2, 2).contains(x, y)) return openDevice();
        if (panelButton(2, 3).contains(x, y)) return showScreen(.bookmarks);
        if (refreshButton().contains(x, y)) return cycleRefreshSetting();
        if (topButton(false).contains(x, y)) {
            saveState();
            scanLibrary();
            return showScreen(.library);
        }
        if (topButton(true).contains(x, y)) {
            quit_requested = true;
            return;
        }
        if (panelButton(2, 1).contains(x, y)) {
            const exported = exportAllNotes();
            toast("Exported {d} books / {d} errors", .{ exported.books, exported.errors });
            return;
        }
        if (panelButton(2, 0).contains(x, y)) {
            search_editing = true;
            need_page = false;
            return showScreen(.search);
        }
        if (panelButton(0, 0).contains(x, y)) {
            showScreen(.toc);
            return ensureDetectedToc();
        }
        if (panelButton(0, 1).contains(x, y)) return showScreen(.notes);
        if (panelButton(0, 2).contains(x, y)) {
            menu_open = false;
            return markFull(WF_GC16);
        }
        if (book.is_pdf and panelButton(1, 3).contains(x, y)) {
            _ = pthread_mutex_lock(&pool.mtx);
            pool.split = !pool.split;
            pool.step = 0;
            pool.gen +%= 1;
            pool.shown = -1;
            _ = pthread_cond_broadcast(&pool.cond);
            _ = pthread_mutex_unlock(&pool.mtx);
            book.words_page = -1;
            book.state_dirty = true;
            need_page = true;
            toast("Split two-page scans: {s}", .{if (pool.split) "on" else "off"});
            return markFull(WF_REAGL);
        }
        if (panelButton(0, 3).contains(x, y)) {
            if (book.is_pdf) {
                _ = pthread_mutex_lock(&pool.mtx);
                pool.trim = !pool.trim;
                pool.gen +%= 1;
                pool.shown = -1;
                _ = pthread_cond_broadcast(&pool.cond);
                _ = pthread_mutex_unlock(&pool.mtx);
                book.words_page = -1;
                book.state_dirty = true;
                need_page = true;
                return;
            }
            menu_open = false;
            return goPage(0, t_ev);
        }
        if (book.is_pdf) {
            if (panelButton(1, 0).contains(x, y)) {
                const mode: ViewMode = @fromBackingInt(@intCast((@backingInt(pool.view) + @as(u8, 1)) % 4));
                setView(mode, null);
                return;
            }
            if (panelButton(1, 1).contains(x, y)) {
                return setView(pool.view, null);
            }
            if (panelButton(1, 2).contains(x, y)) {
                toggleBookmark();
                menu_open = false;
                return markFull(WF_GC16);
            }
        }
        if (book.reflow) {
            const f = pool.font;
            const m = pool.margin;
            if (bookFontButton().contains(x, y)) return setTextStyle(text_mode, @mod(book_font + 1, 3));
            if (textModeButton().contains(x, y)) return setTextStyle(@mod(text_mode + 2, 3), book_font);
            if (spacingButton().contains(x, y)) {
                const spacing: f32 = if (pool.spacing < 1.3) 1.4 else if (pool.spacing < 1.6) 1.7 else 1.15;
                relayoutStyle(f, m, spacing);
                need_page = true;
                return;
            }
            if (panelButton(1, 0).contains(x, y)) return relayoutAndShow(fontStep(f, -1), m);
            if (panelButton(1, 1).contains(x, y)) return relayoutAndShow(fontStep(f, 1), m);
            if (panelButton(1, 2).contains(x, y)) return relayoutAndShow(f, @max(m - 6, 0));
            if (panelButton(1, 3).contains(x, y)) return relayoutAndShow(f, @min(m + 6, 60));
        }
        if (bottomPanel().contains(x, y) or topBar().contains(x, y)) return;
        menu_open = false;
        return markFull(WF_GC16);
    }
    if (annotationAt(x, y)) |k| {
        editing_note = k;
        popup_open = true;
        sel_active = false;
        return markDirty(popupRect().grow(10), WF_REAGL);
    }
    const xs: i32 = @intCast(W);
    if (x < @divTrunc(xs * 3, 10)) return turnView(-1, t_ev);
    if (x > @divTrunc(xs * 7, 10)) return turnView(1, t_ev);
    if (book.is_pdf and !center_dispatch) {
        center_pending = true;
        center_x = x;
        center_y = y;
        center_t = nowUs();
        return;
    }
    menu_open = true;
    markDirty(topBar(), WF_GL16);
    markDirty(bottomPanel(), WF_GL16);
}

const FONT_PX = [_]f32{ 14, 16, 18, 20, 23, 26, 30, 34, 40 };
fn fontStep(current: f32, dir: i32) f32 {
    if (dir > 0) {
        for (FONT_PX) |px| if (px * 0.75 > current + 0.01) return px * 0.75;
        return FONT_PX[FONT_PX.len - 1] * 0.75;
    }
    var i = FONT_PX.len;
    while (i > 0) {
        i -= 1;
        if (FONT_PX[i] * 0.75 < current - 0.01) return FONT_PX[i] * 0.75;
    }
    return FONT_PX[0] * 0.75;
}
fn relayoutAndShow(f: f32, m: f32) void {
    relayout(f, m);
    toast("Text {d:.0}px \xc2\xb7 margin {d:.0} pt", .{ f / 0.75, m });
    need_page = true;
}

fn popupAction(i: i32) void {
    if (i == 4 and editing_note == null and sel_active and sel_a == sel_b) return defineSelection();
    const region = Rect.unite(selectionScreenRect(), popupRect().grow(10));
    if (editing_note) |k| {
        if (i == 5) {
            editing_note = null;
            popup_open = false;
            sel_active = false;
            return openNoteEditor(k);
        }
        if (i == 0) {
            deleteNote(k);
            toast("Annotation deleted", .{});
        } else if (i == 1) {
            book.notes[k].style = if (book.notes[k].style == 0) 1 else 0;
            saveNotes();
        } else if (i == 2 and book.nnotes < book.notes.len) {
            var n = book.notes[k];
            n.text = alloc.dupe(u8, n.text) catch return;
            n.comment = alloc.dupe(u8, n.comment) catch &.{};
            n.style = 2;
            n.ts = zr_now_seconds();
            book.notes[book.nnotes] = n;
            book.nnotes += 1;
            saveNotes();
            toast("Copied to notes", .{});
        }
        editing_note = null;
        popup_open = false;
        sel_active = false;
        closeOverlayRefresh(Rect.full());
        return;
    }
    const with_note = i == 5;
    if (((i >= 0 and i <= 2) or with_note) and book.nnotes < book.notes.len) {
        const style: usize = if (with_note) 1 else @intCast(i);
        var n: Note = undefined;
        n.comment = &.{};
        n.anchor = .{};
        n.unresolved = false;
        if (book.reflow and zr_anchor_words(book.doc, pool.cur, @intCast(@min(sel_a, sel_b)), @intCast(@max(sel_a, sel_b)), &n.anchor) == 0) n.unresolved = true;
        n.page = pool.cur;
        n.style = @intCast(style);
        n.ts = zr_now_seconds();
        var tb: [8192]u8 = undefined;
        n.text = alloc.dupe(u8, selectionText(&tb)) catch &.{};
        n.nq = selectionQuads(sel_a, sel_b, &n.q);
        book.notes[book.nnotes] = n;
        book.nnotes += 1;
        saveNotes();
        logf("note saved: page {d} {s} ({d} quads)", .{ n.page + 1, STYLE_NAMES[style], n.nq });
        if (with_note) {
            sel_active = false;
            popup_open = false;
            return openNoteEditor(book.nnotes - 1);
        }
        if (n.unresolved) toast("Saved text / location unresolved", .{}) else toast("Saved {s} \xc2\xb7 p. {d}", .{ STYLE_NAMES[style], pool.cur + 1 });
    }
    sel_active = false;
    popup_open = false;
    closeOverlayRefresh(region);
}

fn onLongPress(x: i32, y: i32) void {
    handle_dx = 0;
    handle_dy = 0;
    switch (screen) {
        .reader => {
            if (dictionary_open or menu_open or popup_open or !textReady()) return;
            loadWords();
            const w = wordAt(x, y, false) orelse return;
            sel_active = true;
            sel_a = w;
            sel_b = w;
            editing_note = null;
            markDirty(selectionScreenRect(), WF_DU);
        },
        .bookmarks => bookmarksLongPress(x, y),
        .library => libLongPress(x, y),
        .notes => {
            const per = rowsPerPage();
            for (0..per) |i| {
                if (!rowRect(i).contains(x, y)) continue;
                const k = list_page * per + i;
                if (k >= book.nnotes) return;
                deleteNote(k);
                toast("Note deleted", .{});
                markFull(WF_REAGL);
                return;
            }
        },
        else => {},
    }
}

fn onDrag(x: i32, y: i32) void {
    if (sel_active and !popup_open) {
        const w = wordAt(x + handle_dx, y + handle_dy, true) orelse return;
        const before = selectionScreenRect();
        if (dragging_handle == .start) {
            if (w == sel_a) return;
            sel_a = @min(w, sel_b);
        } else {
            if (w == sel_b) return;
            sel_b = if (dragging_handle == .end) @max(w, sel_a) else w;
        }
        markDirty(Rect.unite(before, selectionScreenRect()), WF_DU);
    } else if (slider_active) {
        const sr = sliderRect();
        const frac = std.math.clamp(@as(f32, @floatFromInt(x - sr.x)) / @as(f32, @floatFromInt(sr.w)), 0, 1);
        const p: i32 = @intFromFloat(@round(frac * @as(f32, @floatFromInt(pool.npages - 1))));
        if (p != slider_page) {
            slider_page = p;
            markDirty(.{ .x = 0, .y = bottomPanel().y, .w = @intCast(W), .h = 200 }, WF_GL16);
        }
    }
}

// ---------------- gestures ----------------
const Gesture = struct {
    down: bool = false,
    x0: i32 = 0,
    y0: i32 = 0,
    t0: u64 = 0,
    x: i32 = 0,
    y: i32 = 0,
    moved: bool = false,
    long_fired: bool = false,
};
var gs: Gesture = .{};
const LONG_US: u64 = 550_000;
const MOVE_TOL: i32 = 36;

fn finishPan(dx: i32, dy: i32) void {
    const g = visibleGeometry() orelse return;
    const old_shown = pool.shown;
    _ = pthread_mutex_lock(&pool.mtx);
    if (g.max_x > 0) pool.pan_x = std.math.clamp(pool.pan_x - @as(f32, @floatFromInt(dx)) / g.max_x, 0, 1);
    if (g.max_y > 0) pool.pan_y = std.math.clamp(pool.pan_y - @as(f32, @floatFromInt(dy)) / g.max_y, 0, 1);
    invalidateView();
    instantDraft(old_shown, g);
    _ = pthread_mutex_unlock(&pool.mtx);
    logf("PDF pan: x={d:.3} y={d:.3}", .{ pool.pan_x, pool.pan_y });
}
const DOUBLE_TAP_US: u64 = 220_000;
var center_pending = false;
var center_x: i32 = 0;
var center_y: i32 = 0;
var center_t: u64 = 0;
var center_dispatch = false;
var zoom_second = false;
fn flushCenterTap() void {
    if (!center_pending) return;
    center_pending = false;
    center_dispatch = true;
    onReaderTap(center_x, center_y, center_t);
    center_dispatch = false;
}
fn checkCenterTap() void {
    if (center_pending and !gs.down and nowUs() -| center_t >= DOUBLE_TAP_US) flushCenterTap();
}
fn onDown(x: i32, y: i32, t: u64) void {
    if (sleep_phase != .awake) return;
    if (screen == .device) {
        for (0..2) |i| if (lightSlider(i).contains(x, y)) {
            light_drag = i;
            changeLight(i, lightAt(x));
            break;
        };
    }
    zoom_second = false;
    if (center_pending) {
        if (t -| center_t < DOUBLE_TAP_US and @abs(x - center_x) < 90 and @abs(y - center_y) < 90) {
            zoom_second = true;
            center_pending = false;
        } else flushCenterTap();
    }
    gs = .{ .down = true, .x0 = x, .y0 = y, .t0 = t, .x = x, .y = y };
    handle_dx = 0;
    handle_dy = 0;
    if (screen == .reader and sel_active and popup_open and editing_note == null) {
        // Wrapped selections can put the two generous hit targets almost on
        // top of one another. Choose the nearest centre, never first-match.
        const start_r = handleRect(.start);
        const end_r = handleRect(.end);
        const sx = x - start_r.x - @divTrunc(start_r.w, 2);
        const sy = y - start_r.y - @divTrunc(start_r.h, 2);
        const ex = x - end_r.x - @divTrunc(end_r.w, 2);
        const ey = y - end_r.y - @divTrunc(end_r.h, 2);
        const prefer_end = end_r.grow(28).contains(x, y) and
            (!start_r.grow(28).contains(x, y) or ex * ex + ey * ey < sx * sx + sy * sy);
        const which: Handle = if (prefer_end) .end else .start;
        const hr = handleRect(which);
        if (hr.grow(28).contains(x, y)) {
            const old = Rect.unite(selectionScreenRect(), popupRect().grow(10));
            const a = @min(sel_a, sel_b);
            const b = @max(sel_a, sel_b);
            sel_a = a;
            sel_b = b;
            dragging_handle = which;
            const wr = toScreen(wordRect(if (which == .start) sel_a else sel_b));
            handle_dx = wr.x + @divTrunc(wr.w, 2) - x;
            handle_dy = wr.y + @divTrunc(wr.h, 2) - y;
            gs.long_fired = true;
            popup_open = false;
            markDirty(old, WF_DU);
            return;
        }
    }
    if (screen == .reader and menu_open and sliderRect().grow(20).contains(x, y)) {
        slider_active = true;
        slider_page = pool.cur;
        onDrag(x, y);
    }
}
fn onMove(x: i32, y: i32) void {
    if (sleep_phase != .awake) return;
    if (light_drag) |i| {
        changeLight(i, lightAt(x));
        return;
    }
    gs.x = x;
    gs.y = y;
    if (@abs(x - gs.x0) > MOVE_TOL or @abs(y - gs.y0) > MOVE_TOL) gs.moved = true;
    if (gs.long_fired or slider_active) onDrag(x, y);
}
fn onUp(t: u64) void {
    gs.down = false;
    if (sleep_phase != .awake) return;
    if (light_drag != null) {
        light_drag = null;
        return;
    }
    if (dictionary_open) {
        if (!gs.moved and !gs.long_fired) definitionTap(gs.x0, gs.y0);
        return;
    }
    if (zoom_second and !gs.moved and screen == .reader and book.is_pdf) {
        zoom_second = false;
        return zoomCycle(gs.x0, gs.y0);
    }
    if (slider_active) {
        slider_active = false;
        if (slider_page != pool.cur) goPage(slider_page, t) else markDirty(bottomPanel(), WF_GL16);
        return;
    }
    if (sel_active and gs.long_fired) {
        // v0.9.6: a plain tap that landed on a handle's generous hit area
        // still means "make this word the end word".
        const tapped_handle = dragging_handle != .none and !gs.moved and editing_note == null;
        dragging_handle = .none;
        if (tapped_handle) {
            loadWords();
            if (wordAt(gs.x0, gs.y0, false)) |w| {
                if (w < sel_a) sel_a = w else sel_b = w;
            }
        }
        popup_open = true;
        markDirty(Rect.unite(selectionScreenRect(), popupRect().grow(10)), WF_REAGL);
        return;
    }
    if (gs.long_fired) return;
    const dx = gs.x - gs.x0;
    const dy = gs.y - gs.y0;
    if (gs.moved) {
        if (screen == .reader and book.is_pdf and !menu_open and !popup_open) {
            if (pool.view == .zoom15 or pool.view == .zoom2) {
                return finishPan(dx, dy);
            }
            if (pool.view == .width and @abs(dy) > 150 and @abs(dy) > @abs(dx)) {
                return turnView(if (dy < 0) 1 else -1, t);
            }
        }
        if (screen == .reader and !menu_open and !popup_open and @abs(dx) > 150 and @abs(dx) > @abs(dy)) {
            turnView(if (dx < 0) 1 else -1, t);
        }
        return;
    }
    onTap(gs.x0, gs.y0, t);
}
fn checkLongPress() void {
    if (sleep_phase != .awake or screen == .device) return;
    if (gs.down and !gs.moved and !gs.long_fired and !slider_active and nowUs() -| gs.t0 >= LONG_US) {
        gs.long_fired = true;
        onLongPress(gs.x, gs.y);
    }
}

// ---------------- input devices ----------------
const Input = struct {
    touch_fd: i32 = -1,
    power_fd: i32 = -1,
    xmin: i32 = 0,
    xmax: i32 = 0,
    ymin: i32 = 0,
    ymax: i32 = 0,
    slot: i32 = 0,
    got_mt: bool = false,
    rx: i32 = 0,
    ry: i32 = 0,
    down: bool = false,
    was_down: bool = false,
    grabbed: bool = false,
};
var in: Input = .{};

fn testBit(bits: []const u8, b: usize) bool {
    return b / 8 < bits.len and (bits[b / 8] >> @intCast(b % 8)) & 1 == 1;
}
fn findInputs() void {
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        var pbuf: [32]u8 = undefined;
        const path = std.fmt.bufPrintSentinel(&pbuf, "/dev/input/event{d}", .{i}, 0) catch continue;
        const rc = linux.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true, .CLOEXEC = true }, 0);
        if (bad(rc)) continue;
        const fd: i32 = @intCast(rc);
        var absb: [8]u8 = @splat(0);
        var keyb: [96]u8 = @splat(0);
        _ = linux.ioctl(fd, EVIOCGBIT(EV_ABS, absb.len), @intFromPtr(&absb));
        _ = linux.ioctl(fd, EVIOCGBIT(EV_KEY, keyb.len), @intFromPtr(&keyb));
        if (in.touch_fd < 0 and testBit(&absb, ABS_MT_POSITION_X) and testBit(&absb, ABS_MT_POSITION_Y)) {
            var ax = std.mem.zeroes(AbsInfo);
            var ay = std.mem.zeroes(AbsInfo);
            _ = linux.ioctl(fd, EVIOCGABS(ABS_MT_POSITION_X), @intFromPtr(&ax));
            _ = linux.ioctl(fd, EVIOCGABS(ABS_MT_POSITION_Y), @intFromPtr(&ay));
            in.touch_fd = fd;
            in.xmin = ax.minimum;
            in.xmax = ax.maximum;
            in.ymin = ay.minimum;
            in.ymax = ay.maximum;
            logf("touch: {s} x[{d},{d}] y[{d},{d}]", .{ path, ax.minimum, ax.maximum, ay.minimum, ay.maximum });
            continue;
        }
        if (in.power_fd < 0 and testBit(&keyb, KEY_POWER)) {
            in.power_fd = fd;
            logf("power: {s}", .{path});
            continue;
        }
        _ = linux.close(fd);
    }
    const mono: c_int = 1;
    if (in.touch_fd >= 0) {
        _ = linux.ioctl(in.touch_fd, EVIOCSCLOCKID, @intFromPtr(&mono));
        var one: c_int = 1;
        in.grabbed = !bad(linux.ioctl(in.touch_fd, EVIOCGRAB, @intFromPtr(&one)));
        if (!in.grabbed) logf("WARNING: EVIOCGRAB on the touch device FAILED (another process holds it); reading non-exclusively", .{});
    } else logf("WARNING: no touch device found", .{});
    if (in.power_fd >= 0) _ = linux.ioctl(in.power_fd, EVIOCSCLOCKID, @intFromPtr(&mono));
}
fn mapX(v: i32) i32 {
    if (in.xmax <= in.xmin) return v;
    return @intCast(@divTrunc(@as(i64, v - in.xmin) * W, in.xmax - in.xmin + 1));
}
fn mapY(v: i32) i32 {
    if (in.ymax <= in.ymin) return v;
    return @intCast(@divTrunc(@as(i64, v - in.ymin) * H, in.ymax - in.ymin + 1));
}

// ---------------- simulator (host testing) ----------------
var sim_pipe_w: i32 = -1;
var shot_names: [64][64]u8 = undefined;
var shot_lens: [64]usize = undefined;
var nshots: usize = 0;
var pending_shot: ?usize = null;

fn simEmit(t: u16, c: u16, v: i32) void {
    const now = nowUs();
    const ev = InputEvent{ .sec = @intCast(now / 1_000_000), .usec = @intCast(now % 1_000_000), .type = t, .code = c, .value = v };
    _ = linux.write(sim_pipe_w, @ptrCast(&ev), @sizeOf(InputEvent));
}
fn simTouch(down: bool, x: i32, y: i32) void {
    if (down) {
        simEmit(EV_ABS, ABS_MT_TRACKING_ID, 1);
        simEmit(EV_ABS, ABS_MT_POSITION_X, x);
        simEmit(EV_ABS, ABS_MT_POSITION_Y, y);
        simEmit(EV_KEY, BTN_TOUCH, 1);
    } else {
        simEmit(EV_ABS, ABS_MT_TRACKING_ID, -1);
        simEmit(EV_KEY, BTN_TOUCH, 0);
    }
    simEmit(EV_SYN, SYN_REPORT, 0);
}
fn simMove(x: i32, y: i32) void {
    simEmit(EV_ABS, ABS_MT_POSITION_X, x);
    simEmit(EV_ABS, ABS_MT_POSITION_Y, y);
    simEmit(EV_SYN, SYN_REPORT, 0);
}
fn simDrag(x0: i32, y0: i32, x1: i32, y1: i32, steps: i32) void {
    var i: i32 = 1;
    while (i <= steps) : (i += 1) {
        simMove(x0 + @divTrunc((x1 - x0) * i, steps), y0 + @divTrunc((y1 - y0) * i, steps));
        sleepMs(30);
    }
}
fn simThread(_: ?*anyopaque) callconv(.c) ?*anyopaque {
    const data = readFile(opts.sim.?) orelse return null;
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \r\t");
        if (line.len == 0 or line[0] == '#') continue;
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const cmd = it.next() orelse continue;
        var a: [4]i32 = .{ 0, 0, 0, 0 };
        var k: usize = 0;
        var word: []const u8 = "";
        while (it.next()) |tok| {
            if (std.fmt.parseInt(i32, tok, 10)) |v| {
                if (k < 4) {
                    a[k] = v;
                    k += 1;
                }
            } else |_| word = tok;
        }
        if (eql(cmd, "down")) {
            simTouch(true, a[0], a[1]);
        } else if (eql(cmd, "move")) {
            simMove(a[0], a[1]);
        } else if (eql(cmd, "up")) {
            simTouch(false, a[0], a[1]);
        } else if (eql(cmd, "tap")) {
            simTouch(true, a[0], a[1]);
            sleepMs(60);
            simTouch(false, a[0], a[1]);
        } else if (eql(cmd, "long")) {
            simTouch(true, a[0], a[1]);
            sleepMs(800);
            if (k >= 4) simDrag(a[0], a[1], a[2], a[3], 12);
            sleepMs(100);
            simTouch(false, a[0], a[1]);
        } else if (eql(cmd, "swipe")) {
            simTouch(true, a[0], a[1]);
            simDrag(a[0], a[1], a[2], a[3], 6);
            simTouch(false, a[2], a[3]);
        } else if (eql(cmd, "popup") or eql(cmd, "menubtn")) {
            const r = if (eql(cmd, "popup")) popupButton(a[0]) else panelButton(a[0], a[1]);
            const cx = r.x + @divTrunc(r.w, 2);
            const cy = r.y + @divTrunc(r.h, 2);
            simTouch(true, cx, cy);
            sleepMs(60);
            simTouch(false, cx, cy);
        } else if (eql(cmd, "wait")) {
            sleepMs(@intCast(a[0]));
        } else if (eql(cmd, "shot") and nshots < shot_names.len) {
            const l = @min(word.len, 63);
            @memcpy(shot_names[nshots][0..l], word[0..l]);
            shot_lens[nshots] = l;
            simEmit(EV_SIM_SHOT, @intCast(nshots), 0);
            nshots += 1;
            sleepMs(400);
        } else if (eql(cmd, "event")) {
            simEmit(EV_SIM_SHOT, 0xFFFC, a[0]);
        } else if (eql(cmd, "power")) {
            simEmit(EV_SIM_SHOT, 0xFFFE, 0);
        } else if (eql(cmd, "wake")) {
            simEmit(EV_SIM_SHOT, 0xFFFD, 0);
        } else if (eql(cmd, "quit")) {
            simEmit(EV_SIM_SHOT, 0xFFFF, 0);
        }
    }
    alloc.free(data);
    return null;
}
fn writeShot(i: usize) void {
    var pb: [1200]u8 = undefined;
    const p = std.fmt.bufPrint(&pb, "{s}/{s}.pgm", .{ opts.shots, shot_names[i][0..shot_lens[i]] }) catch return;
    var b = Buf.init(STRIDE * H + 64);
    defer b.deinit();
    b.print("P5 {d} {d} 255\n", .{ W, H });
    var y: usize = 0;
    while (y < H) : (y += 1) b.put(fb[y * STRIDE ..][0..W]);
    _ = writeFileAtomic(p, b.slice());
    logf("shot {s}", .{p});
}

// Offline audit uses the exact production raster, metrics and decision functions.
// It never opens a framebuffer/input device, writes procfs, or touches settings.
fn auditRefresh() !u8 {
    const path = opts.book orelse {
        logf("audit requires a book path", .{});
        return 2;
    };
    const doc = zr_open(path, LW, LH, 9, 18) orelse return 1;
    defer zr_close(doc);
    const count = zr_page_count(doc);
    const pixels = try alloc.alloc(u8, @as(usize, STRIDE) * H);
    defer alloc.free(pixels);
    const samples = try alloc.alloc(u8, ((@as(usize, W) + SAMPLE_STEP - 1) / SAMPLE_STEP) * ((@as(usize, H) + SAMPLE_STEP - 1) / SAMPLE_STEP));
    defer alloc.free(samples);
    @memset(samples, 255);
    var old: PageMetrics = .{};
    var since: u32 = 0;
    var flashes: u32 = 0;
    var t_render: u64 = 0;
    var t_metrics: u64 = 0;
    const name = std.mem.span(path);
    const base = if (std.mem.lastIndexOfScalar(u8, name, '/')) |i| name[i + 1 ..] else name;
    const stem = if (std.mem.lastIndexOfScalar(u8, base, '.')) |i| base[0..i] else base;
    mkdirP(opts.shots);
    const csv_header = "page,ink,dark,tone,image,photo,dark_to_light,light_to_dark,reason,waveform,update_mode\n";
    _ = linux.write(1, csv_header.ptr, csv_header.len);
    var page: i32 = 0;
    while (page < count) : (page += 1) {
        var r: [4]f32 = undefined;
        const ni: c_int = @intFromBool(opts.no_images);
        const rc = if (zr_is_pdf(doc) != 0) zr_ink_bbox_flags(doc, page, &r, ni, imageFlags()) else zr_page_bounds(doc, page, &r);
        if (rc != 0) return 1;
        const m = fitMatrix(r);
        var rs: ZrRenderStats = .{};
        const start = nowUs();
        if (zr_render_with_stats(doc, page, &m, pixels.ptr, @intCast(W), @intCast(H), @intCast(STRIDE), ni, imageFlags(), &rs) != 0) return 1;
        t_render += nowUs() - start;
        const mt = nowUs();
        const next = pageMetrics(pixels, W, H, STRIDE, rs.image_coverage);
        const delta = transitionMetrics(samples, pixels, W, H, STRIDE);
        const choice = refreshChoice(old, next, delta, page - 1, page, false, since, opts.full_refresh, opts.wf);
        saveSamples(samples, pixels, W, H, STRIDE);
        t_metrics += nowUs() - mt;
        if (choice.mode == WF_GC16) {
            flashes += 1;
            since = 0;
        } else since += 1;
        old = next;
        var line: [512]u8 = undefined;
        const csv = try std.fmt.bufPrint(&line, "{d},{d:.5},{d:.5},{d:.5},{d:.5},{d:.5},{d:.5},{d:.5},{s},{d},{d}\n", .{ page + 1, next.ink, next.dark, next.tone, next.image, next.photo, delta.dark_to_light, delta.light_to_dark, @tagName(choice.reason), choice.mode, if (choice.mode == WF_GL16) UPDATE_MODE_PARTIAL else UPDATE_MODE_FULL });
        _ = linux.write(1, csv.ptr, csv.len);
        if (page < 4) {
            var pb: [1200]u8 = undefined;
            const shot = try std.fmt.bufPrint(&pb, "{s}/30_{s}_p{d}.pgm", .{ opts.shots, stem, page + 1 });
            var image = Buf.init(pixels.len + 64);
            defer image.deinit();
            image.print("P5 {d} {d} 255\n", .{ W, H });
            image.put(pixels);
            if (!writeFileAtomic(shot, image.slice())) return 1;
        }
    }
    logf("audit {s}: pages={d} full={d} per100={d:.2} every={d} mean_render_us={d} mean_metrics_and_delta_us={d}", .{ stem, count, flashes, @as(f32, @floatFromInt(flashes)) * 100 / @as(f32, @floatFromInt(count)), opts.full_refresh, t_render / @as(u64, @intCast(count)), t_metrics / @as(u64, @intCast(count)) });
    return 0;
}

// ---------------- main ----------------
var g_quit: bool = false;
fn onSignal(_: c_int) callconv(.c) void {
    @atomicStore(bool, &g_quit, true, .seq_cst);
}

fn usage() void {
    std.debug.print(
        \\zreader {s}
        \\usage: zreader [options] [book.pdf|.epub|.mobi|.azw3|.txt|.cbz|.fb2]     (no book: Library)
        \\  --wf reagl|gl16    page-turn waveform (default reagl; gl16 is for testing)
        \\  --full-refresh off|4|8|16 periodic clean (default off)
        \\  --no-image-dither  disable image-only 16-level dithering
        \\  --no-clean-scans   do not clean up scanned pages (default: on, Settings)
        \\  --audit-refresh    offline refresh CSV; no device access
        \\  --no-images        experimental: skip drawing images
        \\  --debug            timing line in the menu
        \\  --dictionary FILE  offline dictionary (default DATA/dictionary/wordnet.zdict)
        \\  --latin-dictionary FILE  offline Latin dictionary (default DATA/dictionary/latin.zdict)
        \\  --data DIR         state and notes (default /mnt/us/zreader)
        \\  --books DIR        library root (default /mnt/us/Books)
        \\  --log PATH         log file (default stderr)
        \\  --idle-min N       exit after N minutes without input (default 10, 0 = never)
        \\  --page-cache-mib N saved-page cache cap for instant reopen (default 20, 0 = off)
        \\  --no-governor      do not raise the CPU governor while rendering
        \\  --sim SCRIPT       host test mode: in-memory screen, scripted input
        \\  --shots DIR        where --sim writes screenshots (PGM)
        \\
    , .{VERSION});
}

fn parseArgs(argv: []const [*:0]const u8) bool {
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const a = std.mem.span(argv[i]);
        const has_next = i + 1 < argv.len;
        if (eql(a, "--wf") and has_next) {
            i += 1;
            const v = std.mem.span(argv[i]);
            opts.wf = if (eql(v, "gl16")) WF_GL16 else if (eql(v, "reagl")) WF_REAGL else return false;
        } else if (eql(a, "--shrink") and i + 2 < argv.len) {
            // v0.11.0: command-line form of "Shrink for Kindle" (IN OUT), for tests.
            const t0 = nowUs();
            const rc = zr_shrink_pdf(argv[i + 1], argv[i + 2], 80);
            std.debug.print("shrink rc={d} ms={d}\n", .{ rc, (nowUs() - t0) / 1000 });
            linux.exit(if (rc == 0) 0 else 1);
        } else if (eql(a, "--audit-refresh")) {
            opts.audit_refresh = true;
        } else if (eql(a, "--no-clean-scans") or eql(a, "--clean-scans")) {
            opts.clean_scans = eql(a, "--clean-scans");
            opts.clean_cli = true;
        } else if (eql(a, "--no-image-dither")) {
            opts.image_dither = false;
        } else if (eql(a, "--full-refresh") and has_next) {
            i += 1;
            const v = std.mem.span(argv[i]);
            opts.full_refresh = if (eql(v, "off")) 0 else std.fmt.parseInt(u8, v, 10) catch return false;
            if (opts.full_refresh != 0 and opts.full_refresh != 4 and opts.full_refresh != 8 and opts.full_refresh != 16) return false;
            opts.refresh_cli = true;
        } else if (eql(a, "--no-images")) {
            opts.no_images = true;
        } else if (eql(a, "--debug")) {
            opts.debug = true;
        } else if (eql(a, "--no-governor")) {
            opts.governor = false;
        } else if (eql(a, "--trim") or eql(a, "--no-trim")) {
            // trim is now a per-book setting toggled in the menu
        } else if (eql(a, "--data") and has_next) {
            i += 1;
            opts.data = std.mem.span(argv[i]);
        } else if (eql(a, "--dictionary") and has_next) {
            i += 1;
            opts.dictionary = argv[i];
        } else if (eql(a, "--latin-dictionary") and has_next) {
            i += 1;
            opts.latin_dictionary = argv[i];
        } else if (eql(a, "--books") and has_next) {
            i += 1;
            opts.books = std.mem.span(argv[i]);
        } else if (eql(a, "--log") and has_next) {
            i += 1;
            opts.log = argv[i];
        } else if (eql(a, "--sim-battery") and has_next) {
            i += 1;
            opts.sim_battery = std.fmt.parseInt(c_int, std.mem.span(argv[i]), 10) catch return false;
        } else if (eql(a, "--text-mode") and has_next) {
            i += 1;
            opts.text_mode = std.math.clamp(std.fmt.parseInt(c_int, std.mem.span(argv[i]), 10) catch return false, 0, 2);
        } else if (eql(a, "--legacy-poll")) {
            opts.legacy_poll = true;
        } else if (eql(a, "--stats-idle-sec") and has_next) {
            i += 1;
            opts.stats_idle_sec = std.fmt.parseInt(u32, std.mem.span(argv[i]), 10) catch return false;
        } else if (eql(a, "--upload-port") and has_next) {
            i += 1;
            opts.upload_port = std.fmt.parseInt(u16, std.mem.span(argv[i]), 10) catch return false;
        } else if (eql(a, "--upload-min-free-mib") and has_next) {
            i += 1;
            opts.upload_min_free_mib = std.fmt.parseInt(u64, std.mem.span(argv[i]), 10) catch return false;
        } else if (eql(a, "--page-cache-mib") and has_next) {
            i += 1;
            opts.page_cache_mib = std.fmt.parseInt(u64, std.mem.span(argv[i]), 10) catch return false;
        } else if (eql(a, "--idle-min") and has_next) {
            i += 1;
            opts.idle_min = std.fmt.parseInt(u64, std.mem.span(argv[i]), 10) catch return false;
        } else if (eql(a, "--sim") and has_next) {
            i += 1;
            opts.sim = argv[i];
        } else if (eql(a, "--shots") and has_next) {
            i += 1;
            opts.shots = std.mem.span(argv[i]);
        } else if (a.len > 0 and a[0] != '-' and opts.book == null) {
            opts.book = argv[i];
        } else return false;
    }
    return true;
}

pub fn main(init: std.process.Init.Minimal) !u8 {
    lp_main = nowUs();
    zr_no_core();
    const argv: []const [*:0]const u8 = @ptrCast(init.args.vector);
    if (argv.len == 2 and eql(std.mem.span(argv[1]), "--powerd-events")) return @intCast(zr_watch_events());
    if (argv.len == 4 and eql(std.mem.span(argv[1]), "--make-thumb")) return @intCast(zr_make_thumb(argv[2], argv[3]));
    if (!parseArgs(argv)) {
        usage();
        return 2;
    }
    if (opts.log) |lp| {
        const rc = linux.open(lp, .{ .ACCMODE = .WRONLY, .CREAT = true, .APPEND = true, .CLOEXEC = true }, 0o644);
        if (!bad(rc)) log_fd = @intCast(rc);
    }
    _ = signal(2, onSignal);
    _ = signal(15, onSignal);
    _ = signal(1, onSignal);
    if (opts.audit_refresh) return auditRefresh();
    logf("zreader {s} starting", .{VERSION});

    if (opts.sim == null) {
        const rc = linux.open("/dev/fb0", .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0);
        if (bad(rc)) {
            logf("cannot open /dev/fb0", .{});
            return 1;
        }
        fb_fd = @intCast(rc);
        var v: FbVar = undefined;
        var f: FbFix = undefined;
        if (bad(linux.ioctl(fb_fd, FBIOGET_VSCREENINFO, @intFromPtr(&v))) or bad(linux.ioctl(fb_fd, FBIOGET_FSCREENINFO, @intFromPtr(&f)))) return 1;
        if (v.bits_per_pixel != 8) {
            logf("expected 8 bpp, got {d}", .{v.bits_per_pixel});
            return 1;
        }
        W = v.xres;
        H = v.yres;
        STRIDE = f.line_length;
        const map = linux.mmap(null, f.smem_len, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, fb_fd, 0);
        if (bad(map)) return 1;
        fb = @as([*]u8, @ptrFromInt(map))[0..f.smem_len];
        logf("display grayscale={d}; driver-inverted={} (inherited; software inversion OFF; unchanged)", .{ v.grayscale, v.grayscale == 2 });
        if (v.yoffset != 0) logf("note: fb yoffset={d}", .{v.yoffset});
        if (opts.fast) {
            const flags: u32 = UPDATE_FLAGS_FAST_MODE | 1;
            _ = linux.ioctl(fb_fd, MXCFB_SET_UPDATE_FLAGS_MTK, @intFromPtr(&flags));
        }
    } else {
        fb = try alloc.alloc(u8, STRIDE * H);
        @memset(fb, 0xFF);
    }
    LW = @as(f32, @floatFromInt(W)) * 72.0 / 300.0;
    LH = @as(f32, @floatFromInt(H)) * 72.0 / 300.0;
    logf("screen {d}x{d} stride {d}", .{ W, H, STRIDE });
    lp_fb = nowUs();

    ui = zr_ui_new(sans_font.ptr, sans_font.len) orelse {
        logf("cannot load UI fonts", .{});
        return 1;
    };

    lp_fonts = nowUs();
    var dirs: [1200]u8 = undefined;
    mkdirP(std.fmt.bufPrint(&dirs, "{s}/state", .{opts.data}) catch "");
    mkdirP(std.fmt.bufPrint(&dirs, "{s}/notes", .{opts.data}) catch "");
    if (opts.sim != null) mkdirP(opts.shots);

    loadRefreshSetting();
    init07();
    {
        var cb: [1200]u8 = undefined;
        if (std.fmt.bufPrintSentinel(&cb, "{s}", .{opts.data}, 0)) |dz| {
            if (zr_pc_init(dz, opts.page_cache_mib << 20) == 0) pc_preview = alloc.alloc(u8, @as(usize, STRIDE) * H) catch &.{};
        } else |_| {}
    }
    logf("refresh configuration: every={d}; image_dither={}", .{ opts.full_refresh, opts.image_dither });
    previous_samples = try alloc.alloc(u8, ((@as(usize, W) + SAMPLE_STEP - 1) / SAMPLE_STEP) * ((@as(usize, H) + SAMPLE_STEP - 1) / SAMPLE_STEP));
    defer alloc.free(previous_samples);
    @memset(previous_samples, 255);
    const page_bytes = @as(usize, STRIDE) * H;
    const pool_mem = try alloc.alloc(u8, page_bytes * NSLOT);
    for (&pool.slots, 0..) |*s, i| s.buf = pool_mem[i * page_bytes ..][0..page_bytes];

    var rp: [2]i32 = undefined;
    var dp: [2]i32 = undefined;
    if (bad(linux.pipe2(&rp, .{ .NONBLOCK = true, .CLOEXEC = true })) or bad(linux.pipe2(&dp, .{ .NONBLOCK = true, .CLOEXEC = true }))) return 1;
    pool.pipe_w = rp[1];
    zr_set_ui_wake(rp[1]);
    waiter.pipe_w = dp[1];
    var wth: c_ulong = 0;
    _ = spawn(&wth, waiterThread);

    govInit();

    var sim_th: c_ulong = 0;
    if (opts.sim != null) {
        var sp: [2]i32 = undefined;
        if (bad(linux.pipe2(&sp, .{ .CLOEXEC = true }))) return 1;
        in.touch_fd = sp[0];
        sim_pipe_w = sp[1];
        in.xmin = 0;
        in.xmax = @as(i32, @intCast(W)) - 1;
        in.ymin = 0;
        in.ymax = @as(i32, @intCast(H)) - 1;
        in.grabbed = true;
    } else findInputs();
    if (power_sleeps and !configureSleep(true)) {
        power_sleeps = false;
        saveUi07();
    }

    lp_setup = nowUs();
    scanLibrary();
    lp_library = nowUs();
    if (opts.book) |b| {
        if (openBook(std.mem.span(b))) {
            screen = .reader;
            need_page = true;
        } else {
            libPageChange(WF_GC16);
            if (open_drm) toast("This book is DRM-protected and can't be opened", .{});
        }
    } else libPageChange(WF_GC16);
    if (opts.sim != null) _ = spawn(&sim_th, simThread);

    var pfds: [4]linux.pollfd = undefined;
    var nfds: usize = 0;
    pfds[nfds] = .{ .fd = rp[0], .events = linux.POLL.IN, .revents = 0 };
    nfds += 1;
    pfds[nfds] = .{ .fd = dp[0], .events = linux.POLL.IN, .revents = 0 };
    nfds += 1;
    if (in.touch_fd >= 0) {
        pfds[nfds] = .{ .fd = in.touch_fd, .events = linux.POLL.IN, .revents = 0 };
        nfds += 1;
    }
    if (in.power_fd >= 0) {
        pfds[nfds] = .{ .fd = in.power_fd, .events = linux.POLL.IN, .revents = 0 };
        nfds += 1;
    }

    var last_input = nowUs();
    var last_save = nowUs();
    var raw_logged: u32 = 0;
    var evbuf: [64]InputEvent = undefined;
    var drain: [64]u8 = undefined;

    main_loop: while (!@atomicLoad(bool, &g_quit, .seq_cst) and !quit_requested) {
        tick07();
        libTick();
        shrinkTick();
        if (screen == .upload) {
            const before = up_rev;
            uploadTick();
            if (up_rev != before) last_input = nowUs();
        }
        if (sleep_phase != .awake) last_input = nowUs();
        if (sleep_phase == .awake) searchStep();
        statsTick(last_input);
        pump();
        if (pending_shot) |si| {
            if (!in_flight and !need_page and dirty.empty()) {
                writeShot(si);
                pending_shot = null;
            }
        }
        var timeout: i32 = if (search_running and sleep_phase == .awake) 0 else idleTimeoutMs(last_input, last_save);
        if (search_hit != null) timeout = @min(timeout, 100);
        if (gs.down and !gs.long_fired) timeout = 40;
        if (center_pending) timeout = @min(timeout, 20);
        if (toast_len > 0) timeout = @min(timeout, 200);
        if (lib_hold) timeout = @min(timeout, 15);
        if (lib_menu == .shrink_run) timeout = @min(timeout, 250);
        if (screen == .upload) timeout = @min(timeout, 250);
        _ = linux.poll(&pfds, nfds, timeout);
        const now = nowUs();
        checkLongPress();
        checkCenterTap();
        if (search_hit != null and search_hit_until > 0 and now >= search_hit_until) {
            search_hit = null;
            closeOverlayRefresh(Rect.full());
        }
        if (toast_len > 0 and now > toast_until) {
            toast_len = 0;
            markDirty(toastRect(), WF_REAGL);
        }
        if (sleep_phase == .awake and opts.idle_min > 0 and now - last_input > opts.idle_min * 60 * 1_000_000) {
            logf("no input for {d} minutes; exiting", .{opts.idle_min});
            break;
        }
        if (book.state_dirty and now - last_save > 2_000_000 and now - last_input > 1_500_000) {
            saveState();
            last_save = now;
        }
        for (pfds[0..nfds]) |pf| {
            if (pf.revents & linux.POLL.IN == 0) continue;
            if (pf.fd == rp[0]) {
                _ = linux.read(rp[0], &drain, drain.len);
                if (draft_slot != null) refineDraft();
                continue;
            }
            if (pf.fd == dp[0]) {
                _ = linux.read(dp[0], &drain, drain.len);
                onComplete();
                continue;
            }
            const r = linux.read(pf.fd, @ptrCast(&evbuf), @sizeOf(@TypeOf(evbuf)));
            if (bad(r)) continue;
            for (evbuf[0 .. r / @sizeOf(InputEvent)]) |ev| {
                const t_ev = @as(u64, ev.sec) * 1_000_000 + ev.usec;
                last_input = nowUs();
                if (ev.type == EV_SIM_SHOT) {
                    if (ev.code == 0xFFFF) break :main_loop;
                    if (ev.code == 0xFFFC) {
                        sim_powerd_events = ev.value;
                        continue;
                    }
                    if (ev.code == 0xFFFE) {
                        if (power_sleeps) requestSleep() else quit_requested = true;
                        continue;
                    }
                    if (ev.code == 0xFFFD) {
                        wakeReader();
                        continue;
                    }
                    pending_shot = ev.code;
                    continue;
                }
                if (raw_logged < 20 and opts.sim == null) {
                    raw_logged += 1;
                    logf("ev[{d}] {s} type={d} code=0x{x} value={d}", .{ raw_logged, if (pf.fd == in.power_fd) "power" else "touch", ev.type, ev.code, ev.value });
                }
                if (pf.fd == in.power_fd) {
                    if (ev.type == EV_KEY and ev.code == KEY_POWER and ev.value == 1) {
                        if (power_sleeps) {
                            requestSleep();
                        } else {
                            logf("power button; exiting", .{});
                            break :main_loop;
                        }
                    }
                    continue;
                }
                switch (ev.type) {
                    EV_ABS => switch (ev.code) {
                        ABS_MT_SLOT => in.slot = ev.value,
                        ABS_MT_POSITION_X => {
                            if (in.slot == 0) in.rx = ev.value;
                        },
                        ABS_MT_POSITION_Y => {
                            if (in.slot == 0) in.ry = ev.value;
                        },
                        ABS_MT_TRACKING_ID => {
                            if (in.slot == 0) {
                                in.down = ev.value >= 0;
                                in.got_mt = true;
                            }
                        },
                        else => {},
                    },
                    EV_KEY => if (ev.code == BTN_TOUCH) {
                        if (!in.got_mt) in.down = ev.value != 0;
                    },
                    EV_SYN => if (ev.code == SYN_REPORT) {
                        const x = mapX(in.rx);
                        const y = mapY(in.ry);
                        if (in.down and !in.was_down) {
                            onDown(x, y, t_ev);
                        } else if (in.down and in.was_down) {
                            if (x != gs.x or y != gs.y) onMove(x, y);
                        } else if (!in.down and in.was_down) {
                            onUp(t_ev);
                        }
                        in.was_down = in.down;
                    },
                    else => {},
                }
            }
        }
    }

    logf("exiting", .{});
    if (screen == .upload) stopUpload();
    zr_device_sleep(0);
    zr_device_stop();
    closeBook();
    zr_pc_stop();
    zrd_close();
    zrl_close();
    if (in.touch_fd >= 0 and opts.sim == null) {
        var zero: c_int = 0;
        if (in.grabbed) _ = linux.ioctl(in.touch_fd, EVIOCGRAB, @intFromPtr(&zero));
        _ = linux.close(in.touch_fd);
    }
    if (in.power_fd >= 0) _ = linux.close(in.power_fd);
    govBoost(false);
    if (fb_fd >= 0) {
        @memset(fb[0 .. STRIDE * H], 0xFF);
        const m = sendUpdate(Rect.full(), WF_GC16, UPDATE_MODE_FULL);
        var md = MarkerData{ .update_marker = m, .collision_test = 0 };
        _ = linux.ioctl(fb_fd, MXCFB_WAIT_FOR_UPDATE_COMPLETE, @intFromPtr(&md));
    }
    _ = pthread_mutex_lock(&waiter.mtx);
    waiter.quit = true;
    _ = pthread_cond_broadcast(&waiter.cond);
    _ = pthread_mutex_unlock(&waiter.mtx);
    _ = pthread_join(wth, null);
    if (sim_th != 0) _ = pthread_join(sim_th, null);

    logf("--- session: turns={d} coalesced={d} render_errors={d} wf={s}", .{ turns, coalesced, pool.errors, if (opts.wf == WF_GL16) "gl16" else "reagl" });
    st_tap_submit.report("touch-up -> submit");
    st_tap_complete.report("touch-up -> complete");
    st_update.report("submit -> complete");
    pool.render_us.report("render (workers)");
    return 0;
}

// Host-only tests exercise the production coordinate, gesture and persistence code.
fn testPage(page: i32, trim: bool) !void {
    const doc = zr_open("../testbooks/digital-small1.pdf", LW, LH, 9, 18) orelse return error.OpenTestBook;
    book.doc = doc;
    book.open = true;
    book.words = try alloc.alloc(ZrWord, 8192);
    book.wtext = try alloc.alloc(u8, 262144);
    pool.cur = page;
    pool.gen = 1;
    visible_page = page;
    shown_gen = 1;
    need_page = false;
    book.words_page = -1;
    var r: [4]f32 = undefined;
    const rc = if (trim) zr_ink_bbox(doc, page, &r, 0) else zr_page_bounds(doc, page, &r);
    try std.testing.expectEqual(@as(c_int, 0), rc);
    shown_m = fitMatrix(r);
    loadWords();
    sel_active = false;
    popup_open = false;
    menu_open = false;
    editing_note = null;
    screen = .reader;
    dirty = .{};
}
fn testPageEnd() void {
    zr_close(book.doc);
    alloc.free(book.words);
    alloc.free(book.wtext);
    book.words = &.{};
    book.wtext = &.{};
    book.nwords = 0;
    book.open = false;
    sel_active = false;
    popup_open = false;
}
fn wordText(i: usize) []const u8 {
    const w = book.words[i];
    return book.wtext[@intCast(w.off)..][0..@intCast(w.len)];
}
fn testWord(needle: []const u8) !usize {
    for (0..book.nwords) |i| if (eql(wordText(i), needle)) return i;
    return error.MissingTestWord;
}
fn wordCenter(i: usize) [2]i32 {
    const r = toScreen(wordRect(i));
    return .{ r.x + @divTrunc(r.w, 2), r.y + @divTrunc(r.h, 2) };
}
test "screen to PDF coordinates: actual words on pages 7, 17, 19, 39, trim on and off" {
    for ([_]i32{ 6, 16, 18, 38 }) |page| {
        for ([_]bool{ false, true }) |trim| {
            try testPage(page, trim);
            defer testPageEnd();
            var checked: usize = 0;
            for (0..book.nwords) |i| {
                const p = wordCenter(i);
                const got = wordAt(p[0], p[1], false) orelse return error.WordNotHit;
                // On the malformed opening, the drop cap's geometric centre is
                // inside small text: the smaller real word must win that overlap.
                const w = book.words[i];
                if (w.y1 - w.y0 > 35) continue;
                try std.testing.expectEqualStrings(wordText(i), wordText(got));
                const back = toPage(p[0], p[1]);
                try std.testing.expect(back[0] >= w.x0 - 1 and back[0] <= w.x1 + 1);
                checked += 1;
            }
            try std.testing.expect(checked > 250);
            std.debug.print(" [page {d}, trim={}, {d} exact word hits] ", .{ page + 1, trim, checked });
            try std.testing.expectEqual(@as(?usize, null), wordAt(-10, 10, true));
            try std.testing.expectEqual(@as(?usize, null), wordAt(636, 0, false));
            shown_gen = 2;
            try std.testing.expectEqual(@as(?usize, null), wordAt(200, 400, true));
        }
    }
}
test "exact long press, cross-line drag, both handles and clean release" {
    try testPage(6, true);
    defer testPageEnd();
    const a = try testWord("could");
    const b = try testWord("moment");
    const pa = wordCenter(a);
    const pb = wordCenter(b);
    onLongPress(pa[0], pa[1]);
    var tb: [8192]u8 = undefined;
    try std.testing.expectEqualStrings("could", selectionText(&tb));
    onDrag(pb[0], pb[1]);
    try std.testing.expectEqualStrings("could think to say at that exact moment", selectionText(&tb));
    try std.testing.expectEqual(WF_DU, dirty_mode);
    gs.long_fired = true;
    onUp(nowUs());
    try std.testing.expect(popup_open);
    try std.testing.expectEqual(WF_REAGL, dirty_mode);
    const hr = handleRect(.start);
    onDown(hr.x + 15, hr.y + 19, nowUs());
    try std.testing.expectEqual(Handle.start, dragging_handle);
    const np = wordCenter(a + 1);
    onMove(np[0] - handle_dx, np[1] - handle_dy);
    try std.testing.expectEqualStrings("think to say at that exact moment", selectionText(&tb));
    onUp(nowUs());
    const er = handleRect(.end);
    onDown(er.x + 15, er.y + 19, nowUs());
    const ep = wordCenter(b - 1);
    onMove(ep[0] - handle_dx, ep[1] - handle_dy);
    try std.testing.expectEqualStrings("think to say at that exact", selectionText(&tb));
    onUp(nowUs());
    // Backwards drag across the line break gives the same reading-order text.
    popupAction(3);
    const end = a + 19;
    const pe = wordCenter(end);
    onLongPress(pe[0], pe[1]);
    onDrag(pa[0], pa[1]);
    try std.testing.expectEqualStrings("could think to say at that exact moment was this: “If Edgar Allan Mitchell—the sixth man to walk on the", selectionText(&tb));
    var qs: [64][4]f32 = undefined;
    const nq = selectionQuads(sel_a, sel_b, &qs);
    try std.testing.expectEqual(@as(usize, 2), nq);
    try std.testing.expect(!sameTextLine(qs[0], qs[1]));
}
test "legacy notes load, tap edit, change style, copy and delete rewrite both files" {
    try testPage(6, true);
    defer testPageEnd();
    opts.data = "tests/run-unit";
    mkdirP("tests/run-unit/notes");
    const name = "legacy";
    @memcpy(book.name[0..name.len], name);
    book.name_len = name.len;
    try std.testing.expect(writeFileAtomic("tests/run-unit/notes/legacy.json", "[{\"page\":7,\"style\":\"highlight\",\"quads\":[[122.13,241.61,606.91,255.24],[5.00,259.61,152.97,273.24]],\"text\":\"could think\"},{\"page\":39,\"style\":\"underline\",\"quads\":[[30.59,403.61,69.58,417.24]],\"text\":\"friend,\"}]"));
    loadNotes();
    defer freeNotes();
    try std.testing.expectEqual(@as(usize, 2), book.nnotes);
    try std.testing.expectEqual(@as(usize, 2), book.notes[0].nq);
    try std.testing.expectEqual(@as(i64, 0), book.notes[0].ts);
    const r = toScreen(book.notes[0].q[0]);
    onReaderTap(r.x + 10, r.y + 10, nowUs());
    try std.testing.expectEqual(@as(?usize, 0), editing_note);
    popupAction(1);
    try std.testing.expectEqual(@as(u8, 0), book.notes[0].style);
    onReaderTap(r.x + 10, r.y + 10, nowUs());
    popupAction(2);
    try std.testing.expectEqual(@as(usize, 3), book.nnotes);
    try std.testing.expectEqual(@as(u8, 2), book.notes[2].style);
    try std.testing.expectEqualStrings("could think", book.notes[2].text);
    onReaderTap(r.x + 10, r.y + 10, nowUs());
    popupAction(0);
    try std.testing.expectEqual(@as(usize, 2), book.nnotes);
    loadNotes();
    try std.testing.expectEqual(@as(usize, 2), book.nnotes);
    screen = .notes;
    list_page = 0;
    const rr = rowRect(0);
    onLongPress(rr.x + 50, rr.y + 50);
    try std.testing.expectEqual(@as(usize, 1), book.nnotes);
    const txt = readFile("tests/run-unit/notes/legacy.txt") orelse return error.NoTxt;
    defer alloc.free(txt);
    try std.testing.expect(std.mem.indexOf(u8, txt, "friend,") == null);
    try std.testing.expect(std.mem.indexOf(u8, txt, "could think") != null);
    deleteNote(0);
    loadNotes();
    try std.testing.expectEqual(@as(usize, 0), book.nnotes);
    const empty = readFile("tests/run-unit/notes/legacy.txt") orelse return error.NoTxt;
    defer alloc.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
}
test "PW6 physical touch endpoints and page-turn configuration" {
    in.xmin = 0;
    in.xmax = 1271;
    in.ymin = 0;
    in.ymax = 1695;
    try std.testing.expectEqual(@as(i32, 1271), mapX(1271));
    try std.testing.expectEqual(@as(i32, 1695), mapY(1695));
    try std.testing.expectEqual(@as(i32, 0), mapX(0));
    try std.testing.expectEqual(WF_REAGL, (Opts{}).wf);
    try std.testing.expectEqual(@as(usize, 14), pool.slots.len);
    try std.testing.expectEqual(@as(usize, 2), book.threads.len);
}

test "colliding source drop cap is in logical reading order, not before headings" {
    try testPage(16, true);
    defer testPageEnd();
    const a = try testWord("JENNIFER");
    // One JENNIFER is the chapter heading, another is the reconstructed body word.
    var body: ?usize = null;
    for (a + 1..book.nwords) |i| if (eql(wordText(i), "JENNIFER")) {
        body = i;
        break;
    };
    const i = body orelse return error.NoJoinedInitial;
    try std.testing.expectEqualStrings("QUINN", wordText(i + 1));
    const p = wordCenter(i);
    const e = wordCenter(i + 2);
    onLongPress(p[0], p[1]);
    onDrag(e[0], e[1]);
    var text_buf: [1024]u8 = undefined;
    try std.testing.expectEqualStrings("JENNIFER QUINN STARED", selectionText(&text_buf));
}

test "legacy overlapping underline rectangles collapse to one visual baseline" {
    opts.data = "tests/run-unit";
    mkdirP("tests/run-unit/notes");
    const name = "duplicate-lines";
    @memcpy(book.name[0..name.len], name);
    book.name_len = name.len;
    try std.testing.expect(writeFileAtomic("tests/run-unit/notes/duplicate-lines.json", "[{\"page\":7,\"style\":\"underline\",\"quads\":[[12,20,40,32],[35,20.5,80,32.5],[5,40,25,52]],\"text\":\"one line then another\"}]"));
    loadNotes();
    defer freeNotes();
    try std.testing.expectEqual(@as(usize, 1), book.nnotes);
    try std.testing.expectEqual(@as(usize, 2), book.notes[0].nq);
    try std.testing.expectEqual(@as(f32, 12), book.notes[0].q[0][0]);
    try std.testing.expectEqual(@as(f32, 80), book.notes[0].q[0][2]);
}

test "adjacent wrapped selection handles choose nearest endpoint, not first hit" {
    try testPage(6, true);
    defer testPageEnd();
    sel_a = (try testWord("could")) + 1;
    sel_b = sel_a + 18;
    sel_active = true;
    popup_open = true;
    const r = handleRect(.end);
    onDown(r.x + 15, r.y + 19, nowUs());
    try std.testing.expectEqual(Handle.end, dragging_handle);
}

test "adaptive refresh: heavy cover/images and large transitions only, plain text stays REAGL" {
    const text_page: PageMetrics = .{ .ink = 0.08, .dark = 0.06, .tone = 0.03, .image = 0 };
    const illustration: PageMetrics = .{ .photo = 0.3, .ink = 0.20, .dark = 0.15, .tone = 0.15, .image = 0.60 };
    const dark_page: PageMetrics = .{ .ink = 0.50, .dark = 0.48, .tone = 0.10, .image = 0 };
    const mild: Transition = .{ .dark_to_light = 0.06, .light_to_dark = 0.05 };
    try std.testing.expectEqual(WF_REAGL, refreshChoice(text_page, text_page, mild, 2, 3, false, 0, 8, WF_REAGL).mode);
    try std.testing.expectEqual(WF_GC16, refreshChoice(illustration, text_page, mild, 8, 9, false, 0, 8, WF_REAGL).mode);
    try std.testing.expectEqual(WF_GC16, refreshChoice(text_page, illustration, mild, 8, 9, false, 0, 8, WF_REAGL).mode);
    try std.testing.expectEqual(WF_REAGL, refreshChoice(dark_page, text_page, mild, 8, 9, false, 0, 8, WF_REAGL).mode);
    try std.testing.expectEqual(WF_REAGL, refreshChoice(text_page, text_page, .{ .dark_to_light = 0.20 }, 8, 9, false, 0, 8, WF_REAGL).mode);
    // Hardware night mode reverses light/dark; both directions must be covered.
    try std.testing.expectEqual(WF_REAGL, refreshChoice(text_page, text_page, .{ .light_to_dark = 0.20 }, 8, 9, false, 0, 8, WF_REAGL).mode);
    try std.testing.expectEqual(CleanReason.context, refreshChoice(text_page, text_page, mild, 8, 8, true, 0, 8, WF_REAGL).reason);
    try std.testing.expectEqual(CleanReason.cover, refreshChoice(text_page, text_page, mild, 0, 1, false, 0, 8, WF_REAGL).reason);
    try std.testing.expectEqual(CleanReason.opening, refreshChoice(.{}, text_page, .{}, -1, 5, false, 0, 8, WF_REAGL).reason);
    try std.testing.expectEqual(WF_REAGL, refreshChoice(text_page, text_page, mild, 8, 9, false, 500, 0, WF_REAGL).mode);
    for ([_]u8{ 4, 8, 16 }) |every| {
        try std.testing.expectEqual(WF_REAGL, refreshChoice(text_page, text_page, mild, 8, 9, false, every - 2, every, WF_REAGL).mode);
        try std.testing.expectEqual(CleanReason.periodic, refreshChoice(text_page, text_page, mild, 8, 9, false, every - 1, every, WF_REAGL).reason);
    }
}
test "true clean ioctl is GC16 FULL and never toggles driver inversion" {
    const clean = makeUpdate(Rect.full(), WF_GC16, UPDATE_MODE_PARTIAL);
    try std.testing.expectEqual(WF_GC16, clean.waveform_mode);
    try std.testing.expectEqual(UPDATE_MODE_FULL, clean.update_mode);
    try std.testing.expectEqual(WF_GC16, clean.hist_bw_waveform_mode);
    try std.testing.expectEqual(WF_GC16, clean.hist_gray_waveform_mode);
    try std.testing.expectEqual(@as(u32, 0), clean.flags);
    const fast = makeUpdate(Rect.full(), WF_REAGL, UPDATE_MODE_FULL);
    try std.testing.expectEqual(WF_REAGL, fast.waveform_mode);
    try std.testing.expectEqual(@as(u32, 0), fast.flags);
}
test "sample metrics include darkness and both transitions, excluding framebuffer stride padding" {
    var white: [32 * 40]u8 = @splat(255);
    var black: [32 * 40]u8 = @splat(0);
    // Only 32 of each 40-byte row belong to the screen.
    for (0..32) |y| @memset(black[y * 40 + 32 .. y * 40 + 40], 255);
    const w = pageMetrics(&white, 32, 32, 40, 0.4);
    const b = pageMetrics(&black, 32, 32, 40, 0.4);
    try std.testing.expectEqual(@as(f32, 0), w.ink);
    try std.testing.expectEqual(@as(f32, 1), b.ink);
    var samples: [16]u8 = undefined;
    saveSamples(&samples, &black, 32, 32, 40);
    try std.testing.expectEqual(@as(f32, 1), transitionMetrics(&samples, &white, 32, 32, 40).dark_to_light);
    saveSamples(&samples, &white, 32, 32, 40);
    try std.testing.expectEqual(@as(f32, 1), transitionMetrics(&samples, &black, 32, 32, 40).light_to_dark);
}
test "image popup dismissal clears full screen; plain text popup stays on normal path" {
    previous_metrics = .{};
    dirty = .{};
    dirty_mode = WF_DU;
    closeOverlayRefresh(.{ .x = 10, .y = 10, .w = 100, .h = 100 });
    try std.testing.expectEqual(WF_REAGL, dirty_mode);
    previous_metrics = .{ .image = 0.8, .photo = 0.3 };
    dirty = .{};
    dirty_mode = WF_DU;
    closeOverlayRefresh(.{ .x = 10, .y = 10, .w = 100, .h = 100 });
    try std.testing.expectEqual(WF_GC16, dirty_mode);
    try std.testing.expectEqual(Rect.full().w, dirty.w);
    previous_metrics = .{};
}

test "PDF width slices have exact 96px overlap, bounded last slice and view-correct coordinates" {
    const r: [4]f32 = .{ 20, 40, 620, 2040 };
    const a = viewGeometry(r, .width, true, 0, 0, 0);
    const b = viewGeometry(r, .width, true, 1, 0, 0);
    try std.testing.expectEqual(@as(i32, 3), a.steps);
    try std.testing.expectApproxEqAbs(@as(f32, 1272), (r[2] - r[0]) * a.m[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1600), a.m[5] - b.m[5], 0.01);
    try std.testing.expectEqual(a.steps - 1, viewGeometry(r, .width, true, -1, 0, 0).actual_step);
    try std.testing.expectEqual(a.steps - 1, viewGeometry(r, .width, true, 999, 0, 0).actual_step);
    try testPage(6, true);
    defer testPageEnd();
    const i = try testWord("could");
    const w = book.words[i];
    // Place the selected word in a zoomed/panned viewport, including a crop origin.
    shown_m = .{ 3, 0, 0, 3, 50 - w.x0 * 3, 200 - w.y0 * 3 };
    const p = wordCenter(i);
    try std.testing.expectEqual(@as(?usize, i), wordAt(p[0], p[1], false));
}
test "PDF zoom factors and pan clamp never change the raster allocation" {
    const r: [4]f32 = .{ 20, 40, 620, 840 };
    const base = fitMatrix(r);
    const a = viewGeometry(r, .zoom15, false, 0, 0, 0);
    const b = viewGeometry(r, .zoom2, false, 0, 1, 1);
    try std.testing.expectApproxEqAbs(base[0] * 1.5, a.m[0], 0.001);
    try std.testing.expectApproxEqAbs(base[0] * 2, b.m[0], 0.001);
    const max = viewGeometry(r, .zoom2, false, 0, 99, 99);
    try std.testing.expectEqual(b.m, max.m);
    try std.testing.expectEqual(@as(usize, 14), pool.slots.len);
}
test "PDF prefetch keys retain current mode and adjacent screen-sized slices" {
    const old_cur = pool.cur;
    const old_pages = pool.npages;
    const old_view = pool.view;
    const old_step = pool.step;
    defer {
        pool.cur = old_cur;
        pool.npages = old_pages;
        pool.view = old_view;
        pool.step = old_step;
    }
    pool.cur = 4;
    pool.npages = 20;
    pool.view = .width;
    pool.step = 2;
    pool.dir = 1;
    var keys: [10]ViewKey = undefined;
    const n = wantedList(&keys);
    try std.testing.expect(n >= 7);
    try std.testing.expectEqual(ViewKey{ .p = 4, .step = 2 }, keys[0]);
    try std.testing.expectEqual(ViewKey{ .p = 4, .step = 3 }, keys[1]);
    try std.testing.expectEqual(ViewKey{ .p = 4, .step = 4 }, keys[2]);
    pool.view = .zoom2;
    pool.step = 0;
    _ = wantedList(&keys);
    try std.testing.expectEqual(ViewKey{ .p = 5, .step = 0 }, keys[1]);
}

test "portable anchor JSON preserves exact 64-bit checksum and rejects malformed locations" {
    const a: Anchor = .{ .chapter = 17, .start = 42, .end = 390, .hash = 0xfedcba9876543210 };
    var b = Buf.init(256);
    defer b.deinit();
    b.put("{");
    writeAnchor(&b, a);
    b.put("\"page\":1}");
    const parsed = readAnchor(b.slice());
    try std.testing.expectEqual(a.chapter, parsed.chapter);
    try std.testing.expectEqual(a.start, parsed.start);
    try std.testing.expectEqual(a.end, parsed.end);
    try std.testing.expectEqual(a.hash, parsed.hash);
    try std.testing.expectEqual(@as(c_int, -1), readAnchor("{\"anchor_version\":1,\"anchor_chapter\":0,\"anchor_start\":99,\"anchor_end\":2,\"anchor_hash\":\"123\"}").chapter);
    try std.testing.expectEqual(@as(c_int, -1), readAnchor("{\"page\":7}").chapter);
}
test "EPUB font menu has nine visibly separated 14 to 40 CSS pixel-equivalent steps" {
    try std.testing.expectEqual(@as(f32, 10.5), fontStep(9, 1));
    try std.testing.expectEqual(@as(f32, 10.5), fontStep(10.5, -1));
    try std.testing.expectEqual(@as(f32, 30), fontStep(30, 1));
    var f: f32 = FONT_PX[0] * 0.75;
    for (FONT_PX[1..]) |px| {
        const next = fontStep(f, 1);
        try std.testing.expectEqual(px * 0.75, next);
        try std.testing.expect(next / f > 1.1);
        try std.testing.expectEqual(f, fontStep(next, -1));
        f = next;
    }
}

test "legacy JSON Unicode escapes decode to UTF-8 including surrogate pairs" {
    var out: [128]u8 = undefined;
    const decoded = jsonStr("{\"text\":\"caf\\u00e9 \\u2014 \\ud83d\\ude00\"}", "text", &out) orelse return error.UnicodeDecode;
    try std.testing.expectEqualStrings("caf\xc3\xa9 \xe2\x80\x94 \xf0\x9f\x98\x80", decoded);
    try std.testing.expect(jsonStr("{\"text\":\"\\ud83d\"}", "text", &out) == null);
}

test "Define is offered only for one selected word; dictionary gestures cannot turn or pan the book" {
    const old_active = sel_active;
    const old_a = sel_a;
    const old_b = sel_b;
    const old_editing = editing_note;
    const old_gs = gs;
    defer {
        sel_active = old_active;
        sel_a = old_a;
        sel_b = old_b;
        editing_note = old_editing;
        gs = old_gs;
        dictionary_open = false;
    }
    sel_active = true;
    editing_note = null;
    sel_a = 1;
    sel_b = 1;
    try std.testing.expectEqual(@as(i32, 6), popupCount());
    try std.testing.expect(popupButton(4).x < popupButton(3).x);
    sel_b = 2;
    try std.testing.expectEqual(@as(i32, 5), popupCount());
    sel_b = 1;
    editing_note = 0;
    try std.testing.expectEqual(@as(i32, 5), popupCount());
    dictionary_open = true;
    const cur = pool.cur;
    const pan = pool.pan_x;
    gs = .{ .down = true, .x0 = 1000, .y0 = 800, .x = 200, .y = 800, .moved = true };
    onUp(1000);
    try std.testing.expectEqual(cur, pool.cur);
    try std.testing.expectEqual(pan, pool.pan_x);
}

// ---------------- in-book search ----------------
const SearchHit = extern struct { q: [8][4]f32, nq: c_int, off: c_int, len: c_int };
extern fn zr_search_page(z: *ZrDoc, page: c_int, needle: [*:0]const u8, hits: [*]SearchHit, max: c_int, snippets: [*]u8, cap: c_int) c_int;
const SearchResult = struct { page: i32, nq: usize, q: [8][4]f32, snippet: [256]u8, len: usize };
var search_query: [65]u8 = @splat(0);
var search_len: usize = 0;
var search_results: [200]SearchResult = undefined;
var search_count: usize = 0;
var search_scanned: i32 = 0;
var search_errors: usize = 0;
var search_running = false;
var search_editing = true;
var search_list_page: usize = 0;
var search_tick: u64 = 0;
var search_hit: ?SearchResult = null;
var search_hit_until: u64 = 0;
const KEY_ROWS = [_][]const u8{ "1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm'-_" };
// v0.10.6 accent layer (the accent key): replaces the four letter rows.
var kb_accents = false;
const ACCENT_LOWER = [4][10][]const u8{
    .{ "\xc3\xa1", "\xc3\xa0", "\xc3\xa2", "\xc3\xa4", "\xc3\xa3", "\xc3\xa5", "\xc3\xa6", "\xc3\xa7", "\xc3\xa9", "\xc3\xa8" },
    .{ "\xc3\xaa", "\xc3\xab", "\xc3\xad", "\xc3\xac", "\xc3\xae", "\xc3\xaf", "\xc3\xb1", "\xc3\xb3", "\xc3\xb2", "\xc3\xb4" },
    .{ "\xc3\xb6", "\xc3\xb5", "\xc3\xb8", "\xc5\x93", "\xc3\xba", "\xc3\xb9", "\xc3\xbb", "\xc3\xbc", "\xc3\xbd", "\xc3\xbf" },
    .{ "\xc3\x9f", "\xc2\xbf", "\xc2\xa1", "\xc2\xab", "\xc2\xbb", "\xe2\x82\xac", "'", "-", "", "" },
};
const ACCENT_UPPER = [4][10][]const u8{
    .{ "\xc3\x81", "\xc3\x80", "\xc3\x82", "\xc3\x84", "\xc3\x83", "\xc3\x85", "\xc3\x86", "\xc3\x87", "\xc3\x89", "\xc3\x88" },
    .{ "\xc3\x8a", "\xc3\x8b", "\xc3\x8d", "\xc3\x8c", "\xc3\x8e", "\xc3\x8f", "\xc3\x91", "\xc3\x93", "\xc3\x92", "\xc3\x94" },
    .{ "\xc3\x96", "\xc3\x95", "\xc3\x98", "\xc5\x92", "\xc3\x9a", "\xc3\x99", "\xc3\x9b", "\xc3\x9c", "\xc3\x9d", "\xc5\xb8" },
    .{ "\xc3\x9f", "\xc2\xbf", "\xc2\xa1", "\xc2\xab", "\xc2\xbb", "\xe2\x82\xac", "'", "-", "", "" },
};
const ACCENT_LABEL = "\xc3\x80\xc3\x89";
fn accentKey(row: usize, col: usize, upper: bool) []const u8 {
    if (row >= 4 or col >= 10) return "";
    return if (upper) ACCENT_UPPER[row][col] else ACCENT_LOWER[row][col];
}
fn searchAccentButton() Rect {
    return .{ .x = 70, .y = 1020, .w = 300, .h = 110 };
}
fn searchAddStr(t: []const u8) void {
    if (t.len == 0 or search_len + t.len >= search_query.len - 1) return;
    @memcpy(search_query[search_len..][0..t.len], t);
    search_len += t.len;
    search_query[search_len] = 0;
    markDirty(searchField(), WF_REAGL);
}
fn searchKey(row: usize, col: usize) Rect {
    const bw = @divTrunc(@as(i32, @intCast(W)) - 140, 10);
    return .{ .x = 70 + @as(i32, @intCast(col)) * bw, .y = 500 + @as(i32, @intCast(row)) * 130, .w = bw - 10, .h = 110 };
}
fn searchField() Rect {
    return .{ .x = 70, .y = 250, .w = @as(i32, @intCast(W)) - 140, .h = 110 };
}
fn searchControl(which: usize) Rect {
    return switch (which) {
        0 => .{ .x = 390, .y = 1020, .w = @as(i32, @intCast(W)) - 460, .h = 110 },
        1 => .{ .x = 70, .y = 1150, .w = 420, .h = 110 },
        2 => .{ .x = @as(i32, @intCast(W)) - 670, .y = 1150, .w = 600, .h = 110 },
        else => .{ .x = 70, .y = 1300, .w = @as(i32, @intCast(W)) - 140, .h = 110 },
    };
}
fn searchEditButton() Rect {
    return .{ .x = 70, .y = 310, .w = 300, .h = 75 };
}
fn searchRow(i: usize) Rect {
    return .{ .x = 70, .y = 410 + @as(i32, @intCast(i)) * 165, .w = @as(i32, @intCast(W)) - 140, .h = 165 };
}
fn searchAdd(c: u8) void {
    if (search_len >= search_query.len - 1) return;
    search_query[search_len] = c;
    search_len += 1;
    search_query[search_len] = 0;
    markDirty(searchField(), WF_REAGL);
}
fn beginSearch() void {
    if (std.mem.trim(u8, search_query[0..search_len], " ").len == 0) return;
    search_count = 0;
    search_scanned = 0;
    search_errors = 0;
    search_list_page = 0;
    search_running = true;
    search_editing = false;
    search_tick = 0;
    markFull(WF_REAGL);
}
fn searchStep() void {
    if (!search_running or screen != .search) return;
    var hits: [200]SearchHit = undefined;
    var snippets: [65536]u8 = undefined;
    const n = zr_search_page(book.doc, search_scanned, @ptrCast(&search_query), &hits, @intCast(search_results.len - search_count), &snippets, @intCast(snippets.len));
    if (n < 0) search_errors += 1;
    for (hits[0..@intCast(@max(n, 0))]) |h| {
        const dest = &search_results[search_count];
        dest.page = search_scanned;
        dest.nq = @intCast(std.math.clamp(h.nq, 0, 8));
        dest.q = h.q;
        dest.len = @min(@as(usize, @intCast(@max(h.len, 0))), dest.snippet.len);
        @memcpy(dest.snippet[0..dest.len], snippets[@intCast(h.off)..][0..dest.len]);
        search_count += 1;
    }
    search_scanned += 1;
    if (search_scanned >= pool.npages or search_count == search_results.len) {
        search_running = false;
        logf("search complete: pages={d}/{d} hits={d} errors={d}", .{ search_scanned, pool.npages, search_count, search_errors });
    }
    const now = nowUs();
    if (!search_running or now -| search_tick > 300000) {
        search_tick = now;
        markFull(WF_REAGL);
    }
}
fn drawSearch() void {
    header("Search", true);
    if (search_editing) {
        const field = searchField();
        frame(field, 3, 0);
        textFit(SANS, 42, 90, 325, search_query[0..search_len], @floatFromInt(field.w - 40), 0);
        if (kb_accents) {
            for (0..4) |r| for (0..10) |col| {
                const k = accentKey(r, col, false);
                if (k.len > 0) button(searchKey(r, col), k, false);
            };
        } else for (KEY_ROWS, 0..) |row, r| for (row, 0..) |c, col| button(searchKey(r, col), &.{c}, false);
        button(searchAccentButton(), if (kb_accents) "abc" else ACCENT_LABEL, kb_accents);
        button(searchControl(0), "Space", false);
        button(searchControl(1), "Clear", false);
        button(searchControl(2), "Backspace", false);
        button(searchControl(3), "Search book", false);
        text(SANS, 28, 70, 1480, "Case-insensitive / up to 200 matches / \xc3\x80\xc3\x89 = accents", 0x55);
    } else {
        textFit(SANS, 34, 70, 280, search_query[0..search_len], @as(f32, @floatFromInt(W)) - 140, 0);
        button(searchEditButton(), if (search_running) "Stop / edit query" else "Edit query", false);
        var b: [160]u8 = undefined;
        const status = std.fmt.bufPrint(&b, "{d} matches / {d} of {d} pages{s}", .{ search_count, search_scanned, pool.npages, if (search_count == 200) " (limit)" else if (search_running) " ..." else "" }) catch "";
        textFit(SANS, 26, 400, 360, status, @as(f32, @floatFromInt(W)) - 470, 0x55);
        if (!search_running and search_count == 0) text(SANS, 36, 70, 530, "No matches found.", 0x55);
        for (0..6) |i| {
            const k = search_list_page * 6 + i;
            if (k >= search_count) break;
            const h = &search_results[k];
            const r = searchRow(i);
            var pb: [64]u8 = undefined;
            const pg = std.fmt.bufPrint(&pb, "Page {d}", .{h.page + 1}) catch "";
            text(SANS, 28, @floatFromInt(r.x), @floatFromInt(r.y + 42), pg, 0x55);
            textFit(SERIF, 34, @floatFromInt(r.x), @floatFromInt(r.y + 100), h.snippet[0..h.len], @floatFromInt(r.w), 0);
            rowSep(r);
        }
        if (search_list_page > 0) button(pagerPrev(), "Previous", false);
        if ((search_list_page + 1) * 6 < search_count) button(pagerNext(), "Next", false);
        var pb: [48]u8 = undefined;
        const pg = std.fmt.bufPrint(&pb, "{d} / {d}", .{ search_list_page + 1, @max((search_count + 5) / 6, 1) }) catch "";
        textCenter(SANS, 32, .{ .x = 400, .y = @as(i32, @intCast(H)) - 140, .w = @as(i32, @intCast(W)) - 800, .h = 100 }, pg, 0x55);
        if (search_errors > 0) text(SANS, 24, 70, @as(f32, @floatFromInt(H)) - 170, "Some pages could not be searched.", 0x55);
    }
}
fn jumpSearchHit(k: usize, t: u64) void {
    if (k >= search_count) return;
    const hit = search_results[k];
    search_running = false;
    showScreen(.reader);
    goPage(hit.page, t);
    if (book.is_pdf and pool.view != .page and hit.nq > 0) {
        var r: [4]f32 = undefined;
        const trim = viewUsesTrim(book.is_pdf, pool.trim, pool.view, pool.base_width);
        const rc = if (trim) zr_ink_bbox_flags(book.doc, hit.page, &r, @intFromBool(pool.no_images), imageFlags()) else zr_page_bounds(book.doc, hit.page, &r);
        if (rc == 0) {
            const g = viewGeometry(r, pool.view, pool.base_width, 0, 0, 0);
            const q = hit.q[0];
            const x = ((q[0] + q[2]) / 2 - r[0]) * g.m[0];
            const y = ((q[1] + q[3]) / 2 - r[1]) * g.m[3];
            _ = pthread_mutex_lock(&pool.mtx);
            if (pool.view == .width) pool.step = std.math.clamp(@as(i32, @intFromFloat(@floor(@max(y - @as(f32, @floatFromInt(H)) / 3, 0) / (@as(f32, @floatFromInt(H)) - VIEW_OVERLAP)))), 0, g.steps - 1) else {
                pool.pan_x = if (g.max_x > 0) std.math.clamp((x - @as(f32, @floatFromInt(W)) / 2) / g.max_x, 0, 1) else 0;
                pool.pan_y = if (g.max_y > 0) std.math.clamp((y - @as(f32, @floatFromInt(H)) / 2) / g.max_y, 0, 1) else 0;
            }
            invalidateView();
            _ = pthread_mutex_unlock(&pool.mtx);
        }
    }
    search_hit = hit;
    search_hit_until = 0;
}
fn searchTap(x: i32, y: i32, t: u64) void {
    if (topButton(true).contains(x, y)) {
        search_running = false;
        return showScreen(.reader);
    }
    if (search_editing) {
        if (searchAccentButton().contains(x, y)) {
            kb_accents = !kb_accents;
            return markFull(WF_REAGL);
        }
        if (kb_accents) {
            for (0..4) |r| for (0..10) |col| if (searchKey(r, col).contains(x, y)) return searchAddStr(accentKey(r, col, false));
        } else for (KEY_ROWS, 0..) |row, r| for (row, 0..) |c, col| if (searchKey(r, col).contains(x, y)) return searchAdd(c);
        if (searchControl(0).contains(x, y)) return searchAdd(' ');
        if (searchControl(1).contains(x, y)) {
            search_len = 0;
            search_query[0] = 0;
            return markDirty(searchField(), WF_REAGL);
        }
        if (searchControl(2).contains(x, y) and search_len > 0) {
            search_len -= 1;
            while (search_len > 0 and (search_query[search_len] & 0xC0) == 0x80) search_len -= 1;
            search_query[search_len] = 0;
            return markDirty(searchField(), WF_REAGL);
        }
        if (searchControl(3).contains(x, y)) return beginSearch();
    } else {
        if (searchEditButton().contains(x, y)) {
            search_running = false;
            search_editing = true;
            return markFull(WF_REAGL);
        }
        if (pagerPrev().contains(x, y) and search_list_page > 0) {
            search_list_page -= 1;
            return markFull(WF_REAGL);
        }
        if (pagerNext().contains(x, y) and (search_list_page + 1) * 6 < search_count) {
            search_list_page += 1;
            return markFull(WF_REAGL);
        }
        for (0..6) |i| if (searchRow(i).contains(x, y)) return jumpSearchHit(search_list_page * 6 + i, t);
    }
}
fn drawSearchHit() void {
    if (search_hit) |h| {
        if (h.page != pool.cur) return;
        if (search_hit_until == 0) search_hit_until = nowUs() + 1600000;
        for (h.q[0..h.nq]) |q| {
            const r = toScreen(q).grow(5);
            tint(r, 0x90);
            frame(r, 3, 0);
        }
    }
}

test "search keyboard is bounded, accepts spaces, and edit cancels an incremental scan" {
    const old_screen = screen;
    const old_len = search_len;
    const old_query = search_query;
    defer {
        screen = old_screen;
        search_len = old_len;
        search_query = old_query;
        search_running = false;
        search_editing = true;
    }
    screen = .search;
    search_len = 0;
    search_query[0] = 0;
    search_running = false;
    beginSearch();
    try std.testing.expect(!search_running);
    for (0..100) |_| searchAdd('a');
    try std.testing.expectEqual(@as(usize, 64), search_len);
    searchTap(searchControl(1).x + 10, searchControl(1).y + 10, 1);
    try std.testing.expectEqual(@as(usize, 0), search_len);
    searchAdd('q');
    searchAdd(' ');
    searchAdd('x');
    try std.testing.expectEqualStrings("q x", search_query[0..search_len]);
    beginSearch();
    try std.testing.expect(search_running and !search_editing);
    searchTap(searchEditButton().x + 10, searchEditButton().y + 10, 2);
    try std.testing.expect(!search_running and search_editing);
    for (KEY_ROWS, 0..) |row, r| for (row, 0..) |_, col| {
        const rect = searchKey(r, col);
        try std.testing.expect(rect.x >= 0 and rect.x + rect.w < W and rect.y + rect.h < H);
    };
}

// ---------------- clean Markdown exports ----------------
fn markdownText(b: *Buf, s: []const u8) void {
    for (s) |c| switch (c) {
        '\\', '`', '*', '_', '{', '}', '[', ']', '(', ')', '#', '+', '-', '!', '|', '<', '>' => {
            b.put("\\");
            b.put(&.{c});
        },
        else => b.put(&.{c}),
    };
}
fn markdownHeader(b: *Buf, title: []const u8) void {
    b.put("# ");
    markdownText(b, title);
    b.put("\n\n");
}
fn markdownNote(b: *Buf, page: i32, style: usize, passage: []const u8, a: Anchor, unresolved: bool, comment: []const u8) void {
    b.print("## {s} / Page {d}\n\n", .{ STYLE_LABELS[@min(style, 2)], page + 1 });
    if (unresolved) b.put("Location unresolved; original passage retained.\n\n") else if (a.chapter >= 0) b.print("Chapter {d}, text offsets {d}-{d}.\n\n", .{ a.chapter + 1, a.start, a.end });
    var lines = std.mem.splitScalar(u8, passage, '\n');
    while (lines.next()) |line| {
        b.put("> ");
        markdownText(b, std.mem.trimEnd(u8, line, "\r"));
        b.put("\n");
    }
    b.put("\n");
    if (comment.len > 0) {
        b.put("**Note:** ");
        markdownText(b, comment);
        b.put("\n\n");
    }
}
fn writeMarkdown(title: []const u8, b: *Buf) bool {
    if (title.len == 0 or std.mem.indexOfScalar(u8, title, '/') != null) return false;
    var dir: [1200]u8 = undefined;
    const path = std.fmt.bufPrint(&dir, "{s}/export", .{opts.data}) catch return false;
    mkdirP(path);
    var out: [1400]u8 = undefined;
    const name = std.fmt.bufPrint(&out, "{s}/{s}.md", .{ path, title }) catch return false;
    return writeFileAtomic(name, b.slice());
}
fn exportCurrentNotes() void {
    var b = Buf.init(8192);
    defer b.deinit();
    var base: [1200]u8 = undefined;
    const nb = notesBase(&base);
    const title = if (std.mem.lastIndexOfScalar(u8, nb, '/')) |i| nb[i + 1 ..] else nb;
    markdownHeader(&b, book.nameS());
    for (book.notes[0..book.nnotes]) |*n| markdownNote(&b, n.page, n.style, n.text, n.anchor, n.unresolved, n.comment);
    if (!writeMarkdown(title, &b)) logf("Markdown export failed: {s}", .{title});
}
fn exportJson(title: []const u8, data: []const u8) bool {
    const input = std.mem.trim(u8, data, " \r\n\t");
    if (input.len < 2 or input[0] != '[' or input[input.len - 1] != ']') return false;
    var b = Buf.init(8192);
    defer b.deinit();
    markdownHeader(&b, title);
    var it = ObjIter{ .s = input };
    var textbuf: [8192]u8 = undefined;
    var stylebuf: [32]u8 = undefined;
    while (it.next()) |obj| {
        const t = jsonStr(obj, "text", &textbuf) orelse return false;
        const page = jsonNum(obj, "page") orelse return false;
        if (page < 1 or page > 1000000000) return false;
        const style = jsonStr(obj, "style", &stylebuf) orelse "note";
        var sn: usize = 2;
        for (STYLE_NAMES, 0..) |name, i| if (eql(style, name)) {
            sn = i;
        };
        var cbuf: [4096]u8 = undefined;
        const cm = jsonStr(obj, "comment", &cbuf) orelse "";
        markdownNote(&b, @as(i32, @intFromFloat(page)) - 1, sn, t, readAnchor(obj), (jsonNum(obj, "anchor_unresolved") orelse 0) != 0, cm);
    }
    if (all_export) |ab| {
        if (ab.n > 0) ab.put("\n");
        ab.put(b.slice());
    }
    return writeMarkdown(title, &b);
}
const ExportStats = struct { books: usize = 0, errors: usize = 0 };
var all_export: ?*Buf = null;
const ALL_EXPORT_TITLE = "All books - highlights and notes";
fn exportAllNotes() ExportStats {
    var ab = Buf.init(16384);
    defer ab.deinit();
    all_export = &ab;
    defer all_export = null;
    const r = exportAllNotesInner();
    if (ab.n > 0 and !writeMarkdown(ALL_EXPORT_TITLE, &ab)) logf("Markdown export failed: all books", .{});
    return r;
}
fn exportAllNotesInner() ExportStats {
    var result: ExportStats = .{};
    var path: [1400]u8 = undefined;
    const z = std.fmt.bufPrintSentinel(&path, "{s}/notes", .{opts.data}, 0) catch return result;
    const rc = linux.open(z, .{ .ACCMODE = .RDONLY, .DIRECTORY = true, .CLOEXEC = true }, 0);
    if (bad(rc)) return result;
    const fd: i32 = @intCast(rc);
    defer _ = linux.close(fd);
    var entries: [8192]u8 align(8) = undefined;
    while (true) {
        const count = linux.getdents64(fd, &entries, entries.len);
        if (bad(count) or count == 0) break;
        var off: usize = 0;
        while (off < count) {
            const reclen = std.mem.readInt(u16, entries[off + 16 ..][0..2], .little);
            const kind = entries[off + 18];
            const name = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(&entries[off + 19])), 0);
            off += reclen;
            if ((kind != 8 and kind != 0) or name.len <= 5 or !std.mem.endsWith(u8, name, ".json")) continue;
            var full: [1400]u8 = undefined;
            const p = std.fmt.bufPrintSentinel(&full, "{s}/notes/{s}", .{ opts.data, name }, 0) catch {
                result.errors += 1;
                continue;
            };
            const data = readExportFile(p) orelse {
                result.errors += 1;
                continue;
            };
            defer alloc.free(data);
            if (exportJson(name[0 .. name.len - 5], data)) result.books += 1 else result.errors += 1;
        }
    }
    return result;
}
fn readExportFile(path: [*:0]const u8) ?[]u8 {
    const rc = linux.open(path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true, .NOFOLLOW = true, .CLOEXEC = true }, 0);
    if (bad(rc)) return null;
    const fd: i32 = @intCast(rc);
    defer _ = linux.close(fd);
    var b = Buf.init(16384);
    var chunk: [8192]u8 = undefined;
    while (true) {
        const n = linux.read(fd, &chunk, chunk.len);
        if (bad(n)) {
            b.deinit();
            return null;
        }
        if (n == 0) break;
        if (b.n + n > 16 * 1024 * 1024) {
            b.deinit();
            return null;
        }
        const before = b.n;
        b.put(chunk[0..n]);
        if (b.n != before + n) {
            b.deinit();
            return null;
        }
    }
    // Transfer ownership of the allocation, keeping the exact slice length.
    return b.b[0..b.n];
}

test "Markdown export all escapes book text, keeps locations, rejects corrupt input and rewrites after deletion" {
    const old_data = opts.data;
    defer opts.data = old_data;
    opts.data = "tests/run-export-unit";
    mkdirP("tests/run-export-unit/notes");
    try std.testing.expect(writeFileAtomic("tests/run-export-unit/notes/First.json", "[{\"page\":7,\"style\":\"highlight\",\"text\":\"Exact *words* <tag>\\nsecond line\"}]"));
    try std.testing.expect(writeFileAtomic("tests/run-export-unit/notes/Empty.json", "[]"));
    try std.testing.expect(writeFileAtomic("tests/run-export-unit/notes/Corrupt.json", "not JSON"));
    const result = exportAllNotes();
    try std.testing.expectEqual(@as(usize, 2), result.books);
    try std.testing.expectEqual(@as(usize, 1), result.errors);
    const md = readFile("tests/run-export-unit/export/First.md") orelse return error.NoMarkdown;
    defer alloc.free(md);
    try std.testing.expect(std.mem.indexOf(u8, md, "## Highlight / Page 7") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "> Exact \\*words\\* \\<tag\\>\n> second line") != null);
    try std.testing.expect(writeFileAtomic("tests/run-export-unit/notes/First.json", "[]"));
    _ = exportAllNotes();
    const empty = readFile("tests/run-export-unit/export/First.md") orelse return error.NoMarkdown;
    defer alloc.free(empty);
    try std.testing.expectEqualStrings("# First\n\n", empty);
    var b = Buf.init(256);
    defer b.deinit();
    markdownNote(&b, 11, 0, "text", .{ .chapter = 2, .start = 42, .end = 46, .hash = 1 }, false, "");
    try std.testing.expect(std.mem.indexOf(u8, b.slice(), "Chapter 3, text offsets 42-46.") != null);
}

test "auto-cropped width remains cropped when zooming even with the independent trim toggle off" {
    try std.testing.expect(viewUsesTrim(true, false, .width, true));
    try std.testing.expect(viewUsesTrim(true, false, .zoom15, true));
    try std.testing.expect(viewUsesTrim(true, false, .zoom2, true));
    try std.testing.expect(!viewUsesTrim(true, false, .zoom2, false));
    try std.testing.expect(!viewUsesTrim(true, false, .page, true));
    try std.testing.expect(!viewUsesTrim(false, true, .width, true));
}

test "v07 native light clamp and slider endpoint geometry" {
    try std.testing.expectEqual(@as(i32, 0), lightAt(-100));
    try std.testing.expectEqual(@as(i32, 0), lightAt(lightSlider(0).x));
    try std.testing.expectEqual(@as(i32, 24), lightAt(lightSlider(0).x + lightSlider(0).w));
    try std.testing.expectEqual(@as(i32, 24), lightAt(9000));
    try std.testing.expectEqual(@as(i32, 12), lightAt(lightSlider(0).x + @divTrunc(lightSlider(0).w, 2)));
    try std.testing.expect(!power_sleeps);
}
test "v07 recent title progress sorts deterministic and progress bounded" {
    const a = Entry{ .path = @constCast("a"), .title = "Alpha", .folder = "UFO", .opened = 1, .progress = 90 };
    const b = Entry{ .path = @constCast("b"), .title = "Beta", .folder = "History", .opened = 2, .progress = 10 };
    lib_sort = 0;
    try std.testing.expect(libLess({}, b, a));
    lib_sort = 1;
    try std.testing.expect(libLess({}, a, b));
    lib_sort = 2;
    try std.testing.expect(libLess({}, a, b));
    lib_sort = 0;
}
test "v07 sleep default stays off and refuses accidental entry" {
    power_sleeps = false;
    sleep_phase = .awake;
    requestSleep();
    try std.testing.expectEqual(SleepPhase.awake, sleep_phase);
}


test "v08 storage units and legacy time32 opened repair" {
    var b: [64]u8 = undefined;
    try std.testing.expectEqualStrings("0 B", formatBytes(0, &b));
    try std.testing.expectEqualStrings("47.0 MiB", formatBytes(47 * 1024 * 1024, &b));
    try std.testing.expectEqualStrings("9.2 GiB", formatBytes(9878424781, &b));
    try std.testing.expectEqual(@as(i64, 1794022244), repairOpened(-2500945052));
    try std.testing.expectEqual(@as(i64, 1794022244), repairOpened(1794022244));
    try std.testing.expectEqual(@as(i64, 0), repairOpened(-5000000000));
    try std.testing.expect(zr_now_seconds() > 1700000000);
    try std.testing.expect(zr_now_seconds() < 3000000000);
}
test "v08 grey scan paper is not photo ink or periodic cleanup" {
    const scan = PageMetrics{ .ink = 0.4, .tone = 0.8, .image = 0.85, .photo = 0.04 };
    for (0..100) |i| {
        try std.testing.expectEqual(WF_REAGL, refreshChoice(scan, scan, .{ .dark_to_light = 0.2 }, 10, 11, false, @intCast(i), 0, WF_REAGL).mode);
    }
    const photo = PageMetrics{ .ink = 0.4, .image = 0.8, .photo = 0.4 };
    try std.testing.expectEqual(WF_GC16, refreshChoice(scan, photo, .{}, 10, 11, false, 0, 0, WF_REAGL).mode);
}


test "v08 library layout storage and battery screenshot (illustrative values)" {
    fb = try alloc.alloc(u8, @as(usize, STRIDE) * H);
    defer alloc.free(fb);
    ui = zr_ui_new(sans_font.ptr, @intCast(sans_font.len)) orelse return error.UI;
    opts.sim = "preview";
    book.open = false; screen = .library; list_page = 0; toast_len = 0;
    folder_filter = 0; folder_picker = false; lib_sort = 1;
    storage_free = 9878424781; storage_total = 12348030976; books_bytes = 1717986918;
    const names = [_][]const u8{ "A field guide to the night sky", "Notes from the quiet valley", "Collected stories", "The art of careful observation", "A practical programming companion", "A short history of discovery", "Patterns in nature" };
    nlib = names.len;
    for (names, 0..) |name, i| {
        lib[i] = .{ .path = @constCast("preview.pdf"), .title = name, .folder = if (i % 2 == 0) "Reference" else "Literature", .opened = 0, .progress = if (i < 3) @intCast(15 + i * 23) else -1, .bytes = (i + 1) * 1536000, .epub = i % 2 != 0 };
        lib_visible[i] = i;
    }
    nvisible = names.len;
    drawLibrary();
    var image = Buf.init(fb.len + 64); defer image.deinit();
    image.print("P5 {d} {d} 255\n", .{ W, H }); image.put(fb);
    try std.testing.expect(writeFileAtomic("shots/86_library_storage_battery_mock.pgm", image.slice()));
    nlib = 0; nvisible = 0; opts.sim = null;
}

test "v081 library book count formatting" {
    var b: [48]u8 = undefined;
    try std.testing.expectEqualStrings("85 books", formatBookCount(&b, 85, 85, false));
    try std.testing.expectEqualStrings("1 book", formatBookCount(&b, 1, 1, false));
    try std.testing.expectEqualStrings("0 books", formatBookCount(&b, 0, 0, false));
    try std.testing.expectEqualStrings("12 of 85 books", formatBookCount(&b, 12, 85, true));
    try std.testing.expectEqualStrings("85 books", formatBookCount(&b, 85, 85, true));
    nlib = 85; nvisible = 85; folder_filter = 0;
    storage_free = 9878424781; storage_total = 12348030976; books_bytes = 1717986918;
    var line: [200]u8 = undefined;
    try std.testing.expectEqualStrings("85 books  \xc2\xb7  Books 1.6 GiB  \xc2\xb7  9.2 GiB free / 11.5 GiB", libraryFooter(&line));
    folders[0] = "Reference"; nfolders = 1; folder_filter = 1; nvisible = 12;
    try std.testing.expectEqualStrings("12 of 85 books  \xc2\xb7  Books 1.6 GiB  \xc2\xb7  9.2 GiB free / 11.5 GiB", libraryFooter(&line));
    storage_total = 0;
    try std.testing.expectEqualStrings("12 of 85 books  \xc2\xb7  Books 1.6 GiB  \xc2\xb7  Device storage unavailable", libraryFooter(&line));
    nlib = 0; nvisible = 0; nfolders = 0; folder_filter = 0; storage_total = 0;
}

test "v081 library bottom line screenshot with book count (illustrative values)" {
    fb = try alloc.alloc(u8, @as(usize, STRIDE) * H);
    defer alloc.free(fb);
    ui = zr_ui_new(sans_font.ptr, @intCast(sans_font.len)) orelse return error.UI;
    opts.sim = "preview";
    book.open = false; screen = .library; list_page = 0; toast_len = 0;
    folder_picker = false; lib_sort = 1;
    storage_free = 9878424781; storage_total = 12348030976; books_bytes = 1717986918;
    const names = [_][]const u8{ "A field guide to the night sky", "Notes from the quiet valley", "Collected stories", "The art of careful observation", "A practical programming companion", "A short history of discovery", "Patterns in nature" };
    for (names, 0..) |name, i| {
        lib[i] = .{ .path = @constCast("preview.pdf"), .title = name, .folder = "Reference", .opened = 0, .progress = if (i < 3) @intCast(15 + i * 23) else -1, .bytes = (i + 1) * 1536000, .epub = i % 2 != 0 };
        lib_visible[i] = i;
    }
    // 85 books in total (only the first page has rows); second shot filters a folder of 12.
    const variants = [_]struct { filter: usize, visible: usize, name: []const u8 }{
        .{ .filter = 0, .visible = 85, .name = "shots/90_library_book_count_mock.pgm" },
        .{ .filter = 1, .visible = 12, .name = "shots/91_library_folder_count_mock.pgm" },
    };
    folders[0] = "Reference"; nfolders = 1;
    for (variants) |v| {
        nlib = 85; nvisible = v.visible; folder_filter = v.filter;
        @memset(fb, 255);
        drawLibrary();
        var image = Buf.init(fb.len + 64); defer image.deinit();
        image.print("P5 {d} {d} 255\n", .{ W, H }); image.put(fb);
        try std.testing.expect(writeFileAtomic(v.name, image.slice()));
    }
    nlib = 0; nvisible = 0; nfolders = 0; folder_filter = 0; opts.sim = null; storage_total = 0;
}
