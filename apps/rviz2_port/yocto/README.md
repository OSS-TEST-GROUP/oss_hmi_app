# AGL Trout 20.0.3 + RViz2 Wayland 빌드 가이드

이 디렉토리는 RViz2(ROS2 Humble)를 AGL Terrific Trout 20.0.3 (Yocto Scarthgap 5.0) 환경에서 네이티브 Wayland로 포팅하기 위한 Yocto 빌드 리소스를 포함합니다.

---

## 📋 목차

1. [개요](#개요)
2. [사전 요구사항](#사전-요구사항)
3. [빌드 환경 구성](#빌드-환경-구성)
4. [레이어 클론 및 설정](#레이어-클론-및-설정)
5. [빌드 실행](#빌드-실행)
6. [검증 및 실행](#검증-및-실행)
7. [문제 해결](#문제-해결)

---

## 개요

### 프로젝트 구조

```
yocto/
├── README.md                   # 이 파일
├── bblayers.conf.sample        # Yocto 레이어 설정 템플릿
├── local.conf.sample           # Yocto 빌드 설정 템플릿
└── meta-rviz2-agl/             # RViz2 Wayland 포팅용 커스텀 레이어
    ├── conf/
    │   └── layer.conf          # 레이어 메타데이터
    ├── recipes-ros2/
    │   ├── ogre/
    │   │   └── ogre_%.bbappend          # OGRE EGL+Wayland 빌드 설정 (R005에서 작성)
    │   └── rviz2/
    │       ├── rviz2_%.bbappend         # RViz2 Wayland 패치 (R007/R008에서 작성)
    │       └── files/                   # 패치 파일 디렉토리 (R007에서 추가)
    └── COPYING.MIT             # 레이어 라이선스
```

### 핵심 목표

- **X11 제거**: AGL Trout는 순수 Wayland 환경 (X11 미포함)
- **Qt Wayland QPA**: Qt5의 네이티브 Wayland 플러그인 사용
- **OGRE EGL 빌드**: GLX 대신 EGL + Wayland window backend 사용
- **RViz2 패치**: Wayland 감지 시 xcb 강제 전환 로직 제거

---

## 사전 요구사항

### 시스템 요구사항

- **OS**: Ubuntu 22.04 LTS 또는 Debian 12+ (권장)
- **CPU**: 8코어 이상 (병렬 빌드 시 권장)
- **RAM**: 32GB 이상
- **디스크**: 최소 100GB 여유 공간 (빌드 캐시 포함)

### 필수 패키지 설치

```bash
sudo apt-get update
sudo apt-get install -y \
    gawk wget git diffstat unzip texinfo gcc build-essential \
    chrpath socat cpio python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping python3-git python3-jinja2 \
    libegl1-mesa libsdl1.2-dev pylint3 xterm python3-subunit \
    mesa-common-dev zstd liblz4-tool
```

---

## 빌드 환경 구성

### 1. AGL Trout 소스 클론

```bash
# 작업 디렉토리 생성
mkdir -p ~/agl-workspace
cd ~/agl-workspace

# AGL 메타데이터 클론 (Trout 20.0.3 브랜치)
git clone -b trout https://gerrit.automotivelinux.org/gerrit/AGL/meta-agl
git clone https://git.yoctoproject.org/poky -b scarthgap
git clone https://git.openembedded.org/meta-openembedded -b scarthgap
```

### 2. Flutter 및 Qt 레이어 클론

```bash
# Flutter 임베더 레이어 (AGL 기본 HMI)
git clone https://github.com/meta-flutter/meta-flutter -b scarthgap

# Qt5 레이어 (RViz2 런타임 필요)
git clone https://github.com/meta-qt5/meta-qt5 -b scarthgap
```

### 3. ROS2 메타 레이어 클론

```bash
# ROS2 Humble + Scarthgap 조합 (best-effort 지원)
git clone https://github.com/ros/meta-ros -b scarthgap
```

**⚠️ 주의**: `meta-ros`의 `scarthgap` 브랜치는 Humble에 대해 best-effort 수준의 지원만 제공합니다. gcc 13 및 glibc 2.39 환경에서 일부 패키지 빌드 오류가 발생할 수 있습니다.

### 4. meta-rviz2-agl 레이어 배치

이 프로젝트의 `meta-rviz2-agl` 레이어를 AGL 작업 공간에 배치합니다:

```bash
# 옵션 A: 심볼릭 링크 생성 (개발 시 권장)
ln -s <PROJECT_ROOT>/yocto/meta-rviz2-agl ~/agl-workspace/meta-rviz2-agl

# 옵션 B: 복사 (배포 시)
cp -r <PROJECT_ROOT>/yocto/meta-rviz2-agl ~/agl-workspace/meta-rviz2-agl
```

---

## 레이어 클론 및 설정

### 1. 빌드 디렉토리 초기화

```bash
cd ~/agl-workspace
source poky/oe-init-build-env build
```

이 명령은 `build/` 디렉토리를 생성하고 빌드 환경 변수를 설정합니다.

### 2. bblayers.conf 설정

```bash
# 템플릿 복사
cp <PROJECT_ROOT>/yocto/bblayers.conf.sample build/conf/bblayers.conf

# 편집기로 <PROJECT_ROOT> 경로 수정
nano build/conf/bblayers.conf
```

레이어 경로를 실제 환경에 맞게 조정하세요:

```bitbake
BBLAYERS ?= " \
    ${TOPDIR}/../poky/meta \
    ${TOPDIR}/../poky/meta-poky \
    ${TOPDIR}/../meta-openembedded/meta-oe \
    ${TOPDIR}/../meta-openembedded/meta-python \
    ${TOPDIR}/../meta-openembedded/meta-networking \
    ${TOPDIR}/../meta-openembedded/meta-filesystems \
    ${TOPDIR}/../meta-agl/meta-agl-core \
    ${TOPDIR}/../meta-agl/meta-agl-bsp \
    ${TOPDIR}/../meta-flutter \
    ${TOPDIR}/../meta-qt5 \
    ${TOPDIR}/../meta-ros/meta-ros-common \
    ${TOPDIR}/../meta-ros/meta-ros2 \
    ${TOPDIR}/../meta-ros/meta-ros2-humble \
    ${TOPDIR}/../meta-rviz2-agl \
"
```

### 3. local.conf 설정

```bash
# 템플릿 복사
cp <PROJECT_ROOT>/yocto/local.conf.sample build/conf/local.conf

# 머신 및 병렬 빌드 설정 조정
nano build/conf/local.conf
```

핵심 설정 확인:

```bitbake
MACHINE ?= "qemux86-64"  # 타겟 하드웨어에 맞게 조정

# ROS2 Humble + Scarthgap
ROS_DISTRO = "humble"
ROS_OE_RELEASE_SERIES = "scarthgap"

# Wayland 활성화, X11 제거
DISTRO_FEATURES:append = " wayland opengl"
DISTRO_FEATURES:remove = "x11"

# Qt5 Wayland 백엔드
PACKAGECONFIG:pn-qtbase:append = " wayland gles2"
PACKAGECONFIG:pn-qtwayland:append = " wayland-egl"

# Qt5 런타임 추가 (Flutter 이미지에 없으므로 필수)
IMAGE_INSTALL:append = " qtbase qtwayland qtwayland-plugins "
```

---

## 빌드 실행

### 1. 기본 이미지 빌드

```bash
cd ~/agl-workspace/build

# Flutter 기반 AGL 이미지 빌드
bitbake agl-ivi-demo-flutter

# 또는 Qt 기반 이미지
# bitbake agl-ivi-demo
```

### 2. RViz2 개별 빌드 (Phase 2 이후)

```bash
# OGRE EGL 빌드 (R005 완료 후)
bitbake ogre

# RViz2 빌드 (R008 완료 후)
bitbake ros-humble-rviz2
```

### 3. 빌드 로그 확인

```bash
# 특정 레시피 빌드 로그 확인
bitbake -c compile -f ogre 2>&1 | tee ogre-build.log

# 에러 발생 시 상세 로그
bitbake ogre -c compile -v
```

---

## 검증 및 실행

### 1. QEMU 환경 실행

```bash
# QEMU x86_64 부팅
runqemu qemux86-64 kvm serial nographic

# 또는 그래픽 모드
runqemu qemux86-64 kvm
```

### 2. RViz2 실행

```bash
# AGL 이미지 부팅 후 (타겟 또는 QEMU)
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/run/user/1000
export QT_WAYLAND_SHELL_INTEGRATION=xdg-shell

# RViz2 실행
ros2 run rviz2 rviz2
```

### 3. 검증 체크리스트

- [ ] RViz2 프로세스가 segfault 없이 기동
- [ ] `wl_compositor` 인터페이스 바인딩 성공 로그 확인
- [ ] RViz2 윈도우가 agl-compositor 위에 표시
- [ ] 30초 이상 idle 유지 가능

---

## 문제 해결

### 이슈 1: meta-ros2-humble 빌드 실패 (gcc 13 오류)

**증상**: `undefined reference to...`, `no matching function...` 등의 컴파일 에러

**해결**:
```bash
# 오류 패키지 개별 빌드로 로그 확인
bitbake <package-name> -c compile -v

# Kirkstone 브랜치 레시피를 참고하여 패치 작성
# 또는 Jazzy 배포판으로 업그레이드 검토
```

### 이슈 2: OGRE Wayland window backend 미구현

**증상**: OGRE EGL context 생성 실패, segfault in `createRenderWindow`

**해결**:
- `OgreWaylandEGLSupport.cpp` / `OgreWaylandEGLWindow.cpp` 패치 적용 필요
- R005에서 상세 구현 예정
- 단기 대안: SDL2 backend 사용 (`SDL_VIDEODRIVER=wayland`)

### 이슈 3: Qt Wayland 플러그인 로드 실패

**증상**: `Could not load the Qt platform plugin "wayland"`

**해결**:
```bash
# qtwayland-plugins 설치 확인
opkg list-installed | grep qtwayland

# 환경변수 확인
echo $QT_QPA_PLATFORM
echo $XDG_RUNTIME_DIR

# 플러그인 경로 강제 지정
export QT_PLUGIN_PATH=/usr/lib/qt5/plugins
```

### 이슈 4: EGL display 초기화 실패

**증상**: `Failed to create EGL display` 또는 `eglInitialize failed`

**해결**:
```bash
# DRM 장치 권한 확인
ls -l /dev/dri/card0

# 사용자 video 그룹 추가
usermod -a -G video <username>

# Mesa 드라이버 확인
eglinfo
```

### 이슈 5: 이미지 크기 초과

**증상**: 빌드된 이미지가 타겟 플래시 용량을 초과

**해결**:
```bitbake
# local.conf에 추가 (불필요 패키지 제거)
INHERIT += "rm_work"
IMAGE_FEATURES:remove = "dev-pkgs dbg-pkgs"
EXTRA_IMAGE_FEATURES:remove = "tools-sdk"
```

---

## 참고 자료

- **AGL 공식 문서**: https://docs.automotivelinux.org/
- **meta-ros 저장소**: https://github.com/ros/meta-ros
- **분석 보고서**: `hmi/rviz_agl/planning/rviz_agl_wayland_porting_analysis.md`
- **Yocto Project 문서**: https://docs.yoctoproject.org/

---

## Phase별 작업 로드맵

| Phase | Feature ID | 작업 내용 | 산출물 |
|-------|-----------|----------|--------|
| **Phase 1** | R002-R003 | X11/XWayland 기준선 검증 | Docker 컨테이너 |
| **Phase 2** | R004-R007 | OGRE EGL + Qt Wayland + RViz2 패치 | bbappend 레시피 |
| **Phase 3** | R008-R009 | Yocto 통합 빌드 + x64 Wayland 테스트 | AGL 이미지 |
| **Phase 3+** | R010-R012 | arm64 크로스 컴파일 + QEMU 테스트 | arm64 바이너리 |
| **Phase 4** | R014 | 성능 측정 및 최적화 | 벤치마크 보고서 |

현재 상태: **R004 완료 (레이어 스캐폴딩)**

다음 단계: **R005 OGRE EGL+Wayland 빌드**

---

## 라이선스

이 레이어는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `COPYING.MIT` 파일을 참조하세요.

RViz2 및 ROS2 Humble 패키지는 Apache 2.0 및 BSD 라이선스가 적용됩니다.
