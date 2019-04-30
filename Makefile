# -*- GNUMakefile -*-
  
# Requirements:
#  /bin/bash as SHELL

export SHELL = /bin/bash

C_COMPILER="clang-5.0"
COMPILER="clang++-5.0"
MAKEOPTS="-j9"

all:    world

# A lot of implicit dependences, configurations, etc. Don't do it in parallel here!

.NOTPARALLEL:

.PHONY: world

world: \
.build-llvm \
.build-rpclib \
.build-eigen \
.build-airsim \
.build-plugin

# -- eigen

.PHONY: .build-eigen


AirSim/AirLib/deps/eigen3: AirSim
	-[ ! -d $@ ] && mkdir -p $@

AirSim/AirLib/deps/eigen3/Eigen: eigen | AirSim/AirLib/deps/eigen3
	cp -r eigen/Eigen AirSim/AirLib/deps/eigen3

.build-eigen: AirSim/AirLib/deps/eigen3/Eigen

# --- rpclib

.PHONY: .build-rpclib

AirSim/external/rpclib: AirSim
	-[ ! -d $@ ] && mkdir -p $@

AirSim/external/rpclib/rpclib-2.2.1: rpclib | AirSim/external/rpclib
	ln -rs $< $@

.build-rpclib: AirSim/external/rpclib/rpclib-2.2.1

# --- llvm

.PHONY: .build-llvm

llvm/projects/libcxx:	libcxx
	ln -rs $< $@

llvm/projects/libcxxabi:	libcxxabi
	ln -rs $< $@

build/llvm:	| build	llvm/projects/libcxx llvm/projects/libcxxabi
	mkdir $@

build/llvm/Makefile:	| build/llvm
	(cd build/llvm && \
	cmake \
	-DCMAKE_C_COMPILER=${C_COMPILER} \
	-DCMAKE_CXX_COMPILER=${COMPILER} \
	-LIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
	-DLIBCXX_INSTALL_EXPERIMENTAL_LIBRARY=OFF \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DCMAKE_INSTALL_PREFIX=./output ../../llvm \
	)

.build-llvm: build/llvm/Makefile
	make -C build/llvm VERBOSE=1 ${MAKEOPTS} cxx
	make -C build/llvm VERBOSE=1 ${MAKEOPTS} install-libcxx
	make -C build/llvm VERBOSE=1 ${MAKEOPTS} install-libcxxabi
	mkdir -p AirSim/llvm-build/output/include/c++
	-[ ! -L AirSim/llvm-build/output/include/c++/v1 ] && ln -rs build/llvm/output/include/c++/v1 AirSim/llvm-build/output/include/c++/

clean::
	-[ -d "build/llvm" ] && rm -rf build/llvm

# --- airsim

.PHONY: .build-airsim

build/airsim:       | build
	mkdir $@

build/airsim/Makefile:      | build/airsim
	(cd build/airsim && \
	CC="clang-5.0" \
	CXX="clang++-5.0" \
	cmake -G "Unix Makefiles" \
	-DCMAKE_CXX_FLAGS="-I${CURDIR}/eigen/ -I${CURDIR}/rpclib/include/ -stdlib=libc++" \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DCMAKE_BUILD_TYPE=Debug \
	../../AirSim/cmake \
	)

.build-airsim:    .build-llvm build/airsim/Makefile 
	make -C build/airsim VERBOSE=1 ${MAKEOPTS}

clean::
	-[ -d "build/airsim" ] && rm -rf build/airsim

# --- plugin

.PHONY: .build-plugin

.build-plugin: .build-airsim
	mkdir -p AirSim/AirLib/lib/x64/Debug
	mkdir -p AirSim/AirLib/deps/rpclib/lib
	mkdir -p AirSim/AirLib/deps/MavLinkCom/lib
	cp build/airsim/output/lib/libAirLib.a AirSim/AirLib/lib
	cp build/airsim/output/lib/libMavLinkCom.a AirSim/AirLib/deps/MavLinkCom/lib
	cp build/airsim/output/lib/librpc.a AirSim/AirLib/deps/rpclib/lib/librpc.a
	rsync -a --delete build/airsim/output/lib/ AirSim/AirLib/lib/x64/Debug
	rsync -a --delete AirSim/external/rpclib/rpclib-2.2.1/include AirSim/AirLib/deps/rpclib
	rsync -a --delete AirSim/MavLinkCom/include AirSim/AirLib/deps/MavLinkCom
	rsync -aLK --delete AirSim/AirLib AirSim/Unreal/Plugins/AirSim/Source
	AirSim/Unreal/Environments/Blocks/clean.sh
	mkdir -p AirSim/Unreal/Environments/Blocks/Plugins
	rsync -a --delete AirSim/Unreal/Plugins/AirSim AirSim/Unreal/Environments/Blocks/Plugins

# mono UnrealEngine/Engine/Binaries/DotNET/UnrealBuildTool.exe Blocks Development Linux -project="AirSim/Unreal/Environments/Blocks/Blocks.uproject" -editorrecompile -progress -verbose -NoHotReloadFromIDE
