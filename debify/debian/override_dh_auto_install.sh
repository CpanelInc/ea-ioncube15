#!/bin/bash

source debian/vars.sh

set -x

export php_version=`echo "$php_parent" | perl -pe '$_ =~ s/^ea-php(\d)(\d)$/$1.$2/'`

# The module itself
install -d -m 755 $DEB_INSTALL_ROOT${php_extdir}
install -d -m 755 $DEB_INSTALL_ROOT${php_docdir}

install -m 755 ioncube_loader_lin_${php_version}.so $DEB_INSTALL_ROOT${php_extdir}
install -m 644 LICENSE.txt $DEB_INSTALL_ROOT${php_docdir}
install -m 644 README.txt $DEB_INSTALL_ROOT${php_docdir}

# The ini snippet
install -d -m 755 $DEB_INSTALL_ROOT${php_inidir}
cat > $DEB_INSTALL_ROOT${php_inidir}/${inifile} <<EOF
; Enable v15 IonCube Loader extension module
zend_extension="${php_extdir}/ioncube_loader_lin_${php_version}.so"
EOF

echo "DEB_INSTALL_ROOT"
tree $DEB_INSTALL_ROOT

echo "HOME"
tree .

