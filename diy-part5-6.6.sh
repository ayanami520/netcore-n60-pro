#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part5-6.6.sh
# Description: OpenWrt DIY script part 5 (After Update feeds)
#
# 针对 磊科 N60 Pro + padavanonly(237) 闭源驱动源码 的定制脚本
# 由 CodeBuddy 根据用户选择生成：
#   [开关 0] 默认 LAN 地址      -> 192.168.6.1        【已启用】
#   [开关 1] 默认主题 argon     -> 不启用
#   [开关 2] ubi 分区          -> 120 MiB => 128 MiB  【已启用，追回 8 MiB】
#   [开关 3] 组播防火墙规则     -> 保留模板原有功能     【已启用】
#   [开关 4] 关闭 dnsmasq DNS 重定向                    【已启用】
#   [开关 5] 软件源            -> 南京大学镜像（CERNET 成员）【已启用】
#
# 工作目录：脚本由 workflow 在 openwrt/ 目录下执行
#

set -e

echo "============================================================"
echo " diy-part5-6.6.sh 开始执行（CWD = $(pwd)）"
echo "============================================================"

# ============================================================
# 开关 0：默认 LAN 地址改成 192.168.6.1
#   原因：官方默认 192.168.1.1 会和上游光猫撞网段
# ============================================================
echo "[diy-0] 修改默认 LAN 地址为 192.168.6.1 ..."
if [ -f package/base-files/files/bin/config_generate ]; then
	sed -i 's/192\.168\.1\.1/192.168.6.1/g' package/base-files/files/bin/config_generate
	echo "[diy-0] 结果：$(grep -n 'lan) ipad=' package/base-files/files/bin/config_generate || echo '未找到目标行，请检查')"
else
	echo "[diy-0] !! 警告：config_generate 不存在，LAN 地址未修改"
fi

# ============================================================
# 开关 1：默认主题（未启用）
# ============================================================
# sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# ============================================================
# 开关 2：★ ubi 分区 120 MiB -> 128 MiB，追回被浪费的 8 MiB
#   已核对源码实际写法：reg = <0x0580000 0x7280000>;   （注意不是 0x07280000）
#   目标：             reg = <0x0580000 0x7a80000>;   （与官方 ImmortalWrt 一致）
# ============================================================
DTS=target/linux/mediatek/dts/mt7986a-netcore-n60-pro.dts
echo "[diy-2] 检查 ubi 分区 ($DTS) ..."
if [ ! -f "$DTS" ]; then
	echo "[diy-2] !! 警告：设备树文件不存在，分区未改动"
elif grep -q '0x7280000' "$DTS"; then
	sed -i 's/0x7280000/0x7a80000/' "$DTS"
	echo "[diy-2] 已把 ubi 分区扩容到 128 MiB"
elif grep -q '0x7a80000' "$DTS"; then
	echo "[diy-2] ubi 分区已经是 128 MiB，跳过"
else
	echo "[diy-2] !! 警告：没找到 0x7280000，分区未改动！请人工检查设备树"
fi
echo "[diy-2] 当前分区定义："
grep -n -A3 'partition@580000' "$DTS" || true

# ============================================================
# 开关 3：组播防火墙规则（模板原有功能，保留）
# ============================================================
echo "[diy-3] 追加组播防火墙规则 ..."
cat >> package/network/config/firewall/files/firewall.config <<'FIREWALLEOF'

config rule
        option name 'Allow-UDP-igmpproxy'
        option src 'wan'
        option dest 'lan'
        option dest_ip '224.0.0.0/4'
        option proto 'udp'
        option target 'ACCEPT'
        option family 'ipv4'

config rule
        option name 'Allow-UDP-udpxy'
        option src 'wan'
        option dest_ip '224.0.0.0/4'
        option proto 'udp'
        option target 'ACCEPT'
FIREWALLEOF

# ============================================================
# 开关 4：关闭 dnsmasq 的 DNS 重定向
#   官方默认 dns_redirect='1'，会和 homeproxy 的 DNS 劫持冲突
#   写成 uci-defaults，首次启动自动生效
# ============================================================
echo "[diy-4] 写入 uci-defaults（关闭 DNS 重定向）..."
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-disable-dns-redirect <<'UCIEOF'
#!/bin/sh
# 关闭 dnsmasq 的 DNS 重定向，避免与 homeproxy 的 DNS 劫持冲突
uci -q set dhcp.@dnsmasq[0].dns_redirect='0'
uci -q commit dhcp
exit 0
UCIEOF
chmod 0755 package/base-files/files/etc/uci-defaults/99-disable-dns-redirect

