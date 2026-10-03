# Face detection provenance

The optional face-detection showcase integrates Shiqi Yu's `libfacedetection`, a YuNet-family CNN face detector. NativeASM does not vendor or copy its C++ implementation or model arrays in this delta. The small `NativeAsmFaceBridge` file is independently written glue code that calls the published `facedetect_cnn` API through a stable C ABI.

Upstream:

- https://github.com/ShiqiYu/libfacedetection
- https://github.com/ShiqiYu/libfacedetection.train
- https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet

`libfacedetection` is distributed under the 3-clause BSD License. Its copyright notice and redistribution conditions must be retained when redistributing its source or a binary containing it.

Copyright (c) 2015-2019, Shiqi Yu, all rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the names of the copyright holders nor the names of the contributors may be used to endorse or promote products derived from this software without specific prior written permission.

The software is provided by the copyright holders and contributors "as is", without express or implied warranties. The full authoritative license remains in the upstream repository. The bridge build copies the upstream license next to the generated DLL when available; keep that file with redistributed binaries.

OpenCV Zoo's YuNet model directory states that the files in that directory are MIT licensed. This delta does not redistribute the OpenCV Zoo model.
