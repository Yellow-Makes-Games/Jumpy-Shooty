"""Small 3D maths helpers for the robot builder (numpy only).

Conventions match Godot: +Y up, the character faces -Z, its right hand is +X.
Rotations are 3x3 matrices; angles are in degrees at the API surface.
"""
import math
import numpy as np


def v(x, y, z):
    return np.array([x, y, z], dtype=float)


def norm(a):
    n = np.linalg.norm(a)
    return a / n if n > 1e-9 else a * 0.0


def rx(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]], dtype=float)


def ry(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], dtype=float)


def rz(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], dtype=float)


def euler(e):
    """(pitch about X, yaw about Y, roll about Z) in degrees -> matrix, applied yaw * pitch * roll."""
    return ry(e[1]) @ rx(e[0]) @ rz(e[2])


def axis_angle(axis, deg):
    axis = norm(np.asarray(axis, dtype=float))
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    x, y, z = axis
    k = np.array([[0, -z, y], [z, 0, -x], [-y, x, 0]], dtype=float)
    return np.eye(3) * c + s * k + (1 - c) * np.outer(axis, axis)


def frame(x=None, y=None, z=None):
    """Rotation matrix from two of its axes (the third is derived)."""
    if x is None:
        y, z = norm(y), norm(z)
        x = norm(np.cross(y, z))
        z = np.cross(x, y)
    elif y is None:
        z, x = norm(z), norm(x)
        y = norm(np.cross(z, x))
        x = np.cross(y, z)
    else:
        x, y = norm(x), norm(y)
        z = norm(np.cross(x, y))
        x = np.cross(y, z)
    return np.column_stack([x, y, z])


def quat(m):
    """Rotation matrix -> quaternion (x, y, z, w)."""
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        w = 0.25 * s
        x = (m[2, 1] - m[1, 2]) / s
        y = (m[0, 2] - m[2, 0]) / s
        z = (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        w = (m[2, 1] - m[1, 2]) / s
        x = 0.25 * s
        y = (m[0, 1] + m[1, 0]) / s
        z = (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        w = (m[0, 2] - m[2, 0]) / s
        x = (m[0, 1] + m[1, 0]) / s
        y = 0.25 * s
        z = (m[1, 2] + m[2, 1]) / s
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        w = (m[1, 0] - m[0, 1]) / s
        x = (m[0, 2] + m[2, 0]) / s
        y = (m[1, 2] + m[2, 1]) / s
        z = 0.25 * s
    q = np.array([x, y, z, w], dtype=float)
    return q / np.linalg.norm(q)
