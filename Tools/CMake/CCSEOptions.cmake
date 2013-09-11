# -*- mode: cmake -*-
#
# Set up defines necessary to build BoxLib-based code

if(__CCSE_OPTIONS_INCLUDED)
  return()
endif()
set(__CCSE_OPTIONS_INCLUDED)

enable_language(C)
enable_language(CXX)
enable_language(Fortran)

# No idea why we need this.
# I think it was required for Franklin build. -- lpritch
if(PREFER_STATIC_LIBRARIES)
  # Prefer static libraries, but don't require that everything must be static. 
  # This appears to be necessary on Franklin at NERSC right now.  --RTM
  set(CMAKE_FIND_LIBRARY_SUFFIXES .a .lib)
endif(PREFER_STATIC_LIBRARIES)

if(BUILD_STATIC_EXECUTABLES)
    set(CMAKE_EXE_LINKER_FLAGS -static)
    set(CMAKE_FIND_LIBRARY_SUFFIXES .a)
    set(CMAKE_EXE_LINK_DYNAMIC_C_FLAGS)       # remove -Wl,-Bdynamic
    set(CMAKE_EXE_LINK_DYNAMIC_CXX_FLAGS)
    set(CMAKE_SHARED_LIBRARY_C_FLAGS)         # remove -fPIC
    set(CMAKE_SHARED_LIBRARY_CXX_FLAGS)
    set(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS)    # remove -rdynamic
    set(CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS)
endif(BUILD_STATIC_EXECUTABLES)

set(cat_exec "cat")
if (WIN32)
    if( NOT UNIX)
        set(cat_exec "type")
    endif(NOT UNIX)
endif(WIN32)

execute_process(COMMAND "${cat_exec}" "${CCSE_ROOT_DIR}/BoxLib_Version.txt"
                OUTPUT_VARIABLE CCSE_VERSION
                ERROR_VARIABLE  _stderr
                OUTPUT_STRIP_TRAILING_WHITESPACE)

# Testing
include(CMakeDependentOption)
cmake_dependent_option(ENABLE_TESTS "Enable unit testing" ON
                       "ENABLE_UnitTest" ON)
if (ENABLE_TESTS)
    set(BUILD_TESTS 1)
endif()    

include(FortranCInterface)
include(${FortranCInterface_BINARY_DIR}/Output.cmake)

message(STATUS "BoxLib-specific compile settings:")
if(FortranCInterface_GLOBAL_SUFFIX STREQUAL ""  AND FortranCInterface_GLOBAL_CASE STREQUAL "UPPER")
    message(STATUS "   Fortran name mangling scheme to UPPERCASE (upper case, no append underscore)")
    set(BL_FORTLINK UPPERCASE)
elseif(FortranCInterface_GLOBAL_SUFFIX STREQUAL ""  AND FortranCInterface_GLOBAL_CASE STREQUAL "LOWER")
    message(STATUS "   Fortran name mangling scheme to LOWERCASE (lower case, no append underscore)")
    set(BL_FORTLINK LOWERCASE)
elseif(FortranCInterface_GLOBAL_SUFFIX STREQUAL "_" AND FortranCInterface_GLOBAL_CASE STREQUAL "LOWER")
    message(STATUS "   Fortran name mangling scheme to UNDERSCORE (lower case, append underscore)")
    set(BL_FORTLINK "UNDERSCORE")
else()
    message(AUTHOR_WARNING "Fortran to C mangling not backward compatible with older style BoxLib code") 
endif()


set(BL_MACHINE ${CMAKE_SYSTEM_NAME})


if ("${CMAKE_BUILD_TYPE}" STREQUAL "Release")
  set(BL_DEBUG 0)
else()
  set(BL_DEBUG 1)
endif()

if (BL_DEBUG)
  list(APPEND BL_DEFINES BL_USE_MPI)
endif()

# Here is a list of BL_ defines floating around in the code that probably should be 
# explicitly set by the user for the build.  They are left here as TODO, in case some
# systematic approach is discovered for doing this.  For the moment, the only ones
# treated are ones that are known to give problems if not set
#

