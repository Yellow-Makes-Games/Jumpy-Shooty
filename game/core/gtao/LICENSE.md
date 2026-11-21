# GTAO: where it comes from and its licence

The GTAO ambient occlusion in this folder (`gtao_prefilter.glsl`, `gtao_main.glsl`,
`gtao_denoise.glsl`) is ported to Godot from Intel's XeGTAO,
https://github.com/GameTechDev/XeGTAO (version 1.30), which is under the MIT licence
below. Each of those shaders carries the notice too. `gtao_upsample.glsl` (half resolution
back to full), `gtao.gd` and `gtao_effect.gd`, which run
the shaders in Godot, are the project's own work.

| Files | Source | Licence |
| --- | --- | --- |
| `gtao_prefilter.glsl`, `gtao_main.glsl`, `gtao_denoise.glsl` | Ported from XeGTAO (`XeGTAO.hlsli`, `XeGTAO.h`, `vaGTAO.hlsl`) | MIT (below) |

```
MIT License

Copyright (C) 2016-2021, Intel Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
