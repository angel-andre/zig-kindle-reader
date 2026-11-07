// einktest: measure e-ink refresh latency on MTK hwtcon_v2 Kindles (PW5/PW6 class).
// Layouts and ioctl numbers mirror FBInk eink/mtk-kindle.h and koreader-base mxcfb_kindle_h.lua.
const std = @import("std");
const linux = std.os.linux;

const FbBitfield = extern struct { offset: u32, length: u32, msb_right: u32 };
const FbVarScreeninfo = extern struct {
    xres: u32, yres: u32, xres_virtual: u32, yres_virtual: u32,
    xoffset: u32, yoffset: u32, bits_per_pixel: u32, grayscale: u32,
    red: FbBitfield, green: FbBitfield, blue: FbBitfield, transp: FbBitfield,
    nonstd: u32, activate: u32, height: u32, width: u32, accel_flags: u32,
    pixclock: u32, left_margin: u32, right_margin: u32, upper_margin: u32, lower_margin: u32,
    hsync_len: u32, vsync_len: u32, sync: u32, vmode: u32, rotate: u32, colorspace: u32,
    reserved: [4]u32,
};
const FbFixScreeninfo = extern struct {
    id: [16]u8, smem_start: c_ulong, smem_len: u32, type: u32, type_aux: u32, visual: u32,
    xpanstep: u16, ypanstep: u16, ywrapstep: u16, line_length: u32, mmio_start: c_ulong,
    mmio_len: u32, accel: u32, capabilities: u16, reserved: [2]u16,
};
const FBIOGET_VSCREENINFO: u32 = 0x4600;
const FBIOGET_FSCREENINFO: u32 = 0x4602;

const Rect = extern struct { top: u32, left: u32, width: u32, height: u32 };
const AltBuffer = extern struct { phys_addr: u32, width: u32, height: u32, alt_update_region: Rect };
const Swipe = extern struct { direction: u32, steps: u32 };
const UpdateDataMtk = extern struct {
    update_region: Rect,
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
    std.debug.assert(@sizeOf(MarkerData) == 8);
}

fn ioc(dir: u32, nr: u32, size: u32) u32 {
    return (dir << 30) | (size << 16) | (@as(u32, 'F') << 8) | nr;
}
const MXCFB_SEND_UPDATE_MTK = ioc(1, 0x2E, @sizeOf(UpdateDataMtk)); // _IOW
const MXCFB_WAIT_FOR_UPDATE_COMPLETE = ioc(3, 0x2F, @sizeOf(MarkerData)); // _IOWR

const UPDATE_MODE_PARTIAL: u32 = 0;
const UPDATE_MODE_FULL: u32 = 1;
const TEMP_USE_AMBIENT: i32 = 0x1000;
const EPDC_FLAG_FORCE_MONOCHROME: u32 = 0x02;
const WF_DU: u32 = 1;
const WF_GC16: u32 = 2;
const WF_GL16: u32 = 3;
const WF_REAGL: u32 = 4;
const WF_A2: u32 = 6;
const WF_DU4: u32 = 7;

const Wf = struct { name: []const u8, mode: u32, upd: u32 };
const waveforms = [_]Wf{
    .{ .name = "GLR16/REAGL", .mode = WF_REAGL, .upd = UPDATE_MODE_FULL }, // REAGL pairs with FULL
    .{ .name = "GL16", .mode = WF_GL16, .upd = UPDATE_MODE_PARTIAL },
    .{ .name = "GC16", .mode = WF_GC16, .upd = UPDATE_MODE_FULL },
    .{ .name = "DU", .mode = WF_DU, .upd = UPDATE_MODE_PARTIAL },
    .{ .name = "A2", .mode = WF_A2, .upd = UPDATE_MODE_PARTIAL },
    .{ .name = "DU4", .mode = WF_DU4, .upd = UPDATE_MODE_PARTIAL },
};
const REPS = 5;

const Fb = struct {
    mem: []u8,
    v: FbVarScreeninfo,
    f: FbFixScreeninfo,
    bpp: u32,
    fn put(self: *Fb, x: u32, y: u32, g: u8) void {
        const off = @as(usize, y) * self.f.line_length + @as(usize, x) * (self.bpp / 8);
        if (self.bpp == 8) {
            self.mem[off] = g;
        } else if (self.bpp == 16) {
            const v: u16 = (@as(u16, g >> 3) << 11) | (@as(u16, g >> 2) << 5) | (g >> 3);
            self.mem[off] = @truncate(v);
            self.mem[off + 1] = @truncate(v >> 8);
        } else {
            self.mem[off] = g;
            self.mem[off + 1] = g;
            self.mem[off + 2] = g;
            if (self.bpp == 32) self.mem[off + 3] = 0xFF;
        }
    }
    fn fill(self: *Fb, x0: u32, y0: u32, w: u32, h: u32, g: u8) void {
        const x1 = @min(x0 + w, self.v.xres);
        const y1 = @min(y0 + h, self.v.yres);
        var y = y0;
        while (y < y1) : (y += 1) {
            if (self.bpp == 8) {
                const off = @as(usize, y) * self.f.line_length;
                @memset(self.mem[off + x0 .. off + x1], g);
            } else {
                var x = x0;
                while (x < x1) : (x += 1) self.put(x, y, g);
            }
        }
    }
};