# BL_USE_ARRAYVIEW
# BL_USE_SETBUF
# BL_USE_NEWPLOTPER
# BL_FIX_GATHERV_ERROR
# BL_SYNC_RANTABLES
# BL_COALESCE_FABS
# BL_NO_FORT
# BL_SETBUF_SIGNED_CHAR
# BL_USE_FORT_STAR_PRECISION
# BL_FIXHEADERDENORMS
# BL_VISMF_MSGCHECK
# BL_ALWAYS_FIX_DENORMALS
# BL_NOLINEVALUES
# BL_PROF_NOT_REG
# BL_CWD_SIZE
# _BL_ANSI_TIME

set(BL_SPACEDIM 3)
set(BL_PRECISION "DOUBLE")
set(BL_USE_PARTICLES 1)
set(ENABLE_PROFILING 0)
set(ENABLE_BACKTRACE 0)

message(STATUS "   BL_SPACEDIM = ${BL_SPACEDIM} (1,2,3)")
message(STATUS "   BL_MACHINE = ${BL_MACHINE} (<ARCH>)")
message(STATUS "   BL_PRECISION = ${BL_PRECISION} (FLOAT, DOUBLE)")
message(STATUS "   ENABLE_MPI = ${ENABLE_MPI} (0,1)")
message(STATUS "   ENABLE_OpenMP = ${ENABLE_OpenMP} (0,1)")
message(STATUS "   BL_DEBUG = ${BL_DEBUG} (0,1)")
message(STATUS "   BL_USE_PARTICLES = ${BL_USE_PARTICLES} (0,1)")
message(STATUS "   ENABLE_BACKTRACE = ${ENABLE_BACKTRACE} (0,1)")
message(STATUS "   ENABLE_PROFILING = ${ENABLE_PROFILING} (0,1)")

set(BL_DEFINES "BL_NOLINEVALUES;BL_PARALLEL_IO;BL_SPACEDIM=${BL_SPACEDIM};BL_FORT_USE_${BL_FORTLINK};BL_${BL_MACHINE};BL_USE_${BL_PRECISION}")

if (BL_USE_PARTICLES)
  list(APPEND BL_DEFINES BL_USE_PARTICLES)
endif (BL_USE_PARTICLES)

if (ENABLE_PROFILING)
  list(APPEND BL_DEFINES BL_PROFILING)
endif (ENABLE_PROFILING)

if (ENABLE_COMM_PROFILING)
  list(APPEND BL_DEFINES BL_COMM_PROFILING)
endif (ENABLE_COMM_PROFILING)




set(BOXLIB_EXTRA_LIBRARIES)
set(BOXLIB_EXTRA_LIBRARY_PATH)
set(BOXLIB_EXTRA_C_INCLUDE_PATH)
set(BOXLIB_EXTRA_CXX_INCLUDE_PATH)
set(BOXLIB_EXTRA_Fortran_INCLUDE_PATH)

if (ENABLE_MPI)
  list(APPEND BL_DEFINES BL_USE_MPI)
  find_package(MPI REQUIRED)
  list(APPEND BOXLIB_EXTRA_Fortran_INCLUDE_PATH "${MPI_Fortran_INCLUDE_PATH}")
  list(APPEND BOXLIB_EXTRA_C_INCLUDE_PATH "${MPI_CXX_INCLUDE_PATH}")
  list(APPEND BOXLIB_EXTRA_CXX_INCLUDE_PATH "${MPI_CXX_INCLUDE_PATH}")
  list(APPEND CMAKE_CC_FLAGS "${MPI_C_FLAGS}")
  list(APPEND CMAKE_CXX_FLAGS "${MPI_CXX_FLAGS}")
  list(APPEND CMAKE_Fortran_FLAGS "${MPI_Fortran_FLAGS}")
endif()

if (ENABLE_OpenMP)
  set(ENABLE_OMP TRUE)
  list(APPEND BL_DEFINES BL_USE_OMP)
  find_package(OpenMP REQUIRED)
  list(APPEND CMAKE_CC_FLAGS "${OpenMP_C_FLAGS}")
  list(APPEND CMAKE_CXX_FLAGS "${OpenMP_CXX_FLAGS}")
endif()

if (NOT BL_DEBUG)
  list(APPEND BL_DEFINES NDEBUG)
endif()

set_directory_properties(PROPERTIES COMPILE_DEFINITIONS "${BL_DEFINES}")

if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
  list(APPEND CMAKE_CXX_FLAGS "-ftemplate-depth-64 -Wno-deprecated")
endif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
