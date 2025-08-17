#!/bin/bash

set -euxo pipefail

SQLITE3_VERSION="96c92aba00c8375bc32fafcdf12429c58bd8aabfcadab6683e35bbb9cdebf19e" # 3.46.0
PYSQLITE3_VERSION="0.5.3"

echo "开始构建 pysqlite3..."

# 首先尝试下载预编译的 amalgamation 版本
echo "尝试下载预编译的 SQLite amalgamation..."
if wget --timeout=60 --tries=3 --no-verbose "https://www.sqlite.org/2024/sqlite-amalgamation-3460100.zip" -O sqlite-amalgamation.zip 2>/dev/null; then
    echo "下载预编译版本成功..."
    unzip -q sqlite-amalgamation.zip
    mv sqlite-amalgamation-3460100 sqlite
    rm sqlite-amalgamation.zip
    echo "预编译版本准备完成"
else
    echo "预编译版本下载失败，尝试源码版本..."
    
    # 尝试下载源码版本
    if wget --timeout=60 --tries=3 --no-verbose "https://github.com/sqlite/sqlite/archive/refs/tags/version-3.46.0.tar.gz" -O sqlite.tar.gz 2>/dev/null; then
        echo "下载源码版本成功..."
        tar xzf sqlite.tar.gz
        mv sqlite-version-3.46.0 sqlite
        rm sqlite.tar.gz
        
        echo "进入 sqlite 目录进行配置..."
        cd sqlite/
        LIBS="-lm" ./configure --disable-tcl --enable-tempstore=always
        make sqlite3.c
        cd ../
        echo "源码版本准备完成"
    else
        echo "所有下载方法都失败了！"
        exit 1
    fi
fi

# 验证 SQLite 文件是否存在
if [[ ! -f "sqlite/sqlite3.c" ]] || [[ ! -f "sqlite/sqlite3.h" ]]; then
    echo "SQLite 文件不存在，构建失败！"
    ls -la sqlite/
    exit 1
fi

echo "SQLite 源码准备完成，开始构建 pysqlite3..."

# Grab the pysqlite3 source code.
if [[ ! -d "./pysqlite3" ]]; then
  git clone https://github.com/coleifer/pysqlite3.git
fi

cd pysqlite3/
git checkout ${PYSQLITE3_VERSION}

# Copy the sqlite3 source amalgamation into the pysqlite3 directory so we can
# create a self-contained extension module.
cp "../sqlite/sqlite3.c" ./
cp "../sqlite/sqlite3.h" ./

# Build the extension.
python3 setup.py build

# Install the extension.
python3 setup.py install

cd ../
echo "pysqlite3 构建完成！"
