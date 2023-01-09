#! /bin/bash

################################################################################
# Prepare
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -e                          # Abort on errors



################################################################################
# Search
################################################################################

if [ -z "${OPENSSL_DIR}" ]; then
    echo "BEGIN MESSAGE"
    echo "OpenSSL selected, but OPENSSL_DIR not set. Checking some places..."
    echo "END MESSAGE"
    
    DIRS="/usr /usr/local /opt/local /usr/local/packages usr/local/apps /opt/local /opt/homebrew ${HOME} c:/packages/"
    # look into each directory
    for dir in $DIRS; do
        # libraries might have different file extensions
        for libext in a dll dll.a dylib so; do
            # libraries can be in /lib or /lib64
            for libdir in lib64 lib/x86_64-linux-gnu lib/ia64-linux-gnu lib/i386-linux-gnu lib/arm-linux-gnueabihf lib; do
                FILES="include/openssl/ssl.h $libdir/libssl.${libext} $libdir/libcrypto.${libext}"
                # assume this is the one and check all needed files
                OPENSSL_DIR="$dir"
                for file in $FILES; do
                    # discard this directory if one file was not found
                    if [ ! -r "$dir/$file" ]; then
                        unset OPENSSL_DIR
                        break
                    fi
                done
                # don't look further if all files have been found
                if [ -n "$OPENSSL_DIR" ]; then
                    break
                fi
            done
           # don't look further if all files have been found
            if [ -n "$OPENSSL_DIR" ]; then
                break
            fi
        done
        # don't look further if all files have been found
        if [ -n "$OPENSSL_DIR" ]; then
            break
        fi
    done
    
    if [ -z "$OPENSSL_DIR" ]; then
        echo "BEGIN MESSAGE"
        echo "OpenSSL not found"
        echo "END MESSAGE"
    else
        echo "BEGIN MESSAGE"
        echo "Found OpenSSL in ${OPENSSL_DIR}"
        echo "END MESSAGE"
    fi
fi


################################################################################
# Build
################################################################################

if [ -z "${OPENSSL_DIR}"                                                \
     -o "$(echo "${OPENSSL_DIR}" | tr '[a-z]' '[A-Z]')" = 'BUILD' ]
