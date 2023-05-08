#!/bin/bash

set -e -x

ldd --version ldd

if [ ! -d "$SOURCE_DIR/llvm_miniconda" ]; then
  bash setup_python.sh
fi
export PATH=$SOURCE_DIR/llvm_miniconda/envs/mlir/bin:$PATH

Python3_EXECUTABLE="$SOURCE_DIR/llvm_miniconda/envs/mlir/bin/python3"
Python3_ROOT_DIR="$Python3_EXECUTABLE/../../"
echo $Python3_EXECUTABLE

pushd "$BUILD_DIR"

function sedinplace {
  if ! sed --version 2>&1 | grep -i gnu >/dev/null; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}
# prevent recursive NATIVE build
sedinplace 's/if(LLVM_USE_HOST_TOOLS)/if(0)/g' $SOURCE_DIR/llvm-project/llvm/cmake/modules/TableGen.cmake
sedinplace 's/if(LLVM_USE_HOST_TOOLS)/if(0)/g' $SOURCE_DIR/llvm-project/llvm/cmake/modules/AddLLVM.cmake
sedinplace 's/if(LLVM_USE_HOST_TOOLS)/if(0)/g' $SOURCE_DIR/llvm-project/llvm/CMakeLists.txt
sedinplace 's/if(LLVM_USE_HOST_TOOLS)/if(0)/g' $SOURCE_DIR/llvm-project/mlir/tools/mlir-linalg-ods-gen/CMakeLists.txt
sedinplace 's/if(CMAKE_CROSSCOMPILING AND NOT LLVM_CONFIG_PATH)/if(0)/g' $SOURCE_DIR/llvm-project/llvm/tools/llvm-config/CMakeLists.txt
sedinplace 's/if(CMAKE_CROSSCOMPILING)/if(0)/g' $SOURCE_DIR/llvm-project/llvm/tools/llvm-shlib/CMakeLists.txt
# prevent dep on clang for openmp
sedinplace 's/set(ENABLE_CHECK_TARGETS TRUE)//g' $SOURCE_DIR/llvm-project/openmp/cmake/OpenMPTesting.cmake
sedinplace 's/construct_check_openmp_target()//g' $SOURCE_DIR/llvm-project/openmp/CMakeLists.txt

sudo apt install -y clang ccache
export PATH="/usr/lib/ccache:/usr/local/opt/ccache/libexec:$PATH"

unset CMAKE_CONFIGS
CMAKE_CONFIGS="\
  -GNinja \
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
  -DGENERATOR_IS_MULTI_CONFIG=TRUE \
  \
  -DLLVM_ENABLE_RTTI=ON \
  \
  -DCMAKE_CROSSCOMPILING=False \
  -DMLIR_BUILD_MLIR_C_DYLIB=1 \
  -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
  -DMLIR_ENABLE_EXECUTION_ENGINE=ON \
  -DLLVM_BUILD_UTILS=ON \
  -DLLVM_INCLUDE_UTILS=ON \
  -DLLVM_BUILD_TOOLS=ON \
  -DLLVM_INCLUDE_TOOLS=ON \
  -DLLVM_INSTALL_UTILS=ON \
  -DLLVM_HOST_TRIPLE=aarch64-linux-gnueabihf \
  -DLLVM_DEFAULT_TARGET_TRIPLE=aarch64-linux-gnueabihf \
  -DLLVM_ENABLE_PROJECTS=llvm;mlir;openmp;compiler-rt \
  \
  -DENABLE_CHECK_TARGETS=OFF \
  -DOPENMP_ENABLE_LIBOMPTARGET=OFF \
  -DLIBOMP_OMPD_GDB_SUPPORT=OFF \
  -DLIBOMP_USE_QUAD_PRECISION=False \
  \
  -DCMAKE_INSTALL_PREFIX=$BUILD_DIR/LLVM_INSTALL \
  -DLLVM_TARGET_ARCH=AArch64 \
  -DLLVM_TARGETS_TO_BUILD=AArch64 \
  -DPython3_FIND_STRATEGY=LOCATION \
  -DPython3_ROOT_DIR=$Python3_ROOT_DIR"

echo $CMAKE_CONFIGS

ls -l $TABGEN_BUILDIR/bin
$TABGEN_BUILDIR/bin/llvm-tblgen --version

cmake "$SOURCE_DIR/llvm-project/llvm" \
    $CMAKE_CONFIGS \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_TABLEGEN="$TABGEN_BUILDIR/bin/llvm-tblgen" \
    -DMLIR_TABLEGEN="$TABGEN_BUILDIR/bin/mlir-tblgen" \
    -DMLIR_LINALG_ODS_YAML_GEN="$TABGEN_BUILDIR/bin/mlir-linalg-ods-yaml-gen" \
    -DMLIR_LINALG_ODS_YAML_GEN_EXE="$TABGEN_BUILDIR/bin/mlir-linalg-ods-yaml-gen" \
    -DCLANG_TABLEGEN="$TABGEN_BUILDIR/bin/clang-tblgen" \
    -DMLIR_PDLL_TABLEGEN="$TABGEN_BUILDIR/bin/mlir-pdll"

ninja install -j $NUM_JOBS

popd
