#!/bin/bash
set -e  # 遇到错误时立即退出

# 检测操作系统发行版
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
else
    echo "错误：无法检测操作系统发行版，请确保运行在Ubuntu/Debian系统上"
    exit 1
fi

# 更新包列表
echo "正在更新包列表..."
sudo apt-get update -qq

# 安装基础构建工具和依赖
echo "正在安装基础构建工具..."
sudo apt-get install -y -qq \
    git \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libncurses5-dev \
    bc \
    u-boot-tools \
    device-tree-compiler \
    libgpiod-dev \
    python3-pip \
    wget \
    curl \
    unzip \
    sudo \
    locales \
    ca-certificates

# 根据发行版安装特定依赖
case $DISTRO in
    ubuntu)
        echo "检测到Ubuntu系统，安装Ubuntu特定依赖..."
        sudo apt-get install -y -qq \
            libelf-dev \
            libudev-dev \
            libpci-dev \
            libusb-1.0-0-dev \
            pkg-config
        ;;
    debian)
        echo "检测到Debian系统，安装Debian特定依赖..."
        sudo apt-get install -y -qq \
            libelf-dev \
            libudev-dev \
            libpci-dev \
            libusb-1.0-0-dev \
            pkg-config
        ;;
    *)
        echo "错误：不支持的发行版 $DISTRO"
        exit 1
        ;;
esac

# 安装Python依赖（用于Armbian构建脚本）
echo "正在安装Python依赖..."
python3 -m pip install --upgrade pip -qq
python3 -m pip install --user -qq \
    pyyaml \
    requests \
    gitpython

# 清理包缓存
sudo apt-get clean -qq

echo "✅ 依赖安装完成！"