then
    echo "BEGIN MESSAGE"
    echo "Using bundled OpenSSL..."
    echo "END MESSAGE"
    
    # check for required tools. Do this here so that we don't require them when
    # using the system library
    if [ x$TAR = x ] ; then
      echo 'BEGIN ERROR'
      echo 'Could not find tar command. Please make sure that (gnu) tar is present'
      echo 'and that the TAR variable is set to its location.'
      echo 'END ERROR'
      exit 1
    fi
    if [ x$PATCH = x ] ; then
      echo 'BEGIN ERROR'
      echo 'Could not find patch command. Please make sure that (gnu) tar is present'
      echo 'and that the PATCH variable is set to its location.'
      echo 'END ERROR'
      exit 1
    fi

    # Set locations
    THORN=OpenSSL
    NAME=openssl-1.1.1s
    SRCDIR="$(dirname $0)"
    BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
    if [ -z "${OPENSSL_INSTALL_DIR}" ]; then
        INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
    else
        echo "BEGIN MESSAGE"
        echo "Installing OpenSSL into ${OPENSSL_INSTALL_DIR}"
        echo "END MESSAGE"
        INSTALL_DIR=${OPENSSL_INSTALL_DIR}
    fi
    DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
    OPENSSL_DIR=${INSTALL_DIR}

    if [ -e ${DONE_FILE} -a ${DONE_FILE} -nt ${SRCDIR}/dist/${NAME}.tar.gz \
                         -a ${DONE_FILE} -nt ${SRCDIR}/configure.sh ]
    then
        echo "BEGIN MESSAGE"
        echo "OpenSSL has already been built; doing nothing"
        echo "END MESSAGE"
    else
        echo "BEGIN MESSAGE"
        echo "Building OpenSSL"
        echo "END MESSAGE"
        
        # Build in a subshell
        (
        exec >&2                # Redirect stdout to stderr
        if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
            set -x              # Output commands
        fi
        set -e                  # Abort on errors
        cd ${SCRATCH_BUILD}
        
        # Set up environment
        unset EXE
        unset LIBS
        unset MAKEFLAGS # For some reason, OpenSSL does not compile with this
        unset options # OpenSSL's 'config' script uses $options itself
        # OpenSSL doesn't want to link with -fopenmp (can't pass
        # LDFLAGS?), so instead we remove all OpenMP flags
        export CPPFLAGS="$(echo '' $CPPFLAGS | sed -e 's/-f\?openmp//')"
        export CFLAGS="$(echo '' $CFLAGS | sed -e 's/-f\?openmp//')"
        export LDFLAGS="$(echo '' $LDFLAGS | sed -e 's/-f\?openmp//')"
        # OpenSSL does not automatically build a 64bit version on 64bit Macs
        # setting KERNEL_BITS=64 tells it we want one
        if uname -v | grep >/dev/null '^Darwin.*RELEASE_X86_64' ; then
          export KERNEL_BITS=64
        fi
        
        echo "OpenSSL: Preparing directory structure..."
        mkdir build external done 2> /dev/null || true
        rm -rf ${BUILD_DIR} ${INSTALL_DIR}
        mkdir ${BUILD_DIR} ${INSTALL_DIR}
        
        echo "OpenSSL: Unpacking archive..."
        pushd ${BUILD_DIR}
        ${TAR?} xzf ${SRCDIR}/dist/${NAME}.tar.gz

        cd ${NAME}
        ${PATCH?} -p1 < ${SRCDIR}/dist/patchtest.patch
        if [ ! -e .patch_tmp ]; then
            echo 'BEGIN ERROR'
            echo 'The version of patch is too old to understand this patch format.'
            echo 'Please set the PATCH environment variable to a more recent '
            echo 'version of the patch command.'
            echo 'END ERROR'
            exit 1
        fi
        rm -f .patch_tmp
        # ${PATCH?} -p1 < ${SRCDIR}/dist/openssl-1.0.1f-fix_pod_syntax-1.patch
        # # Some (ancient but still used) versions of patch don't support the
        # # patch format used here but also don't report an error using the
        # # exit code. So we use this patch to test for this
        
        echo "OpenSSL: Configuring..."
        ./config --prefix=${OPENSSL_DIR} no-shared
        
        echo "OpenSSL: Building..."
        ${MAKE}
        
        echo "OpenSSL: Installing..."
        ${MAKE} install
        popd
        
        echo "OpenSSL: Cleaning up..."
        rm -rf ${BUILD_DIR}
        
        date > ${DONE_FILE}
        echo "OpenSSL: Done."
        )
        
        if (( $? )); then
            echo 'BEGIN ERROR'
            echo 'Error while building OpenSSL. Aborting.'
            echo 'END ERROR'
            exit 1
        fi
    fi
    
fi



################################################################################
# Configure Cactus
################################################################################

# Set options
OPENSSL_INC_DIRS="${OPENSSL_DIR}/include"
OPENSSL_LIB_DIRS="${OPENSSL_DIR}/lib"
OPENSSL_LIBS='ssl crypto'

OPENSSL_INC_DIRS="$(${CCTK_HOME}/lib/sbin/strip-incdirs.sh ${OPENSSL_INC_DIRS})"
OPENSSL_LIB_DIRS="$(${CCTK_HOME}/lib/sbin/strip-libdirs.sh ${OPENSSL_LIB_DIRS})"

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "OPENSSL_DIR      = ${OPENSSL_DIR}"
echo "OPENSSL_INC_DIRS = ${OPENSSL_INC_DIRS}"
echo "OPENSSL_LIB_DIRS = ${OPENSSL_LIB_DIRS}"
echo "OPENSSL_LIBS     = ${OPENSSL_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(OPENSSL_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(OPENSSL_LIB_DIRS)'
echo 'LIBRARY           $(OPENSSL_LIBS)'
