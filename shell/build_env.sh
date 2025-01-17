#!/bin/bash

# build development enviroment
# install 3th party software or library,like lua、mongodb

# UPDATE to Debian 9.9 at 2019-07-22

BUILD_ENV_LOG=./build_env_log.txt
RAWPKTDIR=../package
PKGDIR=/tmp/mserver_package

# "set -e" will cause bash to exit with an error on any simple command.
# "set -o pipefail" will cause bash to exit with an error on any command
#  in a pipeline as well.
set -e
set -o pipefail

function auto_apt_install()
{
    echo "install $1 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    apt-get -y install $1
}

function append_to_file()
{
    echo "$2" >>$1
}

# install compile enviroment
function build_tool_chain()
{
    echo "build tool chain ..."
    auto_apt_install gcc
    auto_apt_install g++
    auto_apt_install make

    # flatbuffers and mongo will need those to build
    auto_apt_install cmake
    auto_apt_install automake
    auto_apt_install libtool #protobuf需要
}

# install third party library
function build_library()
{
    auto_apt_install uuid-dev
    auto_apt_install libssl-dev # openssl
    # auto_apt_install mysql-server
    # auto_apt_install libmysqlclient-dev
    auto_apt_install libmariadbclient-dev
    auto_apt_install libreadline-dev
    # auto_apt_install pkg-config libssl-dev libsasl2-dev
}

function build_lua()
{
    cd $PKGDIR

    LUAVER=5.3.5
    tar -zxvf lua-$LUAVER.tar.gz
    cd lua-$LUAVER
    make linux install
    make install
}

# 这是一个简单自定义源码安装libmysqlclient-dev的cmake脚本
# 这是为了与apt-get install方式安装兼容
# https://dev.mysql.com/doc/refman/5.5/en/source-configuration-options.html
function build_libmysqlclient()
{
    cd $PKGDIR

    LIBMYSQLV=6.1.6
    LIBMYSQLC=mysql-connector-c-#LIBMYSQLV
    tar -zxvf $LIBMYSQLC.tar.gz
    cd $LIBMYSQLC
    cmake . -DINSTALL_BINDIR=/usr/bin -DINSTALL_DOCDIR=/usr/share/docs/mysql -DINSTALL_DOCREADMEDIR=/usr/share/docs/mysql -DINSTALL_INCLUDEDIR=/usr/include/mysql -DINSTALL_INFODIR=/usr/share/docs/mysql -DINSTALL_LIBDIR=/usr/lib/x86_64-linux-gnu/ -DINSTALL_DOCREADMEDIR=/usr/share/docs/mysql
    make
    make install
}

