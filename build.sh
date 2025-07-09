#!/bin/sh
# Skrip untuk Kompilasi Kernel
# Copyright (c) Mahiroo aka Yudaa

# ============================
# Setup
# ============================
PHONE="Surya"
DEFCONFIG="surya_defconfig"
CLANG="Neutron Clang 19"
ZIPNAME="Test-$(date '+%Y%m%d-%H%M').zip"
BOT_TOKEN="7485743487:AAEKPw9ubSKZKit9BDHfNJSTWcWax4STUZs"
CHAT_ID="-1002354747626"

# ============================
# Variabel untuk pengiriman info
# ============================
DEVICE="Poco X3 NFC"
DISTRO="$(lsb_release -d | awk -F'\t' '{print $2}')"
PARSE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
COMMIT_POINT="$(git rev-parse HEAD)"
CPU_NAME="$(lscpu | grep 'Model name' | awk -F': ' '{print $2}')"
PROCS="$(nproc --all)"
TOTAL_RAM_GB="$(free -g | awk '/^Mem:/{print $2}')"
DATE="$(date '+%Y-%m-%d %H:%M:%S')"
MESSAGE_ERROR="Error Build untuk $PHONE Dibatalkan!"
kernel="out/arch/arm64/boot/Image.gz"
dtb="out/arch/arm64/boot/dtb.img"
dtbo="out/arch/arm64/boot/dtbo.img"
export KBUILD_BUILD_USER="Mahiroo"
export KBUILD_BUILD_HOST="HiraTeam"

# ============================
# Warna output
# ============================
cyan="\033[96m"
green="\033[92m"
red="\033[91m"
blue="\033[94m"
reset="\033[0m"

# ============================
# Fungsi instalasi dependensi
# ============================
function install_dependencies() {
    echo -e "${cyan}==> Memulai instalasi dependensi build kernel...${reset}"
    sudo apt update
    sudo apt install -y bc cpio flex bison aptitude git python-is-python3 tar aria2 perl wget curl lz4 libssl-dev device-tree-compiler
    if [ $? -ne 0 ]; then
        echo -e "${red}[!] Instalasi dependensi gagal!${reset}"
        exit 1
    fi
    echo -e "${green}[+] Instalasi dependensi selesai.${reset}\n"
}

# ============================
# Fungsi kirim pesan Telegram
# ============================
function tg_channelcast() {
    local msg=""
    for POST in "$@"; do
        msg+="${POST}"$'\n'
    done
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d disable_web_page_preview=true \
        -d parse_mode=HTML \
        -d text="${msg}"
}

# ============================
# Kirim pesan awal build
# ============================
function send_initial_message() {
    tg_channelcast \
        "🚀 <b>Kernel Build Dimulai!</b>" \
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" \
        "📱 <b>Device :</b> <code>$DEVICE</code>" \
        "🖥️ <b>Host OS :</b> <code>$DISTRO</code>" \
        "🛠️ <b>Compiler :</b> <code>$CLANG</code>" \
        "🐧 <b>Kernel Version :</b> <code>$(make kernelversion)</code>" \
        "🌿 <b>Git Branch :</b> <code>$PARSE_BRANCH</code>" \
        "📝 <b>Git Commit :</b> $COMMIT_POINT" \
        "⚙️ <b>CPU Info :</b> <code>$CPU_NAME ($PROCS cores)</code>" \
        "🧠 <b>RAM :</b> <code>$TOTAL_RAM_GB GB</code>" \
        "🏷️ <b>Builder :</b> <code>mahiroo@hirateam</code>" \
        "📅 <b>Date :</b> <code>$DATE</code>" \
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" \
        "⌛️ Proses build sedang berjalan... Mohon tunggu hingga selesai."
}

# ============================
# Bersihkan log dan output lama
# ============================
function clean() {
    echo -e "\n${red}[!] MEMBERSIHKAN...${reset}"
    rm -rf log.txt full-build.log out/full_defconfig "$ZIPNAME"
}

