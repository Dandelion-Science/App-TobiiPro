cmake_minimum_required(VERSION 3.16)
project(TobiiPro
	LANGUAGES CXX
	VERSION 1.13.0)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
find_package(tobii_research REQUIRED)

# Find an installed liblsl in paths set by the user (LSL_INSTALL_ROOT)
# and some default paths
find_package(LSL REQUIRED
	HINTS ${LSL_INSTALL_ROOT}
	"${CMAKE_CURRENT_LIST_DIR}/../../LSL/liblsl/build/"
	"${CMAKE_CURRENT_LIST_DIR}/../../LSL/liblsl/out/build/x64-Release"
	PATH_SUFFIXES share/LSL)
get_filename_component(LSL_PATH ${LSL_CONFIG} DIRECTORY)
message(STATUS "Found LSL lib in ${LSL_PATH}")

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)
# Qt6: liblsl >= 1.16's LSL_deploy_qt() expects Qt6::qmake, so Qt5 was the
# mismatched half. Qt6 also requires C++17 (see cxx_std_17 below).
find_package(Qt6 REQUIRED COMPONENTS Widgets)

find_package(Threads REQUIRED)

include(GNUInstallDirs)

# The app rewrites TobiiPro.cfg relative to the working directory, so a launcher
# has to cd here (the .desktop entry below uses Path=).
set(TOBIIPRO_DATADIR "${CMAKE_INSTALL_DATADIR}/${PROJECT_NAME}" CACHE STRING
	"Where TobiiPro.cfg and the logo are installed, relative to the prefix")

# Off: the SDK is proprietary and GPLv3 forbids conveying it with a GPL binary.
option(TOBIIPRO_BUNDLE_SDK
	"Install libtobii_research.so alongside the binary" OFF)

get_filename_component(TOBIIPRO_LIBRARY_DIR ${TOBIIPRO_LIBRARY} DIRECTORY)

# Must precede the targets: CMAKE_INSTALL_RPATH is read into INSTALL_RPATH at
# add_executable() time. Pinning the SDK path here rather than leaving it to
# LD_LIBRARY_PATH is what stops a different build of libtobii_research.so — which
# loads without error and streams wrong gaze — from being picked up.
if(UNIX AND NOT APPLE)
	if(TOBIIPRO_BUNDLE_SDK)
		set(CMAKE_INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")
	else()
		set(CMAKE_INSTALL_RPATH "${TOBIIPRO_LIBRARY_DIR}")
	endif()
endif()

add_executable(${PROJECT_NAME} MACOSX_BUNDLE WIN32
	main.cpp
	mainwindow.cpp
	mainwindow.h
	mainwindow.ui
	TobiiLib.h
	tobiilogo.qrc
)

add_executable(tobiisynctest tobiisynctest.cpp)
target_link_libraries(tobiisynctest TobiiPro::tobii_research)
add_executable(tobiifinder tobiifinder.cpp)
target_link_libraries(tobiifinder TobiiPro::tobii_research)

target_link_libraries(${PROJECT_NAME}
	PRIVATE
	Qt6::Widgets
	Threads::Threads
	LSL::lsl
	TobiiPro::tobii_research
)
target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
target_compile_features(tobiisynctest PUBLIC cxx_std_17)

# Plain install() rules: liblsl 1.17 deprecates installLSLApp/installLSLAuxFiles,
# and the latter globbed libtobii_research.so* into the install tree.
install(TARGETS ${PROJECT_NAME} tobiifinder
	RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
	BUNDLE DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(FILES
	${PROJECT_NAME}.cfg
	tobiilogo.svg
	LICENSE.txt
	DESTINATION ${TOBIIPRO_DATADIR}
)

if(TOBIIPRO_BUNDLE_SDK)
	file(GLOB TOBIIPRO_SDK_LIBS "${TOBIIPRO_LIBRARY_DIR}/libtobii_research.so*")
	install(FILES ${TOBIIPRO_SDK_LIBS} DESTINATION ${CMAKE_INSTALL_LIBDIR})
endif()

# Opt-in, since these write to /usr rather than the prefix: `make install-system`.
if(UNIX AND NOT APPLE)
	option(TOBIIPRO_DESKTOP_INTEGRATION
		"Install the .desktop entry and icon into system directories" OFF)
	set(TOBIIPRO_DESKTOP_PREFIX "/usr" CACHE PATH
		"Prefix for the .desktop entry and icon")
	set(TOBIIPRO_EXEC_PATH
		"${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}/${PROJECT_NAME}"
		CACHE STRING "Exec= line of the .desktop entry")

	if(TOBIIPRO_DESKTOP_INTEGRATION)
		set(TOBIIPRO_WORKING_DIR "${CMAKE_INSTALL_PREFIX}/${TOBIIPRO_DATADIR}")
		configure_file(
			${CMAKE_CURRENT_LIST_DIR}/packaging/linux/tobii-lsl.desktop.in
			${CMAKE_CURRENT_BINARY_DIR}/tobii-lsl.desktop @ONLY)
		install(FILES ${CMAKE_CURRENT_BINARY_DIR}/tobii-lsl.desktop
			DESTINATION ${TOBIIPRO_DESKTOP_PREFIX}/share/applications)
		install(FILES ${CMAKE_CURRENT_LIST_DIR}/packaging/linux/tobii-lsl-512.png
			DESTINATION ${TOBIIPRO_DESKTOP_PREFIX}/share/icons/hicolor/512x512/apps
			RENAME tobii-lsl.png)
	endif()
endif()