function rm_libmysqlclient()
{
    rm -rf /usr/share/docs/mysql
    #rm -f /usr/share/docs/mysql/COPYING
    #rm -f /usr/share/docs/mysql/README
    #rm -f /usr/share/docs/mysql/INFO_SRC
    #rm -f /usr/share/docs/mysql/INFO_BIN
    #rm -f /usr/share/docs/mysql/ChangeLog
    rm -rf /usr/include/mysql
    #rm -f /usr/include/mysql/mysql.h
    #rm -f /usr/include/mysql/mysql_com.h
    #rm -f /usr/include/mysql/mysql_time.h
    #rm -f /usr/include/mysql/my_list.h
    #rm -f /usr/include/mysql/my_alloc.h
    #rm -f /usr/include/mysql/typelib.h
    #rm -f /usr/include/mysql/my_dbug.h
    #rm -f /usr/include/mysql/m_string.h
    #rm -f /usr/include/mysql/my_sys.h
    #rm -f /usr/include/mysql/my_xml.h
    #rm -f /usr/include/mysql/mysql_embed.h
    #rm -f /usr/include/mysql/my_pthread.h
    #rm -f /usr/include/mysql/decimal.h
    #rm -f /usr/include/mysql/errmsg.h
    #rm -f /usr/include/mysql/my_global.h
    #rm -f /usr/include/mysql/my_getopt.h
    #rm -f /usr/include/mysql/sslopt-longopts.h
    #rm -f /usr/include/mysql/my_dir.h
    #rm -f /usr/include/mysql/sslopt-vars.h
    #rm -f /usr/include/mysql/sslopt-case.h
    #rm -f /usr/include/mysql/sql_common.h
    #rm -f /usr/include/mysql/keycache.h
    #rm -f /usr/include/mysql/m_ctype.h
    #rm -f /usr/include/mysql/my_compiler.h
    #rm -f /usr/include/mysql/mysql_com_server.h
    #rm -f /usr/include/mysql/my_byteorder.h
    #rm -f /usr/include/mysql/byte_order_generic.h
    #rm -f /usr/include/mysql/byte_order_generic_x86.h
    #rm -f /usr/include/mysql/little_endian.h
    #rm -f /usr/include/mysql/big_endian.h
    #rm -f /usr/include/mysql/mysql_version.h
    #rm -f /usr/include/mysql/my_config.h
    #rm -f /usr/include/mysql/mysqld_ername.h
    #rm -f /usr/include/mysql/mysqld_error.h
    #rm -f /usr/include/mysql/sql_state.h
    #rm -f /usr/include/mysql/mysql
    #rm -f /usr/include/mysql/mysql/get_password.h
    #rm -f /usr/include/mysql/mysql/psi
    #rm -f /usr/include/mysql/mysql/psi/mysql_thread.h
    #rm -f /usr/include/mysql/mysql/psi/mysql_sp.h
    #rm -f /usr/include/mysql/mysql/psi/psi_base.h
    #rm -f /usr/include/mysql/mysql/psi/mysql_idle.h
    #rm -f /usr/include/mysql/mysql/psi/mysql_transaction.h
    #rm -f /usr/include/mysql/mysql/psi/mysql_socket.h
    #rm -f /usr/include/mysql/mysql/psi/mysql_stage.h
    #rm -f /usr/include/mysql/mysql/psi/psi.h
    #rm -f /usr/include/mysql/mysql/psi/mysql_mdl.h
    #rm -f /usr/include/mysql/mysql/psi/mysql_statement.h
    #rm -f /usr/include/mysql/mysql/psi/mysql_table.h
    #rm -f /usr/include/mysql/mysql/psi/psi_memory.h
    #rm -f /usr/include/mysql/mysql/psi/mysql_memory.h
    #rm -f /usr/include/mysql/mysql/psi/mysql_file.h
    #rm -f /usr/include/mysql/mysql/psi/mysql_ps.h
    #rm -f /usr/include/mysql/mysql/service_mysql_alloc.h
    #rm -f /usr/include/mysql/mysql/client_authentication.h
    #rm -f /usr/include/mysql/mysql/client_plugin.h.pp
    #rm -f /usr/include/mysql/mysql/service_my_snprintf.h
    #rm -f /usr/include/mysql/mysql/plugin_trace.h
    #rm -f /usr/include/mysql/mysql/client_plugin.h
    #rm -f /usr/include/mysql/mysql/plugin_auth_common.h
    rm -f /usr/lib/x86_64-linux-gnu/libmysqlclient.a
    rm -f /usr/lib/x86_64-linux-gnu/libmysqlclient_r.a
    rm -f /usr/lib/x86_64-linux-gnu/libmysqlclient.so.18.3.0
    rm -f /usr/lib/x86_64-linux-gnu/libmysqlclient.so.18
    rm -f /usr/lib/x86_64-linux-gnu/libmysqlclient.so
    rm -f /usr/lib/x86_64-linux-gnu/libmysqlclient_r.so
    rm -f /usr/lib/x86_64-linux-gnu/libmysqlclient_r.so.18
    rm -f /usr/lib/x86_64-linux-gnu/libmysqlclient_r.so.18.3.0
    rm -f /usr/bin/my_print_defaults
    rm -f /usr/bin/perror
    rm -f /usr/bin/mysql_config
}