# ============================================================
# 开关 5：固定/加速软件源
#
# 说明：
#   · CERNET 总站(mirrors.cernet.edu.cn) 只镜像 release，不镜像 24.10-SNAPSHOT，
#     故改用 CERNET 成员镜像 —— 南京大学（实测 6 条源全部可用）。
#   · 本固件由 openwrt-24.10-6.6 分支编译，属于 24.10-SNAPSHOT 系，
#     因此这里指向 SNAPSHOT 而不是某个 release（release 的内核 ABI 不匹配）。
#   · 想要真正"永不漂移"，用本仓库 workflow 产出的 bin/ 软件包仓库
#     放到 NAS 上用 nginx 托管，再把下面地址换成你的 NAS 地址。
# ============================================================
echo "[diy-5] 写入软件源配置 ..."
mkdir -p files/etc/opkg
cat > files/etc/opkg/distfeeds.conf <<'FEEDSEOF'
src/gz immortalwrt_core      https://mirror.nju.edu.cn/immortalwrt/releases/24.10-SNAPSHOT/targets/mediatek/filogic/packages
src/gz immortalwrt_base      https://mirror.nju.edu.cn/immortalwrt/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/base
src/gz immortalwrt_luci      https://mirror.nju.edu.cn/immortalwrt/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/luci
src/gz immortalwrt_packages  https://mirror.nju.edu.cn/immortalwrt/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/packages
src/gz immortalwrt_routing   https://mirror.nju.edu.cn/immortalwrt/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/routing
src/gz immortalwrt_telephony https://mirror.nju.edu.cn/immortalwrt/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/telephony
FEEDSEOF
echo "[diy-5] 软件源内容："
cat files/etc/opkg/distfeeds.conf

echo "============================================================"
# ============================================================
# 开关 6：★ 去掉 helloworld 源对 mihomo / v2ray-geoip 的强制依赖
#
#   背景：helloworld 源的 feeds/helloworld/luci-app-ssr-plus/Makefile 里有：
#
#       config PACKAGE_luci-app-ssr-plus_INCLUDE_Mihomo
#           bool "Include Mihomo (Clash Support)"
#           select PACKAGE_mihomo
#           select PACKAGE_v2ray-geoip
#           default y if aarch64||arm||i386||loongarch64||riscv64||x86_64
#
#   因为本机是 aarch64 且该选项默认 y，Kconfig 的 select 会强制把
#   mihomo（Clash Meta 内核，约 6-11 MiB）和 v2ray-geoip（geoip 库，约 5 MiB）
#   编进固件 —— 哪怕我们根本没选 luci-app-ssr-plus。
#   select 无法用 .config 覆盖（写 is not set 无效），只能直接删掉 feed 里的 select。
#
#   安全性：luci-app-homeproxy 的依赖只有 sing-box / firewall4 /
#           kmod-nft-tproxy / ucode-mod-digest，不含 v2ray-geoip；
#           homeproxy 运行时用自己下载的 .srs 规则集，不读 /usr/share/v2ray/geoip.dat。
#           因此删除这两项不影响科学上网功能。
#
#   时机：本脚本在 feeds update / install 之后执行，所以 Makefile 必然存在。
# ============================================================
echo "[diy-6] 移除 helloworld 源对 mihomo / v2ray-geoip 的强制 select ..."
SSRPLUS_MK=feeds/helloworld/luci-app-ssr-plus/Makefile
if [ -f "$SSRPLUS_MK" ]; then
	sed -i '/^[[:space:]]*select PACKAGE_mihomo[[:space:]]*$/d' "$SSRPLUS_MK" || true
	sed -i '/^[[:space:]]*select PACKAGE_v2ray-geoip[[:space:]]*$/d' "$SSRPLUS_MK" || true
	echo "[diy-6] 剩余匹配行数（期望 0）：$(grep -c 'select PACKAGE_mihomo\|select PACKAGE_v2ray-geoip' "$SSRPLUS_MK" || true)"
	if grep -q 'select PACKAGE_mihomo' "$SSRPLUS_MK"; then
		echo "[diy-6] !! 警告：仍有 select PACKAGE_mihomo 残留，mihomo 可能仍会被编入，请人工检查"
	fi
	if grep -q 'select PACKAGE_v2ray-geoip' "$SSRPLUS_MK"; then
		echo "[diy-6] !! 警告：仍有 select PACKAGE_v2ray-geoip 残留，请人工检查"
	fi
else
	echo "[diy-6] !! 警告：$SSRPLUS_MK 不存在，mihomo / v2ray-geoip 仍会被编入固件！"
fi

echo "============================================================"
echo " diy-part5-6.6.sh 执行完毕"
echo "============================================================"
