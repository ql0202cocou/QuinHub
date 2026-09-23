#!/usr/bin/env python3
"""生成 QuinHub 图标源文件：assets/icon.png（1024 完整图标）+ assets/icon_fg.png（自适应前景，透明底）。
纯 stdlib（zlib PNG 写入）。图形：深蓝圆角方块 + 白色聊天气泡 + 两条蓝色文本线。
"""
import struct
import zlib

W = 1024
BG = (26, 86, 219, 255)      # #1A56DB
WHITE = (255, 255, 255, 255)


def write_png(path, pixels):
    h = len(pixels)
    w = len(pixels[0])
    raw = b''.join(b'\x00' + b''.join(struct.pack('BBBB', *px) for px in row) for row in pixels)
    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)))
        f.write(chunk(b'IDAT', zlib.compress(raw, 9)))
        f.write(chunk(b'IEND', b''))


def in_rounded_rect(x, y, x0, y0, x1, y1, r):
    if not (x0 <= x <= x1 and y0 <= y <= y1):
        return False
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def in_tail(x, y):
    # 气泡左下小尾巴三角形：(0.38,0.60) (0.38,0.74) (0.52,0.60)
    ax, ay = 0.38 * W, 0.60 * W
    bx, by = 0.38 * W, 0.74 * W
    cx, cy = 0.52 * W, 0.60 * W
    d = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay)
    w1 = ((x - ax) * (cy - ay) - (cx - ax) * (y - ay)) / d
    w2 = ((cx - ax) * (y - ay) - (x - ax) * (by - by) * 0 - (x - ax) * 0)  # placeholder
    # 重心坐标
    denom = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    l1 = ((by - cy) * (x - cx) + (cx - bx) * (y - cy)) / denom
    l2 = ((cy - ay) * (x - cx) + (ax - cx) * (y - cy)) / denom
    l3 = 1 - l1 - l2
    return l1 >= 0 and l2 >= 0 and l3 >= 0


def in_bubble(x, y):
    if in_rounded_rect(x, y, 0.22 * W, 0.28 * W, 0.78 * W, 0.62 * W, 0.09 * W):
        return True
    return in_tail(x, y)


def in_text_line(x, y):
    # 两条蓝色横线（气泡内）
    if 0.32 * W <= x <= 0.68 * W and 0.40 * W <= y <= 0.44 * W:
        return True
    if 0.32 * W <= x <= 0.56 * W and 0.50 * W <= y <= 0.54 * W:
        return True
    return False


def gen(full_icon):
    rows = []
    r = 0.22 * W  # 外圆角
    for y in range(W):
        row = []
        for x in range(W):
            if in_bubble(x, y):
                row.append(BG if in_text_line(x, y) else WHITE)
            elif full_icon and in_rounded_rect(x, y, 0, 0, W - 1, W - 1, r):
                row.append(BG)
            else:
                row.append((0, 0, 0, 0))
        rows.append(row)
    return rows


gen(True)
write_png('assets/icon.png', gen(True))
write_png('assets/icon_fg.png', gen(False))
print('icon.png / icon_fg.png generated')