# https://github.com/cyrusimap/cyrus-sasl/releases
# 注意：sasl库编译过程中需要创建软链接(ln -s)
# 在win挂载到linux方式下是不能创建的,导致编译失败
function build_sasl()
{
    # apt-get install libssl-dev libsasl2-dev 方式安装不能静态链接
    # CANT NOT static link sasl2:https://www.cyrusimap.org/sasl/
    # libtool doesn’t always link libraries together. In our environment, we only
    # have static Krb5 libraries; the GSSAPI plugin should link these libraries in
    # on platforms that support it (Solaris and Linux among them) but it does not

    cd $PKGDIR

    SASLVER=2.1.27
    SASL=cyrus-sasl-$SASLVER
    tar -zxvf $SASL.tar.gz
    cd $SASL
    ./configure --enable-static=yes
    # make过程中需要创建符号链接，部分挂载的文件系统是不能创建符号链接的，这时就要把tar包拷到
    # 对应的系统去单独执行
    make
    make install
    #* Plugins are being installed into /usr/local/lib/sasl2,
    #* but the library will look for them in /usr/lib/sasl2.
    #* You need to make sure that the plugins will eventually
    #* be in /usr/lib/sasl2 -- the easiest way is to make a
    #* symbolic link from /usr/lib/sasl2 to /usr/local/lib/sasl2,
    #* but this may not be appropriate for your site, so this
    #* installation procedure won't do it for you.
}

# http://mongoc.org/
# https://github.com/mongodb/mongo-c-driver/releases/download/1.14.0/mongo-c-driver-1.14.0.tar.gz
# http://mongoc.org/libmongoc/current/installing.html
function build_mongo_driver()
{
    # 如果出现aclocal-1.14: command not found,安装automake，版本不对
    # 则修改以下两个文件的am__api_version='1.15'，然后重新./configure
    # mongo-c-driver-1.2.1\configure
    # mongo-c-driver-1.2.1\src\libbson\configure
    cd $PKGDIR

    MONGOCVER=1.15.0
    tar -zxvf mongo-c-driver-$MONGOCVER.tar.gz
    cd mongo-c-driver-$MONGOCVER
    mkdir cmake-build
    cd cmake-build
    cmake -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF -DCMAKE_BUILD_TYPE=Release -DENABLE_STATIC=ON -DENABLE_BSON=ON ..
    # --with-libbson=[auto/system/bundled]
    # 强制使用附带的bson库，不然之前系统编译的bson库可能编译参数不一致(比如不会生成静态bson库)
    # ./configure --disable-automatic-init-and-cleanup --enable-static --with-libbson=bundled
    make
    make install
}

function build_flatbuffers()
{
    cd $PKGDIR

    FBB_VER=1.11.0
    tar -zxvf flatbuffers-$FBB_VER.tar.gz
    cmake flatbuffers-$FBB_VER -Bflatbuffers-$FBB_VER
    make -C flatbuffers-$FBB_VER all
    make -C flatbuffers-$FBB_VER install
    ldconfig -v
}

# 编译protobuf库并安装
# https://github.com/google/protobuf/releases
function build_protoc()
{
    cd $PKGDIR
    PROTOBUF_VER=3.3.0
    tar -xzvf protobuf-$PROTOBUF_VER.tar.gz

    #
    cd protobuf-$PROTOBUF_VER
    # ./autogen.sh 由于这个脚本需要从网上下载gtest，这里是不能直接下载的
    autoreconf -f -i -Wall,no-obsolete
    ./configure
    make
    make install
}

