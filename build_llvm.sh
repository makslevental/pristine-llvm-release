#!/bin/bash

set -e -x

function tmpdir() {
  # Create a temporary build directory
  BUILD_DIR="$(mktemp -d)"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  echo "$BUILD_DIR"
}

function sedinplace {
  if ! sed --version 2>&1 | grep -i gnu >/dev/null; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

usage() {
  echo "Usage: bash build_llvm.sh -o INSTALL_PREFIX -p PLATFORM -c CONFIG [-j NUM_JOBS]"
  echo "Ex: bash build_llvm.sh -o llvm-14.0.0-x86_64-linux-gnu-ubuntu-20.04 -p docker_ubuntu_20.04 -c assert -j 16"
  echo "INSTALL_PREFIX = <string> # \${INSTALL_PREFIX}.tar.xz is created"
  echo "PLATFORM       = {local|docker_ubuntu_20.04}"
  echo "CONFIG         = {release|assert|debug}"
  echo "NUM_JOBS       = {1|2|3|...}"
  exit 1
}


# Parse arguments
build_config="release"
num_jobs=16
while getopts "a:o:p:c:v:j:p:s:" arg; do
  case "$arg" in
  a)
    arch="$OPTARG"
    ;;
  c)
    build_config="$OPTARG"
    ;;
  v)
    py_version="$OPTARG"
    ;;
  j)
    num_jobs="$OPTARG"
    ;;
  p)
    platform="$OPTARG"
    ;;
  *)
    usage
    ;;
  esac
done

function sedinplace {
  if ! sed --version 2>&1 | grep -i gnu >/dev/null; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

export ARCH=$arch
export BUILD_CONFIG=$build_config
export PY_VERSION=$py_version
export NUM_JOBS=$num_jobs
export PLATFORM=$platform

CURRENT_DIR="$(pwd)"

SOURCE_DIR="$CURRENT_DIR"
export SOURCE_DIR
# prevent dep on clang for open mp
sedinplace 's/construct_check_openmp_target()//g' "$SOURCE_DIR/llvm-project/openmp/CMakeLists.txt"
sedinplace 's/set(ENABLE_CHECK_TARGETS TRUE)//g' $SOURCE_DIR/llvm-project/openmp/cmake/OpenMPTesting.cmake
sedinplace 's/extern "C"/extern "C" __attribute__((visibility("default")))/g' $SOURCE_DIR/llvm-project/mlir/lib/ExecutionEngine/AsyncRuntime.cpp

mkdir -p tblgen_build
TABGEN_BUILDIR=$SOURCE_DIR/tblgen_build
export TABGEN_BUILDIR

mkdir -p build
BUILD_DIR=$(pwd)/build
export BUILD_DIR

mkdir -p $BUILD_DIR/LLVM_INSTALL
LLVM_INSTALL=$SOURCE_DIR/llvm_install
mkdir -p $LLVM_INSTALL
export LLVM_INSTALL

# Set up CMake configurations
CMAKE_CONFIGS="\
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DLLVM_BUILD_TESTS=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_BUILD_EXAMPLES=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_BUILD_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  \
  -DLLVM_BUILD_RUNTIMES=OFF \
  -DLLVM_INCLUDE_RUNTIMES=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  \
  -DLLVM_ENABLE_PROJECTS=llvm;mlir;openmp;compiler-rt \
  \
  -DENABLE_CHECK_TARGETS=OFF \
  -DOPENMP_ENABLE_LIBOMPTARGET=OFF \
  -DLIBOMP_OMPD_GDB_SUPPORT=OFF \
  -DLIBOMP_USE_QUAD_PRECISION=False \
  \
  -DLLVM_ENABLE_RTTI=ON \
  -DLLVM_BUILD_UTILS=ON \
  -DLLVM_INCLUDE_UTILS=ON \
  -DLLVM_INSTALL_UTILS=ON \
  -DLLVM_BUILD_TOOLS=ON \
  -DLLVM_INCLUDE_TOOLS=ON \
  -DMLIR_BUILD_MLIR_C_DYLIB=1 \
  -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
  -DMLIR_ENABLE_EXECUTION_ENGINE=ON \
  -DCMAKE_INSTALL_PREFIX=$BUILD_DIR/LLVM_INSTALL"

if [ x"$BUILD_CONFIG" == x"release" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=Release"
elif [ x"$BUILD_CONFIG" == x"assert" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=MinSizeRel -DLLVM_ENABLE_ASSERTIONS=True"
elif [ x"$BUILD_CONFIG" == x"debug" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_ASSERTIONS=True"
elif [ x"$BUILD_CONFIG" == x"relwithdeb" ]; then
  CMAKE_CONFIGS="${CMAKE_CONFIGS} -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLLVM_ENABLE_ASSERTIONS=True"
fi

ls -l $SOURCE_DIR/llvm-project/

if [ ! -d "$TABGEN_BUILDIR/bin" ]; then
  bash build_tblgen.sh
fi

if [ x"$ARCH" == x"arm64" ] && [ x"$PLATFORM" == x"ubuntu-latest" ]; then
  bash $SOURCE_DIR/build_in_docker.sh -d dockcross/linux-arm64-lts -e /work/build_linux_arm64.sh
else
  pushd "$BUILD_DIR"
  Python3_ROOT_DIR="$(which python)/../../"
  if [ x"$ARCH" == x"arm64" ] && [ x"$PLATFORM" == x"macos-latest" ]; then
    export MACOSX_DEPLOYMENT_TARGET="12.0"
    cmake "$SOURCE_DIR/llvm-project/llvm" \
      $CMAKE_CONFIGS \
      -DLLVM_TARGET_ARCH=AArch64 \
      -DLLVM_TARGETS_TO_BUILD=AArch64 \
      -DCMAKE_SYSTEM_NAME=Darwin \
      -DLLVM_DEFAULT_TARGET_TRIPLE="arm64-apple-darwin21.6.0" \
      -DLLVM_HOST_TRIPLE="arm64-apple-darwin21.6.0" \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DCMAKE_CXX_FLAGS='-target arm64-apple-macos -mcpu=apple-m1' \
      -DCMAKE_C_FLAGS='-target arm64-apple-macos -mcpu=apple-m1' \
      -DCMAKE_EXE_LINKER_FLAGS='-arch arm64' \
      -DLLVM_NATIVE_TOOL_DIR="$TABGEN_BUILDIR/bin" \
      -DPython3_FIND_STRATEGY=LOCATION \
      -DPython3_ROOT_DIR="$Python3_ROOT_DIR"
  elif [ x"$ARCH" == x"x86_64" ]; then
    cmake "$SOURCE_DIR/llvm-project/llvm" \
      $CMAKE_CONFIGS \
      -DLLVM_TARGETS_TO_BUILD="X86" \
      -DPython3_FIND_STRATEGY=LOCATION \
      -DPython3_ROOT_DIR="$Python3_ROOT_DIR"
  fi

  make install -j $NUM_JOBS
  popd
fi

if [ x"$PLATFORM" == x"ubuntu-latest" ]; then
  R=r
else
  R=R
fi

cp -L -$R $BUILD_DIR/LLVM_INSTALL/* $LLVM_INSTALL

echo "Completed!"