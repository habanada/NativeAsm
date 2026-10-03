# NativeASM AVX Showcase

This directory contains executable Win64 demonstrations of NativeASM's AVX/FMA encoder and JIT runtime.

## Included workloads

### FFT8 / FMA

An 8-point complex radix-2 FFT. Bit-reversal uses `VSHUFPS` and `VPERM2F128`; butterfly stages use packed arithmetic and FMA. The result is checked against an independent scalar DFT.

### 8x8 transpose

A complete 8x8 `Single` transpose using `VUNPCKLPS`, `VUNPCKHPS`, `VSHUFPS`, `VPERM2F128`, `VINSERTF128`, and `VEXTRACTF128`. The round trip `Transpose(Transpose(M)) = M` is verified.

### Mandelbrot bitmap

Eight pixels are iterated in parallel by a generated AVX kernel. The console first performs a pixel-for-pixel scalar verification and then renders a 1920x1080 24-bit BMP.

### Polynomial / Horner + FMA

Eight degree-7 polynomials are evaluated in parallel with a real `VFMADD213PS` Horner chain and checked against a Double scalar reference.

### Float edge-case matrix

`VMINPS`, `VMAXPS`, clamp, ordered and unordered comparisons are checked bit-for-bit over signed zero, infinities, qNaN payloads, and finite extremes.

### NativeASM AVX face detection

The face detector is fully implemented in Delphi/NativeASM. It does not load OpenCV, ONNX Runtime, libfacedetection, or another inference DLL and it does not require AVX2.

The established OpenCV `haarcascade_frontalface_default.xml` is used only as trained classifier data. OpenCV itself is not linked or loaded.

The runtime pipeline is:

```text
24-bit BMP
  -> grayscale
  -> integral + squared-integral image
  -> multiscale 24x24 sliding windows
  -> HAAR rectangle feature preparation
  -> NativeASM AVX stage kernels, 8 windows in parallel
  -> grouping
  -> annotated 24-bit BMP
```

Every cascade stage is compiled at runtime by NativeASM. The stage kernels use `VCMPPS`, `VANDPS`, `VANDNPS`, `VORPS`, `VADDPS`, and `VMOVMSKPS` with YMM registers. Only AVX is required.

Download the model data once:

```powershell
powershell -ExecutionPolicy Bypass -File .\FaceModel\fetch_model.ps1
```

Copy `haarcascade_frontalface_default.xml` beside the built executable or pass a cascade path explicitly:

```text
NativeAsmAvxShowcase.exe portrait.bmp [haarcascade_frontalface_default.xml]
```

Output:

```text
portrait.faces.bmp
```

See `FACE_DETECTION_PROVENANCE.md` for the implementation/model boundary and licensing notes.

## Projects

Main showcase:

```text
NativeAsmAvxShowcase.dproj
```

DUnitX verification:

```text
Tests\NativeAsmAvxShowcaseDUnitXTests.dproj
```

Both projects are Win64-only.

## Verification philosophy

The showcase keeps visual output separate from correctness. FFT, transpose, Mandelbrot, polynomial and float special-value kernels have independent scalar references. The face detector has a synthetic DUnitX stage test that compares the generated 8-lane AVX classifier against scalar evaluation before any external cascade model is needed.
