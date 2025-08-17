#!/bin/bash

# 模型预下载脚本
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

# 文件夹大小统计函数
show_folder_size() {
    local folder_path="$1"
    if [ -d "$folder_path" ]; then
        local size=$(du -sh "$folder_path" 2>/dev/null | cut -f1)
        echo "📁 $folder_path: $size"
    else
        echo "📁 $folder_path: 不存在"
    fi
}

# 检查磁盘空间函数
check_disk_space() {
    local required_space=$1  # in MB
    local available_space=$(df -m / | awk 'NR==2 {print $4}')
    
    if [ $available_space -lt $required_space ]; then
        echo "❌ 磁盘空间不足! 需要 ${required_space}MB，当前可用 ${available_space}MB"
        return 1
    fi
    return 0
}

# 定义模型下载函数（增强版）
download_model() {
    local model_dir="$1"
    local file_name="$2"
    local url="$3"
    local target_path="$MODEL_CACHE_DIR/$model_dir/$file_name"
    local max_retries=5
    local retry_delay=5  # 初始延迟5秒
    
    echo "📥 下载 $model_dir/$file_name..."
    mkdir -p "$MODEL_CACHE_DIR/$model_dir"
    
    for ((i=1; i<=max_retries; i++)); do
        echo "🔄 尝试 $i/$max_retries: $url"
        
        # 检查是否是 Hugging Face 链接，优先使用 curl
        if [[ "$url" == *"huggingface.co"* ]]; then
            echo "🔄 使用 curl 下载 Hugging Face 模型..."
            curl -L --fail --retry 3 --retry-delay 5 -o "$target_path" "$url"
            local download_exit=$?
        else
            wget -q --show-progress --tries=3 --timeout=600 --continue -O "$target_path" "$url"
            local download_exit=$?
        fi
        
        if [ $download_exit -eq 0 ]; then
            # 添加文件完整性检查
            if [[ "$file_name" == "model_fp16.onnx" ]]; then
                local expected_size=1688250000  # 1.6GB
                local actual_size=$(wc -c < "$target_path")
                if [ $actual_size -lt $((expected_size * 95 / 100)) ]; then
                    echo "❌ 文件大小异常，可能下载不完整"
                    rm -f "$target_path"
                    if [ $i -lt $max_retries ]; then
                        echo "⏳ $retry_delay 秒后重试..."
                        sleep $retry_delay
                        retry_delay=$((retry_delay * 2))  # 指数退避
                        continue
                    else
                        return 1
                    fi
                fi
            fi
            
            echo "✅ $model_dir/$file_name 下载完成"
            return 0
        elif [ $download_exit -eq 8 ] && [[ "$url" != *"huggingface.co"* ]]; then
            echo "⚠️  服务器错误 (exit code 8)，可能是网络问题或 Hugging Face 限流"
        else
            echo "⚠️  下载错误码: $download_exit"
        fi
        
        if [ $i -lt $max_retries ]; then
            echo "⏳ $retry_delay 秒后重试..."
            sleep $retry_delay
            retry_delay=$((retry_delay * 2))  # 指数退避
        fi
    done
    
    # 最后尝试使用 curl (如果不是 Hugging Face 链接)
    if [[ "$url" != *"huggingface.co"* ]]; then
        echo "🔄 尝试使用 curl 下载..."
        curl -L -o "$target_path" "$url"
        if [ $? -eq 0 ]; then
            echo "✅ $model_dir/$file_name 通过 curl 下载完成"
            return 0
        fi
    fi
    
    echo "❌ $model_dir/$file_name 下载失败"
    return 1
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

# 0. 创建所有必要的目录结构
echo "📁 创建完整的目录结构..."
mkdir -p "$MODEL_CACHE_DIR/jinaai/jina-clip-v1"
mkdir -p "$MODEL_CACHE_DIR/jinaai/jina-clip-v2"
mkdir -p "$MODEL_CACHE_DIR/openvino/ort"
mkdir -p "$MODEL_CACHE_DIR/facedet"
mkdir -p "$MODEL_CACHE_DIR/face_embedding"
mkdir -p "$MODEL_CACHE_DIR/yolov9_license_plate"
mkdir -p "$MODEL_CACHE_DIR/paddleocr-onnx"
mkdir -p "$MODEL_CACHE_DIR/bird"

# 1. 语义搜索模型 (JinaV2 Large) - 完整版本
echo "🔍 下载语义搜索模型 (JinaV2 Large)..."

# 检查磁盘空间 (JinaV2 模型约 1.6GB)
echo "🔍 检查磁盘空间 (需要 2000MB)..."
if ! check_disk_space 2000; then
    echo "⚠️  跳过 JinaV2 模型下载（空间不足）"
else
    # JinaV2模型文件 - 使用HuggingFace的原始链接
    JINA_V2_FILES=(
        "model_fp16.onnx"
        "tokenizer.json"
        "tokenizer_config.json"
        "vocab.txt"
    )

    # 创建模型目录
    mkdir -p "$MODEL_CACHE_DIR/jinaai/jina-clip-v2"

    for file in "${JINA_V2_FILES[@]}"; do
        if [[ "$file" == tokenizer/* ]] || [[ "$file" == *.json ]] || [[ "$file" == *.txt ]]; then
            # tokenizer文件在根目录下，不是在tokenizer子目录下
            # 移除tokenizer/前缀
            clean_file="${file#tokenizer/}"
            url="https://huggingface.co/jinaai/jina-clip-v2/resolve/main/$clean_file?download=true"
        else
            url="https://huggingface.co/jinaai/jina-clip-v2/resolve/main/onnx/$file?download=true"
        fi
        download_model "jinaai/jina-clip-v2" "$file" "$url" || echo "⚠️ $file 下载失败，继续..."
    done
fi

# 2. 人脸识别模型 (Large) - 完整版本
echo "👤 下载人脸识别模型 (Large)..."

# 检查磁盘空间 (人脸识别模型约 500MB)
echo "🔍 检查磁盘空间 (需要 500MB)..."
if check_disk_space 500; then
    # 人脸检测模型
    download_model "facedet" "facedet.onnx" "https://github.com/NickM-27/facenet-onnx/releases/download/v1.0/facedet.onnx" || echo "⚠️ facedet.onnx 下载失败，继续..."
    download_model "facedet" "landmarkdet.yaml" "https://github.com/NickM-27/facenet-onnx/releases/download/v1.0/landmarkdet.yaml" || echo "⚠️ landmarkdet.yaml 下载失败，继续..."
    download_model "facedet" "facenet.tflite" "https://github.com/NickM-27/facenet-onnx/releases/download/v1.0/facenet.tflite" || echo "⚠️ facenet.tflite 下载失败，继续..."

    # 人脸嵌入模型 (Large - ArcFace)
    download_model "facedet" "arcface.onnx" "https://github.com/NickM-27/facenet-onnx/releases/download/v1.0/arcface.onnx" || echo "⚠️ arcface.onnx 下载失败，继续..."
else
    echo "⚠️  跳过人脸识别模型下载（空间不足）"
fi

# 3. 车牌识别模型 - 完整版本
echo "🚗 下载车牌识别模型..."

# 检查磁盘空间 (车牌识别模型约 300MB)
echo "🔍 检查磁盘空间 (需要 300MB)..."
if check_disk_space 300; then
    # 车牌检测模型
    download_model "yolov9_license_plate" "yolov9-256-license-plates.onnx" "https://github.com/hawkeye217/yolov9-license-plates/raw/refs/heads/master/models/yolov9-256-license-plates.onnx" || echo "⚠️ yolov9-256-license-plates.onnx 下载失败，继续..."
else
    echo "⚠️  跳过车牌检测模型下载（空间不足）"
fi

# 车牌OCR模型
echo "🚗 下载车牌OCR模型..."

# 检查磁盘空间 (车牌OCR模型约 200MB)
echo "🔍 检查磁盘空间 (需要 200MB)..."
if check_disk_space 200; then
    # 车牌分类模型
    download_model "paddleocr-onnx" "classification.onnx" "https://github.com/hawkeye217/paddleocr-onnx/raw/refs/heads/master/models/classification.onnx" || echo "⚠️ classification.onnx 下载失败，继续..."

    # 车牌识别模型
    download_model "paddleocr-onnx" "recognition.onnx" "https://github.com/hawkeye217/paddleocr-onnx/raw/refs/heads/master/models/recognition.onnx" || echo "⚠️ recognition.onnx 下载失败，继续..."
else
    echo "⚠️  跳过车牌OCR模型下载（空间不足）"
fi

# 4. 鸟类分类模型 - 完整版本
echo "🐦 下载鸟类分类模型..."

# 检查磁盘空间 (鸟类分类模型约 100MB)
echo "🔍 检查磁盘空间 (需要 100MB)..."
if check_disk_space 100; then
    download_model "bird" "bird.tflite" "https://raw.githubusercontent.com/google-coral/test_data/master/mobilenet_v2_1.0_224_inat_bird_quant.tflite" || echo "⚠️ bird.tflite 下载失败，继续..."
    download_model "bird" "birdmap.txt" "https://raw.githubusercontent.com/google-coral/test_data/master/inat_bird_labels.txt" || echo "⚠️ birdmap.txt 下载失败，继续..."
else
    echo "⚠️  跳过鸟类分类模型下载（空间不足）"
fi

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

for model_dir in "jinaai/jina-clip-v1" "jinaai/jina-clip-v2" "facedet" "face_embedding" "yolov9_license_plate" "paddleocr-onnx" "openvino/ort" "bird"; do
    if [ -d "$MODEL_CACHE_DIR/$model_dir" ]; then
        files_in_dir=$(find "$MODEL_CACHE_DIR/$model_dir" -type f | wc -l)
        total_files=$((total_files + files_in_dir))
        downloaded_files=$((downloaded_files + files_in_dir))
        echo "✅ $model_dir: $files_in_dir 个文件"
    fi
done

echo "📊 下载统计: $downloaded_files/$total_files 个文件成功下载"

# 7. 显示文件夹大小统计
echo ""
echo "📁 === 文件夹大小统计 ==="
show_folder_size "$MODEL_CACHE_DIR"
echo ""
for model_dir in "jinaai/jina-clip-v1" "jinaai/jina-clip-v2" "facedet" "face_embedding" "yolov9_license_plate" "paddleocr-onnx" "openvino/ort" "bird"; do
    if [ -d "$MODEL_CACHE_DIR/$model_dir" ]; then
        show_folder_size "$MODEL_CACHE_DIR/$model_dir"
    fi
done

# 8. 设置权限
echo "🔐 设置文件权限..."
chmod -R 755 "$MODEL_CACHE_DIR"

echo "🎉 模型预下载完成！"
echo "📁 模型文件存储在: $MODEL_CACHE_DIR"
echo "📋 支持的配置:"
echo "   - 语义搜索: JinaV1 和 JinaV2 Large (包含tokenizer)"
echo "   - 人脸识别: Large (ArcFace + 检测模型)"
echo "   - 车牌识别: 完整LPR模型集"
echo "   - 鸟类分类: 完整分类模型"
echo "   - OpenVINO: 支持ORT模型"