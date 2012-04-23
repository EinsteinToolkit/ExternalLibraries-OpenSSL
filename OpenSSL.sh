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
    
    FILES="include/openssl/ssl.h lib/libssl.a lib/libcrypto.a"
    DIRS="/usr /usr/local /opt/local"
    for dir in $DIRS; do
        OPENSSL_DIR="$dir"
        for file in $FILES; do
            if [ ! -r "$dir/$file" ]; then
                unset OPENSSL_DIR
                break
            fi
        done
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
    
    # Set locations
    THORN=OpenSSL
    NAME=openssl-1.0.0i
    SRCDIR=$(dirname $0)
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
                         -a ${DONE_FILE} -nt ${SRCDIR}/OpenSSL.sh ]
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
        unset MAKEFLAGS # For some reason, openssl does not compile with this
        
        echo "OpenSSL: Preparing directory structure..."
        mkdir build external done 2> /dev/null || true
        rm -rf ${BUILD_DIR} ${INSTALL_DIR}
        mkdir ${BUILD_DIR} ${INSTALL_DIR}
        
        echo "OpenSSL: Unpacking archive..."
        pushd ${BUILD_DIR}
        ${TAR} xzf ${SRCDIR}/dist/${NAME}.tar.gz
        ${PATCH} -p0 < ${SRCDIR}/dist/darwin.patch
        
        echo "OpenSSL: Configuring..."
        cd ${NAME}
        ./config --prefix=${OPENSSL_DIR}
        
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
if [ "${OPENSSL_DIR}" != '/usr' -a "${OPENSSL_DIR}" != '/usr/local' ]; then
    OPENSSL_INC_DIRS="${OPENSSL_DIR}/include"
    OPENSSL_LIB_DIRS="${OPENSSL_DIR}/lib"
fi
OPENSSL_LIBS='ssl crypto'

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "HAVE_OPENSSL     = 1"
echo "OPENSSL_DIR      = ${OPENSSL_DIR}"
echo "OPENSSL_INC_DIRS = ${OPENSSL_INC_DIRS}"
echo "OPENSSL_LIB_DIRS = ${OPENSSL_LIB_DIRS}"
echo "OPENSSL_LIBS     = ${OPENSSL_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(OPENSSL_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(OPENSSL_LIB_DIRS)'
echo 'LIBRARY           $(OPENSSL_LIBS)'
