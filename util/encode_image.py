#!/bin/python3

from argparse import ArgumentParser
from itertools import cycle, islice
from PIL import Image
from sys import stderr, stdout

def batched(blob, n):
    return (blob[i*n : (i+1)*n] for i in range(len(blob) // n))

def downsample_4bpc(byte, noise):
    if noise:
        # Partial dithering to smooth color bands
        byte += next(noise)//16 - 8

    return sorted([0, byte, 255])[1] >> 4

def downsample_6bpc(byte, noise):
    if noise:
        # Partial dithering to smooth color bands
        byte += next(noise)//64 - 2

    return sorted([0, byte, 255])[1] >> 2

def rgb444(image, noise):
    blob = image.convert('RGB').tobytes()
    blob = [downsample_4bpc(byte, noise) for byte in blob]
    encoded = bytearray()
    hexads = batched(blob, 6)

    for r1, g1, b1, r2, g2, b2 in hexads:
        encoded.append(r1 << 4 | g1)
        encoded.append(b1 << 4 | r2)
        encoded.append(g2 << 4 | b2)

    return encoded

def rgb666(image, noise):
    foo = image.point(lambda p: p & 0xF0)
    foo.save("test.png")
    blob = image.convert('RGB').tobytes()
    blob = [downsample_6bpc(byte, noise) for byte in blob]
    encoded = bytearray()
    pixels = batched(blob, 3)

    for r, g, b in pixels:
        encoded.append(0b11000000 & (g << 6) | b)
        encoded.append(0b11110000 & (r << 4) | g >> 2)
        encoded.append(r >> 4)
        encoded.append(0)

    return encoded

def soi444(image, noise):
    blob = image.convert('RGB').tobytes()
    blob = [downsample_4bpc(byte, noise) for byte in blob]
    encoded = bytearray()
    pixels = batched(blob, 3)
    cache = [None for _ in range(32)]
    prev = None
    run = -1

    push = lambda run: encoded.append(run) if run > -1 else None

    for r, g, b in pixels:
        # Hash color
        idx = 3*r + 5*g + 7*b & 0b0001_1111

        # Push run if it cannot be extended with current pixel
        if prev != (r, g, b) or run == 127:
            push(run)
            run = -1

        if prev == (r, g, b):
            run += 1
        elif cache[idx] == (r, g, b):
            # Cached (0‥31)
            encoded.append(0b1100_0000 | idx)
        else:
            # Literal (0‥15)
            encoded.append(0b1111_0000 | b)
            encoded.append(g << 4 | r)

        # Update encoder state
        prev = cache[idx] = (r, g, b)
    else:
        # Push remaining run
        push(run)

    return encoded

# TODO: Run-length encoding.
def sixel(image, noise):
    blob = image.convert('1').convert('L').tobytes()
    lines = batched(blob, image.width)
    groups = batched([*lines], 6)
    bands = (zip(*lines) for lines in groups)
    encoded = bytearray()

    for band in bands:
        for hexad in band:
            column = 0

            column |= int(hexad[0] > 0)
            column |= int(hexad[1] > 0) << 1
            column |= int(hexad[2] > 0) << 2
            column |= int(hexad[3] > 0) << 3
            column |= int(hexad[4] > 0) << 4
            column |= int(hexad[5] > 0) << 5

            encoded.append(column + ord('?'))

        encoded.append(ord('$'))
        encoded.append(ord('-'))

    return encoded

ENCODINGS = {
    'RGB': lambda image, _: image.convert('RGB').tobytes(),
    'RGB444': rgb444,
    'RGB666': rgb666,
    'SOI444': soi444,
    'Sixel': sixel,
}

parser = ArgumentParser()
parser.add_argument('path')
parser.add_argument('-e', '--encoding', default='RGB', choices=ENCODINGS)
parser.add_argument('-n', '--noise')

args = parser.parse_args()
image = Image.open(args.path)
encoded = None
noise = None

if args.noise:
    texture = Image.open(args.noise).convert('L')
    noise = cycle(texture.tobytes())

encoded = ENCODINGS[args.encoding](image, noise)
stdout.buffer.write(encoded)
