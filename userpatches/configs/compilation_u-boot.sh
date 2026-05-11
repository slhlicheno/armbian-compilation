#!/bin/bash
# userpatches/lib/compilation_u-boot.sh
# 智能多设备 U-Boot 注入与写入引擎 - 支持厂商/设备层级目录

# ==========================================
# 1. 劫持编译过程
# ==========================================
function compile_u-boot() {
    display_alert "⚠️ U-Boot Compilation Hijacked" "Using pre-compiled binaries for ${BOARD}" "wrn"

    # 安全校验：是否在 conf 文件中定义了厂商变量
    if [[ -z "${BOX_SOC_FAMILY}" ]]; then
        display_alert "❌ FATAL ERROR" "BOX_SOC_FAMILY is not defined in config-${BOARD}.conf" "err"
        exit 1
    fi

    # 🚨 核心修改：路径改为 u-boot/厂商/设备名/
    local uboot_src_dir="${SRC}/userpatches/u-boot/${BOX_SOC_FAMILY}/${BOARD}"
    
    if [[ ! -d "${uboot_src_dir}" ]]; then
        display_alert "❌ FATAL ERROR" "U-Boot folder not found\nExpected at: ${uboot_src_dir}" "err"
        exit 1
    fi

    local files_to_inject=()
    local soc_type=""
    
    # 智能检测机制：尝试多种可能的文件名
    if [[ -f "${uboot_src_dir}/u-boot-${BOARD}.bin" ]]; then
        files_to_inject=("u-boot-${BOARD}.bin")
        soc_type="amlogic"
    elif [[ -f "${uboot_src_dir}/u-boot.bin" ]]; then
        files_to_inject=("u-boot.bin")
        soc_type="amlogic"
    elif [[ -f "${uboot_src_dir}/idbloader.img" ]]; then
        display_alert "Detected SoC Type" "Rockchip (RK)" "info"
        files_to_inject=("idbloader.img" "u-boot.itb")
        [[ -f "${uboot_src_dir}/trust.bin" ]] && files_to_inject+="trust.bin"
        soc_type="rockchip"
        
        for f in "${files_to_inject[@]}"; do
            if [[ ! -f "${uboot_src_dir}/${f}" ]]; then
                display_alert "❌ FATAL ERROR" "Rockchip requires specific files, missing: ${f}" "err"
                exit 1
            fi
        done
        
    elif [[ -f "${uboot_src_dir}/u-boot-sunxi-with-spl.bin" ]]; then
        display_alert "Detected SoC Type" "Allwinner (Sunxi)" "info"
        files_to_inject=("u-boot-sunxi-with-spl.bin")
        soc_type="allwinner"
        
    else
        display_alert "❌ FATAL ERROR" "No known U-Boot files found in ${uboot_src_dir}" "err"
        exit 1
    fi

    # 记录 SoC 类型供写入函数使用
    echo "${soc_type}" > "${SRC}/.soc_type_hijack_tmp"

    # 欺骗缓存和输出目录
    local uboot_cache_dir="${SRC}/cache/sources/u-boot/${BOOTSOURCEDIR}"
    mkdir -p "${uboot_cache_dir}"

    local uboot_output_dir="${SRC}/output/u-boot/${BOARD}/${BRANCH}"
    mkdir -p "${uboot_output_dir}"

    for file in "${files_to_inject[@]}"; do
        display_alert "Injecting" "${file}" "ext"
        cp -f "${uboot_src_dir}/${file}" "${uboot_cache_dir}/${file}"
        cp -f "${uboot_src_dir}/${file}" "${uboot_output_dir}/${file}"
    done

    display_alert "✅ U-Boot Injection Complete" "${BOARD} is ready for packing" "info"
    return 0
}

# ==========================================
# 2. 劫持写入过程
# ==========================================
function write_uboot_platform() {
    local dest=$1
    local dir=$2 
    
    if [[ ! -f "${SRC}/.soc_type_hijack_tmp" ]]; then
        display_alert "❌ FATAL ERROR" "Cannot determine SoC type for DD write!" "err"
        exit 1
    fi

    local soc_type=$(cat "${SRC}/.soc_type_hijack_tmp")

    display_alert "⚠️ U-Boot Write Hijacked" "Writing pre-compiled U-Boot to image" "wrn"

    if [[ "${soc_type}" == "amlogic" ]]; then
        # 检查写入的文件名
        local uboot_file=$(ls "${dir}" | grep -E "u-boot-${BOARD}\.bin|u-boot\.bin" | head -n 1)
        if [[ -z "${uboot_file}" ]]; then
            display_alert "❌ FATAL ERROR" "U-Boot file not found for write" "err"
            exit 1
        fi
        dd if="${dir}/${uboot_file}" of="${dest}" bs=512 seek=1 conv=notrunc status=progress
        
    elif [[ "${soc_type}" == "rockchip" ]]; then
        dd if="${dir}/idbloader.img" of="${dest}" bs=512 seek=64 conv=notrunc status=progress
        dd if="${dir}/u-boot.itb" of="${dest}" bs=512 seek=16384 conv=notrunc status=progress
        if [[ -f "${dir}/trust.bin" ]]; then
            dd if="${dir}/trust.bin" of="${dest}" bs=512 seek=24576 conv=notrunc status=progress
        fi
        
    elif [[ "${soc_type}" == "allwinner" ]]; then
        dd if="${dir}/u-boot-sunxi-with-spl.bin" of="${dest}" bs=1024 seek=8 conv=notrunc status=progress
        
    else
        display_alert "❌ FATAL ERROR" "Unknown SoC type for write: ${soc_type}" "err"
        exit 1
    fi
}
