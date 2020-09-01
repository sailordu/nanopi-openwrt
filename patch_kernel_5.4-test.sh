cd friendlywrt-rk3328
cd kernel/
git apply ../../add_fullconenat.diff
wget https://raw.githubusercontent.com/QiuSimons/R2S-OpenWrt/master/PATCH/new/main/999-unlock-1608mhz-rk3328.patch
git apply 999-unlock-1608mhz-rk3328.patch
cd ../
git clone https://github.com/coolsnowwolf/lede && cd lede/
git checkout 12d0742fd52a6fd32ffd1bd0cf58e33eb416416f
cp -a ./target/linux/generic/files/* ../kernel/
./scripts/patch-kernel.sh ../kernel target/linux/generic/backport-5.4
./scripts/patch-kernel.sh ../kernel target/linux/generic/pending-5.4
./scripts/patch-kernel.sh ../kernel target/linux/generic/hack-5.4
cd ../
wget https://github.com/torvalds/linux/raw/master/scripts/kconfig/merge_config.sh && chmod +x merge_config.sh
grep -i '_NETFILTER_\|FLOW' ../.config.override > .config.override
./merge_config.sh -m .config.override kernel/arch/arm64/configs/nanopi-r2_linux_defconfig && mv .config kernel/arch/arm64/configs/nanopi-r2_linux_defconfig

sed -i -r 's/# (CONFIG_.*_ERRATUM_.*?) is.*/\1=y/g' kernel/arch/arm64/configs/nanopi-r2_linux_defconfig
