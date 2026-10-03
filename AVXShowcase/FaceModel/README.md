# NativeASM AVX face model

The runtime detector is implemented inside `NativeAsm.AvxShowcase.FaceDetection.pas` and does not load OpenCV, ONNX Runtime, libfacedetection, or another inference DLL.

The detector consumes the established OpenCV frontal-face HAAR cascade as model data. Download it with:

```powershell
powershell -ExecutionPolicy Bypass -File .\FaceModel\fetch_model.ps1
```

The script places `haarcascade_frontalface_default.xml` beside the showcase project. Copy that file beside `NativeAsmAvxShowcase.exe` after building, or pass an explicit cascade path as the second command-line argument.

Runtime requirements are AVX only. AVX2 is not required.

The OpenCV cascade and OpenCV project are distributed under the OpenCV 3-clause BSD license. Keep the applicable OpenCV license when redistributing the cascade model.