# 我们只需要一个protoc来编译proto文件，不需要源代码
# 可以在github直接下载bin文件，尤其是在win下开发的时候
# https://github.com/google/protobuf/releases
function install_protoc()
{
    cd $PKGDIR

    PROTOC_ZIP=protoc-3.9.0-linux-x86_64.zip
    # curl -OL https://github.com/google/protobuf/releases/download/v3.9.0/$PROTOC_ZIP
    unzip -o $PROTOC_ZIP -d /usr/local bin/protoc
    unzip -o $PROTOC_ZIP -d /usr/local include/*
}

# install mongodb from a tarball download from
# https://www.mongodb.com/download-center#community
# automatic install and setting config and serivce.
function build_mongodb()
{
    echo "build_mongo >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    #cd $PKGDIR
    cd /home/xzc/mongodb

    mkdir -p .mongodb
    # --strip-components 1 在解压时自动去除第一层目录
    tar -zxvf mongodb-linux-x86_64-debian71-3.4.4.tgz -C .mongodb --strip-components 1

    # install exec file
    chmod +x .mongodb/bin/*
    cp -R .mongodb/bin/* /usr/bin

    # install mongod service
    wget https://raw.githubusercontent.com/mongodb/mongo/master/debian/init.d -O /etc/init.d/mongod
    755 = -rwxr-xr-x
    chmod 755 /etc/init.d/mongod
    update-rc.d mongod defaults

    LOGDIR=/var/log/mongodb
    DBPATH=/var/lib/mongodb

    # create mongo user and necessary dir
    groupadd --system mongodb
    useradd --no-create-home --system --gid mongodb --shell /sbin/nologin --comment 'mongodb' mongodb
    mkdir -p $LOGDIR
    chown -R mongodb:mongodb $LOGDIR
    mkdir -p $DBPATH
    chown -R mongodb:mongodb $DBPATH

    # setting config
    # manual:https://docs.mongodb.com/manual/reference/configuration-options/
    # example:https://github.com/mongodb/mongo/blob/master/debian/mongod.conf
    # the config path is specify in init.d script
    MONGODCONF=/etc/mongod.conf
    echo "#mongod.conf" > $MONGODCONF
    append_to_file $MONGODCONF 'systemLog:'
    append_to_file $MONGODCONF '   destination: file'
    append_to_file $MONGODCONF '   path: "'$LOGDIR'/mongod.log"'
    append_to_file $MONGODCONF '   logAppend: true'
    append_to_file $MONGODCONF 'storage:'
    append_to_file $MONGODCONF '   dbPath: '$DBPATH
    append_to_file $MONGODCONF '   journal:'
    append_to_file $MONGODCONF '      enabled: true'
    append_to_file $MONGODCONF 'processManagement:'
    append_to_file $MONGODCONF '   fork: true'
    append_to_file $MONGODCONF 'net:'
    append_to_file $MONGODCONF '   bindIp: 127.0.0.1'
    append_to_file $MONGODCONF '   port: 27013'
    append_to_file $MONGODCONF 'setParameter:'
    append_to_file $MONGODCONF '   enableLocalhostAuthBypass: false'
    append_to_file $MONGODCONF 'security:'
    append_to_file $MONGODCONF '   authorization: enabled'

    # start mongo service using /etc/mongod.conf
    service mongod start

    cd -
}

function build_env_once()
{
    old_pwd=`pwd`
    # 很多软件包包含软件链接，在win挂载目录到linux下开发时解压出错，干脆复制一份
    echo "prepare temp dir $PKGDIR"
    mkdir -p $PKGDIR

    echo "copy all package to $PKGDIR"
    cp $RAWPKTDIR/* $PKGDIR/

    build_tool_chain
    build_library
    build_lua
    build_sasl
    build_mongo_driver
    build_flatbuffers
    install_protoc

    cd $old_pwd
    rm -R $PKGDIR

    echo "all done !!!"
}


build_env_once 2>&1 | tee $BUILD_ENV_LOG

# 只要安装其中一个的话，把上面的代码临时注释掉即可
# build_$1 2>&1 | tee $BUILD_ENV_LOG



# TODO build cppcheck
# https://sourceforge.net/projects/cppcheck/files/cppcheck/1.78/cppcheck-1.78.tar.gz/download
# tar -zxvf cppcheck-1.78.tar.gz
# cd cppcheck-1.78
# make SRCDIR=build CFGDIR=cfg HAVE_RULES=yes
# CFGDIR表示使用当前目录下的cfg目录，如果要make install，请另外指定目录并复制当前cfg目录到指定的目录

# make: pcre-config: Command not found
# If you write HAVE_RULES=yes then pcre must be available. So you have two options:
# 1. Remove HAVE_RULES=yes
# 2. Install pcre(auto_apt_install libpcre3-dev)

# TODO build oclint env
# need debian8(>=gcc5)
# edit /etc/apt/sources.list
# deb-src http://mirrors.163.com/debian-security/ jessie/updates main non-free contrib
# apt-get update
# auto_apt_install g++-6
# download https://github.com/oclint/oclint/releases
# tar -zxvf xx.tar.gz
# cd xxx
# bin/oclint -version

# TODO build bear(oclint tool)
# https://github.com/rizsotto/Bear/archive/2.2.1.tar.gz bear2.2.1.tar.gz
# tar -zxvf bear2.2.1.tar.gz
# cd Bear-2.2.1/
# cmake .
# make
# make install (一定要安装，因为要用到libbear.so)