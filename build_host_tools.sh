#!/usr/bin/env bash
set -xe

export STATIC_FLAGS="-static-libgcc -static-libstdc++"
export GENERATOR=Ninja

LLVM_PROJECT_MAIN_SRC_DIR=/work/llvm-project
LLVM_PROJECT_MAIN_BINARY_DIR=/work/build
LLVM_PROJECT_HOST_MAIN_BINARY_DIR=/work/build_host


export AS=
export AR=
export CMAKE_TOOLCHAIN_FILE=
export LD_LIBRARY_PATH=/opt/rh/devtoolset-10/root/usr/lib64:/opt/rh/devtoolset-10/root/usr/lib:/opt/rh/devtoolset-10/root/usr/lib64/dyninst:/opt/rh/devtoolset-10/root/usr/lib/dyninst:/usr/local/lib64
export CPP=
export PATH=/opt/rh/devtoolset-10/root/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD=
export STRIP=
export CROSS_TRIPLE=
export CXX=
export OBJCOPY=
export AUDITWHEEL_ARCH=aarch64
export FC=
export AUDITWHEEL_PLAT=manylinux2014_aarch64
export PKG_CONFIG_PATH=
export CROSS_ROOT=
export ARCH=
export CC=
export CROSS_COMPILE=
export AUDITWHEEL_POLICY=manylinux2014
export DEFAULT_DOCKCROSS_IMAGE=dockcross/manylinux2014-aarch64:20230809-85db345

cmake \
    -G "$GENERATOR" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER=/opt/rh/devtoolset-10/root/usr/bin/g++ \
    -DCMAKE_CXX_FLAGS="-O2 ${STATIC_FLAGS}" \
    -DCMAKE_C_COMPILER=/opt/rh/devtoolset-10/root/usr/bin/gcc \
    -DLLVM_ENABLE_PROJECTS=mlir \
    -DLLVM_ENABLE_TERMINFO=OFF \
    -DLLVM_ENABLE_ZLIB=OFF \
    -DLLVM_ENABLE_ZSTD=OFF \
    -DLLVM_TARGETS_TO_BUILD=X86 \
    -S${LLVM_PROJECT_MAIN_SRC_DIR}/llvm \
    -B${LLVM_PROJECT_HOST_MAIN_BINARY_DIR}

cmake --build ${LLVM_PROJECT_HOST_MAIN_BINARY_DIR} \
    --target llvm-tblgen mlir-tblgen mlir-linalg-ods-yaml-gen mlir-pdll -j