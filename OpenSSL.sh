#! /bin/bash

################################################################################
# Prepare
################################################################################

# Set up shell
set -x                          # Output commands
set -e                          # Abort on errors

# Set locations
NAME=openssl-0.9.8l
SRCDIR=$(dirname $0)
INSTALL_DIR=${SCRATCH_BUILD}
OPENSSL_DIR=${INSTALL_DIR}/${NAME}

# Clean up environment
unset EXE
unset LIBS
unset MAKEFLAGS



################################################################################
# Build
################################################################################

(
    exec >&2                    # Redirect stdout to stderr
    set -x                      # Output commands
    set -e                      # Abort on errors
    cd ${INSTALL_DIR}
    if [ -e done-${NAME} -a done-${NAME} -nt ${SRCDIR}/dist/${NAME}.tar.gz ]; then
        echo "OpenSSL: The enclosed OpenSSL library has already been built; doing nothing"
    else
        echo "OpenSSL: Building enclosed OpenSSL library"
        
        echo "OpenSSL: Unpacking archive..."
        rm -rf build-${NAME}
        mkdir build-${NAME}
        pushd build-${NAME}
        # Should we use gtar or tar?
        TAR=$(gtar --help > /dev/null 2> /dev/null && echo gtar || echo tar)
        ${TAR} xzf ${SRCDIR}/dist/${NAME}.tar.gz
        popd
        
        echo "OpenSSL: Configuring..."
        rm -rf ${NAME}
        mkdir ${NAME}
        pushd build-${NAME}/${NAME}
        ./config --prefix=${OPENSSL_DIR}
        
        echo "OpenSSL: Building..."
        make
        
        echo "OpenSSL: Installing..."
        make install
        popd
        
        echo 'done' > done-${NAME}
        echo "OpenSSL: Done."
    fi
)



################################################################################
# Configure Cactus
################################################################################

# Set options
OPENSSL_INC_DIRS="${OPENSSL_DIR}/include"
OPENSSL_LIB_DIRS="${OPENSSL_DIR}/lib"
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
