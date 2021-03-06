#! /bin/bash

# rstudio-server relies on the PAM headers and libraries from the debian package libpam0g-dev
# needed to install following debian packages:
#   libboost-all-dev

# show commands being run
set -x

source /etc/profile.d/R-3.4.0.sh
source /etc/profile.d/openssl-1.0.2l.sh
export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/jre

# Fail script on error.
set -e


pkgname=rstudio-server
VERSION=1.0.147
basedir=/opt
profiledir=/etc/profile.d
pkginstalldir=${basedir}/${pkgname}
tarinstalldir=${pkginstalldir}/tars
installprefix=${pkginstalldir}/${VERSION}
downloaduri=https://github.com/rstudio/rstudio/archive/v${VERSION}.tar.gz
tarfilebase=rstudio-${VERSION}
tarfilename=rstudio-${VERSION}.tgz
environdir=${basedir}/environ.d
script=$(readlink -f ${0})
installdir=$(dirname ${script})
# patchpath=$(dirname ${installdir})/extra/rstudio/rstudio_boost_pointer.patch

if [[ ! -d ${pkginstalldir}/tars ]] ; then
    mkdir -p ${pkginstalldir}/tars
fi
cd ${pkginstalldir}/tars

if [[ ! -e ${tarfilename} ]] ; then
    curl -L ${downloaduri} > ${tarfilename}
fi
tar xvzf ${tarfilename}

## apply patches for newer boost libraries
#cd ${pkginstalldir}/tars/${tarfilebase}
#patch -p1 < ${patchpath}

#install dependencies
cd ${pkginstalldir}/tars/${tarfilebase}/dependencies/common
# we don't run install-common because they ask for apps password
# to install boost, which we install ourselves
#./install-common
./install-dictionaries
./install-mathjax
./install-gwt
./install-pandoc
./install-packages
./install-libclang

cd ${pkginstalldir}/tars/${tarfilebase}/dependencies/linux
./install-qt-sdk

cd ${pkginstalldir}/tars/${tarfilebase}

# lowering the number of workers as per
# https://support.rstudio.com/hc/en-us/community/posts/201034828-Unable-to-compile-RStudio-Server-on-a-Raspberry-Pi
cat <<- _END_ > rstudio_java_memory.patch
diff -rupN src/gwt/build.xml src.new/gwt/build.xml
--- src/gwt/build.xml	2016-10-18 17:32:41.000000000 -0400
+++ src.new/gwt/build.xml	2016-11-14 01:13:20.579551344 -0500
@@ -102,11 +102,12 @@
             <path refid="project.class.path"/>
          </classpath>
          <!-- add jvmarg -Xss16M or similar if you see a StackOverflowError -->
+         <jvmarg value="-Xss16M"/>
          <jvmarg value="-Xmx1536M"/>
          <arg value="-war"/>
          <arg value="www"/>
          <arg value="-localWorkers"/>
-         <arg value="2"/>
+         <arg value="1"/>
          <arg value="-XdisableClassMetadata"/>
          <arg value="-XdisableCastChecking"/>
          <arg line="-strict"/>
_END_

patch -p0 < rstudio_java_memory.patch


# R_CMethodDef struct seems to no longer have a styles member.
cat <<- _END_ > rstudio_RCMethodDef_styles.patch
--- src/cpp/r/RRoutines.cpp 2017-05-26 11:20:24.451598046 -0400
+++ src/cpp/r/RRoutines.cpp.new 2017-05-26 11:20:11.877663778 -0400
@@ -59,7 +59,7 @@ void registerAll()
       nullMethodDef.fun = NULL ;
       nullMethodDef.numArgs = 0 ;
       nullMethodDef.types = NULL;
-      nullMethodDef.styles = NULL;
+      //nullMethodDef.styles = NULL;
       s_cMethods.push_back(nullMethodDef);
       pCMethods = &s_cMethods[0];
    }
_END_

patch -p0 < rstudio_RCMethodDef_styles.patch


rm -rf build
mkdir -p build
cd build

export GIT_DISCOVERY_ACROSS_FILESYSTEM=1
#export _JAVA_OPTIONS="-Xms512M"

cmake .. \
    -DRSTUDIO_TARGET=Server \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${installprefix} \
    -DOPENSSL_INCLUDE_DIRS=${OPENSSL_HOME}/include/openssl \
    -DOPENSSL_LIBRARIES='-L${OPENSSL_HOME}/include/openssl -lssl -lcrypto'


#    -DOPENSSL_INCLUDE_DIR=${OPENSSL_HOME}/include/openssl \
#    -DOPENSSL_SSL_LIBRARY=${OPENSSL_HOME}/lib/libssl.so \
#    -DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_HOME}/lib/libcrypto.so

umask 022
make install

if [[ ! -d ${environdir} ]] ; then
    mkdir ${environdir}
fi

cat <<- _END_ > ${profiledir}/${pkgname}-${VERSION}.sh
export PATH=${installprefix}/bin:${installprefix}/bin/pandoc:\$PATH
_END_