# ============================
# Bersihkan folder out sebelum build
# ============================
function clean_out_dir() {
    echo -e "${red}[!] Membersihkan folder out sebelum build...${reset}"
    if [ -d out ]; then
        rm -rf out/*
    else
        mkdir out
    fi
}

# ============================
# Hapus file zip dan log setelah build (success/fail)
# ============================
function cleanup_files() {
    echo -e "${red}[!] Menghapus file ZIP dan log setelah build...${reset}"
    [ -f "$ZIPNAME" ] && rm -f "$ZIPNAME"
    rm -f full-build.log log.txt
    rm -f out/full_defconfig
}

# ============================
# Cek dan clone clang jika belum ada
# ============================
function clang() {
    mkdir -p clang && cd clang || exit 1

    curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
    chmod +x antman
    ./antman -S
    ./antman --patch=glibc
    cd .. || exit 1

    git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 gcc64
    git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 gcc32

    export CLANG_DIR="${PWD}/clang"
    export COMPILER_STRING="$(${CLANG_DIR}/bin/clang --version | head -n 1)"

    if ! command -v "${CLANG_DIR}/bin/clang" >/dev/null 2>&1; then
        echo "❌ Clang not found! Exiting..."
        exit 1
    fi
}

# ============================
# Build kernel
# ============================
function build_kernel() {
    clean_out_dir

    export PATH="${PWD}/clang/bin:${PWD}/gcc64/bin:${PWD}/gcc32/bin:$PATH"

    echo -e "${cyan}==> Menyiapkan defconfig...${reset}"
    if ! make -j"$PROCS" O=out ARCH=arm64 "$DEFCONFIG"; then
        echo -e "\n${red}[!] Gagal saat menyiapkan defconfig.${reset}"
        send_log
        cleanup_files
        return 1
    fi

    echo -e "\n${green}=============================================${reset}"
    echo -e "${green}===> Memulai proses build kernel dengan $PROCS core${reset}"
    echo -e "=============================================${reset}\n"

    make -j"$PROCS" \
        O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        AR=llvm-ar \
        NM=llvm-nm \
        LD=ld.lld \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CC=clang \
        DTC_EXT=dtc \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- 2>&1 | tee full-build.log

    grep -Ei "(error|warning)" full-build.log > log.txt

    if grep -q "error:" full-build.log; then
        echo -e "\n${red}[!] Build gagal, mengirim log error...${reset}"
        send_log
        cleanup_files
        return 1
    fi

    if [ ! -f out/arch/arm64/boot/Image ]; then
        echo -e "\n${red}[!] Build gagal, file Image tidak ditemukan!${reset}"
        send_log
        cleanup_files
        return 1
    fi

    echo -e "\n${green}=============================================${reset}"
    echo -e "${green}[+] Build kernel berhasil! Mengompres dan menyiapkan ZIP...${reset}"
    echo -e "=============================================${reset}\n"

    if [ ! -d "AnyKernel3" ]; then
        git clone -q https://github.com/rinnsakaguchi/AnyKernel3.git -b FSociety
    fi

    cp -f "$kernel" "$dtb" "$dtbo" AnyKernel3/
    cd AnyKernel3 || return 1

    zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
    cd .. || exit 1
    rm -rf AnyKernel3

    echo -e "${green}=============================================${reset}"
    echo -e "${green}[+] Meregenerasi full_defconfig...${reset}"
    echo -e "=============================================${reset}"
    make O=out ARCH=arm64 savedefconfig
    mv -f out/defconfig out/full_defconfig

    echo -e "${green}==========================${reset}"
    echo -e "${green} Build selesai dengan sukses!${reset}"
    echo -e "${green} Device     : $PHONE${reset}"
    echo -e "${green} Defconfig  : $DEFCONFIG${reset}"
    echo -e "${green} Toolchain  : $CLANG${reset}"
    echo -e "${green} Zipname    : $ZIPNAME${reset}"
    echo -e "${green} Durasi     : $((SECONDS / 60)) menit $((SECONDS % 60)) detik${reset}"
    echo -e "${green}==========================${reset}"

    upload_zip
    upload_fullbuild_log
    upload_defconfig

    cleanup_files
}

# ============================
# Upload kernel ZIP ke Telegram tanpa caption
# ============================
function upload_zip() {
    echo -e "${green}=============================================${reset}"
    echo -e "${green}[+] Mengunggah ZIP kernel...${reset}"
    echo -e "=============================================${reset}"

    local url="https://api.telegram.org/bot${BOT_TOKEN}/sendDocument"
    curl -s -X POST "${url}" -F document=@"${ZIPNAME}" -F chat_id="${CHAT_ID}" > /dev/null
}

# ============================
# Upload full-build.log ke Telegram dengan caption
# ============================
function upload_fullbuild_log() {
    echo -e "${green}=============================================${reset}"
    echo -e "${green}[+] Mengunggah full-build.log...${reset}"
    echo -e "=============================================${reset}"

    local url="https://api.telegram.org/bot${BOT_TOKEN}/sendDocument"
    curl -s -X POST "${url}" -F document=@"full-build.log" -F caption="Full Build Log - Versi: ${ZIPNAME}" -F chat_id="${CHAT_ID}" > /dev/null
}

# ============================
# Upload defconfig dengan nama surya_defconfig
# ============================
function upload_defconfig() {
    if [ -f out/full_defconfig ]; then
        echo -e "${green}=============================================${reset}"
        echo -e "${green}[+] Mengunggah surya_defconfig...${reset}"
        echo -e "=============================================${reset}"

        cp out/full_defconfig surya_defconfig

        local url="https://api.telegram.org/bot${BOT_TOKEN}/sendDocument"
        curl -s -X POST "${url}" -F document=@"surya_defconfig" -F caption="Full Defconfig - Versi: ${ZIPNAME}" -F chat_id="${CHAT_ID}" > /dev/null

        rm -f surya_defconfig
    else
        echo -e "${red}[!] full_defconfig tidak ditemukan, gagal mengunggah.${reset}"
    fi
}

# Kirim log error/warning saat build gagal
function send_log() {
    local file="log.txt"
    local url="https://api.telegram.org/bot${BOT_TOKEN}/sendDocument"
    echo -e "${red}[!] Mengirim log error/warning ke Telegram...${reset}"
    curl -s -F "chat_id=${CHAT_ID}" -F "document=@${file}" -F "caption=${MESSAGE_ERROR}" "${url}" > /dev/null
}

# ============================
# Eksekusi utama
# ============================
install_dependencies
clean
clang
send_initial_message
build_kernel