fn nowUs() u64 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1_000_000 + @as(u64, @intCast(ts.nsec)) / 1000;
}

fn sysErr(rc: usize) ?linux.E {
    const e = linux.errno(rc);
    return if (e == .SUCCESS) null else e;
}

// Draws a page of "text": a margin, a heading bar, and lines of word-like dark blocks.
// `seed` changes the word pattern so two pages differ everywhere.
fn drawPage(fb: *Fb, seed: u32, region: Rect) void {
    fb.fill(region.left, region.top, region.width, region.height, 0xFF);
    const W = fb.v.xres;
    const H = fb.v.yres;
    const margin = W / 12;
    const line_h: u32 = 44;
    const glyph_h: u32 = 26;
    var rng: u32 = seed *% 2654435761 +% 12345;
    var y: u32 = margin;
    // heading
    if (y + 40 <= H and inRect(region, y, 40)) fb.fill(margin, y, (W - 2 * margin) / 2 + (seed % 3) * 40, 40, 0x00);
    y += 90;
    while (y + glyph_h < H - margin) : (y += line_h) {
        if (!inRect(region, y, glyph_h)) continue;
        var x: u32 = margin;
        while (true) {
            rng = rng *% 1103515245 +% 12345;
            const word = 30 + (rng >> 16) % 140;
            if (x + word > W - margin) break;
            const shade: u8 = if ((rng >> 8) % 7 == 0) 0x55 else 0x00;
            fb.fill(x, y, word, glyph_h, shade);
            x += word + 18;
        }
    }
    // thin rule and gray ramp footer (exercises 16 gray levels)
    if (inRect(region, H - margin + 10, 2)) fb.fill(margin, H - margin + 10, W - 2 * margin, 2, 0x00);
    var i: u32 = 0;
    const sw = (W - 2 * margin) / 16;
    while (i < 16) : (i += 1) {
        if (inRect(region, H - margin + 24, 30)) fb.fill(margin + i * sw, H - margin + 24, sw, 30, @intCast(i * 17));
    }
}

fn inRect(r: Rect, y: u32, h: u32) bool {
    return y + h > r.top and y < r.top + r.height;
}

var marker: u32 = 1;

fn update(fd: i32, r: Rect, mode: u32, upd: u32) !u32 {
    marker +%= 1;
    if (marker == 0) marker = 1;
    var u = std.mem.zeroes(UpdateDataMtk);
    u.update_region = r;
    u.waveform_mode = mode;
    u.update_mode = upd;
    u.update_marker = marker;
    u.temp = TEMP_USE_AMBIENT;
    u.flags = if (mode == WF_A2) EPDC_FLAG_FORCE_MONOCHROME else 0;
    u.hist_bw_waveform_mode = if (mode == WF_REAGL) WF_REAGL else WF_DU;
    u.hist_gray_waveform_mode = if (mode == WF_REAGL) WF_REAGL else WF_GC16;
    if (sysErr(linux.ioctl(fd, MXCFB_SEND_UPDATE_MTK, @intFromPtr(&u)))) |e| {
        std.debug.print("SEND_UPDATE_MTK failed: {s}\n", .{@tagName(e)});
        return error.Ioctl;
    }
    return marker;
}

fn waitDone(fd: i32, m: u32) !void {
    var md = MarkerData{ .update_marker = m, .collision_test = 0 };
    if (sysErr(linux.ioctl(fd, MXCFB_WAIT_FOR_UPDATE_COMPLETE, @intFromPtr(&md)))) |e| {
        std.debug.print("WAIT_FOR_UPDATE_COMPLETE failed: {s}\n", .{@tagName(e)});
        return error.Ioctl;
    }
}

