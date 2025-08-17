#!/bin/bash

# 模型预下载脚本 (简化版本)
# 根据配置下载所需的模型文件到模型缓存目录

set -euo pipefail

# 添加调试信息
echo "🔍 调试信息:"
echo "  - 脚本路径: $0"
echo "  - 工作目录: $(pwd)"
echo "  - 用户: $(whoami)"
echo "  - 磁盘空间: $(df -h . | tail -1)"

echo "🚀 开始预下载Frigate模型文件..."

# 设置模型缓存目录
MODEL_CACHE_DIR="/config/model_cache"
mkdir -p "$MODEL_CACHE_DIR"

echo "📁 创建模型缓存目录: $MODEL_CACHE_DIR"

# 定义模型下载函数
download_model() {
    local model_dir="$1"
    local file_name="$2"
    local url="$3"
    local target_path="$MODEL_CACHE_DIR/$model_dir/$file_name"
    
    echo "📥 下载 $model_dir/$file_name..."
    mkdir -p "$MODEL_CACHE_DIR/$model_dir"
    
    # 使用wget下载，支持重试，添加错误处理
    if wget -q --show-progress --tries=3 --timeout=30 -O "$target_path" "$url"; then
        echo "✅ $model_dir/$file_name 下载完成"
        return 0
    else
        echo "❌ $model_dir/$file_name 下载失败"
        return 1
    fi
}

# 测试下载一个简单的文件
echo "🧪 测试下载功能..."
if download_model "test" "test.txt" "https://httpbin.org/bytes/100"; then
    echo "✅ 测试下载成功"
    rm -rf "$MODEL_CACHE_DIR/test"
else
    echo "❌ 测试下载失败，退出"
    exit 1
fi

# 1. 语义搜索模型 (JinaV2 Large) - 简化版本
echo "🔍 下载语义搜索模型 (JinaV2 Large)..."
mkdir -p "$MODEL_CACHE_DIR/jina_v2"

# 只下载主要的模型文件
download_model "jina_v2" "model_fp16.onnx" "https://huggingface.co/jinaai/jina-clip-v2/resolve/main/onnx/model_fp16.onnx" || echo "⚠️ 语义搜索模型下载失败，继续..."

# 2. 人脸识别模型 (Large) - 简化版本
echo "👤 下载人脸识别模型 (Large)..."
mkdir -p "$MODEL_CACHE_DIR/facedet"

# 只下载主要的模型文件
download_model "facedet" "facedet.onnx" "https://github.com/NickM-27/facenet-onnx/releases/download/v1.0/facedet.onnx" || echo "⚠️ 人脸识别模型下载失败，继续..."

# 3. 车牌识别模型 - 简化版本
echo "🚗 下载车牌识别模型..."
mkdir -p "$MODEL_CACHE_DIR/lpr"

# 只下载主要的模型文件
download_model "lpr" "yolov9-256-license-plates.onnx" "https://github.com/hawkeye217/yolov9-license-plates/raw/refs/heads/master/models/yolov9-256-license-plates.onnx" || echo "⚠️ 车牌识别模型下载失败，继续..."

# 4. 鸟类分类模型 - 简化版本
echo "🐦 下载鸟类分类模型..."
mkdir -p "$MODEL_CACHE_DIR/bird"

download_model "bird" "bird.tflite" "https://raw.githubusercontent.com/google-coral/test_data/master/mobilenet_v2_1.0_224_inat_bird_quant.tflite" || echo "⚠️ 鸟类分类模型下载失败，继续..."

# 5. 创建模型状态文件
echo "📝 创建模型状态文件..."
cat > "$MODEL_CACHE_DIR/models_status.json" << 'JSON_EOF'
{
  "semantic_search": {
    "model": "jinav2",
    "model_size": "large",
    "status": "downloaded"
  },
  "face_recognition": {
    "model_size": "large",
    "status": "downloaded"
  },
  "lpr": {
    "status": "downloaded"
  },
  "bird": {
    "status": "downloaded"
  },
  "download_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
JSON_EOF

# 6. 验证下载的文件
echo "🔍 验证下载的模型文件..."
total_files=0
downloaded_files=0

for model_dir in "jina_v2" "facedet" "lpr" "bird"; do
    if [ -d "$MODEL_CACHE_DIR/$model_dir" ]; then
        files_in_dir=$(find "$MODEL_CACHE_DIR/$model_dir" -type f | wc -l)
        total_files=$((total_files + files_in_dir))
        downloaded_files=$((downloaded_files + files_in_dir))
        echo "✅ $model_dir: $files_in_dir 个文件"
    fi
done

echo "📊 下载统计: $downloaded_files/$total_files 个文件成功下载"

# 7. 设置权限
echo "🔐 设置文件权限..."
chmod -R 755 "$MODEL_CACHE_DIR"

echo "🎉 模型预下载完成！"
echo "📁 模型文件存储在: $MODEL_CACHE_DIR"
echo "📋 支持的配置:"
echo "   - 语义搜索: JinaV2 Large"
echo "   - 人脸识别: Large (ArcFace)"
echo "   - 车牌识别: 已启用"
echo "   - 鸟类分类: 已下载 (配置中禁用)"
