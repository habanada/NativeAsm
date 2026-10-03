# Face detection provenance

The face detector runtime in this showcase is original Delphi/NativeASM code.

It uses the OpenCV `haarcascade_frontalface_default.xml` frontal-face cascade only as trained classifier data. The model is not executable code and OpenCV is not linked or loaded by the showcase.

The detector performs its own 24-bit BMP loading, grayscale conversion, summed-area and squared-summed-area generation, multi-scale sliding-window search, HAAR rectangle evaluation, cascade staging, result grouping, and BMP overlay.

Each cascade stage gets a NativeASM-generated AVX kernel. Eight candidate windows are evaluated in parallel with YMM registers. The generated stage kernel uses AVX instructions including `VCMPPS`, `VANDPS`, `VANDNPS`, `VORPS`, `VADDPS`, and `VMOVMSKPS`. No AVX2 instruction is required.

Model source:
`opencv/opencv`, `data/haarcascades/haarcascade_frontalface_default.xml`, branch `4.x`.

OpenCV license: 3-clause BSD.
