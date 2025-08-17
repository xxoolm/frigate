#!/bin/bash

set -euxo pipefail

SQLITE3_VERSION="96c92aba00c8375bc32fafcdf12429c58bd8aabfcadab6683e35bbb9cdebf19e" # 3.46.0
PYSQLITE3_VERSION="0.5.3"

echo "开始构建 pysqlite3..."

# 定义预编译版本下载链接（优先使用）
PRECOMPILED_URLS=(
    "https://www.sqlite.org/2024/sqlite-amalgamation-3460100.zip"
    "https://www.sqlite.org/2024/sqlite-amalgamation-3460000.zip"
)

# 定义源码版本下载链接（备用）
SOURCE_URLS=(
    "https://github.com/sqlite/sqlite/archive/refs/tags/version-3.46.0.tar.gz"
    "https://github.com/sqlite/sqlite/archive/refs/tags/version-3.46.1.tar.gz"
    "https://www.sqlite.org/src/tarball/sqlite.tar.gz?r=${SQLITE3_VERSION}"
    "https://www.sqlite.org/2024/sqlite-src-3460000.tar.gz"
    "https://www.sqlite.org/2024/sqlite-src-3460100.tar.gz"
)

# 第一步：尝试预编译版本
echo "=== 第一步：尝试预编译版本 ==="
for url_index in "${!PRECOMPILED_URLS[@]}"; do
    url="${PRECOMPILED_URLS[$url_index]}"
    echo "尝试预编译链接 $((url_index + 1))/${#PRECOMPILED_URLS[@]}: $url"
    
    # 清理之前的下载文件
    rm -f sqlite-amalgamation.zip
    
    # 下载预编译版本
    if wget --timeout=60 --tries=3 --no-verbose "$url" -O sqlite-amalgamation.zip 2>/dev/null; then
        echo "下载成功，检查文件类型..."
        
        # 检查文件是否为HTML页面
        if grep -q "<html" sqlite-amalgamation.zip 2>/dev/null || grep -q "<!DOCTYPE" sqlite-amalgamation.zip 2>/dev/null; then
            echo "检测到HTML页面，跳过此链接..."
            continue
        fi
        
        # 检查文件大小
        file_size=$(stat -c%s sqlite-amalgamation.zip 2>/dev/null || echo 0)
        if [ "$file_size" -lt 1048576 ]; then
            echo "文件太小 ($file_size bytes)，跳过此链接..."
            continue
        fi
        
        echo "文件验证通过，解压预编译版本..."
        if unzip -q sqlite-amalgamation.zip 2>/dev/null; then
            if [[ -d "sqlite-amalgamation-3460100" ]]; then
                mv sqlite-amalgamation-3460100 sqlite
                echo "✅ 预编译版本解压成功"
                rm sqlite-amalgamation.zip
                break
            elif [[ -d "sqlite-amalgamation-3460000" ]]; then
                mv sqlite-amalgamation-3460000 sqlite
                echo "✅ 预编译版本解压成功"
                rm sqlite-amalgamation.zip
                break
            else
                echo "解压后的目录结构不符合预期，尝试下一个链接..."
                continue
            fi
        else
            echo "解压失败，尝试下一个链接..."
            continue
        fi
    else
        echo "下载失败，尝试下一个链接..."
        continue
    fi
done

# 第二步：如果预编译版本失败，尝试源码版本
if [[ ! -d "sqlite" ]]; then
    echo "=== 第二步：预编译版本失败，尝试源码版本 ==="
    for url_index in "${!SOURCE_URLS[@]}"; do
        url="${SOURCE_URLS[$url_index]}"
        echo "尝试源码链接 $((url_index + 1))/${#SOURCE_URLS[@]}: $url"
        
        # 清理之前的下载文件
        rm -f sqlite.tar.gz
        
        # 下载源码版本
        if wget --timeout=60 --tries=3 --no-verbose "$url" -O sqlite.tar.gz 2>/dev/null; then
            echo "下载成功，检查文件类型..."
            
            # 检查文件是否为HTML页面
            if grep -q "<html" sqlite.tar.gz 2>/dev/null || grep -q "<!DOCTYPE" sqlite.tar.gz 2>/dev/null; then
                echo "检测到HTML页面，跳过此链接..."
                continue
            fi
            
            # 检查文件大小
            file_size=$(stat -c%s sqlite.tar.gz 2>/dev/null || echo 0)
            if [ "$file_size" -lt 1048576 ]; then
                echo "文件太小 ($file_size bytes)，跳过此链接..."
                continue
            fi
            
            echo "文件验证通过，解压源码版本..."
            if tar -tzf sqlite.tar.gz > /dev/null 2>&1; then
                tar xzf sqlite.tar.gz
                
                # 检查解压后的目录结构
                if [[ -d "sqlite" ]]; then
                    echo "✅ 源码版本解压成功"
                    break
                elif [[ -d "sqlite-version-3.46.0" ]]; then
                    mv sqlite-version-3.46.0 sqlite
                    echo "✅ 源码版本解压成功"
                    break
                elif [[ -d "sqlite-version-3.46.1" ]]; then
                    mv sqlite-version-3.46.1 sqlite
                    echo "✅ 源码版本解压成功"
                    break
                elif [[ -d "sqlite-src-3460000" ]]; then
                    mv sqlite-src-3460000 sqlite
                    echo "✅ 源码版本解压成功"
                    break
                elif [[ -d "sqlite-src-3460100" ]]; then
                    mv sqlite-src-3460100 sqlite
                    echo "✅ 源码版本解压成功"
                    break
                else
                    echo "解压后的目录结构不符合预期，尝试下一个链接..."
                    continue
                fi
            else
                echo "文件验证失败，尝试下一个链接..."
                continue
            fi
        else
            echo "下载失败，尝试下一个链接..."
            continue
        fi
    done
fi

# 检查是否成功创建了 sqlite 目录
if [[ ! -d "sqlite" ]]; then
    echo "❌ 所有下载链接都失败了！"
    exit 1
fi

# 验证 SQLite 文件是否存在
if [[ ! -f "sqlite/sqlite3.c" ]] || [[ ! -f "sqlite/sqlite3.h" ]]; then
    echo "❌ SQLite 文件不存在，需要编译源码版本..."
    
    # 如果是源码版本，需要编译
    if [[ -f "sqlite/configure" ]]; then
        echo "检测到源码版本，开始编译..."
        cd sqlite/
        LIBS="-lm" ./configure --disable-tcl --enable-tempstore=always
        make sqlite3.c
        cd ../
        echo "✅ 源码版本编译完成"
    else
        echo "❌ 既不是预编译版本也不是源码版本，构建失败！"
        ls -la sqlite/
        exit 1
    fi
else
    echo "✅ SQLite 文件验证通过"
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
cp "../sqlite/sqlite3.h" src/

# Build the extension.
python3 setup.py build_static

# Install the extension.
python3 setup.py install

cd ../
echo "✅ pysqlite3 构建完成！"
