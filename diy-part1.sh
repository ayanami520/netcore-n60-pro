#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default

# Add ADGuardHome source
# 说明：
#   1) luci-app-adguardhome 只是「界面 + 控制脚本」，本身不含 AdGuardHome 核心
#      （核心需另行下载 arm64 版本），所以克隆源码并不会明显增大固件体积。
#   2) 但若当前配置并未启用 luci-app-adguardhome，这次克隆纯属浪费，
#      而且原写法一旦外部仓库不可达，chmod 会失败并让整个编译在第一步挂掉。
#   3) 因此改为「按当前 CONFIG_FILE 按需克隆 + 失败不致命 + 清理残留」。
ADG_CFG="${GITHUB_WORKSPACE:-.}/${CONFIG_FILE:-}"
if [ -n "${CONFIG_FILE:-}" ] && [ -f "$ADG_CFG" ] && grep -q '^CONFIG_PACKAGE_luci-app-adguardhome=y' "$ADG_CFG"; then
	echo "[diy-1] 当前配置启用了 luci-app-adguardhome，开始克隆源码 ..."
	if git clone --depth 1 https://github.com/rufengsuixing/luci-app-adguardhome package/luci-app-adguardhome; then
		chmod -R 755 ./package/luci-app-adguardhome/* 2>/dev/null || true
		echo "[diy-1] ADGuardHome 源码克隆完成"
	else
		echo "[diy-1] !! 警告：ADGuardHome 源码克隆失败（网络问题？），已跳过，不影响编译"
		rm -rf package/luci-app-adguardhome
	fi
else
	echo "[diy-1] 当前配置未启用 luci-app-adguardhome（CONFIG_FILE=${CONFIG_FILE:-未知}），已跳过源码克隆"
fi