pub fn main(init: std.process.Init.Minimal) !void {
    const argv = init.args.vector;
    var partial = false;
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const a = std.mem.span(argv[i]);
        if (std.mem.eql(u8, a, "--partial")) partial = true else {
            std.debug.print("usage: einktest [--partial]\n", .{});
            return;
        }
    }

    const fd_rc = linux.open("/dev/fb0", .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0);
    if (sysErr(fd_rc)) |e| {
        std.debug.print("open /dev/fb0: {s}\n", .{@tagName(e)});
        return error.Open;
    }
    const fd: i32 = @intCast(fd_rc);
    defer _ = linux.close(fd);

    var fb: Fb = undefined;
    if (sysErr(linux.ioctl(fd, FBIOGET_VSCREENINFO, @intFromPtr(&fb.v)))) |_| return error.Vinfo;
    if (sysErr(linux.ioctl(fd, FBIOGET_FSCREENINFO, @intFromPtr(&fb.f)))) |_| return error.Finfo;
    fb.bpp = fb.v.bits_per_pixel;
    const v = fb.v;
    const f = fb.f;
    std.debug.print(
        \\fix: id="{s}" smem_len={d} line_length={d} type={d} visual={d}
        \\var: xres={d} yres={d} xres_virtual={d} yres_virtual={d} xoff={d} yoff={d}
        \\     bpp={d} grayscale={d} rotate={d} width_mm={d} height_mm={d}
        \\     red={d}/{d} green={d}/{d} blue={d}/{d}
        \\
    , .{
        std.mem.sliceTo(&f.id, 0), f.smem_len, f.line_length, f.type, f.visual,
        v.xres,                    v.yres,     v.xres_virtual, v.yres_virtual, v.xoffset, v.yoffset,
        v.bits_per_pixel,          v.grayscale, v.rotate,     v.width,         v.height,
        v.red.offset, v.red.length, v.green.offset, v.green.length, v.blue.offset, v.blue.length,
    });
    if (fb.bpp != 8 and fb.bpp != 16 and fb.bpp != 24 and fb.bpp != 32) return error.UnsupportedBpp;
    if (v.yoffset != 0) std.debug.print("note: yoffset={d}; drawing at offset 0 only\n", .{v.yoffset});

    const len: usize = f.smem_len;
    const map_rc = linux.mmap(null, len, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, fd, 0);
    if (sysErr(map_rc)) |e| {
        std.debug.print("mmap: {s}\n", .{@tagName(e)});
        return error.Mmap;
    }
    fb.mem = @as([*]u8, @ptrFromInt(map_rc))[0..len];
    defer _ = linux.munmap(fb.mem.ptr, len);

    const full = Rect{ .top = 0, .left = 0, .width = v.xres, .height = v.yres };
    // Changed band for --partial: roughly a paragraph in the middle of the page.
    const band = Rect{ .top = v.yres / 3, .left = 0, .width = v.xres, .height = v.yres / 4 };
    const region = if (partial) band else full;

    // Start from a clean, known state.
    drawPage(&fb, 0, full);
    try waitDone(fd, try update(fd, full, WF_GC16, UPDATE_MODE_FULL));

    var results: [waveforms.len][REPS]u64 = undefined;
    for (waveforms, 0..) |wf, wi| {
        var r: usize = 0;
        while (r < REPS) : (r += 1) {
            drawPage(&fb, @intCast(1 + (r & 1)), region);
            const t0 = nowUs();
            const m = try update(fd, region, wf.mode, wf.upd);
            try waitDone(fd, m);
            results[wi][r] = nowUs() - t0;
        }
        // Clean the panel between waveform groups so ghosting from A2/DU does not skew the next one.
        drawPage(&fb, 0, full);
        try waitDone(fd, try update(fd, full, WF_GC16, UPDATE_MODE_FULL));
    }

    std.debug.print("\nmode: {s}  region: {d}x{d}+{d}+{d}  reps: {d}\n", .{
        if (partial) "partial-rect" else "full-screen", region.width, region.height, region.left, region.top, REPS,
    });
    std.debug.print("{s:<12} {s:>9} {s:>9} {s:>9} {s:>9}   samples(us)\n", .{ "waveform", "min_us", "avg_us", "max_us", "upd" });
    for (waveforms, 0..) |wf, wi| {
        var mn: u64 = std.math.maxInt(u64);
        var mx: u64 = 0;
        var sum: u64 = 0;
        for (results[wi]) |s| {
            mn = @min(mn, s);
            mx = @max(mx, s);
            sum += s;
        }
        std.debug.print("{s:<12} {d:>9} {d:>9} {d:>9} {s:>9}  ", .{ wf.name, mn, sum / REPS, mx, if (wf.upd == UPDATE_MODE_FULL) "FULL" else "PARTIAL" });
        for (results[wi]) |s| std.debug.print(" {d}", .{s});
        std.debug.print("\n", .{});
    }

    // Leave a white screen with a final flashing GC16.
    fb.fill(0, 0, v.xres, v.yres, 0xFF);
    try waitDone(fd, try update(fd, full, WF_GC16, UPDATE_MODE_FULL));
}
