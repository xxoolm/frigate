#!/bin/bash

set -euxo pipefail

SQLITE3_VERSION="96c92aba00c8375bc32fafcdf12429c58bd8aabfcadab6683e35bbb9cdebf19e" # 3.46.0
PYSQLITE3_VERSION="0.5.3"

# 定义多个备用下载链接
SQLITE_DOWNLOAD_URLS=(
    "https://www.sqlite.org/src/tarball/sqlite.tar.gz?r=${SQLITE3_VERSION}"
    "https://www.sqlite.org/2024/sqlite-src-3460000.tar.gz"
    "https://www.sqlite.org/2024/sqlite-src-3460100.tar.gz"
    "https://www.sqlite.org/2024/sqlite-amalgamation-3460100.zip"
    "https://www.sqlite.org/2024/sqlite-amalgamation-3460000.zip"
    "https://github.com/sqlite/sqlite/archive/refs/tags/version-3.46.0.tar.gz"
    "https://github.com/sqlite/sqlite/archive/refs/tags/version-3.46.1.tar.gz"
)

# Fetch the source code for the latest release of Sqlite.
if [[ ! -d "sqlite" ]]; then
  echo "开始下载 SQLite 源码..."
  
  # 尝试所有下载链接
  for url_index in "${!SQLITE_DOWNLOAD_URLS[@]}"; do
    url="${SQLITE_DOWNLOAD_URLS[$url_index]}"
    echo "尝试下载链接 $((url_index + 1))/${#SQLITE_DOWNLOAD_URLS[@]}: $url"
    
    # 清理之前的下载文件
    rm -f sqlite.tar.gz sqlite-amalgamation.zip
    
    # 下载文件
    if wget --timeout=60 --tries=3 --no-verbose "$url" -O sqlite.tar.gz 2>/dev/null; then
      echo "下载成功，检查文件类型..."
      
      # 检查文件是否为HTML页面（错误页面）
      if grep -q "<html" sqlite.tar.gz 2>/dev/null || grep -q "<!DOCTYPE" sqlite.tar.gz 2>/dev/null; then
        echo "检测到HTML页面，跳过此链接..."
        continue
      fi
      
      # 检查文件大小是否合理（至少1MB）
      file_size=$(stat -c%s sqlite.tar.gz 2>/dev/null || echo 0)
      if [ "$file_size" -lt 1048576 ]; then
        echo "文件太小 ($file_size bytes)，可能不是有效的压缩包，跳过此链接..."
        continue
      fi
      
      echo "文件类型检查通过，验证文件完整性..."
      # 验证文件完整性
      if tar -tzf sqlite.tar.gz > /dev/null 2>&1; then
        echo "文件验证成功，正在解压..."
        tar xzf sqlite.tar.gz
        
        # 检查解压后的目录结构
        if [[ -d "sqlite" ]]; then
          echo "SQLite 源码解压成功"
          break
        elif [[ -d "sqlite-src-3460000" ]]; then
          echo "重命名目录..."
          mv sqlite-src-3460000 sqlite
          break
        elif [[ -d "sqlite-src-3460100" ]]; then
          echo "重命名目录..."
          mv sqlite-src-3460100 sqlite
          break
        elif [[ -d "sqlite-version-3.46.0" ]]; then
          echo "重命名目录..."
          mv sqlite-version-3.46.0 sqlite
          break
        elif [[ -d "sqlite-version-3.46.1" ]]; then
          echo "重命名目录..."
          mv sqlite-version-3.46.1 sqlite
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
  
  # 检查是否成功创建了 sqlite 目录
  if [[ ! -d "sqlite" ]]; then
    echo "所有下载链接都失败了，尝试使用预编译版本..."
    
    # 尝试使用预编译的 amalgamation
    if wget --timeout=60 --tries=3 --no-verbose "https://www.sqlite.org/2024/sqlite-amalgamation-3460100.zip" -O sqlite-amalgamation.zip 2>/dev/null; then
      echo "下载预编译版本成功..."
      unzip -q sqlite-amalgamation.zip
      mv sqlite-amalgamation-3460100 sqlite
      rm sqlite-amalgamation.zip
    else
      echo "所有下载方法都失败了！"
      exit 1
    fi
  fi
  
  echo "进入 sqlite 目录进行配置..."
  cd sqlite/
  
  # 检查是否需要配置和编译
  if [[ ! -f "sqlite3.c" ]]; then
    echo "需要配置和编译 SQLite..."
    LIBS="-lm" ./configure --disable-tcl --enable-tempstore=always
    make sqlite3.c
  else
    echo "SQLite amalgamation 已存在，跳过编译..."
  fi
  
  cd ../
  rm -f sqlite.tar.gz sqlite-amalgamation.zip
  echo "SQLite 源码准备完成"
fi

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
